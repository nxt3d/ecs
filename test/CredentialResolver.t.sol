// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/CredentialResolver.sol";
import "../src/utils/NameCoder.sol";

contract CredentialResolverTest is Test {
    /* --- Test Accounts --- */
    
    address owner = address(0x1001);
    address user = address(0x1002);
    address operator = address(0x1003);
    
    /* --- Contract Variables --- */
    
    CredentialResolver public resolver;
    
    /* --- Constants --- */
    
    bytes32 public constant LABELHASH = keccak256("test");
    
    /* --- Setup --- */
    
    function setUp() public {
        resolver = new CredentialResolver(owner);
        
        vm.prank(owner);
        resolver.setLabelOwner(LABELHASH, user);
    }
    
    /* --- Test Dividers --- */
    
    function test1000________________________________________________________________________________() public pure {}
    function test1100____________________CREDENTIAL_RESOLVER_TESTS_________________________________() public pure {}
    function test1200________________________________________________________________________________() public pure {}
    
    /* --- Access Control Tests --- */
    
    function test_001____setLabelOwner_______________OwnerCanSetLabelOwner() public {
        bytes32 newLabelhash = keccak256("new");
        
        vm.prank(owner);
        resolver.setLabelOwner(newLabelhash, user);
        
        assertEq(resolver.getOwner(newLabelhash), user);
    }
    
    function test_002____setOperator_________________CanApproveOperator() public {
        vm.prank(user);
        resolver.setOperator(operator, true);
        
        assertTrue(resolver.isAuthorized(LABELHASH, operator));
    }
    
    /* --- Record Tests --- */
    
    function test_003____setAddr_____________________SetsAndGetsAddress() public {
        address addr = address(0x123);
        
        vm.prank(user);
        resolver.setAddr(LABELHASH, addr);
        
        // Direct get
        bytes memory result = resolver.addr(LABELHASH, 60);
        // addressRecords stores bytes packed address (20 bytes), so abi.decode would fail
        
        address resolvedAddr2;
        assembly {
            resolvedAddr2 := div(mload(add(result, 32)), exp(256, 12))
        }
        assertEq(resolvedAddr2, addr);
    }
    
    function test_004____setText_____________________SetsAndGetsText() public {
        string memory key = "email";
        string memory value = "test@example.com";
        
        vm.prank(user);
        resolver.setText(LABELHASH, key, value);
        
        assertEq(resolver.text(LABELHASH, key), value);
    }
    
    function test_005____setContenthash______________SetsAndGetsContenthash() public {
        bytes memory hash = hex"123456";
        
        vm.prank(user);
        resolver.setContenthash(LABELHASH, hash);
        
        assertEq(resolver.contenthash(LABELHASH), hash);
    }
    
    function test_006____setData_____________________SetsAndGetsData() public {
        string memory key = "custom";
        bytes memory data = hex"abcdef";
        
        vm.prank(user);
        resolver.setData(LABELHASH, key, data);
        
        assertEq(resolver.getData(LABELHASH, key), data);
    }
    
    /* --- Resolve Function Tests --- */
    
    function test_007____resolve_____________________ResolvesAddr() public {
        address addr = address(0x123);
        vm.prank(user);
        resolver.setAddr(LABELHASH, addr);
        
        bytes memory name = NameCoder.encode("test.ecs.eth");
        bytes memory data = abi.encodeWithSelector(
            bytes4(keccak256("addr(bytes32)")),
            bytes32(0)
        );
        
        bytes memory result = resolver.resolve(name, data);
        address resolvedAddr = abi.decode(result, (address));
        assertEq(resolvedAddr, addr);
    }
    
    function test_008____resolve_____________________ResolvesText() public {
        string memory key = "email";
        string memory value = "test@example.com";
        vm.prank(user);
        resolver.setText(LABELHASH, key, value);
        
        bytes memory name = NameCoder.encode("test.ecs.eth");
        bytes memory data = abi.encodeWithSelector(
            bytes4(keccak256("text(bytes32,string)")),
            bytes32(0),
            key
        );
        
        bytes memory result = resolver.resolve(name, data);
        string memory resolvedValue = abi.decode(result, (string));
        assertEq(resolvedValue, value);
    }
}

