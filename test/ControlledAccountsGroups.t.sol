// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/credentials/controlled-accounts/ControlledAccounts.sol";

/**
 * @title ControlledAccountsGroupsTest
 * @dev Test group functionality in ControlledAccounts contract
 * 
 * This test verifies that the group functionality works correctly,
 * including group isolation, credential resolution with groups,
 * and proper event emission.
 */
contract ControlledAccountsGroupsTest is Test {
    
    /* --- State Variables --- */
    
    ControlledAccounts public controlledAccounts;
    
    /* --- Test Addresses --- */
    
    address constant CONTROLLER1 = address(0x1111111111111111111111111111111111111111);
    address constant CONTROLLER2 = address(0x2222222222222222222222222222222222222222);
    address constant CONTROLLED1 = address(0x3333333333333333333333333333333333333333);
    address constant CONTROLLED2 = address(0x4444444444444444444444444444444444444444);
    address constant CONTROLLED3 = address(0x5555555555555555555555555555555555555555);
    address constant CONTROLLED4 = address(0x6666666666666666666666666666666666666666);
    
    /* --- Test Group IDs --- */
    
    bytes32 constant FAMILY_GROUP = keccak256(bytes("family"));
    bytes32 constant WORK_GROUP = keccak256(bytes("work"));
    bytes32 constant FRIENDS_GROUP = keccak256(bytes("friends"));
    bytes32 constant PROJECT_GROUP = keccak256(bytes("project"));
    
    /* --- Setup --- */
    
    function setUp() public {
        controlledAccounts = new ControlledAccounts();
        _setupTestData();
    }
    
    /* --- Test Data Setup --- */
    
    function _setupTestData() internal {
        // Controller1 sets up accounts in different groups
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(FAMILY_GROUP, CONTROLLED1);
        
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(FAMILY_GROUP, CONTROLLED2);
        
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(WORK_GROUP, CONTROLLED2);
        
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(WORK_GROUP, CONTROLLED3);
        
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(FRIENDS_GROUP, CONTROLLED1);
        
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(FRIENDS_GROUP, CONTROLLED3);
        
        // Controller1 also has some accounts in default group
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(CONTROLLED4);
        
        // Controller2 sets up different groups
        vm.prank(CONTROLLER2);
        controlledAccounts.declareControlledAccount(PROJECT_GROUP, CONTROLLED1);
        
        vm.prank(CONTROLLER2);
        controlledAccounts.declareControlledAccount(PROJECT_GROUP, CONTROLLED4);
        
        // Some controlled accounts verify their controllers
        vm.prank(CONTROLLED1);
        controlledAccounts.setController(CONTROLLER1);
        
        vm.prank(CONTROLLED2);
        controlledAccounts.setController(CONTROLLER1);
        
        vm.prank(CONTROLLED3);
        controlledAccounts.setController(CONTROLLER1);
        
        vm.prank(CONTROLLED4);
        controlledAccounts.setController(CONTROLLER1);
    }
    
    /* --- Group Management Tests --- */
    
    function test_001____groupManagement____AddAccountsToGroups() public {
        // Verify family group
        address[] memory familyAccounts = controlledAccounts.getControlledAccounts(CONTROLLER1, FAMILY_GROUP);
        assertEq(familyAccounts.length, 2);
        assertEq(familyAccounts[0], CONTROLLED1);
        assertEq(familyAccounts[1], CONTROLLED2);
        
        // Verify work group
        address[] memory workAccounts = controlledAccounts.getControlledAccounts(CONTROLLER1, WORK_GROUP);
        assertEq(workAccounts.length, 2);
        assertEq(workAccounts[0], CONTROLLED2);
        assertEq(workAccounts[1], CONTROLLED3);
        
        // Verify friends group
        address[] memory friendsAccounts = controlledAccounts.getControlledAccounts(CONTROLLER1, FRIENDS_GROUP);
        assertEq(friendsAccounts.length, 2);
        assertEq(friendsAccounts[0], CONTROLLED1);
        assertEq(friendsAccounts[1], CONTROLLED3);
        
        // Verify default group
        address[] memory defaultAccounts = controlledAccounts.getControlledAccounts(CONTROLLER1);
        assertEq(defaultAccounts.length, 1);
        assertEq(defaultAccounts[0], CONTROLLED4);
    }
    
    function test_002____groupManagement____GroupIsolation() public {
        // Add same account to different groups
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(FAMILY_GROUP, CONTROLLED4);
        
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(WORK_GROUP, CONTROLLED4);
        
        // Verify account exists in both groups
        address[] memory familyAccounts = controlledAccounts.getControlledAccounts(CONTROLLER1, FAMILY_GROUP);
        address[] memory workAccounts = controlledAccounts.getControlledAccounts(CONTROLLER1, WORK_GROUP);
        
        assertEq(familyAccounts.length, 3); // CONTROLLED1, CONTROLLED2, CONTROLLED4
        assertEq(workAccounts.length, 3);   // CONTROLLED2, CONTROLLED3, CONTROLLED4
        
        // Remove from one group only
        vm.prank(CONTROLLER1);
        controlledAccounts.removeControlledAccount(FAMILY_GROUP, CONTROLLED4);
        
        // Verify account removed from family but still in work
        address[] memory familyAccountsAfter = controlledAccounts.getControlledAccounts(CONTROLLER1, FAMILY_GROUP);
        address[] memory workAccountsAfter = controlledAccounts.getControlledAccounts(CONTROLLER1, WORK_GROUP);
        
        assertEq(familyAccountsAfter.length, 2); // Back to CONTROLLED1, CONTROLLED2
        assertEq(workAccountsAfter.length, 3);   // Still CONTROLLED2, CONTROLLED3, CONTROLLED4
    }
    
    function test_003____groupManagement____MultipleControllersWithGroups() public {
        // Verify Controller2's project group
        address[] memory projectAccounts = controlledAccounts.getControlledAccounts(CONTROLLER2, PROJECT_GROUP);
        assertEq(projectAccounts.length, 2);
        assertEq(projectAccounts[0], CONTROLLED1);
        assertEq(projectAccounts[1], CONTROLLED4);
        
        // Verify Controller2 has no default group accounts
        address[] memory defaultAccounts = controlledAccounts.getControlledAccounts(CONTROLLER2);
        assertEq(defaultAccounts.length, 0);
    }
    
    function test_004____groupManagement____AddMultipleAccountsToGroup() public {
        address[] memory newAccounts = new address[](2);
        newAccounts[0] = address(0x7777777777777777777777777777777777777777);
        newAccounts[1] = address(0x8888888888888888888888888888888888888888);
        
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccounts(FAMILY_GROUP, newAccounts);
        
        // Verify accounts were added
        address[] memory familyAccounts = controlledAccounts.getControlledAccounts(CONTROLLER1, FAMILY_GROUP);
        assertEq(familyAccounts.length, 4); // Original 2 + new 2
        assertEq(familyAccounts[2], address(0x7777777777777777777777777777777777777777));
        assertEq(familyAccounts[3], address(0x8888888888888888888888888888888888888888));
    }
    
    function test_005____groupManagement____RemoveFromGroup() public {
        // Remove CONTROLLED2 from family group
        vm.prank(CONTROLLER1);
        controlledAccounts.removeControlledAccount(FAMILY_GROUP, CONTROLLED2);
        
        // Verify removal
        address[] memory familyAccounts = controlledAccounts.getControlledAccounts(CONTROLLER1, FAMILY_GROUP);
        assertEq(familyAccounts.length, 1);
        assertEq(familyAccounts[0], CONTROLLED1);
        
        // Verify CONTROLLED2 still exists in work group
        address[] memory workAccounts = controlledAccounts.getControlledAccounts(CONTROLLER1, WORK_GROUP);
        assertEq(workAccounts.length, 2);
        assertEq(workAccounts[0], CONTROLLED2);
        assertEq(workAccounts[1], CONTROLLED3);
    }
    
    function test_006____groupManagement____RemoveNonExistentFromGroup() public {
        // Try to remove account that doesn't exist in group
        vm.prank(CONTROLLER1);
        controlledAccounts.removeControlledAccount(FAMILY_GROUP, address(0x9999999999999999999999999999999999999999));
        
        // Verify family group unchanged
        address[] memory familyAccounts = controlledAccounts.getControlledAccounts(CONTROLLER1, FAMILY_GROUP);
        assertEq(familyAccounts.length, 2);
        assertEq(familyAccounts[0], CONTROLLED1);
        assertEq(familyAccounts[1], CONTROLLED2);
    }
    
    /* --- Credential Resolution Tests --- */
    
    function test_007____credentialResolution____FamilyGroupCredential() public {
        bytes memory identifier = _createDNSIdentifier(
            "1111111111111111111111111111111111111111",
            "3c"
        );
        
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts:family");
        
        string memory expected = string(abi.encodePacked(
            "0x3333333333333333333333333333333333333333\n",
            "0x4444444444444444444444444444444444444444"
        ));
        
        assertEq(result, expected);
    }
    
    function test_008____credentialResolution____WorkGroupCredential() public {
        bytes memory identifier = _createDNSIdentifier(
            "1111111111111111111111111111111111111111",
            "3c"
        );
        
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts:work");
        
        string memory expected = string(abi.encodePacked(
            "0x4444444444444444444444444444444444444444\n",
            "0x5555555555555555555555555555555555555555"
        ));
        
        assertEq(result, expected);
    }
    
    function test_009____credentialResolution____FriendsGroupCredential() public {
        bytes memory identifier = _createDNSIdentifier(
            "1111111111111111111111111111111111111111",
            "3c"
        );
        
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts:friends");
        
        string memory expected = string(abi.encodePacked(
            "0x3333333333333333333333333333333333333333\n",
            "0x5555555555555555555555555555555555555555"
        ));
        
        assertEq(result, expected);
    }
    
    function test_010____credentialResolution____DefaultGroupCredential() public {
        bytes memory identifier = _createDNSIdentifier(
            "1111111111111111111111111111111111111111",
            "3c"
        );
        
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts");
        
        string memory expected = "0x6666666666666666666666666666666666666666";
        
        assertEq(result, expected);
    }
    
    function test_011____credentialResolution____Controller2ProjectGroup() public {
        bytes memory identifier = _createDNSIdentifier(
            "2222222222222222222222222222222222222222",
            "3c"
        );
        
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts:project");
        
        string memory expected = string(abi.encodePacked(
            "0x3333333333333333333333333333333333333333\n",
            "0x6666666666666666666666666666666666666666"
        ));
        
        assertEq(result, expected);
    }
    
    function test_012____credentialResolution____EmptyGroupReturnsEmpty() public {
        bytes memory identifier = _createDNSIdentifier(
            "1111111111111111111111111111111111111111",
            "3c"
        );
        
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts:empty");
        
        assertEq(result, "");
    }
    
    function test_013____credentialResolution____UnknownControllerGroupReturnsEmpty() public {
        bytes memory identifier = _createDNSIdentifier(
            "9999999999999999999999999999999999999999",
            "3c"
        );
        
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts:family");
        
        assertEq(result, "");
    }
    
    /* --- Event Tests --- */
    
    function test_014____events____DeclareControlledAccountInGroup() public {
        vm.startPrank(CONTROLLER1);
        
        vm.expectEmit(true, true, false, true);
        address[] memory expectedAccounts = new address[](1);
        expectedAccounts[0] = address(0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa);
        emit ControlledAccounts.ControlledAccountsDeclaredInGroup(CONTROLLER1, FAMILY_GROUP, expectedAccounts);
        
        controlledAccounts.declareControlledAccount(FAMILY_GROUP, address(0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa));
        
        vm.stopPrank();
    }
    
    function test_015____events____DeclareControlledAccountsInGroup() public {
        address[] memory accounts = new address[](2);
        accounts[0] = address(0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB);
        accounts[1] = address(0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC);
        
        vm.startPrank(CONTROLLER1);
        
        vm.expectEmit(true, true, false, true);
        emit ControlledAccounts.ControlledAccountsDeclaredInGroup(CONTROLLER1, WORK_GROUP, accounts);
        
        controlledAccounts.declareControlledAccounts(WORK_GROUP, accounts);
        
        vm.stopPrank();
    }
    
    function test_016____events____RemoveControlledAccountFromGroup() public {
        // First add an account to remove
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(FAMILY_GROUP, address(0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd));
        
        // Then remove it
        vm.startPrank(CONTROLLER1);
        
        vm.expectEmit(true, true, true, false);
        emit ControlledAccounts.ControlledAccountRemovedFromGroup(CONTROLLER1, FAMILY_GROUP, address(0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd));
        
        controlledAccounts.removeControlledAccount(FAMILY_GROUP, address(0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd));
        
        vm.stopPrank();
    }
    
    /* --- Edge Cases --- */
    
    function test_017____edgeCases____EmptyGroupName() public {
        bytes memory identifier = _createDNSIdentifier(
            "1111111111111111111111111111111111111111",
            "3c"
        );
        
        // Test with empty group name after colon
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts:");
        
        // Should treat as default group since empty group name
        string memory expected = "0x6666666666666666666666666666666666666666";
        
        assertEq(result, expected);
    }
    
    function test_018____edgeCases____SameAccountInMultipleGroups() public {
        // Add same account to multiple groups
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(FAMILY_GROUP, CONTROLLED4);
        
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(WORK_GROUP, CONTROLLED4);
        
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(FRIENDS_GROUP, CONTROLLED4);
        
        // Verify account exists in all groups
        address[] memory familyAccounts = controlledAccounts.getControlledAccounts(CONTROLLER1, FAMILY_GROUP);
        address[] memory workAccounts = controlledAccounts.getControlledAccounts(CONTROLLER1, WORK_GROUP);
        address[] memory friendsAccounts = controlledAccounts.getControlledAccounts(CONTROLLER1, FRIENDS_GROUP);
        
        assertEq(familyAccounts.length, 3);   // CONTROLLED1, CONTROLLED2, CONTROLLED4
        assertEq(workAccounts.length, 3);     // CONTROLLED2, CONTROLLED3, CONTROLLED4
        assertEq(friendsAccounts.length, 3);  // CONTROLLED1, CONTROLLED3, CONTROLLED4
        
        // Verify CONTROLLED4 is in all three groups
        bool foundInFamily = false;
        bool foundInWork = false;
        bool foundInFriends = false;
        
        for (uint256 i = 0; i < familyAccounts.length; i++) {
            if (familyAccounts[i] == CONTROLLED4) foundInFamily = true;
        }
        for (uint256 i = 0; i < workAccounts.length; i++) {
            if (workAccounts[i] == CONTROLLED4) foundInWork = true;
        }
        for (uint256 i = 0; i < friendsAccounts.length; i++) {
            if (friendsAccounts[i] == CONTROLLED4) foundInFriends = true;
        }
        
        assertTrue(foundInFamily);
        assertTrue(foundInWork);
        assertTrue(foundInFriends);
    }
    
    function test_019____edgeCases____ZeroAddressInGroups() public {
        // Add zero address to a group
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(FAMILY_GROUP, address(0));
        
        // Verify zero address was added
        address[] memory familyAccounts = controlledAccounts.getControlledAccounts(CONTROLLER1, FAMILY_GROUP);
        assertEq(familyAccounts.length, 3); // CONTROLLED1, CONTROLLED2, address(0)
        assertEq(familyAccounts[2], address(0));
    }
    
    function test_020____edgeCases____SelfControlInGroups() public {
        // Add controller to its own group
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(FAMILY_GROUP, CONTROLLER1);
        
        // Verify self-control was added
        address[] memory familyAccounts = controlledAccounts.getControlledAccounts(CONTROLLER1, FAMILY_GROUP);
        assertEq(familyAccounts.length, 3); // CONTROLLED1, CONTROLLED2, CONTROLLER1
        assertEq(familyAccounts[2], CONTROLLER1);
    }
    
    /* --- Helper Functions --- */
    
    function _createDNSIdentifier(string memory addressHex, string memory cointypeHex) internal pure returns (bytes memory) {
        bytes memory addressBytes = bytes(addressHex);
        bytes memory cointypeBytes = bytes(cointypeHex);
        
        // Calculate total length: address_length + address + cointype_length + cointype
        uint256 totalLength = 1 + addressBytes.length + 1 + cointypeBytes.length;
        
        bytes memory result = new bytes(totalLength);
        uint256 offset = 0;
        
        // Address label: length + hex chars
        result[offset++] = bytes1(uint8(addressBytes.length));
        for (uint256 i = 0; i < addressBytes.length; i++) {
            result[offset++] = addressBytes[i];
        }
        
        // Cointype label: length + hex chars
        result[offset++] = bytes1(uint8(cointypeBytes.length));
        for (uint256 i = 0; i < cointypeBytes.length; i++) {
            result[offset++] = cointypeBytes[i];
        }
        
        return result;
    }
}
