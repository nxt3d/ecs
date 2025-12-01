// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/ECSRegistry.sol";

contract ECSRegistryTest is Test {
    /* --- Test Accounts --- */
    
    address admin = address(0x1001);
    address registrar = address(0x1002);
    address user1 = address(0x1003);
    address user2 = address(0x1004);
    address operator = address(0x1005);
    address resolver = address(0x1006);
    
    /* --- Contract Variables --- */
    
    ECSRegistry public registry;
    
    /* --- Domain Variables --- */
    
    bytes32 public labelhash;
    string public constant LABEL = "testlabel";
    uint256 public constant DURATION = 365 days;
    
    /* --- Setup --- */
    
    function setUp() public {
        vm.startPrank(admin);
        registry = new ECSRegistry();
        registry.grantRole(registry.REGISTRAR_ROLE(), registrar);
        vm.stopPrank();
        
        labelhash = keccak256(bytes(LABEL));
    }
    
    /* --- Test Dividers --- */
    
    function test1000________________________________________________________________________________() public pure {}
    function test1100____________________ECS_REGISTRY_TESTS___________________________________() public pure {}
    function test1200________________________________________________________________________________() public pure {}
    
    /* --- Initialization Tests --- */
    
    function test_001____constructor_________________SetsAdminRole() public view {
        assertTrue(registry.hasRole(registry.ADMIN_ROLE(), admin));
        assertTrue(registry.hasRole(registry.DEFAULT_ADMIN_ROLE(), admin));
    }
    
    /* --- Registration Tests --- */
    
    function test_002____setLabelhashRecord__________RegistrarCanRegister() public {
        uint256 expires = block.timestamp + DURATION;
        
        vm.startPrank(registrar);
        vm.expectEmit(true, false, false, true);
        emit ECSRegistry.NewLabelhashOwner(labelhash, LABEL, user1);
        
        registry.setLabelhashRecord(LABEL, user1, resolver, expires);
        vm.stopPrank();
        
        assertEq(registry.owner(labelhash), user1);
        assertEq(registry.resolver(labelhash), resolver);
        assertEq(registry.getExpiration(labelhash), expires);
        assertEq(registry.getLabel(labelhash), LABEL);
    }
    
    function test_003____setLabelhashRecord__________NonRegistrarCannotRegister() public {
        uint256 expires = block.timestamp + DURATION;
        
        vm.startPrank(user1);
        bytes4 selector = bytes4(keccak256("AccessControlUnauthorizedAccount(address,bytes32)"));
        vm.expectRevert(abi.encodeWithSelector(selector, user1, registry.REGISTRAR_ROLE()));
        registry.setLabelhashRecord(LABEL, user1, resolver, expires);
        vm.stopPrank();
    }
    
    function test_004____setLabelhashRecord__________CannotOverwriteUnexpired() public {
        uint256 expires = block.timestamp + DURATION;
        
        vm.startPrank(registrar);
        registry.setLabelhashRecord(LABEL, user1, resolver, expires);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                ECSRegistry.labelhashNotExpired.selector,
                labelhash,
                expires
            )
        );
        registry.setLabelhashRecord(LABEL, user2, resolver, expires);
        vm.stopPrank();
    }
    
    function test_005____setLabelhashRecord__________CanOverwriteExpired() public {
        uint256 expires = block.timestamp + DURATION;
        
        vm.startPrank(registrar);
        registry.setLabelhashRecord(LABEL, user1, resolver, expires);
        vm.stopPrank();
        
        vm.warp(expires + 1);
        
        vm.startPrank(registrar);
        uint256 newExpires = block.timestamp + DURATION;
        registry.setLabelhashRecord(LABEL, user2, resolver, newExpires);
        vm.stopPrank();
        
        assertEq(registry.owner(labelhash), user2);
        assertEq(registry.getExpiration(labelhash), newExpires);
    }
    
    /* --- Record Management Tests --- */
    
    function test_006____setRecord___________________OwnerCanSetRecord() public {
        // Setup record first
        uint256 expires = block.timestamp + DURATION;
        vm.prank(registrar);
        registry.setLabelhashRecord(LABEL, user1, resolver, expires);
        
        address newResolver = address(0x999);
        bytes32 secret = bytes32(uint256(1));
        
        // Commit
        vm.startPrank(user1); // Committer can be anyone, but setRecord checks auth
        bytes32 commitment = keccak256(abi.encodePacked(labelhash, user2, newResolver, secret));
        registry.commit(commitment);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 60);
        
        vm.startPrank(user1);
        vm.expectEmit(true, false, false, true);
        emit ECSRegistry.ResolverChanged(labelhash, newResolver);
        
        registry.setRecord(labelhash, user2, newResolver, secret);
        vm.stopPrank();
        
        assertEq(registry.owner(labelhash), user2);
        assertEq(registry.resolver(labelhash), newResolver);
    }
    
    function test_007____setRecord___________________NonOwnerCannotSetRecord() public {
        // Setup record first
        uint256 expires = block.timestamp + DURATION;
        vm.prank(registrar);
        registry.setLabelhashRecord(LABEL, user1, resolver, expires);
        
        bytes32 secret = bytes32(uint256(1));
        bytes32 commitment = keccak256(abi.encodePacked(labelhash, user2, resolver, secret));
        
        vm.prank(user2);
        registry.commit(commitment);
        
        vm.warp(block.timestamp + 60);
        
        vm.startPrank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                ECSRegistry.NotAuthorised.selector,
                labelhash,
                user2
            )
        );
        registry.setRecord(labelhash, user2, resolver, secret);
        vm.stopPrank();
    }
    
    /* --- Access Control Tests --- */
    
    function test_008____setApprovalForAll___________CanApproveOperator() public {
        // Setup record first
        uint256 expires = block.timestamp + DURATION;
        vm.prank(registrar);
        registry.setLabelhashRecord(LABEL, user1, resolver, expires);
        
        vm.startPrank(user1);
        registry.setApprovalForAll(operator, true);
        
        // Operator should be able to set owner
        vm.stopPrank();
        
        vm.startPrank(operator);
        registry.setOwner(labelhash, user2);
        vm.stopPrank();
        
        assertEq(registry.owner(labelhash), user2);
    }
    
    function test_009____setOwner____________________OwnerCanTransfer() public {
        uint256 expires = block.timestamp + DURATION;
        vm.prank(registrar);
        registry.setLabelhashRecord(LABEL, user1, resolver, expires);
        
        vm.startPrank(user1);
        emit ECSRegistry.Transfer(labelhash, user2);
        registry.setOwner(labelhash, user2);
        vm.stopPrank();
        
        assertEq(registry.owner(labelhash), user2);
    }
    
    function test_010____setResolver_________________OwnerCanSetResolver() public {
        uint256 expires = block.timestamp + DURATION;
        vm.prank(registrar);
        registry.setLabelhashRecord(LABEL, user1, resolver, expires);
        
        address newResolver = address(0x888);
        bytes32 secret = bytes32(uint256(2));
        
        // Commit (owner is user1)
        vm.prank(user1);
        bytes32 commitment = keccak256(abi.encodePacked(labelhash, user1, newResolver, secret));
        registry.commit(commitment);
        
        vm.warp(block.timestamp + 60);
        
        vm.startPrank(user1);
        emit ECSRegistry.ResolverChanged(labelhash, newResolver);
        registry.setResolver(labelhash, newResolver, secret);
        vm.stopPrank();
        
        assertEq(registry.resolver(labelhash), newResolver);
    }
    
    /* --- Expiration Tests --- */
    
    function test_011____extendExpiration____________RegistrarCanExtend() public {
        uint256 expires = block.timestamp + DURATION;
        vm.prank(registrar);
        registry.setLabelhashRecord(LABEL, user1, resolver, expires);
        
        uint256 newExpires = expires + 365 days;
        
        vm.startPrank(registrar);
        registry.extendExpiration(labelhash, newExpires);
        vm.stopPrank();
        
        assertEq(registry.getExpiration(labelhash), newExpires);
    }
    
    function test_012____extendExpiration____________CannotReduceExpiration() public {
        uint256 expires = block.timestamp + DURATION;
        vm.prank(registrar);
        registry.setLabelhashRecord(LABEL, user1, resolver, expires);
        
        uint256 newExpires = expires - 1 days;
        
        vm.startPrank(registrar);
        vm.expectRevert(
            abi.encodeWithSelector(
                ECSRegistry.CannotReduceExpirationTime.selector,
                expires,
                newExpires
            )
        );
        registry.extendExpiration(labelhash, newExpires);
        vm.stopPrank();
    }
    
    function test_013____isExpired___________________ReturnsCorrectStatus() public {
        uint256 expires = block.timestamp + DURATION;
        vm.prank(registrar);
        registry.setLabelhashRecord(LABEL, user1, resolver, expires);
        
        assertFalse(registry.isExpired(labelhash));
        
        vm.warp(expires + 1);
        assertTrue(registry.isExpired(labelhash));
    }
    
    /* --- Resolver Mapping Tests --- */
    
    function test_014____setResolver_________________UpdatesMappingAndAllowsReuse() public {
        // 1. Setup
        uint256 expires = block.timestamp + DURATION;
        vm.prank(registrar);
        registry.setLabelhashRecord(LABEL, user1, resolver, expires);
        
        assertEq(registry.resolverToLabelhash(resolver), labelhash);
        
        address resolverB = address(0x999);
        bytes32 secret = bytes32(uint256(3));
        
        // Commit
        vm.prank(user1);
        bytes32 commitment = keccak256(abi.encodePacked(labelhash, user1, resolverB, secret));
        registry.commit(commitment);
        
        vm.warp(block.timestamp + 60);
        
        // 2. Change to Resolver B
        vm.prank(user1);
        registry.setResolver(labelhash, resolverB, secret);
        
        assertEq(registry.resolver(labelhash), resolverB);
        assertEq(registry.resolverToLabelhash(resolver), bytes32(0)); // Old cleared
        assertEq(registry.resolverToLabelhash(resolverB), labelhash); // New set
        
        // 3. Reuse Resolver A for another label
        string memory label2 = "label2";
        bytes32 labelhash2 = keccak256(bytes(label2));
        
        vm.prank(registrar);
        registry.setLabelhashRecord(label2, user1, resolver, expires);
        
        assertEq(registry.resolverToLabelhash(resolver), labelhash2);
        
        // 4. Try to set Resolver B (used by LABEL) for label2
        bytes32 secret2 = bytes32(uint256(4));
        
        vm.prank(user1);
        bytes32 commitment2 = keccak256(abi.encodePacked(labelhash2, user1, resolverB, secret2));
        registry.commit(commitment2);
        
        vm.warp(block.timestamp + 60);
        
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ECSRegistry.ResolverAlreadyInUse.selector,
                resolverB,
                labelhash
            )
        );
        registry.setResolver(labelhash2, resolverB, secret2);
    }
    
    function test_015____setRecord_____________________RevertsIfResolverInUse() public {
        // 1. Setup label1 with resolver
        uint256 expires = block.timestamp + DURATION;
        vm.prank(registrar);
        registry.setLabelhashRecord(LABEL, user1, resolver, expires);
        
        // 2. Setup label2
        string memory label2 = "label2";
        bytes32 labelhash2 = keccak256(bytes(label2));
        vm.prank(registrar);
        registry.setLabelhashRecord(label2, user1, address(0x123), expires); // Initial random resolver
        
        // 3. Try to setRecord for label2 using resolver (which is used by LABEL)
        bytes32 secret = bytes32(uint256(5));
        address newOwner = user2;
        
        vm.prank(user1);
        bytes32 commitment = keccak256(abi.encodePacked(labelhash2, newOwner, resolver, secret));
        registry.commit(commitment);
        
        vm.warp(block.timestamp + 60);
        
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ECSRegistry.ResolverAlreadyInUse.selector,
                resolver,
                labelhash
            )
        );
        registry.setRecord(labelhash2, newOwner, resolver, secret);
    }
}

import "@openzeppelin/contracts/utils/Strings.sol";
