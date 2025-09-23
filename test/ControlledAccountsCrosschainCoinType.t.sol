// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/credentials/controlled-accounts/ControlledAccountsCrosschain.sol";

/**
 * @title ControlledAccountsCrosschainCoinTypeTest
 * @dev Test suite for coin type conversion functions in ControlledAccountsCrosschain
 */
contract ControlledAccountsCrosschainCoinTypeTest is Test {
    
    ControlledAccountsCrosschain public controlledAccounts;
    
    // Test addresses
    address public constant TEST_ADDRESS = address(0x1234567890123456789012345678901234567890);
    address public constant CONTROLLER = address(0x1111111111111111111111111111111111111111);
    
    // Known coin types from ENS address-encoder
    uint256 public constant ETHEREUM_COIN_TYPE = 60; // Ethereum mainnet
    uint256 public constant ETHEREUM_SEPOLIA_COIN_TYPE = 2158638759; // 0x80000000 | 11155111
    uint256 public constant BASE_SEPOLIA_COIN_TYPE = 2147568180; // 0x80000000 | 84532
    uint256 public constant DEFAULT_COIN_TYPE = 0; // Cross-coin-type default
    
    // Chain IDs
    uint256 public constant ETHEREUM_CHAIN_ID = 1;
    uint256 public constant ETHEREUM_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant BASE_SEPOLIA_CHAIN_ID = 84532;
    
    function setUp() public {
        controlledAccounts = new ControlledAccountsCrosschain();
    }
    
    /* --- Chain ID to Coin Type Conversion Tests --- */
    
    function test_001____chainIdToCoinType____EthereumMainnet() public {
        uint256 coinType = controlledAccounts.chainIdToCoinType(ETHEREUM_CHAIN_ID);
        uint256 expected = 0x80000000 | ETHEREUM_CHAIN_ID; // 2147483649
        assertEq(coinType, expected, "Ethereum mainnet coin type should be correct");
    }
    
    function test_002____chainIdToCoinType____EthereumSepolia() public {
        uint256 coinType = controlledAccounts.chainIdToCoinType(ETHEREUM_SEPOLIA_CHAIN_ID);
        assertEq(coinType, ETHEREUM_SEPOLIA_COIN_TYPE, "Ethereum Sepolia coin type should match expected");
    }
    
    function test_003____chainIdToCoinType____BaseSepolia() public {
        uint256 coinType = controlledAccounts.chainIdToCoinType(BASE_SEPOLIA_CHAIN_ID);
        assertEq(coinType, BASE_SEPOLIA_COIN_TYPE, "Base Sepolia coin type should match expected");
    }
    
    function test_004____chainIdToCoinType____SmallChainId() public {
        uint256 coinType = controlledAccounts.chainIdToCoinType(2);
        uint256 expected = 0x80000000 | 2; // 2147483650
        assertEq(coinType, expected, "Small chain ID should convert correctly");
    }
    
    function test_005____chainIdToCoinType____LargeChainId() public {
        uint256 coinType = controlledAccounts.chainIdToCoinType(999999);
        uint256 expected = 0x80000000 | 999999; // 2148483647
        assertEq(coinType, expected, "Large chain ID should convert correctly");
    }
    
    function test_006____chainIdToCoinType____MaxValidChainId() public {
        uint256 maxValidChainId = 0x7FFFFFFF; // Maximum valid chain ID
        uint256 coinType = controlledAccounts.chainIdToCoinType(maxValidChainId);
        uint256 expected = 0x80000000 | maxValidChainId; // 0xFFFFFFFF
        assertEq(coinType, expected, "Maximum valid chain ID should convert correctly");
    }
    
    function test_007____chainIdToCoinType____RevertsOnInvalidChainId() public {
        uint256 invalidChainId = 0x80000000; // Too large
        vm.expectRevert("Chain ID too large for EVM coin type conversion");
        controlledAccounts.chainIdToCoinType(invalidChainId);
    }
    
    function test_008____chainIdToCoinType____RevertsOnLargerInvalidChainId() public {
        uint256 invalidChainId = 0x80000001; // Even larger
        vm.expectRevert("Chain ID too large for EVM coin type conversion");
        controlledAccounts.chainIdToCoinType(invalidChainId);
    }
    
    /* --- Coin Type to Chain ID Conversion Tests --- */
    
    function test_009____coinTypeToChainId____EthereumMainnet() public {
        uint256 chainId = controlledAccounts.coinTypeToChainId(0x80000000 | ETHEREUM_CHAIN_ID);
        assertEq(chainId, ETHEREUM_CHAIN_ID, "Ethereum mainnet chain ID should be correct");
    }
    
    function test_010____coinTypeToChainId____EthereumSepolia() public {
        uint256 chainId = controlledAccounts.coinTypeToChainId(ETHEREUM_SEPOLIA_COIN_TYPE);
        assertEq(chainId, ETHEREUM_SEPOLIA_CHAIN_ID, "Ethereum Sepolia chain ID should be correct");
    }
    
    function test_011____coinTypeToChainId____BaseSepolia() public {
        uint256 chainId = controlledAccounts.coinTypeToChainId(BASE_SEPOLIA_COIN_TYPE);
        assertEq(chainId, BASE_SEPOLIA_CHAIN_ID, "Base Sepolia chain ID should be correct");
    }
    
    function test_012____coinTypeToChainId____SmallCoinType() public {
        uint256 coinType = 0x80000000 | 2;
        uint256 chainId = controlledAccounts.coinTypeToChainId(coinType);
        assertEq(chainId, 2, "Small coin type should convert to correct chain ID");
    }
    
    function test_013____coinTypeToChainId____LargeCoinType() public {
        uint256 coinType = 0x80000000 | 999999;
        uint256 chainId = controlledAccounts.coinTypeToChainId(coinType);
        assertEq(chainId, 999999, "Large coin type should convert to correct chain ID");
    }
    
    function test_014____coinTypeToChainId____MaxValidCoinType() public {
        uint256 maxCoinType = 0xFFFFFFFF; // Maximum valid EVM coin type
        uint256 chainId = controlledAccounts.coinTypeToChainId(maxCoinType);
        assertEq(chainId, 0x7FFFFFFF, "Maximum valid coin type should convert correctly");
    }
    
    function test_015____coinTypeToChainId____RevertsOnStandardCoinType() public {
        vm.expectRevert("Not an EVM coin type");
        controlledAccounts.coinTypeToChainId(ETHEREUM_COIN_TYPE); // Standard SLIP44 coin type
    }
    
    function test_016____coinTypeToChainId____RevertsOnZeroCoinType() public {
        vm.expectRevert("Not an EVM coin type");
        controlledAccounts.coinTypeToChainId(0);
    }
    
    function test_017____coinTypeToChainId____RevertsOnSmallCoinType() public {
        vm.expectRevert("Not an EVM coin type");
        controlledAccounts.coinTypeToChainId(59); // Just below SLIP44_MSB
    }
    
    /* --- Coin Type Validation Tests --- */
    
    function test_018____isValidCoinType____OnlyCurrentChainCoinType() public {
        // Only current chain coin type should be valid for msg.sender
        uint256 currentChainCoinType = controlledAccounts.chainIdToCoinType(block.chainid);
        assertTrue(controlledAccounts.isValidCoinType(currentChainCoinType), "Current chain coin type should be valid");
        
        // Standard coin types should NOT be valid for msg.sender anymore
        assertFalse(controlledAccounts.isValidCoinType(ETHEREUM_COIN_TYPE), "Ethereum mainnet should NOT be valid for msg.sender");
        assertFalse(controlledAccounts.isValidCoinType(0), "Zero coin type should NOT be valid for msg.sender");
        assertFalse(controlledAccounts.isValidCoinType(1), "Small coin type should NOT be valid for msg.sender");
        assertFalse(controlledAccounts.isValidCoinType(0x7FFFFFFF), "Maximum standard coin type should NOT be valid for msg.sender");
    }
    
    function test_019____isValidCoinType____CurrentChainEVMCoinType() public {
        // Test with current chain ID (this test runs on the current chain)
        uint256 currentChainId = block.chainid;
        uint256 currentChainCoinType = 0x80000000 | currentChainId;
        
        assertTrue(controlledAccounts.isValidCoinType(currentChainCoinType), 
                  "Current chain EVM coin type should be valid");
    }
    
    function test_020____isValidCoinType____DifferentChainEVMCoinType() public {
        // Test with a different chain ID (should be invalid on current chain)
        uint256 differentChainId = 999999; // Assuming this is not the current chain
        uint256 differentChainCoinType = 0x80000000 | differentChainId;
        
        // This will be invalid unless we're actually on chain 999999
        bool isValid = controlledAccounts.isValidCoinType(differentChainCoinType);
        bool expectedValid = (differentChainId == block.chainid);
        
        assertEq(isValid, expectedValid, "Different chain EVM coin type validity should match current chain");
    }
    
    function test_021____isValidCoinType____EthereumSepoliaOnSepolia() public {
        // This test assumes we're running on Ethereum Sepolia
        bool isValid = controlledAccounts.isValidCoinType(ETHEREUM_SEPOLIA_COIN_TYPE);
        bool expectedValid = (ETHEREUM_SEPOLIA_CHAIN_ID == block.chainid);
        
        assertEq(isValid, expectedValid, "Ethereum Sepolia coin type validity should match current chain");
    }
    
    function test_022____isValidCoinType____BaseSepoliaOnBaseSepolia() public {
        // This test assumes we're running on Base Sepolia
        bool isValid = controlledAccounts.isValidCoinType(BASE_SEPOLIA_COIN_TYPE);
        bool expectedValid = (BASE_SEPOLIA_CHAIN_ID == block.chainid);
        
        assertEq(isValid, expectedValid, "Base Sepolia coin type validity should match current chain");
    }
    
    function test_022b____isValidCoinTypeForSignature____CurrentChainAndZero() public {
        // Test the new signature validation function
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
        uint256 otherChainCoinType = 0x80000000 | 999999; // Assuming we're not on chain 999999
        assertFalse(controlledAccounts.isValidCoinTypeForSignature(otherChainCoinType), 
                   "Other chain EVM coin types should NOT be valid for signatures");
    }
    
    /* --- Round Trip Conversion Tests --- */
    
    function test_023____roundTripConversion____EthereumMainnet() public {
        uint256 originalChainId = ETHEREUM_CHAIN_ID;
        uint256 coinType = controlledAccounts.chainIdToCoinType(originalChainId);
        uint256 recoveredChainId = controlledAccounts.coinTypeToChainId(coinType);
        
        assertEq(recoveredChainId, originalChainId, "Round trip conversion should preserve chain ID");
    }
    
    function test_024____roundTripConversion____EthereumSepolia() public {
        uint256 originalChainId = ETHEREUM_SEPOLIA_CHAIN_ID;
        uint256 coinType = controlledAccounts.chainIdToCoinType(originalChainId);
        uint256 recoveredChainId = controlledAccounts.coinTypeToChainId(coinType);
        
        assertEq(recoveredChainId, originalChainId, "Round trip conversion should preserve chain ID");
    }
    
    function test_025____roundTripConversion____BaseSepolia() public {
        uint256 originalChainId = BASE_SEPOLIA_CHAIN_ID;
        uint256 coinType = controlledAccounts.chainIdToCoinType(originalChainId);
        uint256 recoveredChainId = controlledAccounts.coinTypeToChainId(coinType);
        
        assertEq(recoveredChainId, originalChainId, "Round trip conversion should preserve chain ID");
    }
    
    function test_026____roundTripConversion____RandomChainIds() public {
        uint256[] memory testChainIds = new uint256[](5);
        testChainIds[0] = 2;
        testChainIds[1] = 100;
        testChainIds[2] = 1000;
        testChainIds[3] = 10000;
        testChainIds[4] = 100000;
        
        for (uint256 i = 0; i < testChainIds.length; i++) {
            uint256 originalChainId = testChainIds[i];
            uint256 coinType = controlledAccounts.chainIdToCoinType(originalChainId);
            uint256 recoveredChainId = controlledAccounts.coinTypeToChainId(coinType);
            
            assertEq(recoveredChainId, originalChainId, 
                    string(abi.encodePacked("Round trip conversion failed for chain ID ", vm.toString(originalChainId))));
        }
    }
    
    /* --- Function Integration Tests --- */
    
    function test_027____declareControlledAccount____ValidCoinType() public {
        // Test with current chain coin type (should work)
        uint256 currentChainCoinType = 0x80000000 | block.chainid;
        
        vm.prank(CONTROLLER);
        controlledAccounts.declareControlledAccount(currentChainCoinType, bytes32(0), TEST_ADDRESS);
        
        address[] memory accounts = controlledAccounts.getControlledAccounts(CONTROLLER, currentChainCoinType, bytes32(0));
        assertEq(accounts.length, 1, "Should have one controlled account");
        assertEq(accounts[0], TEST_ADDRESS, "Controlled account should match");
    }
    
    function test_028____declareControlledAccount____StandardCoinTypeReverts() public {
        // Test with standard coin type (should revert now)
        vm.prank(CONTROLLER);
        vm.expectRevert("Invalid coin type for current chain");
        controlledAccounts.declareControlledAccount(ETHEREUM_COIN_TYPE, bytes32(0), TEST_ADDRESS);
    }
    
    function test_029____declareControlledAccount____InvalidCoinType() public {
        // Test with invalid coin type (should revert)
        uint256 invalidCoinType = 0x80000000 | 999999; // Assuming we're not on chain 999999
        
        vm.prank(CONTROLLER);
        vm.expectRevert("Invalid coin type for current chain");
        controlledAccounts.declareControlledAccount(invalidCoinType, bytes32(0), TEST_ADDRESS);
    }
    
    function test_030____setController____ValidCoinType() public {
        // Test with current chain coin type (should work)
        uint256 currentChainCoinType = 0x80000000 | block.chainid;
        
        vm.prank(TEST_ADDRESS);
        controlledAccounts.setController(currentChainCoinType, CONTROLLER);
        
        assertTrue(controlledAccounts.isController(TEST_ADDRESS, currentChainCoinType, CONTROLLER), 
                  "Controller relationship should be set");
    }
    
    function test_031____setController____StandardCoinTypeReverts() public {
        // Test with standard coin type (should revert now)
        vm.prank(TEST_ADDRESS);
        vm.expectRevert("Invalid coin type for current chain");
        controlledAccounts.setController(ETHEREUM_COIN_TYPE, CONTROLLER);
    }
    
    function test_032____setController____InvalidCoinType() public {
        // Test with invalid coin type (should revert)
        uint256 invalidCoinType = 0x80000000 | 999999; // Assuming we're not on chain 999999
        
        vm.prank(TEST_ADDRESS);
        vm.expectRevert("Invalid coin type for current chain");
        controlledAccounts.setController(invalidCoinType, CONTROLLER);
    }
    
    /* --- Edge Case Tests --- */
    
    function test_033____edgeCases____ZeroChainId() public {
        uint256 coinType = controlledAccounts.chainIdToCoinType(0);
        uint256 expected = 0x80000000; // 0x80000000 | 0
        assertEq(coinType, expected, "Zero chain ID should convert to 0x80000000");
        
        uint256 chainId = controlledAccounts.coinTypeToChainId(coinType);
        assertEq(chainId, 0, "0x80000000 should convert back to zero chain ID");
    }
    
    function test_034____edgeCases____OneChainId() public {
        uint256 coinType = controlledAccounts.chainIdToCoinType(1);
        uint256 expected = 0x80000001; // 0x80000000 | 1
        assertEq(coinType, expected, "Chain ID 1 should convert to 0x80000001");
        
        uint256 chainId = controlledAccounts.coinTypeToChainId(coinType);
        assertEq(chainId, 1, "0x80000001 should convert back to chain ID 1");
    }
    
    function test_035____edgeCases____BitwiseOperations() public {
        // Test that the bitwise operations work correctly
        uint256 testChainId = 0x12345678;
        uint256 coinType = controlledAccounts.chainIdToCoinType(testChainId);
        
        // Verify the MSB is set
        assertTrue((coinType & 0x80000000) != 0, "MSB should be set in EVM coin type");
        
        // Verify the lower bits match the original chain ID
        uint256 lowerBits = coinType & 0x7FFFFFFF;
        assertEq(lowerBits, testChainId, "Lower bits should match original chain ID");
    }
}
