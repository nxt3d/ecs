// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/ECSRegistry.sol";
import "../src/ECSResolver.sol";
import "../src/IExtendedResolver.sol";
import "../src/utils/NameCoder.sol";

// Mock credential resolver for testing
contract MockCredentialResolver is IExtendedResolver {
    string private _defaultResponse;
    bool private _shouldRevert;
    
    constructor(string memory defaultResponse, bool shouldRevert) {
        _defaultResponse = defaultResponse;
        _shouldRevert = shouldRevert;
    }
    
    function resolve(bytes memory /*name*/, bytes memory /*data*/) external view override returns (bytes memory) {
        if (_shouldRevert) {
            revert("Mock revert");
        }
        
        return abi.encode(_defaultResponse);
    }
    
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IExtendedResolver).interfaceId;
    }
}

contract ECSResolverTest is Test {
    /* --- Test Accounts --- */
    
    address admin = address(0x1001);
    address user1 = address(0x1002);
    address registrar = address(0x1003);
    
    /* --- Contract Variables --- */
    
    ECSRegistry public registry;
    ECSResolver public resolver;
    MockCredentialResolver public mockResolver1;
    MockCredentialResolver public mockResolverRevert;
    
    /* --- Setup --- */
    
    function setUp() public {
        vm.startPrank(admin);
        registry = new ECSRegistry();
        resolver = new ECSResolver(registry);
        registry.grantRole(registry.REGISTRAR_ROLE(), registrar);
        vm.stopPrank();
        
        mockResolver1 = new MockCredentialResolver("mock-response-1", false);
        mockResolverRevert = new MockCredentialResolver("", true);
    }
    
    /* --- Test Dividers --- */
    
    function test1000________________________________________________________________________________() public pure {}
    function test1100____________________ECS_RESOLVER_TESTS___________________________________() public pure {}
    function test1200________________________________________________________________________________() public pure {}
    
    /* --- Resolution Tests --- */
    
    function test_001____resolve_____________________ResolvesSuccessfully() public {
        // Register name and set resolver in registry
        string memory label = "test";
        bytes32 labelhash = keccak256(bytes(label));
        uint256 expires = block.timestamp + 365 days;
        
        vm.prank(registrar);
        registry.setLabelhashRecord(label, user1, address(mockResolver1), expires);
        
        // Prepare resolve call
        bytes memory name = NameCoder.encode("test.ecs.eth");
        bytes memory data = abi.encodeWithSelector(
            bytes4(keccak256("text(bytes32,string)")),
            bytes32(0),
            "key"
        );
        
        // The resolver should look up "test" (first label), find mockResolver1, and call it.
        // mockResolver1 returns "mock-response-1" encoded.
        
        // Note: ECSResolver uses CCIP-Read, so off-chain lookup might be triggered if we tested that path,
        // but here we are testing the on-chain flow. 
        // Wait, ECSResolver.resolve returns:
        // return _callCredentialResolver(resolver, name, data);
        // _callCredentialResolver calls ccipRead.
        // CCIPRead will try to call the contract. If it reverts with OffchainLookup, it bubbles up.
        // If it returns a value (like our mock), it calls the callback.
        
        // However, `ccipRead` in `CCIPReader.sol` implementation matters here.
        // If `ccipRead` is standard, it performs a staticcall to the target.
        
        bytes memory result = resolver.resolve(name, data);
        string memory decoded = abi.decode(result, (string));
        
        assertEq(decoded, "mock-response-1");
    }
    
    function test_002____resolve_____________________ReturnsEmptyIfNoResolver() public view {
        // No record set for "unknown"
        bytes memory name = NameCoder.encode("unknown.ecs.eth");
        bytes memory data = "";
        
        bytes memory result = resolver.resolve(name, data);
        assertEq(result.length, 64); // abi.encode("") -> offset 32, length 0. Total 64 bytes.
        string memory decoded = abi.decode(result, (string));
        assertEq(decoded, "");
    }
    
    function test_003____resolve_____________________HandlesRevertFromSubResolver() public {
        // Register name with reverting resolver
        string memory label = "revert";
        uint256 expires = block.timestamp + 365 days;
        
        vm.prank(registrar);
        registry.setLabelhashRecord(label, user1, address(mockResolverRevert), expires);
        
        bytes memory name = NameCoder.encode("revert.ecs.eth");
        bytes memory data = abi.encodeWithSelector(
            bytes4(keccak256("text(bytes32,string)")),
            bytes32(0),
            "key"
        );
        
        vm.expectRevert("Mock revert");
        resolver.resolve(name, data);
    }
    
    /* --- Interface Support Tests --- */
    
    function test_004____supportsInterface___________SupportsIExtendedResolver() public view {
        assertTrue(resolver.supportsInterface(type(IExtendedResolver).interfaceId));
    }
}

