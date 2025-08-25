// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/ECSRegistry.sol";
import "../src/ECSRegistrarController.sol";
import "../src/ECSAddressResolver.sol";
import "../src/RootController.sol";
import "../src/ICredentialResolver.sol";
import {OffchainLookup} from "../src/utils/EIP3668.sol";
import {NameCoder} from "../src/utils/NameCoder.sol";

// Mock credential resolver for testing
contract MockCredentialResolver is ICredentialResolver {
    string private _defaultResponse;
    bool private _shouldRevert;
    bool private _useOffchain;
    string[] private _urls;
    
    constructor(string memory defaultResponse, bool shouldRevert, bool useOffchain) {
        _defaultResponse = defaultResponse;
        _shouldRevert = shouldRevert;
        _useOffchain = useOffchain;
        _urls = new string[](1);
        _urls[0] = "https://api.example.com/";

    }
    
    function setDefaultResponse(string memory response) external {
        _defaultResponse = response;
    }
    
    function setShouldRevert(bool shouldRevert) external {
        _shouldRevert = shouldRevert;
    }
    
    function setUseOffchain(bool useOffchain) external {
        _useOffchain = useOffchain;
    }
    
    function credential(bytes calldata name, string calldata _credential) external view override returns (string memory) {
        if (_shouldRevert) {
            revert("Mock revert");
        }
        
        if (_useOffchain) {
            // Trigger OffchainLookup
            revert OffchainLookup(
                address(0x1234),
                _urls,
                abi.encodeWithSelector(this.credential.selector, name, _credential),
                this.credentialCallback.selector,
                abi.encode(name, _credential)
            );
        }
        
        return _defaultResponse;
    }
    
    function credentialCallback(bytes calldata response, bytes calldata extraData) external pure returns (string memory) {
        // Simple mock callback - just return decoded response
        return abi.decode(response, (string));
    }
    
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(ICredentialResolver).interfaceId;
    }
}

contract ECSAddressResolverTest is Test {
    /* --- Constants --- */
    
    bytes32 private constant ROOT_NAMESPACE = bytes32(0);
    bytes32 private constant ETH_LABEL = keccak256(bytes("eth"));
    bytes32 private constant ECS_LABEL = keccak256(bytes("ecs"));
    
    uint256 private constant REGISTRATION_DURATION = 365 days;
    uint256 private constant SHORT_DURATION = 31 days;
    
    /* --- Test Accounts --- */
    
    address admin = address(0x1001);
    address user1 = address(0x1002);
    address user2 = address(0x1003);
    address operator1 = address(0x1004);
    address operator2 = address(0x1005);
    
    /* --- Contract Variables --- */
    
    ECSRegistry public registry;
    RootController public rootController;
    ECSRegistrarController public controller;
    ECSAddressResolver public resolver;
    
    MockCredentialResolver public mockResolver1;
    MockCredentialResolver public mockResolver2;
    MockCredentialResolver public mockResolver3;
    MockCredentialResolver public mockResolver4;
    MockCredentialResolver public mockResolver5;
    
    /* --- Domain Variables --- */
    
    bytes32 public ethNode;
    bytes32 public baseNode;
    bytes32 public label1Node;
    bytes32 public namespace1Hash;
    bytes32 public namespace2Hash;
    bytes32 public namespace3Hash;
    bytes32 public addrNamespaceHash;
    
    /* --- DNS Encoding Helpers --- */
    
    /**
     * @dev Create a DNS-encoded name for address+cointype format
     * Format: hexaddress.hexcointype.addr.ecs.eth
     */
    function _createAddressDNSName(address targetAddress, uint256 coinType) internal pure returns (bytes memory) {
        // Convert address to hex string (without 0x prefix)
        string memory addressHex = _addressToHexString(targetAddress);
        string memory coinTypeHex = _uint256ToHexString(coinType);
        
        // Create labels
        bytes memory addressLabel = bytes(addressHex);
        bytes memory coinTypeLabel = bytes(coinTypeHex);
        bytes memory addrLabel = bytes("addr");
        bytes memory ecsLabel = bytes("ecs");
        bytes memory ethLabel = bytes("eth");
        
        // Calculate total length: length_bytes + actual_data for each label + terminator
        uint256 totalLength = 1 + addressLabel.length + 1 + coinTypeLabel.length + 1 + addrLabel.length + 1 + ecsLabel.length + 1 + ethLabel.length + 1;
        
        bytes memory result = new bytes(totalLength);
        uint256 offset = 0;
        
        // Address label
        result[offset++] = bytes1(uint8(addressLabel.length));
        for (uint256 i = 0; i < addressLabel.length; i++) {
            result[offset++] = addressLabel[i];
        }
        
        // Cointype label
        result[offset++] = bytes1(uint8(coinTypeLabel.length));
        for (uint256 i = 0; i < coinTypeLabel.length; i++) {
            result[offset++] = coinTypeLabel[i];
        }
        
        // addr label
        result[offset++] = bytes1(uint8(addrLabel.length));
        for (uint256 i = 0; i < addrLabel.length; i++) {
            result[offset++] = addrLabel[i];
        }
        
        // ecs label
        result[offset++] = bytes1(uint8(ecsLabel.length));
        for (uint256 i = 0; i < ecsLabel.length; i++) {
            result[offset++] = ecsLabel[i];
        }
        
        // eth label
        result[offset++] = bytes1(uint8(ethLabel.length));
        for (uint256 i = 0; i < ethLabel.length; i++) {
            result[offset++] = ethLabel[i];
        }
        
        // Terminator
        result[offset] = 0x00;
        
        return result;
    }
    
    function _addressToHexString(address addr) internal pure returns (string memory) {
        uint256 value = uint256(uint160(addr));
        return _uint256ToHexString(value);
    }
    
    function _uint256ToHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 16;
        }
        
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = _hexChar(uint8(value & 0xf));
            value /= 16;
        }
        
        return string(buffer);
    }
    
    function _hexChar(uint8 digit) internal pure returns (bytes1) {
        if (digit < 10) {
            return bytes1(uint8(48 + digit)); // '0' to '9'
        } else {
            return bytes1(uint8(87 + digit)); // 'a' to 'f'
        }
    }
    
    /* --- Setup --- */
    
    function setUp() public {
        // Calculate node hashes using NameCoder for consistency
        ethNode = NameCoder.namehash(NameCoder.encode("eth"), 0);
        baseNode = NameCoder.namehash(NameCoder.encode("ecs.eth"), 0);
        label1Node = NameCoder.namehash(NameCoder.encode("label1.ecs.eth"), 0);
        
        // Deploy contracts
        vm.startPrank(admin);
        registry = new ECSRegistry();
        rootController = new RootController(registry);
        
        // Set up domain structure using NameCoder consistently
        registry.setApprovalForNamespace(ROOT_NAMESPACE, address(rootController), true);
        rootController.setSubnameOwner("eth", admin);
        registry.setSubnameOwner("ecs", "eth", admin, block.timestamp + REGISTRATION_DURATION, false);

        // set the admin as a controller
        registry.grantRole(registry.CONTROLLER_ROLE(), admin);

        // set the expiration for both the eth node and the ecs node
        registry.setExpiration(ethNode, block.timestamp + REGISTRATION_DURATION);
        registry.setExpiration(baseNode, block.timestamp + REGISTRATION_DURATION);
        
        // Deploy controller and resolver with consolidated architecture
        string memory baseDomain = "ecs.eth";
        controller = new ECSRegistrarController(registry, baseDomain);
        resolver = new ECSAddressResolver(registry);
        
        // Set up roles
        registry.grantRole(registry.CONTROLLER_ROLE(), address(controller));
        
        // Approve controller to create subnamespaces under ecs.eth
        registry.setApprovalForNamespace(baseNode, address(controller), true);
        
        vm.stopPrank();
        
        // Fund test accounts before registering namespaces
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        
        // Register namespaces for testing
        uint256 fee = controller.calculateFee(REGISTRATION_DURATION);
        
        vm.startPrank(user1);
        // the user buys the namespace label1.ecs.eth
        namespace1Hash = controller.registerNamespace{value: fee}("label1", REGISTRATION_DURATION);
        // Register additional namespaces for complex tests
        namespace2Hash = controller.registerNamespace{value: fee}("label2", REGISTRATION_DURATION);
        vm.stopPrank();
        
        // Register additional namespaces for complex tests
        vm.startPrank(user2);
        namespace3Hash = controller.registerNamespace{value: fee}("label3", REGISTRATION_DURATION);
        vm.stopPrank();

        // Deploy mock credential resolvers
        mockResolver1 = new MockCredentialResolver("mock-response-1", false, false);  // Normal response
        mockResolver2 = new MockCredentialResolver("mock-response-2", false, false);  // Normal response
        mockResolver3 = new MockCredentialResolver("mock-response-3", false, false);  // Normal response
        mockResolver4 = new MockCredentialResolver("mock-offchain", false, true);   // Offchain lookup
        mockResolver5 = new MockCredentialResolver("mock-revert", true, false);   // Should revert


    }
    
    /* --- Test Dividers --- */
    
    function test1000________________________________________________________________________________() public pure {}
    function test1100____________________ECS_ADDRESS_RESOLVER_TESTS____________________________() public pure {}
    function test1200________________________________________________________________________________() public pure {}
    
    /* --- Constructor Tests --- */
    
    function test_001____constructor_________________InitializesCorrectly() public view {
        assertEq(address(resolver.registry()), address(registry));
    }
    

    
    /* --- Credential Resolver Registration Tests --- */
    
    function test_006____setCredentialResolver_______SetsResolverSuccessfully() public {
        vm.startPrank(user1);
        
        vm.expectEmit(true, true, false, true);
        emit ECSAddressResolver.CredentialResolverRegistered(namespace1Hash, "label1.ecs.eth", address(mockResolver1));
        resolver.setCredentialResolver("label1.ecs.eth", address(mockResolver1));
        
        vm.stopPrank();
        
        assertEq(resolver.credentialResolvers(namespace1Hash), address(mockResolver1));
    }
    
    function test_007____setCredentialResolver_______AllowsApprovedOperator() public {
        // Approve operator via registry
        vm.startPrank(user1);
        registry.setApprovalForNamespace(namespace1Hash, operator1, true);
        vm.stopPrank();
        
        // Operator sets resolver
        vm.startPrank(operator1);
        resolver.setCredentialResolver("label1.ecs.eth", address(mockResolver1));
        vm.stopPrank();
        
        assertEq(resolver.credentialResolvers(namespace1Hash), address(mockResolver1));
    }
    
    function test_008____setCredentialResolver_______RevertsForUnauthorized() public {
        vm.startPrank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                ECSAddressResolver.UnauthorizedNamespaceAccess.selector,
                user2,
                namespace1Hash
            )
        );
        resolver.setCredentialResolver("label1.ecs.eth", address(mockResolver1));
        vm.stopPrank();
    }
    
    function test_009____setCredentialResolver_______AllowsZeroAddressToRemove() public {
        // First set a resolver
        vm.startPrank(user1);
        resolver.setCredentialResolver("label1.ecs.eth", address(mockResolver1));
        assertEq(resolver.credentialResolvers(namespace1Hash), address(mockResolver1));
        
        // Now set to zero address to remove
        vm.expectEmit(true, false, false, true);
        emit ECSAddressResolver.CredentialResolverRemoved(namespace1Hash, "label1.ecs.eth");
        resolver.setCredentialResolver("label1.ecs.eth", address(0));
        vm.stopPrank();
        
        assertEq(resolver.credentialResolvers(namespace1Hash), address(0));
    }
    
    function test_010____setCredentialResolver_______RevertsForExpiredNamespace() public {
        // Register namespace with short duration
        uint256 fee = controller.calculateFee(SHORT_DURATION);
        vm.startPrank(user1);
        bytes32 shortNamespace = controller.registerNamespace{value: fee}("shortlived", SHORT_DURATION);
        vm.stopPrank();
        
        // Fast forward past expiration
        vm.warp(block.timestamp + SHORT_DURATION + 1);
        
        // Try to set resolver for expired namespace
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ECSAddressResolver.NamespaceExpired.selector,
                shortNamespace
            )
        );
        resolver.setCredentialResolver("shortlived.ecs.eth", address(mockResolver1));
        vm.stopPrank();
    }
    
    /* --- Credential Resolver Update Tests --- */
    
    function test_011____setCredentialResolver_______UpdatesResolverSuccessfully() public {
        // First set a resolver
        vm.startPrank(user1);
        resolver.setCredentialResolver("label1.ecs.eth", address(mockResolver1));
        vm.stopPrank();
        
        assertEq(resolver.credentialResolvers(namespace1Hash), address(mockResolver1));
        
        // Update to a different resolver
        vm.startPrank(user1);
        vm.expectEmit(true, true, false, true);
        emit ECSAddressResolver.CredentialResolverRegistered(namespace1Hash, "label1.ecs.eth", address(mockResolver2));
        resolver.setCredentialResolver("label1.ecs.eth", address(mockResolver2));
        vm.stopPrank();
        
        assertEq(resolver.credentialResolvers(namespace1Hash), address(mockResolver2));
    }
    
    function test_012____setCredentialResolver_______AllowsApprovedOperatorToRemove() public {
        // Set resolver and approve operator via registry
        vm.startPrank(user1);
        resolver.setCredentialResolver("label1.ecs.eth", address(mockResolver1));
        registry.setApprovalForNamespace(namespace1Hash, operator1, true);
        vm.stopPrank();
        
        // Operator removes resolver
        vm.startPrank(operator1);
        vm.expectEmit(true, false, false, true);
        emit ECSAddressResolver.CredentialResolverRemoved(namespace1Hash, "label1.ecs.eth");
        resolver.setCredentialResolver("label1.ecs.eth", address(0));
        vm.stopPrank();
        
        assertEq(resolver.credentialResolvers(namespace1Hash), address(0));
    }
    
    function test_013____setCredentialResolver_______RevertsForUnauthorizedUpdate() public {
        // Set resolver
        vm.startPrank(user1);
        resolver.setCredentialResolver("label1.ecs.eth", address(mockResolver1));
        vm.stopPrank();
        
        // User2 tries to update (should fail)
        vm.startPrank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                ECSAddressResolver.UnauthorizedNamespaceAccess.selector,
                user2,
                namespace1Hash
            )
        );
        resolver.setCredentialResolver("label1.ecs.eth", address(mockResolver2));
        vm.stopPrank();
    }
    
    function test_014____setCredentialResolver_______RevertsForExpiredNamespaceUpdate() public {
        // Register and set resolver for short namespace
        uint256 fee = controller.calculateFee(SHORT_DURATION);
        vm.startPrank(user1);
        bytes32 shortNamespace = controller.registerNamespace{value: fee}("shortlived", SHORT_DURATION);
        resolver.setCredentialResolver("shortlived.ecs.eth", address(mockResolver1));
        vm.stopPrank();
        
        // Fast forward past expiration
        vm.warp(block.timestamp + SHORT_DURATION + 1);
        
        // Try to update resolver (should fail)
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ECSAddressResolver.NamespaceExpired.selector,
                shortNamespace
            )
        );
        resolver.setCredentialResolver("shortlived.ecs.eth", address(mockResolver2));
        vm.stopPrank();
    }
    
    /* --- Resolve Function Tests --- */
    
    function test_015____resolve_____________________ResolvesWithSingleNamespace() public {

        // First register the credential subname under label1.ecs.eth
        vm.startPrank(user1);
        registry.setSubnameOwner("credential", "label1.ecs.eth", user1, block.timestamp + REGISTRATION_DURATION, false);
        vm.stopPrank();

        // Set up resolver for credential namespace
        vm.startPrank(user1);
        resolver.setCredentialResolver("credential.label1.ecs.eth", address(mockResolver1));  // Use normal response resolver
        vm.stopPrank();
        
        // Test resolution
        bytes memory name = _createAddressDNSName(address(0x1234), 0x3c);
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x59d1d43c), // text(bytes32,string) selector
            bytes32(0), // dummy node hash (ignored)
            "eth.ecs.label1.credential"
        );
        
        bytes memory result = resolver.resolve(name, data);
        string memory decodedResult = abi.decode(result, (string));
        assertEq(decodedResult, "mock-response-1");
        // WE should resolve the last credential resolver because it is the longest matching namespace
    }
    
    function test_016____resolve_____________________FindsLongestMatchingNamespace() public {

        // First register the credential subname under label1.ecs.eth
        vm.startPrank(user1);
        registry.setSubnameOwner("credential", "label1.ecs.eth", user1, block.timestamp + REGISTRATION_DURATION, false);
        vm.stopPrank();

        // prank admin
        vm.startPrank(admin);
        // on the ECSAddressResolver, set the credential resolver for eth and ecs.eth
        resolver.setCredentialResolver("ecs.eth", address(mockResolver2));
        resolver.setCredentialResolver("eth", address(mockResolver1));
        vm.stopPrank();

        // Set up resolver for credential namespace
        vm.startPrank(user1);
        resolver.setCredentialResolver("credential.label1.ecs.eth", address(mockResolver1));  // Use normal response resolver
        vm.stopPrank();
        
        // Test resolution
        bytes memory name = _createAddressDNSName(address(0x1234), 0x3c);
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x59d1d43c), // text(bytes32,string) selector
            bytes32(0), // dummy node hash (ignored)
            "eth.ecs.label1.credential"
        );
        
        bytes memory result = resolver.resolve(name, data);
        string memory decodedResult = abi.decode(result, (string));
        assertEq(decodedResult, "mock-response-1");
        // WE should resolve the last credential resolver because it is the longest matching namespace
    }

    function test_017____resolve_____________________FindsLongestMatchingNamespaceECSNode() public {

        // First register the credential subname under label1.ecs.eth
        vm.startPrank(user1);
        registry.setSubnameOwner("credential", "label1.ecs.eth", user1, block.timestamp + REGISTRATION_DURATION, false);
        vm.stopPrank();

        // prank admin
        vm.startPrank(admin);
        // on the ECSAddressResolver, set the credential resolver for eth and ecs.eth
        resolver.setCredentialResolver("ecs.eth", address(mockResolver1));  // Use normal response resolver
        resolver.setCredentialResolver("eth", address(mockResolver2));
        vm.stopPrank();

        // Set up resolver for credential namespace
        vm.startPrank(user1);
        resolver.setCredentialResolver("credential.label1.ecs.eth", address(mockResolver1));  // Use normal response resolver
        vm.stopPrank();

        // Test resolution
        bytes memory name = _createAddressDNSName(address(0x1234), 0x3c);
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x59d1d43c), // text(bytes32,string) selector
            bytes32(0), // dummy node hash (ignored)
            "eth.ecs.label1.credential"
        );
        
        bytes memory result = resolver.resolve(name, data);
        string memory decodedResult = abi.decode(result, (string));
        assertEq(decodedResult, "mock-response-1");
        // WE should resolve the last credential resolver because it is the longest matching namespace
    }

    function test_018____resolve_____________________FindsLongestMatchingNamespaceETHNode() public {

        // First register the credential subname under label1.ecs.eth
        vm.startPrank(user1);
        registry.setSubnameOwner("credential", "label1.ecs.eth", user1, block.timestamp + REGISTRATION_DURATION, false);
        vm.stopPrank();

        // prank admin
        vm.startPrank(admin);
        // on the ECSAddressResolver, set the credential resolver for eth and ecs.eth
        resolver.setCredentialResolver("eth", address(mockResolver1));  // Use normal response resolver
        vm.stopPrank();

        // Set up resolver for credential namespace
        vm.startPrank(user1);
        resolver.setCredentialResolver("credential.label1.ecs.eth", address(mockResolver1));  // Use normal response resolver
        vm.stopPrank();

        // Test resolution
        bytes memory name = _createAddressDNSName(address(0x1234), 0x3c);
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x59d1d43c), // text(bytes32,string) selector
            bytes32(0), // dummy node hash (ignored)
            "eth.ecs.label1.credential"
        );
        
        bytes memory result = resolver.resolve(name, data);
        string memory decodedResult = abi.decode(result, (string));
        assertEq(decodedResult, "mock-response-1");
        // WE should resolve the last credential resolver because it is the longest matching namespace
    }
    
    function test_019____resolve_____________________ReturnsEmptyForNoMatch() public {
 
        // Test resolution
        bytes memory name = _createAddressDNSName(address(0x1234), 0x3c);
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x59d1d43c), // text(bytes32,string) selector
            bytes32(0), // dummy node hash (ignored)
            "eth.ecs.label1.credential"
        );
        
        bytes memory result = resolver.resolve(name, data);
        string memory decodedResult = abi.decode(result, (string));
        assertEq(decodedResult, "");
        // WE should resolve the last credential resolver because it is the longest matching namespace
    }
    
    function test_020____resolve_____________________RevertsForUnsupportedFunction() public {
        // Set up resolver
        vm.startPrank(user1);
        resolver.setCredentialResolver("label1.ecs.eth", address(mockResolver1));  // Use normal response resolver
        vm.stopPrank();
        
        // Test with unsupported function selector
        bytes memory name = _createAddressDNSName(address(0x1234), 0x3c);
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x12345678), // Invalid selector
            bytes32(0),
            "label1.ecs.myapp"
        );
        
        vm.expectRevert(abi.encodeWithSignature("UnsupportedFunction(bytes4)", bytes4(0x12345678)));
        resolver.resolve(name, data);
    }
    
    function test_021____resolve_____________________RevertsForExpiredNamespace() public {
        // Register short namespace and set resolver
        uint256 fee = controller.calculateFee(SHORT_DURATION);
        vm.startPrank(user1);
        bytes32 shortNamespace = controller.registerNamespace{value: fee}("shortlived", SHORT_DURATION);
        resolver.setCredentialResolver("shortlived.ecs.eth", address(mockResolver1));  // Use normal response resolver
        vm.stopPrank();
        
        // Fast forward past expiration
        vm.warp(block.timestamp + SHORT_DURATION + 1);
        
        // Try to resolve (should fail)
        bytes memory name = _createAddressDNSName(address(0x1234), 0x3c);
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x59d1d43c),
            bytes32(0),
            "shortlived.ecs.shortlived"
        );

        // an expired just returns empty string
        bytes memory result = resolver.resolve(name, data);
        string memory decodedResult = abi.decode(result, (string));
        assertEq(decodedResult, "");
    }
    
    function test_020____resolve_____________________HandlesOffchainLookup() public {
        // First register the credential subname under label1.ecs.eth
        vm.startPrank(user1);
        registry.setSubnameOwner("credential", "label1.ecs.eth", user1, block.timestamp + REGISTRATION_DURATION, false);
        vm.stopPrank();
        
        // Set up offchain resolver
        vm.startPrank(user1);
        resolver.setCredentialResolver("credential.label1.ecs.eth", address(mockResolver4));  // Use offchain lookup resolver
        vm.stopPrank();
        
        // Test resolution with offchain lookup (should revert with OffchainLookup)
        bytes memory name = _createAddressDNSName(address(0x1234), 0x3c);
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x59d1d43c),
            bytes32(0),
            "eth.ecs.label1.credential" 
        );

        vm.expectRevert();
        resolver.resolve(name, data);
    }
    
    function test_021____onCredentialSuccess_________ReturnsDecodedResult() public view {
        // Test the success callback function
        bytes memory response = abi.encode("callback-result");
        bytes memory extraData = ""; // CCIPReader doesn't use extraData in simple cases
        
        bytes memory result = resolver.onCredentialSuccess(response, extraData);
        string memory decodedResult = abi.decode(result, (string));
        assertEq(decodedResult, "callback-result");
    }
    
    function test_021b___onCredentialFailure_________RethrowsOriginalError() public {
        // Test the failure callback function with mock error data
        bytes memory mockError = abi.encodeWithSignature("Error(string)", "Test error message");
        bytes memory extraData = ""; // CCIPReader doesn't use extraData in simple cases
        
        // The failure callback should revert with the original error
        vm.expectRevert("Test error message");
        resolver.onCredentialFailure(mockError, extraData);
    }
    
    /* --- supportsInterface Tests --- */
    
    function test_022____supportsInterface___________ReturnsCorrectInterfaceSupport() public view {
        // Test IExtendedResolver interface
        assertTrue(resolver.supportsInterface(type(IExtendedResolver).interfaceId));
        
        // Test ERC165 interface
        assertTrue(resolver.supportsInterface(0x01ffc9a7));
        
        // Test invalid interface
        assertFalse(resolver.supportsInterface(0x12345678));
    }

    function test_024____approvalWorkflow____________ManagesApprovalAndOperatorActions() public {
        // First register the credential subname under label1.ecs.eth
        vm.startPrank(user1);
        registry.setSubnameOwner("credential", "label1.ecs.eth", user1, block.timestamp + REGISTRATION_DURATION, false);
        vm.stopPrank();

        // User1 approves operator1 for credential.label1.ecs.eth via registry
        vm.startPrank(user1);
        bytes32 credentialNamespaceHash = NameCoder.namehash(NameCoder.encode("credential.label1.ecs.eth"), 0);
        registry.setApprovalForNamespace(credentialNamespaceHash, operator1, true);
        vm.stopPrank();
        
        // Operator1 registers resolver
        vm.startPrank(operator1);
        resolver.setCredentialResolver("credential.label1.ecs.eth", address(mockResolver1));  // Use normal response resolver
        vm.stopPrank();
        
        // Verify resolver was registered
        assertEq(resolver.credentialResolvers(credentialNamespaceHash), address(mockResolver1));
        
        // Test resolution works
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x59d1d43c),
            bytes32(0),
            "eth.ecs.label1.credential"
        );
        bytes memory name = _createAddressDNSName(address(0x1234), 0x3c);
        bytes memory result = resolver.resolve(name, data);
        assertEq(abi.decode(result, (string)), "mock-response-1");
        
        // User1 revokes approval via registry
        vm.startPrank(user1);
        registry.setApprovalForNamespace(credentialNamespaceHash, operator1, false);
        vm.stopPrank();
        
        // Operator1 can no longer modify the resolver
        vm.startPrank(operator1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ECSAddressResolver.UnauthorizedNamespaceAccess.selector,
                operator1,
                credentialNamespaceHash
            )
        );
        resolver.setCredentialResolver("credential.label1.ecs.eth", address(0));
        vm.stopPrank();
        
        // But resolver still works for resolution
        bytes memory result2 = resolver.resolve(name, data);
        assertEq(abi.decode(result2, (string)), "mock-response-1");
    }
    
    function test_025____namespaceExpiration_________PreventsExpiredNamespaceOperations() public {
        // Register namespace with short duration
        uint256 fee = controller.calculateFee(SHORT_DURATION);
        vm.startPrank(user1);
        bytes32 shortNamespace = controller.registerNamespace{value: fee}("shortlived", SHORT_DURATION);
        
        // First register the credential subname under shortlived.ecs.eth
        vm.startPrank(user1);
        registry.setSubnameOwner("credential", "shortlived.ecs.eth", user1, block.timestamp + SHORT_DURATION, false);
        vm.stopPrank();
        
        // Register resolver while active
        vm.startPrank(user1);
        resolver.setCredentialResolver("credential.shortlived.ecs.eth", address(mockResolver1));  // Use normal response resolver
        vm.stopPrank();
        
        // Verify resolution works while active
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x59d1d43c),
            bytes32(0),
            "eth.ecs.shortlived.credential"
        );
        bytes memory name = _createAddressDNSName(address(0x1234), 0x3c);
        bytes memory result = resolver.resolve(name, data);
        assertEq(abi.decode(result, (string)), "mock-response-1");
        
        // Fast forward past expiration
        vm.warp(block.timestamp + SHORT_DURATION + 1);
        
        // All operations should now fail
        vm.startPrank(user1);
        
        // Cannot register new resolver
        vm.expectRevert(
            abi.encodeWithSelector(
                ECSAddressResolver.NamespaceExpired.selector,
                shortNamespace
            )
        );
        resolver.setCredentialResolver("shortlived.ecs.eth", address(mockResolver2));
        
        // Cannot remove existing resolver
        vm.expectRevert(
            abi.encodeWithSelector(
                ECSAddressResolver.NamespaceExpired.selector,
                shortNamespace
            )
        );
        resolver.setCredentialResolver("shortlived.ecs.eth", address(0));
        
        vm.stopPrank();
        
        // Resolution should return an empty string as bytes
        bytes memory result3 = resolver.resolve(name, data);
        assertEq(abi.decode(result3, (string)), "");
    }
    
    function test_026____errorHandling_______________HandlesCredentialResolverErrors() public {
        // First register the credential subname under label1.ecs.eth
        vm.startPrank(user1);
        registry.setSubnameOwner("credential", "label1.ecs.eth", user1, block.timestamp + REGISTRATION_DURATION, false);
        vm.stopPrank();
        
        // Use mock resolver that reverts
        vm.startPrank(user1);
        resolver.setCredentialResolver("credential.label1.ecs.eth", address(mockResolver5));  // Use reverting resolver
        vm.stopPrank();
        
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x59d1d43c),
            bytes32(0),
            "eth.ecs.label1.credential"
        );
        bytes memory name = _createAddressDNSName(address(0x1234), 0x3c);
        
        // With updated CCIPReader failure callback, errors from credential resolver are propagated
        vm.expectRevert("Mock revert");
        resolver.resolve(name, data);
    }
} 