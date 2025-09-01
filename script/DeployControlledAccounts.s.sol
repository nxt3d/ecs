// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/credentials/controlled-accounts/ControlledAccounts.sol";

/**
 * @title DeployControlledAccounts
 * @dev Deploy the ControlledAccounts credential resolver for testing
 * 
 * This script deploys the ControlledAccounts contract and sets up test data
 * to demonstrate controlled accounts relationships and credential resolution.
 * 
 * Usage:
 * forge script script/DeployControlledAccounts.s.sol:DeployControlledAccounts --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
 */
contract DeployControlledAccounts is Script {
    
    /* --- State Variables --- */
    
    ControlledAccounts public controlledAccounts;
    
    /* --- Environment Variables --- */
    
    // Deployment addresses
    address public deployer;
    address public deployer2;
    
    // Test addresses for controlled accounts relationships
    // Using addresses we control so we can verify them later
    address public controller1;
    address public controller2;
    address public controlled1;
    address public controlled2;
    address public controlled3;
    
    /* --- Setup --- */
    
    function setUp() public {
        deployer = vm.envAddress("PUBLIC_DEPLOYER_ADDRESS");
        deployer2 = vm.envAddress("PUBLIC_DEPLOYER2_ADDRESS");
        
        // Use addresses we control for testing
        controller1 = deployer;  // PUBLIC_DEPLOYER_ADDRESS as controller
        controller2 = deployer2; // PUBLIC_DEPLOYER2_ADDRESS as controller
        
        // PUBLIC_DEPLOYER_ADDRESS controls 2 accounts: itself and PUBLIC_DEPLOYER2_ADDRESS
        controlled1 = deployer;   // PUBLIC_DEPLOYER_ADDRESS controls itself
        controlled2 = deployer2;  // PUBLIC_DEPLOYER_ADDRESS controls PUBLIC_DEPLOYER2_ADDRESS
        // PUBLIC_DEPLOYER2_ADDRESS doesn't control any accounts, just verifies it has a controller
        controlled3 = address(0); // Not used - deployer2 doesn't control any accounts
    }
    
    /* --- Main Deployment --- */
    
    function run() public {
        vm.startBroadcast(deployer);
        
        console.log("[DEPLOY] Deploying ControlledAccounts Credential Resolver");
        console.log("==================================================");
        console.log("");
        
        // Step 1: Deploy ControlledAccounts contract
        console.log("Step 1: Deploying ControlledAccounts contract...");
        controlledAccounts = new ControlledAccounts();
        console.log("[SUCCESS] ControlledAccounts deployed at:", address(controlledAccounts));
        console.log("");
        
        // Step 2: Set up test data
        console.log("Step 2: Setting up test controlled accounts relationships...");
        _setupTestData();
        console.log("");
        
        // Step 3: Print deployment summary
        console.log("Step 3: Deployment Summary");
        _printDeploymentSummary();
        
        vm.stopBroadcast();
    }
    
    /* --- Test Data Setup --- */
    
    function _setupTestData() internal {
        // Set up controlled accounts for PUBLIC_DEPLOYER_ADDRESS
        // For testing, we can add the same address multiple times
        address[] memory accountsToControl = new address[](3);
        accountsToControl[0] = controlled1; // PUBLIC_DEPLOYER_ADDRESS (self-control)
        accountsToControl[1] = controlled2; // PUBLIC_DEPLOYER2_ADDRESS
        accountsToControl[2] = controlled2; // PUBLIC_DEPLOYER2_ADDRESS (duplicate for testing)
        
        controlledAccounts.declareControlledAccounts(accountsToControl);
        
        // Set up controller relationships
        // PUBLIC_DEPLOYER_ADDRESS sets itself as its own controller
        controlledAccounts.setController(controller1);
        
        console.log("[INFO] Note: PUBLIC_DEPLOYER2_ADDRESS would need to call setController(PUBLIC_DEPLOYER_ADDRESS) separately");
        console.log("[INFO] This requires a transaction from PUBLIC_DEPLOYER2_ADDRESS with its private key");
        
        console.log("[SUCCESS] Test data setup complete:");
        console.log("   Controller1 (PUBLIC_DEPLOYER_ADDRESS):", controller1);
        console.log("     - Controls:", controlled1, controlled2);
        console.log("     - Also controls (duplicate):", controlled2);
        console.log("   Controller2 (PUBLIC_DEPLOYER2_ADDRESS):", controller2);
        console.log("     - Verifies it is controlled by:", controller1);
    }
    
    /* --- Deployment Summary --- */
    
    function _printDeploymentSummary() internal view {
        console.log("[SUMMARY] Deployment Summary");
        console.log("====================");
        console.log("");
        console.log("[CONTRACTS] Contracts Deployed:");
        console.log("   ControlledAccounts:", address(controlledAccounts));
        console.log("");
        console.log("[CREDENTIAL] Credential Key:");
        console.log("   eth.ecs.controlled-accounts.accounts");
        console.log("");
        console.log("[TESTDATA] Test Data:");
        console.log("   Controller1 (PUBLIC_DEPLOYER_ADDRESS):", controller1);
        console.log("   Controller2 (PUBLIC_DEPLOYER2_ADDRESS):", controller2);
        console.log("   Controlled1 (PUBLIC_DEPLOYER_ADDRESS - self-control):", controlled1);
        console.log("   Controlled2 (PUBLIC_DEPLOYER2_ADDRESS):", controlled2);
        console.log("   Controlled3 (PUBLIC_DEPLOYER2_ADDRESS - duplicate for testing):", controlled2);
        console.log("");
        console.log("[VERIFY] Verification Commands:");
        console.log("");
        console.log("   # Check controlled accounts for PUBLIC_DEPLOYER_ADDRESS");
        console.log("   cast call", address(controlledAccounts));
        console.log("   getControlledAccounts(address)", controller1);
        console.log("   --rpc-url $BASE_SEPOLIA_RPC_URL");
        console.log("");
        console.log("   # Check controlled accounts for PUBLIC_DEPLOYER2_ADDRESS");
        console.log("   cast call", address(controlledAccounts));
        console.log("   getControlledAccounts(address)", controller2);
        console.log("   --rpc-url $BASE_SEPOLIA_RPC_URL");
        console.log("");
        console.log("   # Check controller for PUBLIC_DEPLOYER_ADDRESS (self-control)");
        console.log("   cast call", address(controlledAccounts));
        console.log("   getController(address)", controlled1);
        console.log("   --rpc-url $BASE_SEPOLIA_RPC_URL");
        console.log("");
        console.log("   # Check controller for PUBLIC_DEPLOYER2_ADDRESS");
        console.log("   cast call", address(controlledAccounts));
        console.log("   getController(address)", controlled2);
        console.log("   --rpc-url $BASE_SEPOLIA_RPC_URL");
        console.log("");
        console.log("   # Check controller for PUBLIC_DEPLOYER2_ADDRESS");
        console.log("   cast call", address(controlledAccounts));
        console.log("   getController(address)", controlled2);
        console.log("   --rpc-url $BASE_SEPOLIA_RPC_URL");
        console.log("");
        console.log("   # Complete the setup - PUBLIC_DEPLOYER2_ADDRESS sets its controller");
        console.log("   cast send", address(controlledAccounts));
        console.log("   setController(address)", controller1);
        console.log("   --private-key $DEPLOYER2_PRIVATE_KEY");
        console.log("   --rpc-url $BASE_SEPOLIA_RPC_URL");
        console.log("");
        console.log("[RESOLUTION] Credential Resolution Testing:");
        console.log("");
        console.log("   # Test credential resolution for Controller1");
        console.log("   # DNS identifier: {controller1_address}.3c (Ethereum coin type)");
        console.log("   # This would be used in: {controller1_address}.3c.addr.ecs.eth");
        console.log("");
        console.log("   # Test credential resolution for Controller2");
        console.log("   # DNS identifier: {controller2_address}.3c (Ethereum coin type)");
        console.log("   # This would be used in: {controller2_address}.3c.addr.ecs.eth");
        console.log("");
        console.log("[SUCCESS] ControlledAccounts deployment complete!");
        console.log("[INFO] Use this contract to test controlled accounts credential resolution");
    }
}
