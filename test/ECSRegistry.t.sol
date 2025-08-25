// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/ECSRegistry.sol";
import "../src/utils/NameCoder.sol";

contract ECSRegistryTest is Test {
    
    /* --- Test Contracts --- */
    
    ECSRegistry public registry;
    
    /* --- Test Constants --- */
    
    bytes32 constant ROOT_NODE = bytes32(0);
    uint256 constant TEST_EXPIRATION = 365 days;
    
    /* --- Test Accounts --- */
    
    address public admin = address(0x1001);
    address public user1 = address(0x1002);
    address public user2 = address(0x1003);
    address public operator = address(0x1004);
    address public newOwner = address(0x1005);
    
    /* --- Test State --- */
    
    bytes32 public ethNode;     // .eth
    bytes32 public nameNode;    // name.eth  
    bytes32 public subNode;     // sub.name.eth
    
    /* --- Setup --- */
    
    function setUp() public {
        // Deploy registry from admin account
        vm.startPrank(admin);
        registry = new ECSRegistry();
        
        // Grant CONTROLLER_ROLE to admin for testing expiration functions
        registry.grantRole(registry.CONTROLLER_ROLE(), admin);
        vm.stopPrank();
        
        // Pre-calculate node hashes for testing: eth -> name.eth -> sub.name.eth
        ethNode = NameCoder.namehash(NameCoder.encode("eth"), 0);
        nameNode = NameCoder.namehash(NameCoder.encode("name.eth"), 0);
        subNode = NameCoder.namehash(NameCoder.encode("sub.name.eth"), 0);
    }
    
    // Test identification dividers
    function test1000________________________________________________________________________________() public {}
    function test1100________________________ECS_REGISTRY_TESTS__________________________________() public {}
    function test1200________________________________________________________________________________() public {}
    
    /* --- Constructor Tests --- */
    
    function test_001____constructor_________________SetsAdminAsRootOwner() public {
        // Test that constructor sets the root node (0x0) owner to deployer
        assertEq(registry.owner(ROOT_NODE), admin);
        assertTrue(registry.recordExists(ROOT_NODE));
    }
    
    /* --- setOwner Tests --- */
    
    function test_002____setOwner___________________TransfersOwnershipToNewAddress() public {
        // Setup: admin creates .eth node
        vm.startPrank(admin);
        registry.setSubnameOwner("eth", "", admin, block.timestamp + TEST_EXPIRATION, false);
        vm.stopPrank();
        
        // Test transferring ownership to user1
        vm.startPrank(admin);
        vm.expectEmit(true, false, false, true);
        emit ECSRegistry.Transfer(ethNode, user1);
        registry.setOwner(ethNode, user1);
        vm.stopPrank();
        
        // Verify new ownership
        assertEq(registry.owner(ethNode), user1);
    }
    
    function test_003____setOwner___________________OnlyOwnerCanTransferOwnership() public {
        // Setup: admin creates .eth node and transfers to user1
        vm.startPrank(admin);
        registry.setSubnameOwner("eth", "", user1, block.timestamp + TEST_EXPIRATION, false);
        vm.stopPrank();
        
        // Test that non-owner cannot transfer ownership
        vm.startPrank(user2);
        vm.expectRevert(abi.encodeWithSelector(ECSRegistry.Unauthorized.selector, ethNode, user2));
        registry.setOwner(ethNode, user2);
        vm.stopPrank();
        
        // Verify ownership unchanged
        assertEq(registry.owner(ethNode), user1);
    }
    
    function test_004____setOwner___________________NodeSpecificApprovedOperatorCanTransferOwnership() public {
        // Setup: admin creates .eth node, transfers to user1, user1 approves operator for specific node
        vm.startPrank(admin);
        registry.setSubnameOwner("eth", "", user1, block.timestamp + TEST_EXPIRATION, false);
        vm.stopPrank();
        
        vm.startPrank(user1);
        registry.setApprovalForNamespace(ethNode, operator, true);
        vm.stopPrank();
        
        // Test that node-specific approved operator can transfer
        vm.startPrank(operator);
        vm.expectEmit(true, false, false, true);
        emit ECSRegistry.Transfer(ethNode, user2);
        registry.setOwner(ethNode, user2);
        vm.stopPrank();
        
        // Verify new ownership
        assertEq(registry.owner(ethNode), user2);
    }
    
    /* --- setSubnameOwner Tests --- */
    
    function test_005____setSubnameOwner_____________CreatesSubnodeAndReturnsHash() public {
        // Test creating .eth subnode from root
        vm.startPrank(admin);
        vm.expectEmit(true, false, false, true);
        emit ECSRegistry.Transfer(ethNode, user1);
        
        bytes32 returnedNode = registry.setSubnameOwner("eth", "", user1, block.timestamp + TEST_EXPIRATION, false);
        vm.stopPrank();
        
        // Verify the returned node hash matches expected
        assertEq(returnedNode, ethNode);
        assertEq(registry.owner(ethNode), user1);
        assertTrue(registry.recordExists(ethNode));
    }
    
    function test_006____setSubnameOwner_____________OnlyParentOwnerCanCreateSubnode() public {
        // Setup: admin creates .eth node and transfers to user1
        vm.startPrank(admin);
        registry.setSubnameOwner("eth", "", user1, block.timestamp + TEST_EXPIRATION, false);
        vm.stopPrank();
        
        // Test that non-parent-owner cannot create name.eth subnode
        vm.startPrank(user2);
        vm.expectRevert(abi.encodeWithSelector(ECSRegistry.Unauthorized.selector, ethNode, user2));
        registry.setSubnameOwner("name", "eth", user2, block.timestamp + TEST_EXPIRATION, false);
        vm.stopPrank();
        
        // Verify name.eth subnode was not created
        assertEq(registry.owner(nameNode), address(0));
        assertFalse(registry.recordExists(nameNode));
    }
    
    function test_007____setSubnameOwner_____________NodeSpecificApprovedOperatorCanCreateSubnode() public {
        // Setup: admin creates .eth node, transfers to user1, user1 approves operator for specific node
        vm.startPrank(admin);
        registry.setSubnameOwner("eth", "", user1, block.timestamp + TEST_EXPIRATION, false);
        vm.stopPrank();
        
        vm.startPrank(user1);
        registry.setApprovalForNamespace(ethNode, operator, true);
        vm.stopPrank();
        
        // Test that node-specific approved operator can create name.eth subnode
        vm.startPrank(operator);
        bytes32 returnedNode = registry.setSubnameOwner("name", "eth", user2, block.timestamp + TEST_EXPIRATION, false);
        vm.stopPrank();
        
        // Verify name.eth subnode creation
        assertEq(returnedNode, nameNode);
        assertEq(registry.owner(nameNode), user2);
    }
    
    function test_008____setSubnameOwner_____________NamespaceOwnersCanCreateSubNamespacesForFree() public {
        // This tests the specific requirement that namespace owners can create sub namespaces for free
        
        // Setup: admin creates .eth, then myapp.eth namespace and transfers to user1
        vm.startPrank(admin);
        registry.setSubnameOwner("eth", "", admin, block.timestamp + TEST_EXPIRATION, false);
        vm.stopPrank();
        
        bytes32 myappNode = NameCoder.namehash(NameCoder.encode("myapp.eth"), 0);
        
        vm.startPrank(admin);
        registry.setSubnameOwner("myapp", "eth", user1, block.timestamp + TEST_EXPIRATION, false);
        vm.stopPrank();
        
        // Test that namespace owner can create multiple sub-namespaces
        vm.startPrank(user1);
        
        // Create "api.myapp.eth"
        bytes32 apiNode = NameCoder.namehash(NameCoder.encode("api.myapp.eth"), 0);
        bytes32 returnedApiNode = registry.setSubnameOwner("api", "myapp.eth", user1, block.timestamp + TEST_EXPIRATION, false);
        
        // Create "web.myapp.eth"
        bytes32 webNode = NameCoder.namehash(NameCoder.encode("web.myapp.eth"), 0);
        bytes32 returnedWebNode = registry.setSubnameOwner("web", "myapp.eth", user1, block.timestamp + TEST_EXPIRATION, false);
        
        // Create "mobile.myapp.eth"
        bytes32 mobileNode = NameCoder.namehash(NameCoder.encode("mobile.myapp.eth"), 0);
        bytes32 returnedMobileNode = registry.setSubnameOwner("mobile", "myapp.eth", user1, block.timestamp + TEST_EXPIRATION, false);
        
        vm.stopPrank();
        
        // Verify all sub-namespaces were created successfully
        assertEq(returnedApiNode, apiNode);
        assertEq(returnedWebNode, webNode);
        assertEq(returnedMobileNode, mobileNode);
        
        assertEq(registry.owner(apiNode), user1);
        assertEq(registry.owner(webNode), user1);
        assertEq(registry.owner(mobileNode), user1);
        
        assertTrue(registry.recordExists(apiNode));
        assertTrue(registry.recordExists(webNode));
        assertTrue(registry.recordExists(mobileNode));
        
        // Test that user1 can create deep hierarchies (e.g., "v1.api.myapp.eth")
        bytes32 v1ApiNode = NameCoder.namehash(NameCoder.encode("v1.api.myapp.eth"), 0);
        
        vm.startPrank(user1);
        bytes32 returnedV1ApiNode = registry.setSubnameOwner("v1", "api.myapp.eth", user1, block.timestamp + TEST_EXPIRATION, false);
        vm.stopPrank();
        
        assertEq(returnedV1ApiNode, v1ApiNode);
        assertEq(registry.owner(v1ApiNode), user1);
        assertTrue(registry.recordExists(v1ApiNode));
    }
    
    /* --- setApprovalForNamespace Tests --- */
    
    function test_009____setApprovalForNamespace__________ApprovesOperatorForSpecificNode() public {
        // Setup: admin creates .eth node and transfers to user1
        vm.startPrank(admin);
        registry.setSubnameOwner("eth", "", user1, block.timestamp + TEST_EXPIRATION, false);
        vm.stopPrank();
        
        // Test approving operator for specific node
        vm.startPrank(user1);
        vm.expectEmit(true, true, true, true);
        emit ECSRegistry.ApprovalForNamespace(ethNode, user1, operator, true);
        registry.setApprovalForNamespace(ethNode, operator, true);
        vm.stopPrank();
        
        // Verify approval
        assertTrue(registry.isApprovedForNamespace(ethNode, operator));
    }
    
    function test_010____setApprovalForNamespace__________DisapprovesOperatorForSpecificNode() public {
        // Setup: admin creates .eth node, transfers to user1, user1 approves operator
        vm.startPrank(admin);
        registry.setSubnameOwner("eth", "", user1, block.timestamp + TEST_EXPIRATION, false);
        vm.stopPrank();
        
        vm.startPrank(user1);
        registry.setApprovalForNamespace(ethNode, operator, true);
        vm.stopPrank();
        
        // Test disapproving operator for specific node
        vm.startPrank(user1);
        vm.expectEmit(true, true, true, true);
        emit ECSRegistry.ApprovalForNamespace(ethNode, user1, operator, false);
        registry.setApprovalForNamespace(ethNode, operator, false);
        vm.stopPrank();
        
        // Verify disapproval
        assertFalse(registry.isApprovedForNamespace(ethNode, operator));
    }
    
    function test_011____setApprovalForNamespace__________OnlyNamespaceOwnerCanSetApproval() public {
        // Setup: admin creates .eth node and transfers to user1
        vm.startPrank(admin);
        registry.setSubnameOwner("eth", "", user1, block.timestamp + TEST_EXPIRATION, false);
        vm.stopPrank();
        
        // Test that non-owner cannot set approval
        vm.startPrank(user2);
        vm.expectRevert(abi.encodeWithSelector(ECSRegistry.OnlyNamespaceOwner.selector, ethNode, user2, user1));
        registry.setApprovalForNamespace(ethNode, operator, true);
        vm.stopPrank();
        
        // Verify no approval was set
        assertFalse(registry.isApprovedForNamespace(ethNode, operator));
    }
    
    /* --- owner Tests --- */
    
    function test_012____owner______________________ReturnsCorrectOwnerAddress() public {
        // Test root node owner
        assertEq(registry.owner(ROOT_NODE), admin);
        
        // Setup: admin creates .eth node and transfers to user1
        vm.startPrank(admin);
        registry.setSubnameOwner("eth", "", user1, block.timestamp + TEST_EXPIRATION, false);
        vm.stopPrank();
        
        // Test .eth node owner
        assertEq(registry.owner(ethNode), user1);
        
        // Test non-existent node
        bytes32 nonExistentNode = NameCoder.namehash(NameCoder.encode("nonexistent"), 0);
        assertEq(registry.owner(nonExistentNode), address(0));
    }
    
    function test_013____owner______________________HandlesRegistryAsOwnerEdgeCase() public {
        // Test the edge case where registry itself is set as owner
        vm.startPrank(admin);
        registry.setSubnameOwner("eth", "", address(registry), block.timestamp + TEST_EXPIRATION, false);
        vm.stopPrank();
        
        // Should return address(0) when registry is the owner
        assertEq(registry.owner(ethNode), address(0));
    }
    
    /* --- recordExists Tests --- */
    
    function test_014____recordExists________________ReturnsTrueForExistingRecords() public {
        // Root node should exist
        assertTrue(registry.recordExists(ROOT_NODE));
        
        // Create .eth node
        vm.startPrank(admin);
        registry.setSubnameOwner("eth", "", user1, block.timestamp + TEST_EXPIRATION, false);
        vm.stopPrank();
        
        // .eth node should exist
        assertTrue(registry.recordExists(ethNode));
    }
    
    function test_015____recordExists________________ReturnsFalseForNonExistentRecords() public {
        bytes32 nonExistentNode = NameCoder.namehash(NameCoder.encode("nonexistent"), 0);
        assertFalse(registry.recordExists(nonExistentNode));
    }
    
    /* --- isApprovedForNamespace Tests --- */
    
    function test_016____isApprovedForNamespace___________ReturnsTrueForApprovedOperators() public {
        // Setup: admin creates .eth node and transfers to user1
        vm.startPrank(admin);
        registry.setSubnameOwner("eth", "", user1, block.timestamp + TEST_EXPIRATION, false);
        vm.stopPrank();
        
        // Setup node-specific approval
        vm.startPrank(user1);
        registry.setApprovalForNamespace(ethNode, operator, true);
        vm.stopPrank();
        
        // Test approval check
        assertTrue(registry.isApprovedForNamespace(ethNode, operator));
    }
    
    function test_017____isApprovedForNamespace___________ReturnsFalseForNonApprovedOperators() public {
        // Setup: admin creates .eth node and transfers to user1
        vm.startPrank(admin);
        registry.setSubnameOwner("eth", "", user1, block.timestamp + TEST_EXPIRATION, false);
        vm.stopPrank();
        
        // Test without setting approval
        assertFalse(registry.isApprovedForNamespace(ethNode, operator));
        
        // Test after disapproval
        vm.startPrank(user1);
        registry.setApprovalForNamespace(ethNode, operator, true);
        registry.setApprovalForNamespace(ethNode, operator, false);
        vm.stopPrank();
        
        assertFalse(registry.isApprovedForNamespace(ethNode, operator));
    }
    
    /* --- isAuthorizedForNamespace Tests --- */
    
    function test_018____isAuthorizedForNamespace_________ReturnsTrueForNodeOwner() public {
        // Setup: admin creates .eth node and transfers to user1
        vm.startPrank(admin);
        registry.setSubnameOwner("eth", "", user1, block.timestamp + TEST_EXPIRATION, false);
        vm.stopPrank();
        
        // Test that node owner is authorized
        assertTrue(registry.isAuthorizedForNamespace(ethNode, user1));
    }
    
    function test_019____isAuthorizedForNamespace_________ReturnsTrueForNodeSpecificApprovedOperator() public {
        // Setup: admin creates .eth node and transfers to user1
        vm.startPrank(admin);
        registry.setSubnameOwner("eth", "", user1, block.timestamp + TEST_EXPIRATION, false);
        vm.stopPrank();
        
        // Setup node-specific approval
        vm.startPrank(user1);
        registry.setApprovalForNamespace(ethNode, operator, true);
        vm.stopPrank();
        
        // Test that node-specific approved operator is authorized
        assertTrue(registry.isAuthorizedForNamespace(ethNode, operator));
    }
    
    function test_020____isAuthorizedForNamespace_________ReturnsFalseForUnauthorizedAddress() public {
        // Setup: admin creates .eth node and transfers to user1
        vm.startPrank(admin);
        registry.setSubnameOwner("eth", "", user1, block.timestamp + TEST_EXPIRATION, false);
        vm.stopPrank();
        
        // Test that unauthorized address is not authorized
        assertFalse(registry.isAuthorizedForNamespace(ethNode, user2));
    }
    
    /* --- Complex Integration Tests --- */
    
    function test_021____complexHierarchy____________CreatesAndManagesMultiLevelHierarchy() public {
        // Create a complex hierarchy: root -> com -> example -> api -> v1
        bytes32 comNode = NameCoder.namehash(NameCoder.encode("com"), 0);
        bytes32 exampleNode = NameCoder.namehash(NameCoder.encode("example.com"), 0);
        bytes32 apiNode = NameCoder.namehash(NameCoder.encode("api.example.com"), 0);
        bytes32 v1Node = NameCoder.namehash(NameCoder.encode("v1.api.example.com"), 0);
        
        // Admin creates .com
        vm.startPrank(admin);
        registry.setSubnameOwner("com", "", user1, block.timestamp + TEST_EXPIRATION, false);
        vm.stopPrank();
        
        // User1 creates example.com
        vm.startPrank(user1);
        registry.setSubnameOwner("example", "com", user1, block.timestamp + TEST_EXPIRATION, false);
        vm.stopPrank();
        
        // User1 creates api.example.com and transfers to user2
        vm.startPrank(user1);
        registry.setSubnameOwner("api", "example.com", user2, block.timestamp + TEST_EXPIRATION, false);
        vm.stopPrank();
        
        // User2 creates v1.api.example.com
        vm.startPrank(user2);
        registry.setSubnameOwner("v1", "api.example.com", user2, block.timestamp + TEST_EXPIRATION, false);
        vm.stopPrank();
        
        // Verify the entire hierarchy
        assertEq(registry.owner(comNode), user1);
        assertEq(registry.owner(exampleNode), user1);
        assertEq(registry.owner(apiNode), user2);
        assertEq(registry.owner(v1Node), user2);
        
        // Verify all records exist
        assertTrue(registry.recordExists(comNode));
        assertTrue(registry.recordExists(exampleNode));
        assertTrue(registry.recordExists(apiNode));
        assertTrue(registry.recordExists(v1Node));
    }
    
    function test_022____approvalManagement__________ManagesComplexApprovalScenarios() public {
        // Setup: admin creates .eth node and transfers to user1
        vm.startPrank(admin);
        registry.setSubnameOwner("eth", "", user1, block.timestamp + TEST_EXPIRATION, false);
        vm.stopPrank();
        
        // User1 sets node-specific approval for operator on .eth node
        vm.startPrank(user1);
        registry.setApprovalForNamespace(ethNode, operator, true);
        vm.stopPrank();
        
        // Operator can now create name.eth subnode
        vm.startPrank(operator);
        registry.setSubnameOwner("name", "eth", user2, block.timestamp + TEST_EXPIRATION, false);
        vm.stopPrank();
        
        // User1 can still manage the .eth node (transfer ownership)
        vm.startPrank(user1);
        registry.setOwner(ethNode, user2);
        vm.stopPrank();
        
        // Verify final state
        assertEq(registry.owner(ethNode), user2);      // .eth owned by user2
        assertEq(registry.owner(nameNode), user2);     // name.eth owned by user2
        
        // After ownership transfer, the node-specific approval from user1 is no longer valid
        // because the approval is tied to the original owner (user1)
        assertFalse(registry.isApprovedForNamespace(ethNode, operator));
        
        // The operator is no longer authorized for the node since ownership changed
        assertFalse(registry.isAuthorizedForNamespace(ethNode, operator));
        
        // Only the new owner (user2) is authorized
        assertTrue(registry.isAuthorizedForNamespace(ethNode, user2));
    }
    
    /* --- Expiration Management Tests --- */
    
    function test_023____expiration__________________SetsAndReadsExpirationCorrectly() public {
        uint256 expiration = block.timestamp + TEST_EXPIRATION;
        
        // Create .eth node with expiration
        vm.startPrank(admin);
        registry.setSubnameOwner("eth", "", user1, expiration, false);
        vm.stopPrank();
        
        // Verify expiration is set correctly
        assertEq(registry.getExpiration(ethNode), expiration);
        assertFalse(registry.isExpired(ethNode));
        
        // Fast forward past expiration
        vm.warp(expiration + 1);
        
        // Verify node is now expired
        assertTrue(registry.isExpired(ethNode));
    }
    
    function test_024____expiration__________________UpdatesExpirationCorrectly() public {
        uint256 initialExpiration = block.timestamp + TEST_EXPIRATION;
        uint256 newExpiration = block.timestamp + TEST_EXPIRATION * 2;
        
        // Create .eth node with initial expiration
        vm.startPrank(admin);
        registry.setSubnameOwner("eth", "", user1, initialExpiration, false);
        vm.stopPrank();
        
        // Update expiration (admin has CONTROLLER_ROLE)
        vm.startPrank(admin);
        vm.expectEmit(true, false, false, true);
        emit ECSRegistry.ExpirationSet(ethNode, newExpiration);
        registry.setExpiration(ethNode, newExpiration);
        vm.stopPrank();
        
        // Verify new expiration
        assertEq(registry.getExpiration(ethNode), newExpiration);
    }
    
    function test_025____expiration__________________OnlyControllerCanUpdateExpiration() public {
        uint256 expiration = block.timestamp + TEST_EXPIRATION;
        
        // Create .eth node with expiration
        vm.startPrank(admin);
        registry.setSubnameOwner("eth", "", user1, expiration, false);
        vm.stopPrank();
        
        // Try to update expiration from non-controller (user2)
        vm.startPrank(user2);
        vm.expectRevert();  // AccessControlUnauthorizedAccount error expected
        registry.setExpiration(ethNode, expiration * 2);
        vm.stopPrank();
        
        // Verify expiration unchanged
        assertEq(registry.getExpiration(ethNode), expiration);
        
        // Owner (user1) also cannot update expiration without CONTROLLER_ROLE
        vm.startPrank(user1);
        vm.expectRevert();  // AccessControlUnauthorizedAccount error expected
        registry.setExpiration(ethNode, expiration * 2);
        vm.stopPrank();
        
        // Verify expiration still unchanged
        assertEq(registry.getExpiration(ethNode), expiration);
    }
} 