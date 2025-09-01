// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/credentials/ethstars/StarResolver.sol";
import "../src/credentials/ethstars/StarNameResolver.sol";
import "../src/credentials/controlled-accounts/ControlledAccounts.sol";

/**
 * @title DeployCredentialsToBase
 * @dev Deployment script for credential resolvers on Base network (both mainnet and testnet)
 * 
 * This script deploys the onchain credential resolvers that store the actual data:
 * - StarResolver (ethstars credential - address-based)
 * - StarNameResolver (ethstars credential - name-based) 
 * - ControlledAccounts (controlled-accounts credential)
 * 
 * Usage for Base Sepolia:
 * forge script script/DeployCredentialsToBase.s.sol:DeployCredentialsToBase --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --broadcast --verify --etherscan-api-key $BASESCAN_API_KEY
 * 
 * Usage for Base Mainnet:
 * forge script script/DeployCredentialsToBase.s.sol:DeployCredentialsToBase --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --broadcast --verify --etherscan-api-key $BASESCAN_API_KEY
 */
contract DeployCredentialsToBase is Script {
    
    /* --- Deployed Contracts --- */
    
    StarResolver public starResolver;
    StarNameResolver public starNameResolver;
    ControlledAccounts public controlledAccounts;
    
    /* --- Configuration --- */
    
    // Network detection
    uint256 public chainId;
    string public networkName;
    
    /* --- Deployment Function --- */
    
    function run() external {
        // Get chain ID to determine network
        chainId = block.chainid;
        
        if (chainId == 8453) {
            networkName = "Base Mainnet";
        } else if (chainId == 84532) {
            networkName = "Base Sepolia";
        } else {
            revert(string(abi.encodePacked("Unsupported chain ID: ", vm.toString(chainId))));
        }
        
        vm.startBroadcast();
        
        // Get deployer address from msg.sender after broadcast starts
        address deployer = msg.sender;
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);
        console.log("Network:", networkName);
        console.log("Chain ID:", chainId);
        
        console.log("\n=== DEPLOYING CREDENTIAL RESOLVERS TO BASE ===\n");
        
        // Step 1: Deploy StarResolver (ethstars address-based credential)
        console.log("1. Deploying StarResolver (ethstars address-based)...");
        starResolver = new StarResolver();
        console.log("   StarResolver deployed at:", address(starResolver));
        console.log("   Text record key:", starResolver.textRecordKey());
        console.log("   Star price:", starResolver.starPrice(), "wei");
        
        // Step 2: Deploy StarNameResolver (ethstars name-based credential)
        console.log("\n2. Deploying StarNameResolver (ethstars name-based)...");
        starNameResolver = new StarNameResolver();
        console.log("   StarNameResolver deployed at:", address(starNameResolver));
        console.log("   Text record key:", starNameResolver.textRecordKey());
        console.log("   Star price:", starNameResolver.starPrice(), "wei");
        
        // Step 3: Deploy ControlledAccounts (controlled-accounts credential)
        console.log("\n3. Deploying ControlledAccounts...");
        controlledAccounts = new ControlledAccounts();
        console.log("   ControlledAccounts deployed at:", address(controlledAccounts));
        console.log("   Text record key:", controlledAccounts.textRecordKey());
        console.log("   Controlled accounts: unlimited per controller");
        
        // Step 4: Set up test data
        console.log("\n4. Setting up test data...");
        _setupTestData();
        
        vm.stopBroadcast();
        
        // Step 5: Print deployment summary
        _printDeploymentSummary(deployer);
        
        console.log("\n=== CREDENTIAL RESOLVERS DEPLOYMENT COMPLETE ===\n");
    }
    
    /* --- Helper Functions --- */
    
    function _setupTestData() internal {
        // Test addresses
        address vitalikAddress = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
        uint256 ethereumCoinType = 60; // Ethereum mainnet coin type [[memory:2860596]]
        
        // Get deployer addresses from environment or use msg.sender
        address publicDeployerAddress;
        address publicDeployer2Address;
        
        try vm.envAddress("PUBLIC_DEPLOYER_ADDRESS") returns (address envAddr) {
            publicDeployerAddress = envAddr;
        } catch {
            publicDeployerAddress = msg.sender;
        }
        
        try vm.envAddress("PUBLIC_DEPLOYER2_ADDRESS") returns (address envAddr2) {
            publicDeployer2Address = envAddr2;
        } catch {
            publicDeployer2Address = address(0);
        }
        
        console.log("   Setting up test data with addresses:");
        console.log("     Vitalik address:", vitalikAddress);
        console.log("     Public deployer address:", publicDeployerAddress);
        console.log("     Public deployer 2 address:", publicDeployer2Address);
        
        // Set up ethstars test data - buy one star for vitalik.eth
        console.log("   Setting up ethstars test data...");
        uint256 starPrice = starResolver.starPrice();
        console.log("     Star price:", starPrice, "wei");
        
        // Buy star for Vitalik's address with Ethereum coin type
        starResolver.buyStar{value: starPrice}(vitalikAddress, ethereumCoinType);
        console.log("     [SUCCESS] Bought 1 star for vitalik.eth (", vitalikAddress, ") with coin type", ethereumCoinType);
        
        // Also buy star for Vitalik's address via StarNameResolver (name-based)
        starNameResolver.buyStar{value: starPrice}("vitalik.eth");
        console.log("     [SUCCESS] Bought 1 star for vitalik.eth (name-based)");
        
        // Set up controlled accounts test data (if we have both addresses)
        if (publicDeployer2Address != address(0)) {
            console.log("   Setting up controlled accounts test data...");
            
            // Set up the relationship: PUBLIC_DEPLOYER_ADDRESS controls PUBLIC_DEPLOYER2_ADDRESS
            address[] memory controlledAddresses = new address[](1);
            controlledAddresses[0] = publicDeployer2Address;
            
            // Declare controlled accounts (this will be called by PUBLIC_DEPLOYER_ADDRESS)
            // Note: We need to use vm.prank to simulate calling from the correct address
            vm.prank(publicDeployerAddress);
            controlledAccounts.declareControlledAccounts(controlledAddresses);
            console.log("     [SUCCESS] Set", publicDeployer2Address, "as controlled by", publicDeployerAddress);
            
            // Optionally, have the controlled account verify the relationship
            vm.prank(publicDeployer2Address);
            controlledAccounts.setController(publicDeployerAddress);
            console.log("     [SUCCESS] Verified controller relationship from controlled account side");
            
        } else {
            console.log("   Skipping controlled accounts test data (PUBLIC_DEPLOYER2_ADDRESS not set)");
        }
        
        console.log("   [SUCCESS] Test data setup complete!");
    }
    
    function _printDeploymentSummary(address deployer) internal view {
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Network:", networkName);
        console.log("Chain ID:", chainId);
        console.log("Deployer:", deployer);
        
        console.log("\nCredential Resolvers:");
        console.log("  - StarResolver (ethstars address-based):", address(starResolver));
        console.log("  - StarNameResolver (ethstars name-based):", address(starNameResolver));
        console.log("  - ControlledAccounts:", address(controlledAccounts));
        
        console.log("\nCredential Keys:");
        console.log("  - StarResolver:", starResolver.textRecordKey());
        console.log("  - StarNameResolver:", starNameResolver.textRecordKey());
        console.log("  - ControlledAccounts:", controlledAccounts.textRecordKey());
        
        console.log("\nConfiguration:");
        console.log("  - Star price (both star resolvers):", starResolver.starPrice(), "wei");
        console.log("  - Controlled accounts: unlimited per controller");
        
        console.log("\nTest Data:");
        address vitalikAddress = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
        console.log("  - Vitalik.eth (", vitalikAddress, ") has 1 star (address-based and name-based)");
        
        try vm.envAddress("PUBLIC_DEPLOYER_ADDRESS") returns (address publicDeployerAddress) {
            try vm.envAddress("PUBLIC_DEPLOYER2_ADDRESS") returns (address publicDeployer2Address) {
                console.log("  - Controlled accounts relationship:");
                console.log("    Controller:", publicDeployerAddress);
                console.log("    Controlled:", publicDeployer2Address);
            } catch {
                console.log("  - Controlled accounts: Not set up (PUBLIC_DEPLOYER2_ADDRESS missing)");
            }
        } catch {
            console.log("  - Controlled accounts: Not set up (PUBLIC_DEPLOYER_ADDRESS missing)");
        }
        
        console.log("\nNext Steps:");
        console.log("1. These contracts are now ready to store credential data on Base");
        console.log("2. Deploy the ECS protocol on Sepolia pointing to these contracts");
        console.log("3. Test credential resolution via the deployed resolvers");
        console.log("4. Configure the offchain resolvers to fetch from these addresses");
        
        console.log("\nTesting Commands:");
        console.log("1. Test star count for Vitalik:");
        console.log("   cast call", address(starResolver));
        console.log("   \"starCounts(address,uint256)(uint256)\"", vitalikAddress);
        console.log("   60 --rpc-url $BASE_SEPOLIA_RPC_URL");
        console.log("2. Test controlled accounts:");
        console.log("   cast call", address(controlledAccounts));
        console.log("   \"getControlledAccounts(address)(address[])\" <CONTROLLER_ADDRESS>");
        console.log("   --rpc-url $BASE_SEPOLIA_RPC_URL");
        
        console.log("\nContract Verification:");
        console.log("All contracts deployed with verification enabled.");
        console.log("Check BaseScan for verification status.");
        
        // Export addresses for use in other scripts
        console.log("\n=== CONTRACT ADDRESSES FOR REFERENCE ===");
        console.log("StarResolver:", address(starResolver));
        console.log("StarNameResolver:", address(starNameResolver));
        console.log("ControlledAccounts:", address(controlledAccounts));
    }
}
