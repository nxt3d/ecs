// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/RootController.sol";
import "../src/ECSRegistry.sol";
import "../src/utils/NameCoder.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract RootControllerTest is Test {
    RootController public rootController;
    ECSRegistry public registry;
    
    /* --- Constants --- */
    
    bytes32 private constant ROOT_NAMESPACE = bytes32(0);
    uint256 private constant TEST_EXPIRATION = 365 days;
    
    /* --- Test Accounts --- */
    
    address admin = address(0x1001);
    address controller1 = address(0x1002);
    address controller2 = address(0x1003);
    address user1 = address(0x1004);
    address user2 = address(0x1005);
    
    /* --- Setup --- */
    
    function setUp() public {
        vm.startPrank(admin);
        registry = new ECSRegistry();
        rootController = new RootController(registry);
        
        // Transfer root namespace ownership to RootController
        registry.setApprovalForNamespace(ROOT_NAMESPACE, address(rootController), true);
        vm.stopPrank();
    }
    
    /* --- Test Dividers --- */
    
    function test1000________________________________________________________________________________() public pure {}
    function test1100_____________________ROOT_CONTROLLER_TESTS___________________________________() public pure {}
    function test1200________________________________________________________________________________() public pure {}
    
    /* --- Constructor Tests --- */
    
    function test_001____constructor_________________SetsECSRegistryReference() public view {
        assertEq(address(rootController.ecs()), address(registry));
    }
    
    function test_002____constructor_________________GrantsRolesToDeployer() public view {
        assertTrue(rootController.hasRole(rootController.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(rootController.hasRole(rootController.ADMIN_ROLE(), admin));
        assertTrue(rootController.hasRole(rootController.CONTROLLER_ROLE(), admin));
    }
    
    /* --- setSubnameOwner Tests --- */
    
    function test_003____setSubnameOwner_____________CreatesTopLevelDomainSuccessfully() public {
        bytes32 ethNode = NameCoder.namehash(NameCoder.encode("eth"), 0);
        
        vm.startPrank(admin);
        vm.expectEmit(true, false, false, true);
        emit ECSRegistry.Transfer(ethNode, user1);
        rootController.setSubnameOwner("eth", user1);
        vm.stopPrank();
        
        assertEq(registry.owner(ethNode), user1);
        assertTrue(registry.recordExists(ethNode));
    }
    
    function test_004____setSubnameOwner_____________OnlyControllerRoleCanCreateTLD() public {
        vm.startPrank(user1);
        vm.expectRevert();
        rootController.setSubnameOwner("eth", user1);
        vm.stopPrank();
        
        bytes32 ethNode = NameCoder.namehash(NameCoder.encode("eth"), 0);
        assertEq(registry.owner(ethNode), address(0));
        assertFalse(registry.recordExists(ethNode));
    }
    
    function test_005____setSubnameOwner_____________CannotCreateLockedTLD() public {
        // Lock the .eth label
        vm.startPrank(admin);
        rootController.lock("eth");
        vm.stopPrank();
        
        // Try to create .eth TLD
        vm.startPrank(admin);
        vm.expectRevert("TLD is locked");
        rootController.setSubnameOwner("eth", user1);
        vm.stopPrank();
        
        bytes32 ethNode = NameCoder.namehash(NameCoder.encode("eth"), 0);
        assertEq(registry.owner(ethNode), address(0));
        assertFalse(registry.recordExists(ethNode));
    }
    
    function test_006____setSubnameOwner_____________ControllerCanCreateMultipleTLDs() public {
        bytes32 ethNode = NameCoder.namehash(NameCoder.encode("eth"), 0);
        bytes32 comNode = NameCoder.namehash(NameCoder.encode("com"), 0);
        bytes32 orgNode = NameCoder.namehash(NameCoder.encode("org"), 0);
        
        vm.startPrank(admin);
        rootController.setSubnameOwner("eth", user1);
        rootController.setSubnameOwner("com", user2);
        rootController.setSubnameOwner("org", user1);
        vm.stopPrank();
        
        assertEq(registry.owner(ethNode), user1);
        assertEq(registry.owner(comNode), user2);
        assertEq(registry.owner(orgNode), user1);
        assertTrue(registry.recordExists(ethNode));
        assertTrue(registry.recordExists(comNode));
        assertTrue(registry.recordExists(orgNode));
    }
    
    function test_007____setSubnameOwner_____________AddedControllerCanCreateTLD() public {
        // Add controller1 as a controller
        vm.startPrank(admin);
        rootController.addController(controller1);
        vm.stopPrank();
        
        // Controller1 creates .eth TLD
        bytes32 ethNode = NameCoder.namehash(NameCoder.encode("eth"), 0);
        
        vm.startPrank(controller1);
        rootController.setSubnameOwner("eth", user1);
        vm.stopPrank();
        
        assertEq(registry.owner(ethNode), user1);
        assertTrue(registry.recordExists(ethNode));
    }
    
    /* --- lock Tests --- */
    
    function test_008____lock________________________LocksLabelSuccessfully() public {
        vm.startPrank(admin);
        vm.expectEmit(true, false, false, true);
        emit RootController.TLDLocked(keccak256(bytes("eth")));
        rootController.lock("eth");
        vm.stopPrank();
        
        assertTrue(rootController.isLocked("eth"));
    }
    
    function test_009____lock________________________OnlyAdminRoleCanLockTLD() public {
        vm.startPrank(user1);
        vm.expectRevert();
        rootController.lock("eth");
        vm.stopPrank();
        
        assertFalse(rootController.isLocked("eth"));
    }
    
    function test_010____lock________________________CanLockMultipleLabels() public {
        vm.startPrank(admin);
        rootController.lock("eth");
        rootController.lock("com");
        rootController.lock("org");
        vm.stopPrank();
        
        assertTrue(rootController.isLocked("eth"));
        assertTrue(rootController.isLocked("com"));
        assertTrue(rootController.isLocked("org"));
    }
    
    function test_011____lock________________________LockingPreventsFutureTLDCreation() public {
        // Create .eth TLD first
        vm.startPrank(admin);
        rootController.setSubnameOwner("eth", user1);
        vm.stopPrank();
        
        bytes32 ethNode = NameCoder.namehash(NameCoder.encode("eth"), 0);
        assertEq(registry.owner(ethNode), user1);
        
        // Lock .com label
        vm.startPrank(admin);
        rootController.lock("com");
        vm.stopPrank();
        
        // Try to create .com TLD (should fail)
        vm.startPrank(admin);
        vm.expectRevert("TLD is locked");
        rootController.setSubnameOwner("com", user2);
        vm.stopPrank();
        
        bytes32 comNode = NameCoder.namehash(NameCoder.encode("com"), 0);
        assertEq(registry.owner(comNode), address(0));
        assertFalse(registry.recordExists(comNode));
    }
    
    /* --- addController Tests --- */
    
    function test_012____addController_______________GrantsControllerRoleSuccessfully() public {
        vm.startPrank(admin);
        rootController.addController(controller1);
        vm.stopPrank();
        
        assertTrue(rootController.hasRole(rootController.CONTROLLER_ROLE(), controller1));
    }
    
    function test_013____addController_______________OnlyAdminRoleCanAddController() public {
        vm.startPrank(user1);
        vm.expectRevert();
        rootController.addController(controller1);
        vm.stopPrank();
        
        assertFalse(rootController.hasRole(rootController.CONTROLLER_ROLE(), controller1));
    }
    
    function test_014____addController_______________CanAddMultipleControllers() public {
        vm.startPrank(admin);
        rootController.addController(controller1);
        rootController.addController(controller2);
        vm.stopPrank();
        
        assertTrue(rootController.hasRole(rootController.CONTROLLER_ROLE(), controller1));
        assertTrue(rootController.hasRole(rootController.CONTROLLER_ROLE(), controller2));
    }
    
    function test_015____addController_______________AddedControllerCanPerformControllerActions() public {
        // Add controller1
        vm.startPrank(admin);
        rootController.addController(controller1);
        vm.stopPrank();
        
        // Controller1 creates .eth TLD
        bytes32 ethNode = NameCoder.namehash(NameCoder.encode("eth"), 0);
        
        vm.startPrank(controller1);
        rootController.setSubnameOwner("eth", user1);
        vm.stopPrank();
        
        assertEq(registry.owner(ethNode), user1);
        assertTrue(registry.recordExists(ethNode));
    }
    
    /* --- removeController Tests --- */
    
    function test_016____removeController____________RevokesControllerRoleSuccessfully() public {
        // Add controller1 first
        vm.startPrank(admin);
        rootController.addController(controller1);
        vm.stopPrank();
        
        assertTrue(rootController.hasRole(rootController.CONTROLLER_ROLE(), controller1));
        
        // Remove controller1
        vm.startPrank(admin);
        rootController.removeController(controller1);
        vm.stopPrank();
        
        assertFalse(rootController.hasRole(rootController.CONTROLLER_ROLE(), controller1));
    }
    
    function test_017____removeController____________OnlyAdminRoleCanRemoveController() public {
        // Add controller1 first
        vm.startPrank(admin);
        rootController.addController(controller1);
        vm.stopPrank();
        
        // User1 tries to remove controller1
        vm.startPrank(user1);
        vm.expectRevert();
        rootController.removeController(controller1);
        vm.stopPrank();
        
        assertTrue(rootController.hasRole(rootController.CONTROLLER_ROLE(), controller1));
    }
    
    function test_018____removeController____________RemovedControllerCannotPerformControllerActions() public {
        // Add controller1 first
        vm.startPrank(admin);
        rootController.addController(controller1);
        vm.stopPrank();
        
        // Remove controller1
        vm.startPrank(admin);
        rootController.removeController(controller1);
        vm.stopPrank();
        
        // Controller1 tries to create .eth TLD (should fail)
        vm.startPrank(controller1);
        vm.expectRevert();
        rootController.setSubnameOwner("eth", user1);
        vm.stopPrank();
        
        bytes32 ethNode = NameCoder.namehash(NameCoder.encode("eth"), 0);
        assertEq(registry.owner(ethNode), address(0));
        assertFalse(registry.recordExists(ethNode));
    }
    
    /* --- supportsInterface Tests --- */
    
    function test_019____supportsInterface___________ReturnsCorrectInterfaceSupport() public view {
        // Test AccessControl interface
        bytes4 accessControlInterface = type(IAccessControl).interfaceId;
        assertTrue(rootController.supportsInterface(accessControlInterface));
        
        // Test ERC165 interface
        bytes4 erc165Interface = type(IERC165).interfaceId;
        assertTrue(rootController.supportsInterface(erc165Interface));
        
        // Test invalid interface
        bytes4 invalidInterface = bytes4(keccak256("invalid()"));
        assertFalse(rootController.supportsInterface(invalidInterface));
    }
    
    /* --- Complex Integration Tests --- */
    
    function test_020____complexWorkflow_____________ManagesMultipleTLDsAndControllers() public {
        // Add multiple controllers
        vm.startPrank(admin);
        rootController.addController(controller1);
        rootController.addController(controller2);
        vm.stopPrank();
        
        // Controllers create different TLDs
        bytes32 ethNode = NameCoder.namehash(NameCoder.encode("eth"), 0);
        bytes32 comNode = NameCoder.namehash(NameCoder.encode("com"), 0);
        bytes32 orgNode = NameCoder.namehash(NameCoder.encode("org"), 0);
        
        vm.startPrank(controller1);
        rootController.setSubnameOwner("eth", user1);
        vm.stopPrank();
        
        vm.startPrank(controller2);
        rootController.setSubnameOwner("com", user2);
        vm.stopPrank();
        
        vm.startPrank(admin);
        rootController.setSubnameOwner("org", user1);
        vm.stopPrank();
        
        // Lock .net to prevent future creation
        vm.startPrank(admin);
        rootController.lock("net");
        vm.stopPrank();
        
        // Try to create .net (should fail)
        vm.startPrank(controller1);
        vm.expectRevert("TLD is locked");
        rootController.setSubnameOwner("net", user2);
        vm.stopPrank();
        
        // Remove controller1
        vm.startPrank(admin);
        rootController.removeController(controller1);
        vm.stopPrank();
        
        // Controller1 can no longer create TLDs
        vm.startPrank(controller1);
        vm.expectRevert();
        rootController.setSubnameOwner("info", user1);
        vm.stopPrank();
        
        // Verify final state
        assertEq(registry.owner(ethNode), user1);
        assertEq(registry.owner(comNode), user2);
        assertEq(registry.owner(orgNode), user1);
        assertTrue(rootController.isLocked("net"));
        assertFalse(rootController.hasRole(rootController.CONTROLLER_ROLE(), controller1));
        assertTrue(rootController.hasRole(rootController.CONTROLLER_ROLE(), controller2));
    }
    
    function test_021____roleHierarchy_______________AdminCanPerformControllerActions() public {
        // Admin (who has CONTROLLER_ROLE) can create TLDs
        bytes32 ethNode = NameCoder.namehash(NameCoder.encode("eth"), 0);
        
        vm.startPrank(admin);
        rootController.setSubnameOwner("eth", user1);
        vm.stopPrank();
        
        assertEq(registry.owner(ethNode), user1);
        assertTrue(registry.recordExists(ethNode));
        
        // Admin can also lock TLDs
        vm.startPrank(admin);
        rootController.lock("com");
        vm.stopPrank();
        
        assertTrue(rootController.isLocked("com"));
        
        // Admin can manage controllers
        vm.startPrank(admin);
        rootController.addController(controller1);
        rootController.removeController(controller1);
        vm.stopPrank();
        
        assertFalse(rootController.hasRole(rootController.CONTROLLER_ROLE(), controller1));
    }
    
    function test_022____lockingEdgeCases____________LockingDoesNotAffectExistingTLDs() public {
        // Create .eth TLD
        bytes32 ethNode = NameCoder.namehash(NameCoder.encode("eth"), 0);
        
        vm.startPrank(admin);
        rootController.setSubnameOwner("eth", user1);
        vm.stopPrank();
        
        assertEq(registry.owner(ethNode), user1);
        
        // Lock .eth label
        vm.startPrank(admin);
        rootController.lock("eth");
        vm.stopPrank();
        
        // Existing .eth TLD should still exist and be owned by user1
        assertEq(registry.owner(ethNode), user1);
        assertTrue(registry.recordExists(ethNode));
        assertTrue(rootController.isLocked("eth"));
        
        // But cannot create another .eth TLD (hypothetically)
        vm.startPrank(admin);
        vm.expectRevert("TLD is locked");
        rootController.setSubnameOwner("eth", user2);
        vm.stopPrank();
        
        // Ownership should remain unchanged
        assertEq(registry.owner(ethNode), user1);
    }
} 