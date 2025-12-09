// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/ECSRegistry.sol";
import "../src/ECSRegistrar.sol";

/**
 * @title CommitControlledAccounts - Step 1 of 2
 * @notice Creates a commitment for "controlled-accounts.ecs.eth"
 * 
 * USAGE:
 *   forge script script/CommitControlledAccounts.s.sol:CommitControlledAccounts \
 *     --rpc-url $SEPOLIA_RPC_URL \
 *     --broadcast \
 *     -vv
 * 
 * REQUIRED ENV VARS:
 *   - DEPLOYER_PRIVATE_KEY
 *   - ECS_REGISTRAR_ADDRESS
 * 
 * OPTIONAL ENV VARS:
 *   - CC_RESOLVER_ADDRESS (default: 0xCE943F957FC46a8d048505E6949e32201a128f84)
 *   - REGISTRATION_SECRET (will be generated and displayed if not provided)
 * 
 * WHAT IT DOES:
 *   1. Creates a commitment for the "controlled-accounts" label
 *   2. Submits the commitment to ECSRegistrar
 *   3. Displays the secret to use in the next step
 * 
 * AFTER RUNNING:
 *   1. WAIT AT LEAST 60 SECONDS
 *   2. Run: forge script script/RegisterControlledAccounts.s.sol --broadcast
 *      (Use the same REGISTRATION_SECRET shown below)
 */
contract CommitControlledAccounts is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        
        // Load deployed ECS contract addresses
        address registrarAddress = vm.envAddress("ECS_REGISTRAR_ADDRESS");
        
        // CCResolver address from deployment
        address ccResolverAddress = vm.envAddress("CC_RESOLVER_ADDRESS");
        
        // Registration parameters
        string memory label = "controlled-accounts";
        uint256 duration = 365 days * 10; // 10 years
        
        // Compute deployer address first
        address deployerAddress = vm.addr(deployerPrivateKey);
        
        // Generate or use provided secret
        bytes32 secret;
        try vm.envBytes32("REGISTRATION_SECRET") returns (bytes32 envSecret) {
            secret = envSecret;
            console.log("Using REGISTRATION_SECRET from environment");
        } catch {
            secret = keccak256(abi.encodePacked("controlled-accounts-", block.timestamp, deployerAddress));
            console.log("Generated new REGISTRATION_SECRET");
        }
        
        // Connect to deployed contracts
        ECSRegistrar registrar = ECSRegistrar(registrarAddress);
        
        console.log("=======================================================");
        console.log("STEP 1: COMMIT controlled-accounts.ecs.eth");
        console.log("=======================================================");
        console.log("This creates a commitment to prevent front-running.");
        console.log("After committing, you must wait 60 seconds before");
        console.log("registering in Step 2.");
        console.log("");
        console.log("Configuration:");
        console.log("  ECS Registrar:", registrarAddress);
        console.log("  CCResolver:", ccResolverAddress);
        console.log("  Label:", label);
        console.log("  Duration:", duration / 365 days, "years");
        console.log("=======================================================");
        
        // Check if name is available
        bool isAvailable = registrar.available(label);
        console.log("");
        console.log("Checking availability...");
        console.log("  Name available:", isAvailable);
        
        if (!isAvailable) {
            console.log("");
            console.log("ERROR: Name is not available for registration");
            console.log("The name may already be registered and not expired.");
            revert("Name not available");
        }
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Create and submit commitment
        bytes32 commitment = registrar.createCommitment(
            label,
            deployerAddress,
            ccResolverAddress,
            duration,
            secret
        );
        
        // Check if commitment already exists
        uint256 existingCommitment = registrar.commitments(commitment);
        if (existingCommitment != 0) {
            console.log("");
            console.log("ERROR: This commitment already exists!");
            console.log("Committed at timestamp:", existingCommitment);
            console.log("You can proceed to Step 2 if 60 seconds have passed.");
            vm.stopBroadcast();
            return;
        }
        
        // Submit commitment
        registrar.commit(commitment);
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("=======================================================");
        console.log("SUCCESS! Commitment Submitted");
        console.log("=======================================================");
        console.log("Commitment Hash:", vm.toString(commitment));
        console.log("Timestamp:", block.timestamp);
        console.log("=======================================================");
        console.log("");
        console.log("IMPORTANT - Save this secret for Step 2:");
        console.log("  REGISTRATION_SECRET=", vm.toString(secret));
        console.log("");
        console.log("=======================================================");
        console.log("NEXT STEPS:");
        console.log("=======================================================");
        console.log("1. WAIT AT LEAST 60 SECONDS");
        console.log("");
        console.log("2. Run the registration script:");
        console.log("   forge script script/RegisterControlledAccounts.s.sol \\");
        console.log("     --rpc-url $SEPOLIA_RPC_URL \\");
        console.log("     --broadcast \\");
        console.log("     -vv");
        console.log("");
        console.log("3. Make sure to set the secret in your environment:");
        console.log("   export REGISTRATION_SECRET=", vm.toString(secret));
        console.log("=======================================================");
    }
}

