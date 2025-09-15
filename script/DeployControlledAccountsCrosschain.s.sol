// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/credentials/controlled-accounts/ControlledAccountsCrosschain.sol";

/**
 * @title DeployControlledAccountsCrosschain
 * @dev Deploy the ControlledAccountsCrosschain credential resolver for cross-chain testing
 * 
 * This script deploys the ControlledAccountsCrosschain contract and sets up test data
 * to demonstrate cross-chain controlled accounts relationships and credential resolution.
 * 
 * Usage:
 * forge script script/DeployControlledAccountsCrosschain.s.sol:DeployControlledAccountsCrosschain --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
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
    
    // Chain IDs
    uint256 constant L1_CHAIN_ID = 11155111; // Sepolia testnet
    uint256 constant BASE_CHAIN_ID = 84532;  // Base Sepolia testnet
    uint256 constant DEFAULT_CHAIN_ID = 0;   // Cross-chain default
    
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
        console.log("Step 2: Setting up cross-chain controlled accounts relationships...");
        _setupTestData();
        console.log("");
        
        // Step 3: Print deployment summary
        console.log("Step 3: Deployment Summary");
        _printDeploymentSummary();
        
        vm.stopBroadcast();
    }
    
    /* --- Test Data Setup --- */
    
    function _setupTestData() internal {
        // Set up controlled accounts for Sepolia (chain ID 11155111)
        console.log("Setting up Sepolia controlled accounts (chain ID 11155111)...");
        
        // Deployer declares controlled accounts on Sepolia (default group)
        controlledAccounts.declareControlledAccount(L1_CHAIN_ID, bytes32(0), controlled1); // Self-control
        controlledAccounts.declareControlledAccount(L1_CHAIN_ID, bytes32(0), controlled2); // Controls deployer2
        controlledAccounts.declareControlledAccount(L1_CHAIN_ID, bytes32(0), controlled3); // Dummy account 1
        controlledAccounts.declareControlledAccount(L1_CHAIN_ID, bytes32(0), controlled4); // Dummy account 2
        
        // Set up controller relationships for L1
        console.log("Setting up L1 controller relationships...");
        controlledAccounts.setController(L1_CHAIN_ID, controller1); // Deployer sets itself as controller
        
        // Note: controlled2, controlled3, controlled4 would need to call setController themselves
        // For testing, we'll simulate this by directly setting the relationships
        console.log("[INFO] Note: Other accounts would need to call setController themselves");
        console.log("[INFO] This requires transactions from those accounts with their private keys");
        console.log("[INFO] Deployer has already set itself as controller on L1");
        console.log("[INFO] Deployer2 needs to call setController to verify the relationship");
        
        // Set up controlled accounts for Base Sepolia (chain ID 84532)
        console.log("Setting up Base Sepolia controlled accounts (chain ID 84532)...");
        controlledAccounts.declareControlledAccount(BASE_CHAIN_ID, bytes32(0), baseAccount1);
        controlledAccounts.declareControlledAccount(BASE_CHAIN_ID, bytes32(0), baseAccount2);
        
        // Set up cross-chain controller relationships (chain ID 0)
        console.log("Setting up cross-chain controller relationships (chain ID 0)...");
        // Note: In real usage, baseAccount1 and baseAccount2 would call setControllerWithSignature
        // or setController themselves to establish the cross-chain relationship
        
        console.log("[SUCCESS] Cross-chain test data setup complete:");
        console.log("   Sepolia (chain ID 11155111):");
        console.log("     - Controller1 (PUBLIC_DEPLOYER_ADDRESS):", controller1);
        console.log("     - Controls:", controlled1);
        console.log("     - Controls:", controlled2);
        console.log("     - Controls:", controlled3);
        console.log("     - Controls:", controlled4);
        console.log("   Base Sepolia (chain ID 84532):");
        console.log("     - Controller1 (PUBLIC_DEPLOYER_ADDRESS):", controller1);
        console.log("     - Controls:", baseAccount1);
        console.log("     - Controls:", baseAccount2);
        console.log("   Cross-chain (chain ID 0):");
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
        console.log("   Sepolia default group: eth.ecs.controlled-accounts.accounts:11155111");
        console.log("   Base Sepolia default group: eth.ecs.controlled-accounts.accounts:84532");
        console.log("   Cross-chain verification: eth.ecs.controlled-accounts.accounts:0");
        console.log("");
        console.log("[TESTDATA] Test Data:");
        console.log("   Controller1 (PUBLIC_DEPLOYER_ADDRESS):", controller1);
        console.log("   Controller2 (PUBLIC_DEPLOYER2_ADDRESS):", controller2);
        console.log("   Sepolia Controlled Accounts:");
        console.log("     - Controlled1 (PUBLIC_DEPLOYER_ADDRESS - self-control):", controlled1);
        console.log("     - Controlled2 (PUBLIC_DEPLOYER2_ADDRESS):", controlled2);
        console.log("     - Controlled3 (Dummy account 1):", controlled3);
        console.log("     - Controlled4 (Dummy account 2):", controlled4);
        console.log("   Base Sepolia Controlled Accounts:");
        console.log("     - BaseAccount1:", baseAccount1);
        console.log("     - BaseAccount2:", baseAccount2);
        console.log("");
        console.log("[VERIFY] Verification Commands:");
        console.log("");
        console.log("   # Check Sepolia controlled accounts for PUBLIC_DEPLOYER_ADDRESS");
        console.log("   cast call", address(controlledAccounts));
        console.log("   getControlledAccounts(address,uint256,bytes32)", controller1, L1_CHAIN_ID, "0x0000000000000000000000000000000000000000000000000000000000000000");
        console.log("   --rpc-url $SEPOLIA_RPC_URL");
        console.log("");
        console.log("   # Check Base Sepolia controlled accounts for PUBLIC_DEPLOYER_ADDRESS");
        console.log("   cast call", address(controlledAccounts));
        console.log("   getControlledAccounts(address,uint256,bytes32)", controller1, BASE_CHAIN_ID, "0x0000000000000000000000000000000000000000000000000000000000000000");
        console.log("   --rpc-url $SEPOLIA_RPC_URL");
        console.log("");
        console.log("   # Check if deployer is controller for itself on Sepolia");
        console.log("   cast call", address(controlledAccounts));
        console.log("   isController(address,uint256,address)", controlled1, L1_CHAIN_ID, controller1);
        console.log("   --rpc-url $SEPOLIA_RPC_URL");
        console.log("");
        console.log("   # Check if deployer is controller for baseAccount1 on cross-chain");
        console.log("   cast call", address(controlledAccounts));
        console.log("   isController(address,uint256,address)", baseAccount1, DEFAULT_CHAIN_ID, controller1);
        console.log("   --rpc-url $SEPOLIA_RPC_URL");
        console.log("");
        console.log("[RESOLUTION] Credential Resolution Testing:");
        console.log("");
        console.log("   # Test Sepolia credential resolution");
        console.log("   # DNS identifier: {controller1_address}.3c (Ethereum coin type)");
        console.log("   # Credential key: eth.ecs.controlled-accounts.accounts:11155111");
        console.log("   # This would be used in: {controller1_address}.3c.addr.ecs.eth");
        console.log("");
        console.log("   # Test Base Sepolia credential resolution");
        console.log("   # DNS identifier: {controller1_address}.3c (Ethereum coin type)");
        console.log("   # Credential key: eth.ecs.controlled-accounts.accounts:84532");
        console.log("   # This would be used in: {controller1_address}.3c.addr.ecs.eth");
        console.log("");
        console.log("   # Test cross-chain credential resolution");
        console.log("   # DNS identifier: {controller1_address}.3c (Ethereum coin type)");
        console.log("   # Credential key: eth.ecs.controlled-accounts.accounts:0");
        console.log("   # This would be used in: {controller1_address}.3c.addr.ecs.eth");
        console.log("");
        console.log("[SETUP] Required Setup Commands:");
        console.log("");
        console.log("   # IMPORTANT: Deployer must set itself as controller on Sepolia (already done in deployment)");
        console.log("   # This was completed during deployment, but for reference:");
        console.log("   cast send", address(controlledAccounts));
        console.log("   setController(uint256,address)", L1_CHAIN_ID, controller1);
        console.log("   --private-key $DEPLOYER_PRIVATE_KEY");
        console.log("   --rpc-url $SEPOLIA_RPC_URL");
        console.log("");
        console.log("   # REQUIRED: Deployer2 must set deployer as its controller on Sepolia");
        console.log("   # This verifies that deployer2 acknowledges deployer as its controller");
        console.log("   cast send", address(controlledAccounts));
        console.log("   setController(uint256,address)", L1_CHAIN_ID, controller1);
        console.log("   --private-key $DEPLOYER2_PRIVATE_KEY");
        console.log("   --rpc-url $SEPOLIA_RPC_URL");
        console.log("");
        console.log("[CROSSCHAIN] Cross-Chain Setup Commands:");
        console.log("");
        console.log("   # Set up cross-chain relationship for baseAccount1");
        console.log("   # This would require a signature from baseAccount1's private key");
        console.log("   cast send", address(controlledAccounts));
        console.log("   setControllerWithSignature(address,address,bytes)", baseAccount1, controller1, "0x...");
        console.log("   --private-key $DEPLOYER_PRIVATE_KEY");
        console.log("   --rpc-url $SEPOLIA_RPC_URL");
        console.log("");
        console.log("[SUCCESS] ControlledAccountsCrosschain deployment complete!");
        console.log("[INFO] Use this contract to test cross-chain controlled accounts credential resolution");
    }
}
