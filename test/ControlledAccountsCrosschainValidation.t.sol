// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/credentials/controlled-accounts/ControlledAccountsCrosschain.sol";

/**
 * @title ControlledAccountsCrosschainValidationTest
 * @dev Test suite for the new validation logic in ControlledAccountsCrosschain
 */
contract ControlledAccountsCrosschainValidationTest is Test {
    
    ControlledAccountsCrosschain public controlledAccounts;
    
    // Test addresses
    address public constant TEST_ADDRESS = address(0x2e988A386a799F506693793c6A5AF6B54dfAaBfB); // vm.addr(0x1234567890123456789012345678901234567890123456789012345678901234)
    address public constant CONTROLLER = address(0x1111111111111111111111111111111111111111);
    
    // Known coin types
    uint256 public constant ETHEREUM_COIN_TYPE = 60; // Ethereum mainnet
    uint256 public constant ETHEREUM_SEPOLIA_COIN_TYPE = 2158638759; // 0x80000000 | 11155111
    uint256 public constant BASE_SEPOLIA_COIN_TYPE = 2147568180; // 0x80000000 | 84532
    uint256 public constant DEFAULT_COIN_TYPE = 0; // Cross-coin-type default
    
    function setUp() public {
        controlledAccounts = new ControlledAccountsCrosschain();
    }
    
    /* --- Validation Tests --- */
    
    function test_001____msgSenderCanOnlySetCurrentChainCoinType() public {
        uint256 currentChainCoinType = controlledAccounts.chainIdToCoinType(block.chainid);
        
        // Should work with current chain coin type
        vm.prank(CONTROLLER);
        controlledAccounts.declareControlledAccount(currentChainCoinType, bytes32(0), TEST_ADDRESS);
        
        address[] memory accounts = controlledAccounts.getControlledAccounts(CONTROLLER, currentChainCoinType, bytes32(0));
        assertEq(accounts.length, 1, "Should have one controlled account");
        assertEq(accounts[0], TEST_ADDRESS, "Controlled account should match");
    }
    
    function test_002____msgSenderCannotSetStandardCoinTypes() public {
        // Should revert with standard coin types
        vm.prank(CONTROLLER);
        vm.expectRevert("Invalid coin type for current chain");
        controlledAccounts.declareControlledAccount(ETHEREUM_COIN_TYPE, bytes32(0), TEST_ADDRESS);
    }
    
    function test_003____msgSenderCannotSetOtherChainEVMCoinTypes() public {
        // Should revert with other chain EVM coin types
        vm.prank(CONTROLLER);
        vm.expectRevert("Invalid coin type for current chain");
        controlledAccounts.declareControlledAccount(ETHEREUM_SEPOLIA_COIN_TYPE, bytes32(0), TEST_ADDRESS);
    }
    
    function test_004____msgSenderCannotSetCoinTypeZero() public {
        // Should revert with coin type 0
        vm.prank(CONTROLLER);
        vm.expectRevert("Invalid coin type for current chain");
        controlledAccounts.declareControlledAccount(0, bytes32(0), TEST_ADDRESS);
    }
    
    function test_005____setControllerWithCurrentChainCoinType() public {
        uint256 currentChainCoinType = controlledAccounts.chainIdToCoinType(block.chainid);
        
        // Should work with current chain coin type
        vm.prank(TEST_ADDRESS);
        controlledAccounts.setController(currentChainCoinType, CONTROLLER);
        
        assertTrue(controlledAccounts.isController(TEST_ADDRESS, currentChainCoinType, CONTROLLER), 
                  "Controller relationship should be set");
    }
    
    function test_006____setControllerCannotSetStandardCoinTypes() public {
        // Should revert with standard coin types
        vm.prank(TEST_ADDRESS);
        vm.expectRevert("Invalid coin type for current chain");
        controlledAccounts.setController(ETHEREUM_COIN_TYPE, CONTROLLER);
    }
    
    function test_007____setControllerCannotSetOtherChainEVMCoinTypes() public {
        // Should revert with other chain EVM coin types
        vm.prank(TEST_ADDRESS);
        vm.expectRevert("Invalid coin type for current chain");
        controlledAccounts.setController(ETHEREUM_SEPOLIA_COIN_TYPE, CONTROLLER);
    }
    
    function test_008____setControllerCannotSetCoinTypeZero() public {
        // Should revert with coin type 0
        vm.prank(TEST_ADDRESS);
        vm.expectRevert("Invalid coin type for current chain");
        controlledAccounts.setController(0, CONTROLLER);
    }
    
    /* --- Signature Validation Tests --- */
    
    function test_009____signatureCanSetCurrentChainCoinType() public {
        uint256 currentChainCoinType = controlledAccounts.chainIdToCoinType(block.chainid);
        
        // Create the message hash (same format as contract)
        bytes32 messageHash = keccak256(abi.encodePacked(
            "ControlledAccounts: setControllerWithSignature",
            TEST_ADDRESS,
            currentChainCoinType,
            CONTROLLER,
            address(controlledAccounts)
        ));
        
        // Convert to Ethereum signed message hash
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            messageHash
        ));
        
        // Sign the message using the test private key
        uint256 privateKey = 0x1234567890123456789012345678901234567890123456789012345678901234;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // Set the controller using signature
        controlledAccounts.setControllerWithSignature(TEST_ADDRESS, currentChainCoinType, CONTROLLER, signature);
        
        assertTrue(controlledAccounts.isController(TEST_ADDRESS, currentChainCoinType, CONTROLLER), 
                  "Controller relationship should be set via signature");
    }
    
    function test_010____signatureCanSetCoinTypeZero() public {
        // Create the message hash for coin type 0
        bytes32 messageHash = keccak256(abi.encodePacked(
            "ControlledAccounts: setControllerWithSignature",
            TEST_ADDRESS,
            uint256(0),
            CONTROLLER,
            address(controlledAccounts)
        ));
        
        // Convert to Ethereum signed message hash
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            messageHash
        ));
        
        // Sign the message using the test private key
        uint256 privateKey = 0x1234567890123456789012345678901234567890123456789012345678901234;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // Set the controller using signature with coin type 0
        controlledAccounts.setControllerWithSignature(TEST_ADDRESS, 0, CONTROLLER, signature);
        
        assertTrue(controlledAccounts.isController(TEST_ADDRESS, 0, CONTROLLER), 
                  "Controller relationship should be set via signature with coin type 0");
    }
    
    function test_011____signatureCannotSetStandardCoinTypes() public {
        // Create a signature for the controlled account
        bytes32 messageHash = keccak256(abi.encodePacked(
            "ControlledAccounts: setControllerWithSignature",
            TEST_ADDRESS,
            ETHEREUM_COIN_TYPE,
            CONTROLLER,
            address(controlledAccounts)
        ));
        
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            messageHash
        ));
        
        // Sign with TEST_ADDRESS private key
        uint256 privateKey = 0x1234567890123456789012345678901234567890123456789012345678901234;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // Should revert with standard coin types
        vm.expectRevert("Invalid coin type for signature-based controller setting");
        controlledAccounts.setControllerWithSignature(TEST_ADDRESS, ETHEREUM_COIN_TYPE, CONTROLLER, signature);
    }
    
    function test_012____signatureCannotSetOtherChainEVMCoinTypes() public {
        // Create a signature for the controlled account
        bytes32 messageHash = keccak256(abi.encodePacked(
            "ControlledAccounts: setControllerWithSignature",
            TEST_ADDRESS,
            ETHEREUM_SEPOLIA_COIN_TYPE,
            CONTROLLER,
            address(controlledAccounts)
        ));
        
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            messageHash
        ));
        
        // Sign with TEST_ADDRESS private key
        uint256 privateKey = 0x1234567890123456789012345678901234567890123456789012345678901234;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // Should revert with other chain EVM coin types
        vm.expectRevert("Invalid coin type for signature-based controller setting");
        controlledAccounts.setControllerWithSignature(TEST_ADDRESS, ETHEREUM_SEPOLIA_COIN_TYPE, CONTROLLER, signature);
    }
    
    /* --- Validation Function Tests --- */
    
    function test_013____isValidCoinTypeOnlyAllowsCurrentChain() public {
        uint256 currentChainCoinType = controlledAccounts.chainIdToCoinType(block.chainid);
        
        // Only current chain coin type should be valid
        assertTrue(controlledAccounts.isValidCoinType(currentChainCoinType), 
                  "Current chain coin type should be valid");
        
        // Standard coin types should NOT be valid
        assertFalse(controlledAccounts.isValidCoinType(ETHEREUM_COIN_TYPE), 
                   "Standard coin types should NOT be valid");
        
        // Other chain EVM coin types should NOT be valid
        assertFalse(controlledAccounts.isValidCoinType(ETHEREUM_SEPOLIA_COIN_TYPE), 
                   "Other chain EVM coin types should NOT be valid");
        
        // Coin type 0 should NOT be valid
        assertFalse(controlledAccounts.isValidCoinType(0), 
                   "Coin type 0 should NOT be valid for msg.sender");
    }
    
    function test_014____isValidCoinTypeForSignatureAllowsCurrentChainAndZero() public {
        uint256 currentChainCoinType = controlledAccounts.chainIdToCoinType(block.chainid);
        
        // Current chain coin type should be valid for signatures
        assertTrue(controlledAccounts.isValidCoinTypeForSignature(currentChainCoinType), 
                  "Current chain coin type should be valid for signatures");
        
        // Coin type 0 should be valid for signatures
        assertTrue(controlledAccounts.isValidCoinTypeForSignature(0), 
                  "Coin type 0 should be valid for signatures");
        
        // Standard coin types should NOT be valid for signatures
        assertFalse(controlledAccounts.isValidCoinTypeForSignature(ETHEREUM_COIN_TYPE), 
                   "Standard coin types should NOT be valid for signatures");
        
        // Other chain EVM coin types should NOT be valid for signatures
        assertFalse(controlledAccounts.isValidCoinTypeForSignature(ETHEREUM_SEPOLIA_COIN_TYPE), 
                   "Other chain EVM coin types should NOT be valid for signatures");
    }
}
