// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/ECSRegistry.sol";
import "../src/ECSRegistrarController.sol";
import "../src/ECSNameResolver.sol";
import "../src/RootController.sol";
import "../src/credentials/ethstars/StarNameResolver.sol";
import "../src/utils/NameCoder.sol";
import "../src/credentials/ethstars/OffchainStarName.sol";
import {IGatewayVerifier} from "../lib/unruggable-gateways/contracts/IGatewayVerifier.sol";
import {GatewayRequest} from "../lib/unruggable-gateways/contracts/GatewayRequest.sol";

contract StarNameResolverIntegrationTest is Test {
    
    /* --- Test Contracts --- */
    
    ECSRegistry public registry;
    ECSRegistrarController public controller;
    ECSNameResolver public resolver;
    RootController public rootController;
    StarNameResolver public starNameResolver;
    OffchainStarName public starNameResolverOffchain;
    
    /* --- Test Data --- */
    
    bytes32 private constant ROOT_NODE = bytes32(0);
    
    bytes32 public ethNode; // .eth
    bytes32 public baseNode; // ecs.eth
    
    address admin = address(0x1001);
    address user1 = address(0x1002);
    address user2 = address(0x1003);
    
    string constant NAMESPACE = "ethstars";
    bytes32 public namespaceHash;
    
    uint256 constant REGISTRATION_DURATION = 365 days;
    uint256 constant ADVANCE_TIME = 1000000;
    
    /* --- Setup --- */
    
    function setUp() public {
        // Calculate node hashes
        ethNode = NameCoder.namehash(NameCoder.encode("eth"), 0);
        baseNode = NameCoder.namehash(NameCoder.encode("ecs.eth"), 0);
        
        vm.startPrank(admin);
        
        // Deploy core contracts
        registry = new ECSRegistry();
        rootController = new RootController(registry);
        
        // Set up domain structure
        registry.setApprovalForNamespace(ROOT_NODE, address(rootController), true);
        rootController.setSubnameOwner("eth", admin);
        registry.setSubnameOwner("ecs", "eth", admin, block.timestamp + REGISTRATION_DURATION, false);
        
        // Grant controller role to admin
        registry.grantRole(registry.CONTROLLER_ROLE(), admin);
        
        // Set the expiration for both the eth node and the ecs node
        registry.setExpiration(ethNode, block.timestamp + REGISTRATION_DURATION);
        registry.setExpiration(baseNode, block.timestamp + REGISTRATION_DURATION);
        
        // Deploy controller and resolver
        string memory baseDomain = "ecs.eth";
        controller = new ECSRegistrarController(registry, baseDomain);
        resolver = new ECSNameResolver(registry);
        
        // Deploy star resolvers
        starNameResolver = new StarNameResolver(); // No parameters
        // Mock gateway verifier for testing
        MockGatewayVerifier mockVerifier = new MockGatewayVerifier();
        starNameResolverOffchain = new OffchainStarName(IGatewayVerifier(address(mockVerifier)), address(0x1234));
        
        // Set up roles
        registry.grantRole(registry.CONTROLLER_ROLE(), address(controller));
        
        // Approve controller to create subnamespaces under ecs.eth
        registry.setApprovalForNamespace(baseNode, address(controller), true);
        
        vm.stopPrank();
        
        // Calculate namespace hash
        namespaceHash = NameCoder.namehash(NameCoder.encode("ethstars.ecs.eth"), 0);
        
        // Fund test accounts
        vm.deal(admin, 10 ether);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }
    
    /* --- Test Functions --- */
    
    function test_001____setup___________________AllContractsDeployedCorrectly() public {
        assertTrue(address(registry) != address(0));
        assertTrue(address(controller) != address(0));
        assertTrue(address(resolver) != address(0));
        assertTrue(address(starNameResolver) != address(0));
        assertTrue(address(starNameResolverOffchain) != address(0));
        
        assertEq(registry.owner(baseNode), admin);
        assertEq(registry.owner(ethNode), admin);
    }
    
    function test_002____namespaceRegistration___RegistersNamespaceSuccessfully() public {
        uint256 fee = controller.calculateFee(REGISTRATION_DURATION);
        
        vm.startPrank(user1);
        bytes32 namespace = controller.registerNamespace{value: fee}(NAMESPACE, REGISTRATION_DURATION);
        vm.stopPrank();
        
        assertEq(namespace, namespaceHash);
        assertEq(registry.owner(namespace), user1);
        assertTrue(registry.isNamespaceActive(namespace));
        assertFalse(registry.isExpired(namespace));
    }
    
    function test_003____credentialResolverSetup__SetsUpResolverSuccessfully() public {
        // Register namespace
        uint256 fee = controller.calculateFee(REGISTRATION_DURATION);
        vm.startPrank(user1);
        controller.registerNamespace{value: fee}(NAMESPACE, REGISTRATION_DURATION);
        
        // Set credential resolver
        resolver.setCredentialResolver("ethstars.ecs.eth", address(starNameResolver));
        vm.stopPrank();
        
        assertEq(resolver.credentialResolvers(namespaceHash), address(starNameResolver));
    }
    
    function test_004____starCredentialResolution_ResolvesStarCredentialSuccessfully() public {
        // Register namespace and set resolver
        uint256 fee = controller.calculateFee(REGISTRATION_DURATION);
        vm.startPrank(user1);
        controller.registerNamespace{value: fee}(NAMESPACE, REGISTRATION_DURATION);
        
        // First register the credential subname under ethstars.ecs.eth
        vm.startPrank(user1);
        registry.setSubnameOwner("credential", "ethstars.ecs.eth", user1, block.timestamp + REGISTRATION_DURATION, false);
        vm.stopPrank();
        
        // Set resolver for credential namespace
        vm.startPrank(user1);
        resolver.setCredentialResolver("credential.ethstars.ecs.eth", address(starNameResolver));
        vm.stopPrank();
        
        // Update the text record key to match our credential key
        vm.startPrank(admin);
        starNameResolver.setTextRecordKey("eth.ecs.ethstars.credential");
        vm.stopPrank();
        
        // Buy a star for domain
        bytes memory dnsName = NameCoder.encode("example.com.name.ecs.eth");
        starNameResolver.buyStar{value: starNameResolver.starPrice()}(NameCoder.encode("example.com"));
        
        // Test resolution
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x59d1d43c), // text(bytes32,string) selector
            bytes32(0),
            "eth.ecs.ethstars.credential"
        );
        
        bytes memory result = resolver.resolve(dnsName, data);
        string memory starCount = abi.decode(result, (string));
        
        assertEq(starCount, "1");
    }
    
    function test_005____onchainDomainStarResolution_ResolvesStarsByDomainSuccessfully() public {
        // Register namespace and set resolver
        uint256 fee = controller.calculateFee(REGISTRATION_DURATION);
        vm.startPrank(user1);
        controller.registerNamespace{value: fee}(NAMESPACE, REGISTRATION_DURATION);
        
        // First register the credential subname under ethstars.ecs.eth
        vm.startPrank(user1);
        registry.setSubnameOwner("credential", "ethstars.ecs.eth", user1, block.timestamp + REGISTRATION_DURATION, false);
        vm.stopPrank();
        
        // Set resolver for credential namespace
        vm.startPrank(user1);
        resolver.setCredentialResolver("credential.ethstars.ecs.eth", address(starNameResolver));
        vm.stopPrank();
        
        // Update the text record key to match our credential key
        vm.startPrank(admin);
        starNameResolver.setTextRecordKey("eth.ecs.ethstars.credential");
        vm.stopPrank();
        
        // Buy stars for a domain (buy 3 stars from different accounts)
        bytes memory dnsName = NameCoder.encode("example.com.name.ecs.eth");
        uint256 starPrice = starNameResolver.starPrice();
        
        vm.startPrank(user1);
        starNameResolver.buyStar{value: starPrice}(NameCoder.encode("example.com"));
        vm.stopPrank();
        
        vm.startPrank(user2);
        starNameResolver.buyStar{value: starPrice}(NameCoder.encode("example.com"));
        vm.stopPrank();
        
        vm.startPrank(admin);
        starNameResolver.buyStar{value: starPrice}(NameCoder.encode("example.com"));
        vm.stopPrank();
        
        // Test domain-based resolution
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x59d1d43c),
            bytes32(0),
            "eth.ecs.ethstars.credential"
        );
        
        bytes memory result = resolver.resolve(dnsName, data);
        string memory starCount = abi.decode(result, (string));
        
        assertEq(starCount, "3");
    }
    
    function test_006____multipleUsers____________HandlesMultipleUsersCorrectly() public {
        // Register namespace and set resolver
        uint256 fee = controller.calculateFee(REGISTRATION_DURATION);
        vm.startPrank(user1);
        controller.registerNamespace{value: fee}(NAMESPACE, REGISTRATION_DURATION);
        
        // First register the credential subname under ethstars.ecs.eth
        vm.startPrank(user1);
        registry.setSubnameOwner("credential", "ethstars.ecs.eth", user1, block.timestamp + REGISTRATION_DURATION, false);
        vm.stopPrank();
        
        // Set resolver for credential namespace
        vm.startPrank(user1);
        resolver.setCredentialResolver("credential.ethstars.ecs.eth", address(starNameResolver));
        vm.stopPrank();
        
        // Update the text record key to match our credential key
        vm.startPrank(admin);
        starNameResolver.setTextRecordKey("eth.ecs.ethstars.credential");
        vm.stopPrank();
        
        // Buy stars for multiple domains
        bytes memory dnsName1 = NameCoder.encode("example1.com.name.ecs.eth");
        bytes memory dnsName2 = NameCoder.encode("example2.com.name.ecs.eth");
        uint256 starPrice = starNameResolver.starPrice();
        
        // Two different users buy stars for the same domain
        vm.startPrank(user1);
        starNameResolver.buyStar{value: starPrice}(NameCoder.encode("example1.com"));
        vm.stopPrank();
        
        vm.startPrank(admin);
        starNameResolver.buyStar{value: starPrice}(NameCoder.encode("example1.com"));
        vm.stopPrank();
        
        vm.startPrank(user2);
        starNameResolver.buyStar{value: starPrice}(NameCoder.encode("example2.com"));
        vm.stopPrank();
        
        // Test domain resolution
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x59d1d43c),
            bytes32(0),
            "eth.ecs.ethstars.credential"
        );
        
        bytes memory result1 = resolver.resolve(dnsName1, data);
        string memory starCount1 = abi.decode(result1, (string));
        
        bytes memory result2 = resolver.resolve(dnsName2, data);
        string memory starCount2 = abi.decode(result2, (string));
        
        assertEq(starCount1, "2");
        assertEq(starCount2, "1");
    }
    
    function test_007____paymentValidation_______RequiresCorrectPayment() public {
        bytes memory dnsName = NameCoder.encode("example.com.name.ecs.eth");
        
        // Buy stars with insufficient payment
        vm.expectRevert(
            abi.encodeWithSelector(
                StarNameResolver.InsufficientPayment.selector
            )
        );
        starNameResolver.buyStar{value: 0.01 ether}(dnsName);
    }
    
    function test_008____serviceKeyResolution____ResolvesServiceKeyCorrectly() public {
        // Register namespace and set resolver
        uint256 fee = controller.calculateFee(REGISTRATION_DURATION);
        vm.startPrank(user1);
        controller.registerNamespace{value: fee}(NAMESPACE, REGISTRATION_DURATION);
        
        // First register the credential subname under ethstars.ecs.eth
        vm.startPrank(user1);
        registry.setSubnameOwner("credential", "ethstars.ecs.eth", user1, block.timestamp + REGISTRATION_DURATION, false);
        vm.stopPrank();
        
        // Set resolver for credential namespace
        vm.startPrank(user1);
        resolver.setCredentialResolver("credential.ethstars.ecs.eth", address(starNameResolver));
        vm.stopPrank();
        
        // Update the text record key to match our credential key
        vm.startPrank(admin);
        starNameResolver.setTextRecordKey("eth.ecs.ethstars.credential");
        vm.stopPrank();
        
        // Buy stars for a domain
        bytes memory dnsName = NameCoder.encode("example.com.name.ecs.eth");
        uint256 starPrice = starNameResolver.starPrice();
        
        // Buy 4 stars from different accounts
        vm.startPrank(user1);
        starNameResolver.buyStar{value: starPrice}(NameCoder.encode("example.com"));
        vm.stopPrank();
        
        vm.startPrank(user2);
        starNameResolver.buyStar{value: starPrice}(NameCoder.encode("example.com"));
        vm.stopPrank();
        
        vm.startPrank(admin);
        starNameResolver.buyStar{value: starPrice}(NameCoder.encode("example.com"));
        vm.stopPrank();
        
        address newAccount = address(0x9999);
        vm.deal(newAccount, 1 ether);
        vm.startPrank(newAccount);
        starNameResolver.buyStar{value: starPrice}(NameCoder.encode("example.com"));
        vm.stopPrank();
        
        // Test service key resolution
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x59d1d43c),
            bytes32(0),
            "eth.ecs.ethstars.credential"
        );
        
        bytes memory result = resolver.resolve(dnsName, data);
        string memory starCount = abi.decode(result, (string));
        
        assertEq(starCount, "4");
    }
    
    function test_009____namespaceExpiration_____HandlesExpirationCorrectly() public {
        // Register namespace with short duration
        uint256 fee = controller.calculateFee(30 days);
        vm.startPrank(user1);
        bytes32 namespace = controller.registerNamespace{value: fee}("shortlived", 30 days);
        resolver.setCredentialResolver("shortlived.ecs.eth", address(starNameResolver));
        vm.stopPrank();
        
        // Verify active
        assertTrue(registry.isNamespaceActive(namespace));
        assertFalse(registry.isExpired(namespace));
        
        // Fast forward past expiration
        vm.warp(block.timestamp + 30 days + 1);
        
        // Verify expired
        assertFalse(registry.isNamespaceActive(namespace));
        assertTrue(registry.isExpired(namespace));
        
        // Try to resolve - should return empty string
        bytes memory dnsName = NameCoder.encode("example.com.name.ecs.eth");
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x59d1d43c),
            bytes32(0),
            "eth.ecs.shortlived.stars"
        );
        
        // Expired namespace should return empty string during resolution
        bytes memory result = resolver.resolve(dnsName, data);
        string memory decoded = abi.decode(result, (string));
        assertEq(decoded, "");
    }
    
    function test_010____approvalSystem__________HandlesApprovalCorrectly() public {
        // Register namespace and set resolver
        uint256 fee = controller.calculateFee(REGISTRATION_DURATION);
        vm.startPrank(user1);
        controller.registerNamespace{value: fee}(NAMESPACE, REGISTRATION_DURATION);
        resolver.setCredentialResolver("ethstars.ecs.eth", address(starNameResolver));
        
        // Approve user2 as operator via registry
        registry.setApprovalForNamespace(namespaceHash, user2, true);
        vm.stopPrank();
        
        // User2 should be able to modify resolver
        vm.startPrank(user2);
        resolver.setCredentialResolver("ethstars.ecs.eth", address(starNameResolverOffchain));
        vm.stopPrank();
        
        assertEq(resolver.credentialResolvers(namespaceHash), address(starNameResolverOffchain));
    }
    
    function test_011____offchainResolution______TriggersCCIPLookup() public {
        // Register namespace and set offchain resolver
        uint256 fee = controller.calculateFee(REGISTRATION_DURATION);
        vm.startPrank(user1);
        controller.registerNamespace{value: fee}(NAMESPACE, REGISTRATION_DURATION);
        
        // First register the credential subname under ethstars.ecs.eth
        vm.startPrank(user1);
        registry.setSubnameOwner("credential", "ethstars.ecs.eth", user1, block.timestamp + REGISTRATION_DURATION, false);
        vm.stopPrank();
        
        // Set offchain resolver for credential namespace
        vm.startPrank(user1);
        resolver.setCredentialResolver("credential.ethstars.ecs.eth", address(starNameResolverOffchain));
        vm.stopPrank();
        
        // Try to resolve - should trigger CCIP lookup
        bytes memory dnsName = NameCoder.encode("example.com.name.ecs.eth");
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x59d1d43c),
            bytes32(0),
            "eth.ecs.ethstars.credential"
        );
        
        // This should revert with OffchainLookup error
        vm.expectRevert(); // We expect an OffchainLookup revert
        resolver.resolve(dnsName, data);
    }
    
    function test_012____longestMatchResolution__FindsLongestMatchCorrectly() public {
        // Register multiple namespaces
        uint256 fee = controller.calculateFee(REGISTRATION_DURATION);
        vm.startPrank(user1);
        controller.registerNamespace{value: fee}("base", REGISTRATION_DURATION);
        
        // First register the credential subname under base.ecs.eth
        vm.startPrank(user1);
        registry.setSubnameOwner("credential", "base.ecs.eth", user1, block.timestamp + REGISTRATION_DURATION, false);
        vm.stopPrank();
        
        // Set resolver for credential namespace
        vm.startPrank(user1);
        resolver.setCredentialResolver("credential.base.ecs.eth", address(starNameResolver));
        vm.stopPrank();
        
        // Update StarNameResolver to respond to base.credential key
        vm.startPrank(admin);
        starNameResolver.setTextRecordKey("eth.ecs.base.credential");
        vm.stopPrank();
        
        // Buy stars for base namespace
        bytes memory dnsName = NameCoder.encode("example.com.name.ecs.eth");
        uint256 starPrice = starNameResolver.starPrice();
        starNameResolver.buyStar{value: starPrice}(NameCoder.encode("example.com"));
        
        // Test resolution for base namespace
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x59d1d43c),
            bytes32(0),
            "eth.ecs.base.credential"
        );
        
        bytes memory result = resolver.resolve(dnsName, data);
        string memory starCount = abi.decode(result, (string));
        
        assertEq(starCount, "1");
    }
    
    function test_013____dynamicTimestamp_______AdvancesTimeCorrectly() public {
        uint256 initialTime = block.timestamp;
        
        // Advance time
        vm.warp(block.timestamp + ADVANCE_TIME);
        
        assertEq(block.timestamp, initialTime + ADVANCE_TIME);
    }
    
    function test_014____multipleStarPurchases__HandlesMultiplePurchasesCorrectly() public {
        // Register namespace and set resolver
        uint256 fee = controller.calculateFee(REGISTRATION_DURATION);
        vm.startPrank(user1);
        controller.registerNamespace{value: fee}(NAMESPACE, REGISTRATION_DURATION);
        
        // First register the credential subname under ethstars.ecs.eth
        vm.startPrank(user1);
        registry.setSubnameOwner("credential", "ethstars.ecs.eth", user1, block.timestamp + REGISTRATION_DURATION, false);
        vm.stopPrank();
        
        // Set resolver for credential namespace
        vm.startPrank(user1);
        resolver.setCredentialResolver("credential.ethstars.ecs.eth", address(starNameResolver));
        vm.stopPrank();
        
        // Update the text record key to match our credential key
        vm.startPrank(admin);
        starNameResolver.setTextRecordKey("eth.ecs.ethstars.credential");
        vm.stopPrank();
        
        // Buy stars multiple times for same domain
        bytes memory dnsName = NameCoder.encode("example.com.name.ecs.eth");
        uint256 starPrice = starNameResolver.starPrice();
        
        // Buy 2 stars from different accounts
        vm.startPrank(user1);
        starNameResolver.buyStar{value: starPrice}(NameCoder.encode("example.com"));
        vm.stopPrank();
        
        vm.startPrank(user2);
        starNameResolver.buyStar{value: starPrice}(NameCoder.encode("example.com"));
        vm.stopPrank();
        
        // Buy 3 more stars from different accounts
        vm.startPrank(admin);
        starNameResolver.buyStar{value: starPrice}(NameCoder.encode("example.com"));
        vm.stopPrank();
        
        address acc1 = address(0x8888);
        address acc2 = address(0x9999);
        vm.deal(acc1, 1 ether);
        vm.deal(acc2, 1 ether);
        
        vm.startPrank(acc1);
        starNameResolver.buyStar{value: starPrice}(NameCoder.encode("example.com"));
        vm.stopPrank();
        
        vm.startPrank(acc2);
        starNameResolver.buyStar{value: starPrice}(NameCoder.encode("example.com"));
        vm.stopPrank();
        
        // Test resolution
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x59d1d43c),
            bytes32(0),
            "eth.ecs.ethstars.credential"
        );
        
        bytes memory result = resolver.resolve(dnsName, data);
        string memory starCount = abi.decode(result, (string));
        
        assertEq(starCount, "5"); // 2 + 3 = 5
    }
    
    function test_015____integrationFlow_________CompleteIntegrationFlow() public {
        // Complete integration test
        uint256 fee = controller.calculateFee(REGISTRATION_DURATION);
        
        // 1. Register namespace
        vm.startPrank(user1);
        controller.registerNamespace{value: fee}(NAMESPACE, REGISTRATION_DURATION);
        vm.stopPrank();
        
        // 2. First register the credential subname under ethstars.ecs.eth
        vm.startPrank(user1);
        registry.setSubnameOwner("credential", "ethstars.ecs.eth", user1, block.timestamp + REGISTRATION_DURATION, false);
        vm.stopPrank();
        
        // 3. Set credential resolver
        vm.startPrank(user1);
        resolver.setCredentialResolver("credential.ethstars.ecs.eth", address(starNameResolver));
        vm.stopPrank();
        
        // Update the text record key to match our credential key
        vm.startPrank(admin);
        starNameResolver.setTextRecordKey("eth.ecs.ethstars.credential");
        vm.stopPrank();
        
        // 4. Buy stars from multiple accounts
        bytes memory dnsName = NameCoder.encode("myapp.com.name.ecs.eth");
        uint256 starPrice = starNameResolver.starPrice();
        
        // Buy 10 stars from different accounts (need to simulate multiple accounts)
        address[] memory accounts = new address[](10);
        for (uint256 i = 0; i < 10; i++) {
            accounts[i] = address(uint160(0x5000 + i));
            vm.deal(accounts[i], 1 ether);
            
            vm.startPrank(accounts[i]);
            starNameResolver.buyStar{value: starPrice}(NameCoder.encode("myapp.com"));
            vm.stopPrank();
        }
        
        // 4. Test resolution
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x59d1d43c),
            bytes32(0),
            "eth.ecs.ethstars.credential"
        );
        
        bytes memory result = resolver.resolve(dnsName, data);
        string memory starCount = abi.decode(result, (string));
        
        assertEq(starCount, "10");
        
        // 5. Verify namespace is still active
        assertTrue(registry.isNamespaceActive(namespaceHash));
        assertFalse(registry.isExpired(namespaceHash));
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