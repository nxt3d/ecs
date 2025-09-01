// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/credentials/controlled-accounts/ControlledAccounts.sol";

contract ControlledAccountsSimpleTest is Test {
    ControlledAccounts public controlledAccounts;
    
    /* --- Test Accounts --- */
    
    address admin = address(0x1001);
    address user1 = address(0x1002);
    address user2 = address(0x1003);
    address user3 = address(0x1004);
    
    // Test addresses for controlled accounts
    address constant CONTROLLED_ACCOUNT_1 = address(0x1234567890123456789012345678901234567890);
    address constant CONTROLLED_ACCOUNT_2 = address(0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD);
    address constant CONTROLLED_ACCOUNT_3 = address(0x9876543210987654321098765432109876543210);
    
    string constant DEFAULT_TEXT_RECORD_KEY = "eth.ecs.controlled-accounts.accounts";
    
    /* --- Setup --- */
    
    function setUp() public {
        vm.startPrank(admin);
        controlledAccounts = new ControlledAccounts();
        vm.stopPrank();
    }
    
    /* --- Basic Functionality Tests --- */
    
    function test_declareControlledAccount_single() public {
        vm.startPrank(user1);
        
        vm.expectEmit(true, true, false, true);
        address[] memory expectedAccounts = new address[](1);
        expectedAccounts[0] = CONTROLLED_ACCOUNT_1;
        emit ControlledAccounts.ControlledAccountsDeclaredInGroup(user1, bytes32(0), expectedAccounts);
        
        controlledAccounts.declareControlledAccount(CONTROLLED_ACCOUNT_1);
        
        vm.stopPrank();
        
        // Verify controlled account
        address[] memory declaredAccounts = controlledAccounts.getControlledAccounts(user1);
        assertEq(declaredAccounts.length, 1);
        assertEq(declaredAccounts[0], CONTROLLED_ACCOUNT_1);
    }
    
    function test_declareControlledAccount_multiple() public {
        vm.startPrank(user1);
        
        // Add multiple accounts one by one
        controlledAccounts.declareControlledAccount(CONTROLLED_ACCOUNT_1);
        controlledAccounts.declareControlledAccount(CONTROLLED_ACCOUNT_2);
        controlledAccounts.declareControlledAccount(CONTROLLED_ACCOUNT_3);
        
        vm.stopPrank();
        
        // Verify all accounts were added
        address[] memory declaredAccounts = controlledAccounts.getControlledAccounts(user1);
        assertEq(declaredAccounts.length, 3);
        assertEq(declaredAccounts[0], CONTROLLED_ACCOUNT_1);
        assertEq(declaredAccounts[1], CONTROLLED_ACCOUNT_2);
        assertEq(declaredAccounts[2], CONTROLLED_ACCOUNT_3);
    }
    
    function test_declareControlledAccounts_array() public {
        address[] memory accounts = new address[](2);
        accounts[0] = CONTROLLED_ACCOUNT_1;
        accounts[1] = CONTROLLED_ACCOUNT_2;
        
        vm.startPrank(user1);
        
        vm.expectEmit(true, true, false, true);
        emit ControlledAccounts.ControlledAccountsDeclaredInGroup(user1, bytes32(0), accounts);
        
        controlledAccounts.declareControlledAccounts(accounts);
        
        vm.stopPrank();
        
        // Verify controlled accounts
        address[] memory declaredAccounts = controlledAccounts.getControlledAccounts(user1);
        assertEq(declaredAccounts.length, 2);
        assertEq(declaredAccounts[0], CONTROLLED_ACCOUNT_1);
        assertEq(declaredAccounts[1], CONTROLLED_ACCOUNT_2);
    }
    
    function test_removeControlledAccount() public {
        // First add accounts
        vm.startPrank(user1);
        controlledAccounts.declareControlledAccount(CONTROLLED_ACCOUNT_1);
        controlledAccounts.declareControlledAccount(CONTROLLED_ACCOUNT_2);
        vm.stopPrank();
        
        // Remove one account
        vm.startPrank(user1);
        
        vm.expectEmit(true, true, true, false);
        emit ControlledAccounts.ControlledAccountRemovedFromGroup(user1, bytes32(0), CONTROLLED_ACCOUNT_1);
        
        controlledAccounts.removeControlledAccount(CONTROLLED_ACCOUNT_1);
        
        vm.stopPrank();
        
        // Verify account was removed
        address[] memory remainingAccounts = controlledAccounts.getControlledAccounts(user1);
        assertEq(remainingAccounts.length, 1);
        assertEq(remainingAccounts[0], CONTROLLED_ACCOUNT_2);
    }
    
    function test_removeControlledAccount_nonExistent() public {
        // Try to remove account that doesn't exist - should not revert, just do nothing
        vm.startPrank(user1);
        controlledAccounts.removeControlledAccount(CONTROLLED_ACCOUNT_1);
        vm.stopPrank();
        
        // Verify no accounts
        address[] memory accounts = controlledAccounts.getControlledAccounts(user1);
        assertEq(accounts.length, 0);
    }
    
    function test_setController() public {
        vm.startPrank(CONTROLLED_ACCOUNT_1);
        
        vm.expectEmit(true, true, false, false);
        emit ControlledAccounts.ControllerSet(CONTROLLED_ACCOUNT_1, user1);
        
        controlledAccounts.setController(user1);
        
        vm.stopPrank();
        
        // Verify controller was set
        assertEq(controlledAccounts.getController(CONTROLLED_ACCOUNT_1), user1);
    }
    
    function test_setController_replaceExisting() public {
        // Set initial controller
        vm.startPrank(CONTROLLED_ACCOUNT_1);
        controlledAccounts.setController(user1);
        vm.stopPrank();
        
        // Replace with new controller
        vm.startPrank(CONTROLLED_ACCOUNT_1);
        
        vm.expectEmit(true, true, false, false);
        emit ControlledAccounts.ControllerSet(CONTROLLED_ACCOUNT_1, user2);
        
        controlledAccounts.setController(user2);
        
        vm.stopPrank();
        
        // Verify new controller was set
        assertEq(controlledAccounts.getController(CONTROLLED_ACCOUNT_1), user2);
    }
    
    function test_setController_toZero() public {
        // Set controller first
        vm.startPrank(CONTROLLED_ACCOUNT_1);
        controlledAccounts.setController(user1);
        vm.stopPrank();
        
        // Remove controller by setting to zero address
        vm.startPrank(CONTROLLED_ACCOUNT_1);
        
        vm.expectEmit(true, true, false, false);
        emit ControlledAccounts.ControllerRemoved(CONTROLLED_ACCOUNT_1, user1);
        
        controlledAccounts.setController(address(0));
        
        vm.stopPrank();
        
        // Verify controller was removed
        assertEq(controlledAccounts.getController(CONTROLLED_ACCOUNT_1), address(0));
    }
    
    function test_getControlledAccounts_empty() public view {
        address[] memory accounts = controlledAccounts.getControlledAccounts(user1);
        assertEq(accounts.length, 0);
    }
    
    function test_getController_empty() public view {
        address controller = controlledAccounts.getController(CONTROLLED_ACCOUNT_1);
        assertEq(controller, address(0));
    }
    
    function test_multipleControllers() public {
        // User1 declares accounts
        vm.startPrank(user1);
        controlledAccounts.declareControlledAccount(CONTROLLED_ACCOUNT_1);
        controlledAccounts.declareControlledAccount(CONTROLLED_ACCOUNT_2);
        vm.stopPrank();
        
        // User2 declares different accounts
        vm.startPrank(user2);
        controlledAccounts.declareControlledAccount(CONTROLLED_ACCOUNT_3);
        vm.stopPrank();
        
        // Some controlled accounts verify their controllers
        vm.startPrank(CONTROLLED_ACCOUNT_1);
        controlledAccounts.setController(user1);
        vm.stopPrank();
        
        vm.startPrank(CONTROLLED_ACCOUNT_3);
        controlledAccounts.setController(user2);
        vm.stopPrank();
        
        // Verify all relationships
        address[] memory user1Accounts = controlledAccounts.getControlledAccounts(user1);
        assertEq(user1Accounts.length, 2);
        assertEq(user1Accounts[0], CONTROLLED_ACCOUNT_1);
        assertEq(user1Accounts[1], CONTROLLED_ACCOUNT_2);
        
        address[] memory user2Accounts = controlledAccounts.getControlledAccounts(user2);
        assertEq(user2Accounts.length, 1);
        assertEq(user2Accounts[0], CONTROLLED_ACCOUNT_3);
        
        assertEq(controlledAccounts.getController(CONTROLLED_ACCOUNT_1), user1);
        assertEq(controlledAccounts.getController(CONTROLLED_ACCOUNT_3), user2);
        assertEq(controlledAccounts.getController(CONTROLLED_ACCOUNT_2), address(0)); // Not verified
    }
    
    function test_allowDuplicates() public {
        vm.startPrank(user1);
        
        // Add same account multiple times - should be allowed
        controlledAccounts.declareControlledAccount(CONTROLLED_ACCOUNT_1);
        controlledAccounts.declareControlledAccount(CONTROLLED_ACCOUNT_1);
        controlledAccounts.declareControlledAccount(CONTROLLED_ACCOUNT_1);
        
        vm.stopPrank();
        
        // Verify all entries were added (duplicates allowed)
        address[] memory accounts = controlledAccounts.getControlledAccounts(user1);
        assertEq(accounts.length, 3);
        assertEq(accounts[0], CONTROLLED_ACCOUNT_1);
        assertEq(accounts[1], CONTROLLED_ACCOUNT_1);
        assertEq(accounts[2], CONTROLLED_ACCOUNT_1);
    }
    
    function test_allowZeroAddress() public {
        vm.startPrank(user1);
        
        // Should be allowed to declare zero address as controlled
        controlledAccounts.declareControlledAccount(address(0));
        
        vm.stopPrank();
        
        address[] memory accounts = controlledAccounts.getControlledAccounts(user1);
        assertEq(accounts.length, 1);
        assertEq(accounts[0], address(0));
    }
    
    function test_allowSelfControl() public {
        vm.startPrank(user1);
        
        // Should be allowed to declare self as controlled
        controlledAccounts.declareControlledAccount(user1);
        
        vm.stopPrank();
        
        address[] memory accounts = controlledAccounts.getControlledAccounts(user1);
        assertEq(accounts.length, 1);
        assertEq(accounts[0], user1);
    }
    
    function test_setTextRecordKey() public {
        string memory newKey = "new.custom.key";
        
        vm.startPrank(admin);
        
        vm.expectEmit(false, false, false, true);
        emit ControlledAccounts.TextRecordKeyUpdated(DEFAULT_TEXT_RECORD_KEY, newKey);
        
        controlledAccounts.setTextRecordKey(newKey);
        
        vm.stopPrank();
        
        assertEq(controlledAccounts.textRecordKey(), newKey);
    }
    
    /* --- Group Functionality Tests --- */
    
    function test_declareControlledAccount_inGroup() public {
        bytes32 familyGroup = keccak256(bytes("family"));
        
        vm.startPrank(user1);
        
        vm.expectEmit(true, true, false, true);
        address[] memory expectedAccounts = new address[](1);
        expectedAccounts[0] = CONTROLLED_ACCOUNT_1;
        emit ControlledAccounts.ControlledAccountsDeclaredInGroup(user1, familyGroup, expectedAccounts);
        
        controlledAccounts.declareControlledAccount(familyGroup, CONTROLLED_ACCOUNT_1);
        
        vm.stopPrank();
        
        // Verify controlled account in group
        address[] memory declaredAccounts = controlledAccounts.getControlledAccounts(user1, familyGroup);
        assertEq(declaredAccounts.length, 1);
        assertEq(declaredAccounts[0], CONTROLLED_ACCOUNT_1);
        
        // Verify default group is empty
        address[] memory defaultAccounts = controlledAccounts.getControlledAccounts(user1);
        assertEq(defaultAccounts.length, 0);
    }
    
    function test_declareControlledAccounts_array_inGroup() public {
        bytes32 workGroup = keccak256(bytes("work"));
        address[] memory accounts = new address[](2);
        accounts[0] = CONTROLLED_ACCOUNT_1;
        accounts[1] = CONTROLLED_ACCOUNT_2;
        
        vm.startPrank(user1);
        
        vm.expectEmit(true, true, false, true);
        emit ControlledAccounts.ControlledAccountsDeclaredInGroup(user1, workGroup, accounts);
        
        controlledAccounts.declareControlledAccounts(workGroup, accounts);
        
        vm.stopPrank();
        
        // Verify controlled accounts in group
        address[] memory declaredAccounts = controlledAccounts.getControlledAccounts(user1, workGroup);
        assertEq(declaredAccounts.length, 2);
        assertEq(declaredAccounts[0], CONTROLLED_ACCOUNT_1);
        assertEq(declaredAccounts[1], CONTROLLED_ACCOUNT_2);
    }
    
    function test_removeControlledAccount_fromGroup() public {
        bytes32 familyGroup = keccak256(bytes("family"));
        
        // First add accounts to group
        vm.startPrank(user1);
        controlledAccounts.declareControlledAccount(familyGroup, CONTROLLED_ACCOUNT_1);
        controlledAccounts.declareControlledAccount(familyGroup, CONTROLLED_ACCOUNT_2);
        vm.stopPrank();
        
        // Remove one account from group
        vm.startPrank(user1);
        
        vm.expectEmit(true, true, true, false);
        emit ControlledAccounts.ControlledAccountRemovedFromGroup(user1, familyGroup, CONTROLLED_ACCOUNT_1);
        
        controlledAccounts.removeControlledAccount(familyGroup, CONTROLLED_ACCOUNT_1);
        
        vm.stopPrank();
        
        // Verify account was removed from group
        address[] memory remainingAccounts = controlledAccounts.getControlledAccounts(user1, familyGroup);
        assertEq(remainingAccounts.length, 1);
        assertEq(remainingAccounts[0], CONTROLLED_ACCOUNT_2);
    }
    
    function test_multipleGroups() public {
        bytes32 familyGroup = keccak256(bytes("family"));
        bytes32 workGroup = keccak256(bytes("work"));
        bytes32 friendsGroup = keccak256(bytes("friends"));
        
        vm.startPrank(user1);
        
        // Add accounts to different groups
        controlledAccounts.declareControlledAccount(familyGroup, CONTROLLED_ACCOUNT_1);
        controlledAccounts.declareControlledAccount(familyGroup, CONTROLLED_ACCOUNT_2);
        
        controlledAccounts.declareControlledAccount(workGroup, CONTROLLED_ACCOUNT_2);
        controlledAccounts.declareControlledAccount(workGroup, CONTROLLED_ACCOUNT_3);
        
        controlledAccounts.declareControlledAccount(friendsGroup, CONTROLLED_ACCOUNT_1);
        controlledAccounts.declareControlledAccount(friendsGroup, CONTROLLED_ACCOUNT_3);
        
        // Add to default group
        controlledAccounts.declareControlledAccount(CONTROLLED_ACCOUNT_1);
        
        vm.stopPrank();
        
        // Verify each group has correct accounts
        address[] memory familyAccounts = controlledAccounts.getControlledAccounts(user1, familyGroup);
        assertEq(familyAccounts.length, 2);
        assertEq(familyAccounts[0], CONTROLLED_ACCOUNT_1);
        assertEq(familyAccounts[1], CONTROLLED_ACCOUNT_2);
        
        address[] memory workAccounts = controlledAccounts.getControlledAccounts(user1, workGroup);
        assertEq(workAccounts.length, 2);
        assertEq(workAccounts[0], CONTROLLED_ACCOUNT_2);
        assertEq(workAccounts[1], CONTROLLED_ACCOUNT_3);
        
        address[] memory friendsAccounts = controlledAccounts.getControlledAccounts(user1, friendsGroup);
        assertEq(friendsAccounts.length, 2);
        assertEq(friendsAccounts[0], CONTROLLED_ACCOUNT_1);
        assertEq(friendsAccounts[1], CONTROLLED_ACCOUNT_3);
        
        address[] memory defaultAccounts = controlledAccounts.getControlledAccounts(user1);
        assertEq(defaultAccounts.length, 1);
        assertEq(defaultAccounts[0], CONTROLLED_ACCOUNT_1);
    }
    
    function test_groupIsolation() public {
        bytes32 group1 = keccak256(bytes("group1"));
        bytes32 group2 = keccak256(bytes("group2"));
        
        vm.startPrank(user1);
        
        // Add same account to different groups
        controlledAccounts.declareControlledAccount(group1, CONTROLLED_ACCOUNT_1);
        controlledAccounts.declareControlledAccount(group2, CONTROLLED_ACCOUNT_1);
        
        vm.stopPrank();
        
        // Verify account exists in both groups
        address[] memory group1Accounts = controlledAccounts.getControlledAccounts(user1, group1);
        assertEq(group1Accounts.length, 1);
        assertEq(group1Accounts[0], CONTROLLED_ACCOUNT_1);
        
        address[] memory group2Accounts = controlledAccounts.getControlledAccounts(user1, group2);
        assertEq(group2Accounts.length, 1);
        assertEq(group2Accounts[0], CONTROLLED_ACCOUNT_1);
        
        // Remove from one group only
        vm.startPrank(user1);
        controlledAccounts.removeControlledAccount(group1, CONTROLLED_ACCOUNT_1);
        vm.stopPrank();
        
        // Verify account removed from group1 but still in group2
        address[] memory group1AccountsAfter = controlledAccounts.getControlledAccounts(user1, group1);
        assertEq(group1AccountsAfter.length, 0);
        
        address[] memory group2AccountsAfter = controlledAccounts.getControlledAccounts(user1, group2);
        assertEq(group2AccountsAfter.length, 1);
        assertEq(group2AccountsAfter[0], CONTROLLED_ACCOUNT_1);
    }
    
    function test_defaultGroupVsCustomGroup() public {
        bytes32 customGroup = keccak256(bytes("custom"));
        
        vm.startPrank(user1);
        
        // Add to default group
        controlledAccounts.declareControlledAccount(CONTROLLED_ACCOUNT_1);
        
        // Add to custom group
        controlledAccounts.declareControlledAccount(customGroup, CONTROLLED_ACCOUNT_2);
        
        vm.stopPrank();
        
        // Verify default group
        address[] memory defaultAccounts = controlledAccounts.getControlledAccounts(user1);
        assertEq(defaultAccounts.length, 1);
        assertEq(defaultAccounts[0], CONTROLLED_ACCOUNT_1);
        
        // Verify custom group
        address[] memory customAccounts = controlledAccounts.getControlledAccounts(user1, customGroup);
        assertEq(customAccounts.length, 1);
        assertEq(customAccounts[0], CONTROLLED_ACCOUNT_2);
        
        // Verify they are isolated
        assertEq(defaultAccounts[0], CONTROLLED_ACCOUNT_1);
        assertEq(customAccounts[0], CONTROLLED_ACCOUNT_2);
    }
    
    function test_removeControlledAccount_nonExistentFromGroup() public {
        bytes32 group = keccak256(bytes("test"));
        
        // Try to remove account that doesn't exist in group - should not revert, just do nothing
        vm.startPrank(user1);
        controlledAccounts.removeControlledAccount(group, CONTROLLED_ACCOUNT_1);
        vm.stopPrank();
        
        // Verify group is empty
        address[] memory accounts = controlledAccounts.getControlledAccounts(user1, group);
        assertEq(accounts.length, 0);
    }
    
    function test_getControlledAccounts_emptyGroup() public view {
        bytes32 group = keccak256(bytes("empty"));
        address[] memory accounts = controlledAccounts.getControlledAccounts(user1, group);
        assertEq(accounts.length, 0);
    }
}
