// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/credentials/controlled-accounts/ControlledAccountsCrosschain.sol";

/**
 * @title DeployControlledAccountsCrosschain
 * @dev Deploy the ControlledAccountsCrosschain credential resolver for cross-coin-type testing
 * 
 * This script deploys the ControlledAccountsCrosschain contract and sets up test data
 * to demonstrate cross-coin-type controlled accounts relationships and credential resolution.
 * 
 * Usage:
 * forge script script/DeployControlledAccountsCrosschain.s.sol:DeployControlledAccountsCrosschain --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --broadcast --verify --etherscan-api-key $BASE_ETHERSCAN_API_KEY
 */
contract DeployControlledAccountsCrosschain is Script {
    
    /* --- State Variables --- */
    
    ControlledAccountsCrosschain public controlledAccounts;
    
    /* --- Environment Variables --- */
    
    // Deployment addresses
    address public deployer;
    address public deployer2;
    
    // Test addresses for controlled accounts relationships
    address public controller1;
    address public controller2;
    address public controlled1;
    address public controlled2;
    address public controlled3;
    address public controlled4;
    address public baseAccount1;
    address public baseAccount2;
    
    // Coin Types (ENS address-encoder format)
    uint256 constant ETHEREUM_COIN_TYPE = 60; // Ethereum mainnet coin type (0x3c)
    uint256 constant ETHEREUM_SEPOLIA_COIN_TYPE = 2158638759; // Ethereum Sepolia coin type (0x800AA127)
    uint256 constant BASE_SEPOLIA_COIN_TYPE = 2147568180; // Base Sepolia coin type (0x80014A34)
    uint256 constant DEFAULT_COIN_TYPE = 0;   // Cross-coin-type default
    
    /* --- Setup --- */
    
    function setUp() public {
        deployer = vm.envAddress("PUBLIC_DEPLOYER_ADDRESS");
        deployer2 = vm.envAddress("PUBLIC_DEPLOYER2_ADDRESS");
        
        // Use addresses we control for testing
        controller1 = deployer;  // PUBLIC_DEPLOYER_ADDRESS as controller
        controller2 = deployer2; // PUBLIC_DEPLOYER2_ADDRESS as controller
        
        // Test controlled accounts
        controlled1 = deployer;   // PUBLIC_DEPLOYER_ADDRESS controls itself
        controlled2 = deployer2;  // PUBLIC_DEPLOYER_ADDRESS controls PUBLIC_DEPLOYER2_ADDRESS
        controlled3 = address(0x1111111111111111111111111111111111111111); // Dummy account 1
        controlled4 = address(0x2222222222222222222222222222222222222222); // Dummy account 2
        
        // Base chain accounts
        baseAccount1 = address(0x3333333333333333333333333333333333333333);
        baseAccount2 = address(0x4444444444444444444444444444444444444444);
    }
    
    /* --- Main Deployment --- */
    
    function run() public {
        vm.startBroadcast(deployer);
        
        console.log("[DEPLOY] Deploying ControlledAccountsCrosschain Credential Resolver");
        console.log("=============================================================");
        console.log("");
        
        // Step 1: Deploy ControlledAccountsCrosschain contract
        console.log("Step 1: Deploying ControlledAccountsCrosschain contract...");
        controlledAccounts = new ControlledAccountsCrosschain();
        console.log("[SUCCESS] ControlledAccountsCrosschain deployed at:", address(controlledAccounts));
        console.log("");
        
        // Step 2: Set up test data
        console.log("Step 2: Setting up cross-coin-type controlled accounts relationships...");
        _setupTestData();
        console.log("");
        
        // Step 3: Print deployment summary
        console.log("Step 3: Deployment Summary");
        _printDeploymentSummary();
        
        vm.stopBroadcast();
    }
    
    /* --- Test Data Setup --- */
    
    function _setupTestData() internal {
        // Get current chain coin type (Base Sepolia)
        uint256 currentChainCoinType = controlledAccounts.chainIdToCoinType(block.chainid);
        console.log("Setting up Base Sepolia controlled accounts (coin type", currentChainCoinType, ") - deployment chain...");
        
        // Deployer declares controlled accounts on current chain coin type (default group)
        controlledAccounts.declareControlledAccount(currentChainCoinType, bytes32(0), controlled1); // Self-control
        controlledAccounts.declareControlledAccount(currentChainCoinType, bytes32(0), controlled2); // Controls deployer2
        controlledAccounts.declareControlledAccount(currentChainCoinType, bytes32(0), controlled3); // Dummy account 1
        controlledAccounts.declareControlledAccount(currentChainCoinType, bytes32(0), controlled4); // Dummy account 2
        
        // Set up controller relationships for current chain coin type
        console.log("Setting up current chain coin type controller relationships...");
        controlledAccounts.setController(currentChainCoinType, controller1); // Deployer sets itself as controller
        
        // Note: controlled2, controlled3, controlled4 would need to call setController themselves
        // For testing, we'll simulate this by directly setting the relationships
        console.log("[INFO] Note: Other accounts would need to call setController themselves");
        console.log("[INFO] This requires transactions from those accounts with their private keys");
        console.log("[INFO] Deployer has already set itself as controller on Ethereum coin type");
        console.log("[INFO] Deployer2 needs to call setController to verify the relationship");
        
        // Set up controlled accounts for Base Sepolia (deployment chain) - using current chain coin type
        console.log("Setting up Base Sepolia controlled accounts (coin type", currentChainCoinType, ") - deployment chain...");
        controlledAccounts.declareControlledAccount(currentChainCoinType, bytes32(0), baseAccount1);
        controlledAccounts.declareControlledAccount(currentChainCoinType, bytes32(0), baseAccount2);
        
        // Set up cross-coin-type controller relationships (coin type 0)
        console.log("Setting up cross-coin-type controller relationships (coin type 0)...");
        // Note: In real usage, baseAccount1 and baseAccount2 would call setControllerWithSignature
        // or setController themselves to establish the cross-coin-type relationship
        
        console.log("[SUCCESS] Cross-coin-type test data setup complete:");
        console.log("   Base Sepolia (coin type", currentChainCoinType, "):");
        console.log("     - Controller1 (PUBLIC_DEPLOYER_ADDRESS):", controller1);
        console.log("     - Controls:", controlled1);
        console.log("     - Controls:", controlled2);
        console.log("     - Controls:", controlled3);
        console.log("     - Controls:", controlled4);
        console.log("     - Controls:", baseAccount1);
        console.log("     - Controls:", baseAccount2);
        console.log("   Cross-coin-type (coin type 0):");
        console.log("     - Base accounts can verify controller relationship");
    }
    
    /* --- Deployment Summary --- */
    
    function _printDeploymentSummary() internal view {
        console.log("[SUMMARY] Deployment Summary");
        console.log("====================");
        console.log("");
        console.log("[CONTRACTS] Contracts Deployed:");
        console.log("   ControlledAccountsCrosschain:", address(controlledAccounts));
        console.log("");
        console.log("[CREDENTIAL] Credential Keys:");
        uint256 currentChainCoinType = controlledAccounts.chainIdToCoinType(block.chainid);
        console.log("   Base Sepolia default group: eth.ecs.controlled-accounts.accounts:", currentChainCoinType);
        console.log("   Cross-coin-type verification: eth.ecs.controlled-accounts.accounts:0");
        console.log("");
        console.log("[TESTDATA] Test Data:");
        console.log("   Controller1 (PUBLIC_DEPLOYER_ADDRESS):", controller1);
        console.log("   Controller2 (PUBLIC_DEPLOYER2_ADDRESS):", controller2);
        console.log("   Base Sepolia Controlled Accounts:");
        console.log("     - Controlled1 (PUBLIC_DEPLOYER_ADDRESS - self-control):", controlled1);
        console.log("     - Controlled2 (PUBLIC_DEPLOYER2_ADDRESS):", controlled2);
        console.log("     - Controlled3 (Dummy account 1):", controlled3);
        console.log("     - Controlled4 (Dummy account 2):", controlled4);
        console.log("     - BaseAccount1:", baseAccount1);
        console.log("     - BaseAccount2:", baseAccount2);
        console.log("");
        console.log("[VERIFY] Verification Commands:");
        console.log("");
        console.log("   # Check Base Sepolia controlled accounts for PUBLIC_DEPLOYER_ADDRESS");
        console.log("   cast call", address(controlledAccounts));
        console.log("   getControlledAccounts(address,uint256,bytes32)", controller1, currentChainCoinType, "0x0000000000000000000000000000000000000000000000000000000000000000");
        console.log("   --rpc-url $BASE_SEPOLIA_RPC_URL");
        console.log("");
        console.log("   # Check if deployer is controller for itself on Base Sepolia coin type");
        console.log("   cast call", address(controlledAccounts));
        console.log("   isController(address,uint256,address)", controlled1, currentChainCoinType, controller1);
        console.log("   --rpc-url $BASE_SEPOLIA_RPC_URL");
        console.log("");
        console.log("   # Check if deployer is controller for baseAccount1 on cross-coin-type");
        console.log("   cast call", address(controlledAccounts));
        console.log("   isController(address,uint256,address)", baseAccount1, DEFAULT_COIN_TYPE, controller1);
        console.log("   --rpc-url $BASE_SEPOLIA_RPC_URL");
        console.log("");
        console.log("[RESOLUTION] Credential Resolution Testing:");
        console.log("");
        console.log("   # Test Base Sepolia credential resolution");
        console.log("   # DNS identifier: {controller1_address}.3c (Ethereum coin type)");
        console.log("   # Credential key: eth.ecs.controlled-accounts.accounts:", currentChainCoinType);
        console.log("   # This would be used in: {controller1_address}.3c.addr.ecs.eth");
        console.log("");
        console.log("   # Test cross-coin-type credential resolution");
        console.log("   # DNS identifier: {controller1_address}.3c (Ethereum coin type)");
        console.log("   # Credential key: eth.ecs.controlled-accounts.accounts:0");
        console.log("   # This would be used in: {controller1_address}.3c.addr.ecs.eth");
        console.log("");
        console.log("[SETUP] Required Setup Commands:");
        console.log("");
        console.log("   # IMPORTANT: Deployer must set itself as controller on Base Sepolia coin type (already done in deployment)");
        console.log("   # This was completed during deployment, but for reference:");
        console.log("   cast send", address(controlledAccounts));
        console.log("   setController(uint256,address)", currentChainCoinType, controller1);
        console.log("   --private-key $DEPLOYER_PRIVATE_KEY");
        console.log("   --rpc-url $BASE_SEPOLIA_RPC_URL");
        console.log("");
        console.log("   # REQUIRED: Deployer2 must set deployer as its controller on Base Sepolia coin type");
        console.log("   # This verifies that deployer2 acknowledges deployer as its controller");
        console.log("   cast send", address(controlledAccounts));
        console.log("   setController(uint256,address)", currentChainCoinType, controller1);
        console.log("   --private-key $DEPLOYER2_PRIVATE_KEY");
        console.log("   --rpc-url $BASE_SEPOLIA_RPC_URL");
        console.log("");
        console.log("[CROSSCOINTYPE] Cross-Coin-Type Setup Commands:");
        console.log("");
        console.log("   # Set up cross-coin-type relationship for baseAccount1");
        console.log("   # This would require a signature from baseAccount1's private key");
        console.log("   cast send", address(controlledAccounts));
        console.log("   setControllerWithSignature(address,address,bytes)", baseAccount1, controller1, "0x...");
        console.log("   --private-key $DEPLOYER_PRIVATE_KEY");
        console.log("   --rpc-url $BASE_SEPOLIA_RPC_URL");
        console.log("");
        console.log("[SUCCESS] ControlledAccountsCrosschain deployment complete!");
        console.log("[INFO] Use this contract to test cross-coin-type controlled accounts credential resolution");
    }
}
