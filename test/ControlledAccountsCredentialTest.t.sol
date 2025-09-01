// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/credentials/controlled-accounts/ControlledAccounts.sol";
import "../src/utils/ECSUtils.sol";

/**
 * @title ControlledAccountsCredentialTest
 * @dev Test controlled accounts credential resolution
 * 
 * This test verifies that the ControlledAccounts contract correctly resolves
 * credentials when queried with DNS-encoded identifiers.
 */
contract ControlledAccountsCredentialTest is Test {
    
    /* --- State Variables --- */
    
    ControlledAccounts public controlledAccounts;
    
    /* --- Test Addresses --- */
    
    address constant CONTROLLER1 = address(0x1111111111111111111111111111111111111111);
    address constant CONTROLLER2 = address(0x2222222222222222222222222222222222222222);
    address constant CONTROLLED1 = address(0x3333333333333333333333333333333333333333);
    address constant CONTROLLED2 = address(0x4444444444444444444444444444444444444444);
    address constant CONTROLLED3 = address(0x5555555555555555555555555555555555555555);
    
    /* --- Setup --- */
    
    function setUp() public {
        controlledAccounts = new ControlledAccounts();
        _setupTestData();
    }
    
    /* --- Test Data Setup --- */
    
    function _setupTestData() internal {
        // Controller 1 declares controlled accounts
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(CONTROLLED1);
        
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(CONTROLLED2);
        
        // Controller 2 declares controlled accounts
        vm.prank(CONTROLLER2);
        controlledAccounts.declareControlledAccount(CONTROLLED3);
        
        // Controlled accounts set their controllers
        vm.prank(CONTROLLED1);
        controlledAccounts.setController(CONTROLLER1);
        
        vm.prank(CONTROLLED2);
        controlledAccounts.setController(CONTROLLER1);
        
        vm.prank(CONTROLLED3);
        controlledAccounts.setController(CONTROLLER2);
    }
    
    /* --- Credential Resolution Tests --- */
    
    function test_001____credentialResolution____Controller1ReturnsCorrectAccounts() public {
        // Create DNS-encoded identifier for Controller1 with Ethereum coin type (60 = 0x3c)
        bytes memory identifier = _createDNSIdentifier(
            "1111111111111111111111111111111111111111", // Controller1 address without 0x
            "3c" // Ethereum coin type in hex
        );
        
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts");
        
        // Expected result: two addresses on separate lines
        string memory expected = string(abi.encodePacked(
            "0x3333333333333333333333333333333333333333\n",
            "0x4444444444444444444444444444444444444444"
        ));
        
        assertEq(result, expected);
    }
    
    function test_002____credentialResolution____Controller2ReturnsCorrectAccounts() public {
        // Create DNS-encoded identifier for Controller2 with Ethereum coin type (60 = 0x3c)
        bytes memory identifier = _createDNSIdentifier(
            "2222222222222222222222222222222222222222", // Controller2 address without 0x
            "3c" // Ethereum coin type in hex
        );
        
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts");
        
        // Expected result: one address
        string memory expected = "0x5555555555555555555555555555555555555555";
        
        assertEq(result, expected);
    }
    
    function test_003____credentialResolution____UnknownControllerReturnsEmpty() public {
        // Create DNS-encoded identifier for unknown controller
        bytes memory identifier = _createDNSIdentifier(
            "9999999999999999999999999999999999999999", // Unknown address
            "3c" // Ethereum coin type in hex
        );
        
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts");
        
        assertEq(result, "");
    }
    
    function test_004____credentialResolution____WrongCredentialKeyReturnsEmpty() public {
        // Create DNS-encoded identifier for Controller1
        bytes memory identifier = _createDNSIdentifier(
            "1111111111111111111111111111111111111111",
            "3c"
        );
        
        string memory result = controlledAccounts.credential(identifier, "wrong.credential.key");
        
        assertEq(result, "");
    }
    
    function test_005____credentialResolution____DifferentCoinTypeStillWorks() public {
        // Test with Bitcoin coin type (1 = 0x01)
        bytes memory identifier = _createDNSIdentifier(
            "1111111111111111111111111111111111111111",
            "01" // Bitcoin coin type in hex
        );
        
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts");
        
        // Should still return the same controlled accounts (coin type doesn't matter for this credential)
        string memory expected = string(abi.encodePacked(
            "0x3333333333333333333333333333333333333333\n",
            "0x4444444444444444444444444444444444444444"
        ));
        
        assertEq(result, expected);
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
    
    /* --- Verification Tests --- */
    
    function test_006____verification____ControlledAccountsStateIsCorrect() public {
        // Verify the state is set up correctly
        address[] memory controller1Accounts = controlledAccounts.getControlledAccounts(CONTROLLER1);
        address[] memory controller2Accounts = controlledAccounts.getControlledAccounts(CONTROLLER2);
        
        assertEq(controller1Accounts.length, 2);
        assertEq(controller1Accounts[0], CONTROLLED1);
        assertEq(controller1Accounts[1], CONTROLLED2);
        
        assertEq(controller2Accounts.length, 1);
        assertEq(controller2Accounts[0], CONTROLLED3);
    }
    
    function test_007____verification____ControllerRelationshipsAreCorrect() public {
        // Verify the controller relationships are set up correctly
        address controller1 = controlledAccounts.getController(CONTROLLED1);
        address controller2 = controlledAccounts.getController(CONTROLLED2);
        address controller3 = controlledAccounts.getController(CONTROLLED3);
        
        assertEq(controller1, CONTROLLER1);
        assertEq(controller2, CONTROLLER1);
        assertEq(controller3, CONTROLLER2);
    }
    
    /* --- Group Credential Resolution Tests --- */
    
    function test_008____groupCredentialResolution____FamilyGroupReturnsCorrectAccounts() public {
        // Set up group data
        bytes32 familyGroup = keccak256(bytes("family"));
        
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(familyGroup, CONTROLLED1);
        
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(familyGroup, CONTROLLED2);
        
        // Create DNS-encoded identifier for Controller1
        bytes memory identifier = _createDNSIdentifier(
            "1111111111111111111111111111111111111111",
            "3c"
        );
        
        // Test credential resolution with group
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts:family");
        
        // Expected result: two addresses on separate lines
        string memory expected = string(abi.encodePacked(
            "0x3333333333333333333333333333333333333333\n",
            "0x4444444444444444444444444444444444444444"
        ));
        
        assertEq(result, expected);
    }
    
    function test_009____groupCredentialResolution____WorkGroupReturnsCorrectAccounts() public {
        // Set up group data
        bytes32 workGroup = keccak256(bytes("work"));
        
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(workGroup, CONTROLLED2);
        
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(workGroup, CONTROLLED3);
        
        // Create DNS-encoded identifier for Controller1
        bytes memory identifier = _createDNSIdentifier(
            "1111111111111111111111111111111111111111",
            "3c"
        );
        
        // Test credential resolution with group
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts:work");
        
        // Expected result: two addresses on separate lines
        string memory expected = string(abi.encodePacked(
            "0x4444444444444444444444444444444444444444\n",
            "0x5555555555555555555555555555555555555555"
        ));
        
        assertEq(result, expected);
    }
    
    function test_010____groupCredentialResolution____DefaultGroupStillWorks() public {
        // Create DNS-encoded identifier for Controller1
        bytes memory identifier = _createDNSIdentifier(
            "1111111111111111111111111111111111111111",
            "3c"
        );
        
        // Test credential resolution without group (default group)
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts");
        
        // Expected result: two addresses on separate lines (from original setup)
        string memory expected = string(abi.encodePacked(
            "0x3333333333333333333333333333333333333333\n",
            "0x4444444444444444444444444444444444444444"
        ));
        
        assertEq(result, expected);
    }
    
    function test_011____groupCredentialResolution____EmptyGroupReturnsEmpty() public {
        // Create DNS-encoded identifier for Controller1
        bytes memory identifier = _createDNSIdentifier(
            "1111111111111111111111111111111111111111",
            "3c"
        );
        
        // Test credential resolution with empty group
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts:empty");
        
        assertEq(result, "");
    }
    
    function test_012____groupCredentialResolution____GroupIsolationWorks() public {
        // Set up different groups with same accounts
        bytes32 familyGroup = keccak256(bytes("family"));
        bytes32 workGroup = keccak256(bytes("work"));
        
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(familyGroup, CONTROLLED1);
        
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(workGroup, CONTROLLED1);
        
        // Create DNS-encoded identifier for Controller1
        bytes memory identifier = _createDNSIdentifier(
            "1111111111111111111111111111111111111111",
            "3c"
        );
        
        // Test both groups return the same account
        string memory familyResult = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts:family");
        string memory workResult = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts:work");
        
        string memory expected = "0x3333333333333333333333333333333333333333";
        
        assertEq(familyResult, expected);
        assertEq(workResult, expected);
        
        // Remove from one group only
        vm.prank(CONTROLLER1);
        controlledAccounts.removeControlledAccount(familyGroup, CONTROLLED1);
        
        // Test family group now empty, work group still has account
        string memory familyResultAfter = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts:family");
        string memory workResultAfter = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts:work");
        
        assertEq(familyResultAfter, "");
        assertEq(workResultAfter, expected);
    }
    
    function test_013____groupCredentialResolution____InvalidGroupFormat() public {
        // Create DNS-encoded identifier for Controller1
        bytes memory identifier = _createDNSIdentifier(
            "1111111111111111111111111111111111111111",
            "3c"
        );
        
        // Test with valid credential key but no group (should use default group)
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts");
        
        // Should treat as default group since no colon found
        string memory expected = string(abi.encodePacked(
            "0x3333333333333333333333333333333333333333\n",
            "0x4444444444444444444444444444444444444444"
        ));
        
        assertEq(result, expected);
    }
    
    function test_014____groupCredentialResolution____EmptyGroupName() public {
        // Create DNS-encoded identifier for Controller1
        bytes memory identifier = _createDNSIdentifier(
            "1111111111111111111111111111111111111111",
            "3c"
        );
        
        // Test with empty group name after colon
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts:");
        
        // Should treat as default group since empty group name
        string memory expected = string(abi.encodePacked(
            "0x3333333333333333333333333333333333333333\n",
            "0x4444444444444444444444444444444444444444"
        ));
        
        assertEq(result, expected);
    }
}
