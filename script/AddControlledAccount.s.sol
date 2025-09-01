// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/credentials/controlled-accounts/ControlledAccounts.sol";

/**
 * @title AddControlledAccount
 * @dev Script to add an additional controlled account to the existing ControlledAccounts contract
 * Adds address 0x1111111111111111111111111111111111111111 to PUBLIC_DEPLOYER_ADDRESS's controlled accounts
 * This address will NOT have a corresponding accountController set (orphaned controlled account)
 */
contract AddControlledAccount is Script {
    // Contract address from previous deployment
    address public constant CONTROLLED_ACCOUNTS_CONTRACT = 0x940b8E6c426991283406d01bF65A5AC2AdA24a79;
    
    // Address to add (all 1s)
    address public constant NEW_CONTROLLED_ACCOUNT = 0x1111111111111111111111111111111111111111;
    
    // Deployer address
    address public deployer;
    
    function setUp() public {
        deployer = vm.envAddress("PUBLIC_DEPLOYER_ADDRESS");
    }
    
    function run() public {
        vm.startBroadcast();
        
        console.log("[ADD] Adding Additional Controlled Account");
        console.log("==========================================");
        console.log("");
        console.log("Contract:", CONTROLLED_ACCOUNTS_CONTRACT);
        console.log("Deployer:", deployer);
        console.log("New Controlled Account:", NEW_CONTROLLED_ACCOUNT);
        console.log("");
        
        // Get the ControlledAccounts contract instance
        ControlledAccounts controlledAccounts = ControlledAccounts(CONTROLLED_ACCOUNTS_CONTRACT);
        
        console.log("Step 1: Adding new controlled account...");
        
        // Add the new controlled account to the deployer's list
        controlledAccounts.declareControlledAccount(NEW_CONTROLLED_ACCOUNT);
        
        console.log("[SUCCESS] Added", NEW_CONTROLLED_ACCOUNT, "to controlled accounts");
        console.log("");
        
        console.log("Step 2: Verification Summary");
        console.log("============================");
        console.log("");
        console.log("[SUCCESS] New controlled account added");
        console.log("[INFO] No accountController set for", NEW_CONTROLLED_ACCOUNT);
        console.log("   This creates an 'orphaned' controlled account for testing");
        console.log("");
        console.log("[VERIFY] Verification Commands:");
        console.log("");
        console.log("   # Check updated controlled accounts list");
        console.log("   cast call", CONTROLLED_ACCOUNTS_CONTRACT);
        console.log("   getControlledAccounts(address)", deployer);
        console.log("   --rpc-url $BASE_SEPOLIA_RPC_URL");
        console.log("");
        console.log("   # Check that NEW_CONTROLLED_ACCOUNT has no controller");
        console.log("   cast call", CONTROLLED_ACCOUNTS_CONTRACT);
        console.log("   accountController(address)", NEW_CONTROLLED_ACCOUNT);
        console.log("   --rpc-url $BASE_SEPOLIA_RPC_URL");
        console.log("");
        console.log("   # Should return: 0x0000000000000000000000000000000000000000000000000000000000000000");
        console.log("");
        console.log("[STORAGE] Storage Slot Commands:");
        console.log("");
        console.log("   # Check updated controlledAccounts array length");
        console.log("   cast storage", CONTROLLED_ACCOUNTS_CONTRACT);
        console.log("   0xf73d950f5029e91e41bae1e98f9300b6719e27f3cdce81dfc6d4166fe5c1e007");
        console.log("   --rpc-url $BASE_SEPOLIA_RPC_URL");
        console.log("");
        console.log("   # Should now return: 0x0000000000000000000000000000000000000000000000000000000000000004");
        console.log("   # (Array length increased from 3 to 4)");
        console.log("");
        console.log("   # Check new array element 3");
        console.log("   cast storage", CONTROLLED_ACCOUNTS_CONTRACT);
        console.log("   0x29db6b2581fc822327e4883011294e7611cbad7a124cd64f7fdb9b7f50fddbd1");
        console.log("   --rpc-url $BASE_SEPOLIA_RPC_URL");
        console.log("");
        console.log("   # Should return: 0x0000000000000000000000001111111111111111111111111111111111111111");
        console.log("");
        console.log("[SUCCESS] Additional controlled account deployment complete!");
        console.log("[INFO] This creates a test scenario with an orphaned controlled account");
        
        vm.stopBroadcast();
    }
}
