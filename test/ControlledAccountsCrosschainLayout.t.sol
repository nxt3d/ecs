// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/credentials/controlled-accounts/ControlledAccountsCrosschainLayout.sol";

contract ControlledAccountsCrosschainLayoutTest is Test {
    ControlledAccountsCrosschainLayout public controlledAccounts;
    
    // Test addresses from the constructor setup
    address constant DUMMY1 = 0x1111111111111111111111111111111111111111;
    address constant DUMMY2 = 0x2222222222222222222222222222222222222222;
    address constant DUMMY3 = 0x3333333333333333333333333333333333333333;
    address constant DUMMY4 = 0x4444444444444444444444444444444444444444;
    address constant BASE_ACCOUNT1 = 0x5555555555555555555555555555555555555555;
    address constant BASE_ACCOUNT2 = 0x6666666666666666666666666666666666666666;
    
    uint256 constant L1_CHAIN_ID = 1;
    uint256 constant BASE_CHAIN_ID = 8453;
    uint256 constant DEFAULT_CHAIN_ID = 0;

    function setUp() public {
        controlledAccounts = new ControlledAccountsCrosschainLayout();
    }

    function test_001____constructorSetup____Slot0Initialized() public {
        assertEq(controlledAccounts.slot0(), 1, "Slot0 should be initialized to 1");
    }

    function test_002____constructorSetup____L1AccountsDeclared() public {
        address[] memory l1Accounts = controlledAccounts.getControlledAccounts(address(this), L1_CHAIN_ID, bytes32(0));
        
        assertEq(l1Accounts.length, 5, "Should have 5 accounts declared on L1");
        assertEq(l1Accounts[0], address(this), "First account should be deployer");
        assertEq(l1Accounts[1], DUMMY1, "Second account should be dummy1");
        assertEq(l1Accounts[2], DUMMY2, "Third account should be dummy2");
        assertEq(l1Accounts[3], DUMMY3, "Fourth account should be dummy3");
        assertEq(l1Accounts[4], DUMMY4, "Fifth account should be dummy4");
    }

    function test_003____constructorSetup____BaseAccountsDeclared() public {
        address[] memory baseAccounts = controlledAccounts.getControlledAccounts(address(this), BASE_CHAIN_ID, bytes32(0));
        
        assertEq(baseAccounts.length, 2, "Should have 2 accounts declared on Base");
        assertEq(baseAccounts[0], BASE_ACCOUNT1, "First Base account should be baseAccount1");
        assertEq(baseAccounts[1], BASE_ACCOUNT2, "Second Base account should be baseAccount2");
    }

    function test_004____constructorSetup____ControllerRelationshipsSet() public {
        // Deployer should have itself as controller on L1 (self-verification)
        assertTrue(controlledAccounts.isController(address(this), L1_CHAIN_ID, address(this)), "deployer should have itself as controller on L1");
        
        // dummy1 and dummy2 should have deployer as controller on L1
        assertTrue(controlledAccounts.isController(DUMMY1, L1_CHAIN_ID, address(this)), "dummy1 should have deployer as controller on L1");
        assertTrue(controlledAccounts.isController(DUMMY2, L1_CHAIN_ID, address(this)), "dummy2 should have deployer as controller on L1");
        
        // dummy3 and dummy4 should NOT have deployer as controller on L1
        assertFalse(controlledAccounts.isController(DUMMY3, L1_CHAIN_ID, address(this)), "dummy3 should NOT have deployer as controller on L1");
        assertFalse(controlledAccounts.isController(DUMMY4, L1_CHAIN_ID, address(this)), "dummy4 should NOT have deployer as controller on L1");
        
        // Base accounts should have deployer as controller for default chain ID 0
        assertTrue(controlledAccounts.isController(BASE_ACCOUNT1, DEFAULT_CHAIN_ID, address(this)), "baseAccount1 should have deployer as controller for chain ID 0");
        assertTrue(controlledAccounts.isController(BASE_ACCOUNT2, DEFAULT_CHAIN_ID, address(this)), "baseAccount2 should have deployer as controller for chain ID 0");
    }

    function test_005____credentialResolution____L1DefaultGroup() public {
        bytes memory identifier = abi.encodePacked(address(this));
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts:1");
        
        // Should return all 5 accounts declared on L1
        assertTrue(bytes(result).length > 0, "Should return non-empty result for L1 default group");
        
        // Check that the result contains the expected addresses
        assertTrue(_containsAddress(result, address(this)), "Result should contain deployer address");
        assertTrue(_containsAddress(result, DUMMY1), "Result should contain dummy1 address");
        assertTrue(_containsAddress(result, DUMMY2), "Result should contain dummy2 address");
        assertTrue(_containsAddress(result, DUMMY3), "Result should contain dummy3 address");
        assertTrue(_containsAddress(result, DUMMY4), "Result should contain dummy4 address");
    }

    function test_006____credentialResolution____BaseDefaultGroup() public {
        bytes memory identifier = abi.encodePacked(address(this));
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts:8453");
        
        // Should return 2 accounts declared on Base
        assertTrue(bytes(result).length > 0, "Should return non-empty result for Base default group");
        
        // Check that the result contains the expected addresses
        assertTrue(_containsAddress(result, BASE_ACCOUNT1), "Result should contain baseAccount1 address");
        assertTrue(_containsAddress(result, BASE_ACCOUNT2), "Result should contain baseAccount2 address");
    }

    function test_007____credentialResolution____UnknownController() public {
        address unknownController = 0x9999999999999999999999999999999999999999;
        bytes memory identifier = abi.encodePacked(unknownController);
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts:1");
        
        assertEq(result, "", "Should return empty string for unknown controller");
    }

    function test_008____credentialResolution____WrongCredentialKey() public {
        bytes memory identifier = abi.encodePacked(address(this));
        string memory result = controlledAccounts.credential(identifier, "wrong.credential.key");
        
        assertEq(result, "", "Should return empty string for wrong credential key");
    }

    /* --- Helper Functions --- */

    function _containsAddress(string memory result, address addr) internal pure returns (bool) {
        bytes memory resultBytes = bytes(result);
        bytes memory addrBytes = abi.encodePacked(addr);
        
        // Convert address to hex string for comparison
        string memory addrHex = _addressToHexString(addr);
        bytes memory addrHexBytes = bytes(addrHex);
        
        // Simple string contains check
        for (uint256 i = 0; i <= resultBytes.length - addrHexBytes.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < addrHexBytes.length; j++) {
                if (resultBytes[i + j] != addrHexBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return true;
        }
        return false;
    }

    function _addressToHexString(address addr) internal pure returns (string memory) {
        bytes memory data = abi.encodePacked(addr);
        bytes memory alphabet = "0123456789abcdef";
        bytes memory result = new bytes(42); // 0x + 40 hex chars
        
        result[0] = '0';
        result[1] = 'x';
        
        for (uint256 i = 0; i < 20; i++) {
            result[2 + i * 2] = alphabet[uint8(data[i] >> 4)];
            result[3 + i * 2] = alphabet[uint8(data[i] & 0x0f)];
        }
        
        return string(result);
    }
}
