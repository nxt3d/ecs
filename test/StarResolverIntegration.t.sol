// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/ECSRegistry.sol";
import "../src/ECSRegistrarController.sol";
import "../src/ECSAddressResolver.sol";
import "../src/RootController.sol";
import "../src/credentials/ethstars/StarResolver.sol";
import "../src/credentials/ethstars/OffchainStarAddr.sol";
import {IGatewayVerifier} from "../lib/unruggable-gateways/contracts/IGatewayVerifier.sol";
import {GatewayRequest} from "../lib/unruggable-gateways/contracts/GatewayRequest.sol";
import "../src/utils/NameCoder.sol";

contract StarResolverIntegrationTest is Test {
    
    /* --- Test Contracts --- */
    
    ECSRegistry public registry;
    ECSRegistrarController public controller;
    ECSAddressResolver public resolver;
    RootController public rootController;
    StarResolver public starResolver;
    OffchainStarAddr public starResolverOffchain;
    
    /* --- Test Data --- */
    
    string constant SERVICE_KEY = "eth.ecs.ethstars.stars";
    uint256 constant REGISTRATION_DURATION = 365 days;
    
    // Test addresses and cointypes
    address constant TEST_ADDRESS = 0x34d79fFE0A82636ef12De45408bDF8B20c0f01e1;
    uint256 constant TEST_COINTYPE = 0x3c;
    
    // DNS encoding of "addr.ecs.eth" + terminator: 0x04+"addr"+0x03+"ecs"+0x03+"eth"+0x00
    bytes constant DNS_SUFFIX = hex"0461646472036563730365746800";

    /* --- Helper Functions --- */
    
    /**
     * @dev Create DNS-encoded name for address.cointype.addr.ecs.eth
     * @param addr The address
     * @param coinType The coin type
     * @return The DNS-encoded name
     */
    function _createDNSName(address addr, uint256 coinType) internal pure returns (bytes memory) {
        // Convert address to hex string (without 0x prefix)
        string memory addressHex = _uint256ToHexString(uint256(uint160(addr)));
        
        // Convert cointype to hex string
        string memory coinTypeHex = _uint256ToHexString(coinType);
        
        // Build dynamic part: address label + cointype label
        bytes memory addressBytes = bytes(addressHex);
        bytes memory coinTypeBytes = bytes(coinTypeHex);
        
        // Calculate total length needed
        uint256 totalLength = 1 + addressBytes.length + // address label
                             1 + coinTypeBytes.length + // cointype label  
                             1 + 4 + // "addr" label
                             1 + 3 + // "ecs" label
                             1 + 3 + // "eth" label
                             1;      // null terminator
        
        bytes memory result = new bytes(totalLength);
        uint256 offset = 0;
        
        // Address label: length + hex chars
        result[offset++] = bytes1(uint8(addressBytes.length));
        for (uint256 i = 0; i < addressBytes.length; i++) {
            result[offset++] = addressBytes[i];
        }
        
        // CoinType label: length + hex chars
        result[offset++] = bytes1(uint8(coinTypeBytes.length));
        for (uint256 i = 0; i < coinTypeBytes.length; i++) {
            result[offset++] = coinTypeBytes[i];
        }
        
        // "addr" label
        result[offset++] = bytes1(uint8(4));
        result[offset++] = bytes1(uint8(bytes1('a')));
        result[offset++] = bytes1(uint8(bytes1('d')));
        result[offset++] = bytes1(uint8(bytes1('d')));
        result[offset++] = bytes1(uint8(bytes1('r')));
        
        // "ecs" label
        result[offset++] = bytes1(uint8(3));
        result[offset++] = bytes1(uint8(bytes1('e')));
        result[offset++] = bytes1(uint8(bytes1('c')));
        result[offset++] = bytes1(uint8(bytes1('s')));
        
        // "eth" label
        result[offset++] = bytes1(uint8(3));
        result[offset++] = bytes1(uint8(bytes1('e')));
        result[offset++] = bytes1(uint8(bytes1('t')));
        result[offset++] = bytes1(uint8(bytes1('h')));
        
        // Null terminator
        result[offset++] = bytes1(uint8(0));
        
        return result;
    }

    function _addressToHexString(address addr) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(40);
        
        uint256 value = uint256(uint160(addr));
        for (uint256 i = 0; i < 20; i++) {
            uint256 byteIndex = 19 - i;
            str[i * 2] = alphabet[(value >> (byteIndex * 8 + 4)) & 0xf];
            str[i * 2 + 1] = alphabet[(value >> (byteIndex * 8)) & 0xf];
        }
        
        return string(str);
    }

    function _uint256ToHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        
        bytes memory alphabet = "0123456789abcdef";
        uint256 temp = value;
        uint256 length = 0;
        
        // Calculate length
        while (temp != 0) {
            length++;
            temp >>= 4;
        }
        
        bytes memory str = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            str[length - 1 - i] = alphabet[value & 0xf];
            value >>= 4;
        }
        
        return string(str);
    }
    
    /* --- Test Accounts --- */
    
    address public admin = address(0x1001);
    address public user1 = address(0x1002);
    address public user2 = address(0x1003);
    address public targetAddress = address(0x1004);
    
    /* --- Test State --- */
    
    bytes32 public ethstarsNamespace; // Stored namespace hash from registration
    
    /* --- Setup --- */
    
    function setUp() public {
        // Deploy core contracts from admin account
        vm.startPrank(admin);
        
        registry = new ECSRegistry();
        
        // Set up root controller
        rootController = new RootController(registry);
        registry.setApprovalForNamespace(bytes32(0), address(rootController), true);
        
        // Register .eth TLD and set ecs.eth subnode
        bytes32 ethNode = NameCoder.namehash(NameCoder.encode("eth"), 0);
        rootController.setSubnameOwner("eth", admin); // Set .eth to admin
        
        // Create ecs.eth subnode
        registry.setSubnameOwner("ecs", "eth", admin, block.timestamp + REGISTRATION_DURATION, false); // Set ecs.eth to admin
        
        // Grant controller role to admin
        registry.grantRole(registry.CONTROLLER_ROLE(), admin);
        
        // Set the expiration for both the eth node and the ecs node
        bytes32 baseNode = NameCoder.namehash(NameCoder.encode("ecs.eth"), 0);
        registry.setExpiration(ethNode, block.timestamp + REGISTRATION_DURATION);
        registry.setExpiration(baseNode, block.timestamp + REGISTRATION_DURATION);
        
        // Deploy controller and resolver
        string memory baseDomain = "ecs.eth";
        controller = new ECSRegistrarController(registry, baseDomain);
        
        // Grant controller role to controller
        registry.grantRole(registry.CONTROLLER_ROLE(), address(controller));
        
        // Approve controller to create subnamespaces under ecs.eth
        registry.setApprovalForNamespace(baseNode, address(controller), true);
        
        // Deploy resolver that uses the consolidated registry
        resolver = new ECSAddressResolver(registry);
        
        // Deploy star resolvers
        starResolver = new StarResolver();
        
        // Mock gateway verifier for testing
        MockGatewayVerifier mockVerifier = new MockGatewayVerifier();
        starResolverOffchain = new OffchainStarAddr(IGatewayVerifier(address(mockVerifier)), address(0x1234));
        
        vm.stopPrank();
        
        // Fund test accounts
        vm.deal(admin, 10 ether);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }
    
    // Identify the file being tested
    function test1000________________________________________________________________________________() public {}
    function test1100________________________STAR_RESOLVER_INTEGRATION___________________________() public {}
    function test1200________________________________________________________________________________() public {}

    /* --- Test: Register Namespace --- */
    
    function test_001____registerNamespace___________RegisterEthEcsEthstarsNamespace() public {
        vm.startPrank(user1);
        
        // Calculate fee for 1 year registration
        uint256 fee = controller.calculateFee(REGISTRATION_DURATION);
        
        // Register "ethstars" namespace under ecs.eth and store the hash
        ethstarsNamespace = controller.registerNamespace{value: fee}("ethstars", REGISTRATION_DURATION);
        
        assertEq(registry.owner(ethstarsNamespace), user1);
        assertGt(registry.getExpiration(ethstarsNamespace), block.timestamp);
        
        vm.stopPrank();
    }
    
    /* --- Test: Register Credential Resolver --- */
    
    function test_002____setCredentialResolver___RegisterStarResolverForNamespace() public {
        // First register namespace
        test_001____registerNamespace___________RegisterEthEcsEthstarsNamespace();
        
        vm.startPrank(user1); // user1 owns the ethstars namespace
        
        // First register the credential subname under ethstars.ecs.eth
        registry.setSubnameOwner("credential", "ethstars.ecs.eth", user1, block.timestamp + REGISTRATION_DURATION, false);
        
        // Register onchain star resolver for the credential namespace
        resolver.setCredentialResolver("credential.ethstars.ecs.eth", address(starResolver));
        
        // Update the text record key to match our credential key
        vm.startPrank(admin);
        starResolver.setTextRecordKey("eth.ecs.ethstars.credential");
        vm.stopPrank();
        
        // Verify credential resolver is registered
        bytes32 credentialNamespaceHash = NameCoder.namehash(NameCoder.encode("credential.ethstars.ecs.eth"), 0);
        assertEq(resolver.credentialResolvers(credentialNamespaceHash), address(starResolver));
        
        vm.stopPrank();
    }
    
    /* --- Test: Onchain Star Resolution --- */
    
    function test_003____onchainStarResolution_______ResolveTwoStarsOnchain() public {
        // Register namespace and credential resolver
        test_002____setCredentialResolver___RegisterStarResolverForNamespace();
        
        // User1 buys a star for TEST_ADDRESS on TEST_COINTYPE
        vm.startPrank(user1);
        starResolver.buyStar{value: 0.000001 ether}(TEST_ADDRESS, TEST_COINTYPE);
        vm.stopPrank();
        
        // User2 buys another star for the same address/cointype
        vm.startPrank(user2);
        starResolver.buyStar{value: 0.000001 ether}(TEST_ADDRESS, TEST_COINTYPE);
        vm.stopPrank();
        
        // Test credential resolution via resolver
        vm.startPrank(admin);
        
        // Create DNS-encoded name for TEST_ADDRESS.TEST_COINTYPE.addr.ecs.eth
        bytes memory dnsName = _createDNSName(TEST_ADDRESS, TEST_COINTYPE);
        
        // Test resolving star count with service key
        bytes memory textCalldata = abi.encodeWithSelector(
            bytes4(0x59d1d43c), // text(bytes32,string) selector
            bytes32(0), // dummy node
            "eth.ecs.ethstars.credential"
        );
        
        bytes memory result = resolver.resolve(dnsName, textCalldata);
        string memory starCount = abi.decode(result, (string));
        
        assertEq(starCount, "2"); // Should have 2 stars
        
        // Verify direct access to mapping
        assertEq(starResolver.starCounts(TEST_ADDRESS, TEST_COINTYPE), 2);
        
        vm.stopPrank();
    }
    
    /* --- Test: Offchain Star Resolution --- */
    
    function test_004____offchainStarResolution______TriggerOffchainLookupError() public {
        // Register namespace
        test_001____registerNamespace___________RegisterEthEcsEthstarsNamespace();
        
        vm.startPrank(user1); // user1 owns the ethstars namespace
        
        // First register the credential subname under ethstars.ecs.eth
        registry.setSubnameOwner("credential", "ethstars.ecs.eth", user1, block.timestamp + REGISTRATION_DURATION, false);
        
        // Register offchain star resolver for the credential namespace
        resolver.setCredentialResolver("credential.ethstars.ecs.eth", address(starResolverOffchain));
        
        vm.stopPrank();
        
        // Create DNS-encoded name for TEST_ADDRESS.TEST_COINTYPE.addr.ecs.eth
        bytes memory dnsName = _createDNSName(TEST_ADDRESS, TEST_COINTYPE);
        
        // Test resolving - should trigger OffchainLookup
        bytes memory textCalldata = abi.encodeWithSelector(
            bytes4(0x59d1d43c), // text(bytes32,string) selector
            bytes32(0), // dummy node
            "eth.ecs.ethstars.credential" // Use the new credential key format
        );
        
        // Catch the OffchainLookup error and extract callback data
        try resolver.resolve(dnsName, textCalldata) {
            revert("Expected OffchainLookup error");
        } catch (bytes memory errorData) {
            // Decode the OffchainLookup error
            bytes4 errorSelector = bytes4(errorData);
            // OffchainLookup selector is 0x556f1830
            if (errorSelector == bytes4(keccak256(bytes("OffchainLookup(address,string[],bytes,bytes4,bytes)")))) {
                // Extract the callback parameters from the error (skip 4-byte selector)
                bytes memory cleanErrorData = new bytes(errorData.length - 4);
                for (uint256 i = 0; i < cleanErrorData.length; i++) {
                    cleanErrorData[i] = errorData[i + 4];
                }
                
                (, , , , bytes memory extraData) = abi.decode(
                    cleanErrorData, 
                    (address, string[], bytes, bytes4, bytes)
                );
                
                // Simulate gateway response - pretend gateway returned "5" stars
                bytes memory gatewayResponse = abi.encode("5");
                
                // Test the callback validation by calling the resolver's success callback directly
                // Pass the extraData from the OffchainLookup error to maintain context
                bytes memory callbackResult = resolver.onCredentialSuccess(
                    gatewayResponse,
                    extraData
                );
                
                // Decode and verify the result
                string memory starCount = abi.decode(callbackResult, (string));
                assertEq(starCount, "5");
            } else {
                revert("Expected OffchainLookup error");
            }
        }
    }
    
    /* --- Test: Star Payment Validation --- */
    
    function test_005____starPaymentValidation_______ValidateExactPaymentRequired() public {
        // Try to buy star with incorrect payment
        vm.startPrank(user1);
        
        // Too little payment
        vm.expectRevert(StarResolver.InsufficientPayment.selector);
        starResolver.buyStar{value: 0.0005 ether}(TEST_ADDRESS, TEST_COINTYPE);
        
        // Too much payment
        vm.expectRevert(StarResolver.InsufficientPayment.selector);
        starResolver.buyStar{value: 0.002 ether}(TEST_ADDRESS, TEST_COINTYPE);
        
        // Correct payment should work
        starResolver.buyStar{value: 0.000001 ether}(TEST_ADDRESS, TEST_COINTYPE);
        
        // Verify the star was bought
        assertEq(starResolver.starCounts(TEST_ADDRESS, TEST_COINTYPE), 1);
        
        // Same user trying to buy another star for same address/cointype should fail (restriction)
        vm.expectRevert(StarResolver.AlreadyStarred.selector);
        starResolver.buyStar{value: 0.000001 ether}(TEST_ADDRESS, TEST_COINTYPE);
        
        vm.stopPrank();
    }
    
    /* --- Test: Multiple Stars --- */
    
    function test_006____multipleStars_______________TrackMultipleUsersStarring() public {
        address addr1 = address(0x1111);
        address addr2 = address(0x2222);
        uint256 cointype1 = 0x3c;  // Ethereum
        uint256 cointype2 = 0x89;  // Polygon
        
        // User1 buys stars for different address/cointype combinations
        vm.startPrank(user1);
        starResolver.buyStar{value: 0.000001 ether}(addr1, cointype1);
        starResolver.buyStar{value: 0.000001 ether}(addr1, cointype2);
        starResolver.buyStar{value: 0.000001 ether}(addr2, cointype1);
        vm.stopPrank();
        
        // User2 buys more stars for the same combinations
        vm.startPrank(user2);
        starResolver.buyStar{value: 0.000001 ether}(addr1, cointype1); // Should increment
        starResolver.buyStar{value: 0.000001 ether}(addr2, cointype2); // New combination
        vm.stopPrank();
        
        // Verify star counts for each address/cointype combination
        assertEq(starResolver.starCounts(addr1, cointype1), 2); // 2 stars
        assertEq(starResolver.starCounts(addr1, cointype2), 1); // 1 star
        assertEq(starResolver.starCounts(addr2, cointype1), 1); // 1 star
        assertEq(starResolver.starCounts(addr2, cointype2), 1); // 1 star
        
        // Test credential function with DNS names
        bytes memory dnsName1 = _createDNSName(addr1, cointype1);
        string memory starCount1 = starResolver.credential(dnsName1, "eth.ecs.ethstars.stars");
        assertEq(starCount1, "2");
        
        bytes memory dnsName2 = _createDNSName(addr2, cointype2);
        string memory starCount2 = starResolver.credential(dnsName2, "eth.ecs.ethstars.stars");
        assertEq(starCount2, "1");
        
        // Test wrong key returns empty string
        string memory wrongKey = starResolver.credential(dnsName1, "wrong.key");
        assertEq(wrongKey, "");
    }
    
    /* --- Test: Service Key Resolution --- */
    
    function test_007____serviceKeyResolution________ResolveEthEcsEthstarsStarsKey() public {
        // Register namespace and credential resolver
        test_002____setCredentialResolver___RegisterStarResolverForNamespace();
        
        // Test that the service key resolves correctly through the resolver
        vm.startPrank(admin);
        
        // Create DNS-encoded name for a fresh address/cointype combination
        bytes memory dnsName = _createDNSName(TEST_ADDRESS, TEST_COINTYPE);
        
        // Test resolving with service key
        bytes memory textCalldata = abi.encodeWithSelector(
            bytes4(0x59d1d43c), // text(bytes32,string) selector
            bytes32(0), // dummy node
            "eth.ecs.ethstars.credential"
        );
        
        // This should find the credential resolver and return "0" for new address/cointype
        bytes memory result = resolver.resolve(dnsName, textCalldata);
        string memory credential = abi.decode(result, (string));
        assertEq(credential, "0");
        
        vm.stopPrank();
    }
    
    /* --- Test: Namespace Expiration --- */
    
    function test_008____namespaceExpiration_________PreventActionAfterExpiration() public {
        // Register namespace
        test_001____registerNamespace___________RegisterEthEcsEthstarsNamespace();
        
        // Fast forward past expiration
        vm.warp(block.timestamp + REGISTRATION_DURATION + 1);
        
        vm.startPrank(user1); // user1 owns the ethstars namespace
        
        // Verify the ethstars namespace has expired
        assertTrue(registry.isExpired(ethstarsNamespace)); // Use registry's isExpired method
        assertEq(registry.owner(ethstarsNamespace), user1); // Registry still shows owner
        
        // Now the ECSResolver checks expiration and should prevent credential resolver registration
        vm.expectRevert(abi.encodeWithSelector(ECSAddressResolver.NamespaceExpired.selector, ethstarsNamespace));
        resolver.setCredentialResolver("ethstars.ecs.eth", address(starResolver));
        
        vm.stopPrank();
        
        // Also test that resolution queries fail for expired namespaces
        // First register a credential resolver before expiration to test the query failure
        vm.warp(block.timestamp - REGISTRATION_DURATION - 2); // Go back before expiration
        vm.startPrank(user1); // user1 owns the ethstars namespace
        resolver.setCredentialResolver("ethstars.ecs.eth", address(starResolver));
        vm.stopPrank();
        
        // Fast forward past expiration again
        vm.warp(block.timestamp + REGISTRATION_DURATION + 1);
        
        // Now test that resolution queries return empty string for expired namespace
        bytes memory dnsName = _createDNSName(TEST_ADDRESS, TEST_COINTYPE);
        bytes memory textCalldata = abi.encodeWithSelector(
            bytes4(0x59d1d43c), // text(bytes32,string) selector
            bytes32(0), // dummy node
            SERVICE_KEY // This will match the expired ethstars namespace
        );
        
        // Expired namespace should return empty string during resolution
        bytes memory result = resolver.resolve(dnsName, textCalldata);
        string memory decoded = abi.decode(result, (string));
        assertEq(decoded, "");
    }
    
    /* --- Test: Approval System --- */
    
    function test_009____approvalSystem______________AllowApprovedUserToRegisterResolver() public {
        // Register namespace
        test_001____registerNamespace___________RegisterEthEcsEthstarsNamespace();
        
        vm.startPrank(user1); // user1 owns the ethstars namespace
        
        // Approve user2 to manage the namespace via registry
        registry.setApprovalForNamespace(ethstarsNamespace, user2, true);
        
        vm.stopPrank();
        
        // User2 should now be able to register credential resolver (approved by user1)
        vm.startPrank(user2);
        resolver.setCredentialResolver("ethstars.ecs.eth", address(starResolver));
        assertEq(resolver.credentialResolvers(ethstarsNamespace), address(starResolver));
        vm.stopPrank();
        
        // Admin should not be able to register credential resolver (not approved)
        vm.startPrank(admin);
        vm.expectRevert();
        resolver.setCredentialResolver("ethstars.ecs.eth", address(starResolverOffchain));
        vm.stopPrank();
    }
}

/**
 * @title MockGatewayVerifier
 * @dev Mock implementation of IGatewayVerifier for testing
 */
contract MockGatewayVerifier is IGatewayVerifier {
    function getLatestContext() external pure returns (bytes memory) {
        // Mock implementation - return empty context
        return "";
    }
    
    function gatewayURLs() external pure returns (string[] memory) {
        // Mock implementation - return mock gateway URLs
        string[] memory urls = new string[](1);
        urls[0] = "https://base-sepolia.gateway.unruggable.com";
        return urls;
    }
    
    function getStorageValues(
        bytes memory context,
        GatewayRequest memory req,
        bytes memory proof
    ) external pure returns (bytes[] memory values, uint8 exitCode) {
        // Mock implementation - return mock values
        // For testing, we'll return a single value (2 stars)
        values = new bytes[](1);
        values[0] = abi.encode(uint256(2)); // Mock result: 2 stars
        exitCode = 0; // Success
    }
} 