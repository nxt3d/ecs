// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/ECSRegistry.sol";

/**
 * @title CommitResolverUpdate - Step 1 of 2
 * @notice Creates a commitment to update the resolver for controlled-accounts.ecs.eth
 * 
 * USAGE:
 *   forge script script/CommitResolverUpdate.s.sol:CommitResolverUpdate \
 *     --rpc-url $SEPOLIA_RPC_URL \
 *     --broadcast \
 *     -vv
 * 
 * REQUIRED ENV VARS:
 *   - DEPLOYER_PRIVATE_KEY (must be the owner)
 *   - ECS_REGISTRY_ADDRESS
 *   - NEW_CC_RESOLVER_ADDRESS
 * 
 * OPTIONAL ENV VARS:
 *   - UPDATE_SECRET (will be generated if not provided)
 */
contract CommitResolverUpdate is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address registryAddress = vm.envAddress("ECS_REGISTRY_ADDRESS");
        address newResolverAddress = vm.envAddress("NEW_CC_RESOLVER_ADDRESS");
        
        string memory label = "controlled-accounts";
        bytes32 labelhash = keccak256(bytes(label));
        address deployerAddress = vm.addr(deployerPrivateKey);
        
        ECSRegistry registry = ECSRegistry(registryAddress);
        
        console.log("=======================================================");
        console.log("STEP 1: COMMIT Resolver Update");
        console.log("=======================================================");
        console.log("Name: controlled-accounts.ecs.eth");
        console.log("ECS Registry:", registryAddress);
        console.log("New Resolver:", newResolverAddress);
        console.log("=======================================================");
        
        // Check current registration
        address currentOwner = registry.owner(labelhash);
        address currentResolver = registry.resolver(labelhash);
        
        console.log("");
        console.log("Current:");
        console.log("  Owner:", currentOwner);
        console.log("  Resolver:", currentResolver);
        console.log("");
        
        // Verify caller is the owner
        if (currentOwner != deployerAddress) {
            console.log("ERROR: Caller is not the owner!");
            revert("Not owner");
        }
        
        // Generate or use provided secret
        bytes32 secret;
        try vm.envBytes32("UPDATE_SECRET") returns (bytes32 envSecret) {
            secret = envSecret;
            console.log("Using UPDATE_SECRET from environment");
        } catch {
            secret = keccak256(abi.encodePacked("update-resolver-", block.timestamp, deployerAddress));
            console.log("Generated new UPDATE_SECRET");
        }
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Create and submit commitment
        bytes32 commitment = registry.createCommitment(labelhash, currentOwner, newResolverAddress, secret);
        
        uint256 existingCommitment = registry.commitments(commitment);
        if (existingCommitment != 0) {
            console.log("");
            console.log("ERROR: This commitment already exists!");
            console.log("Committed at:", existingCommitment);
            vm.stopBroadcast();
            return;
        }
        
        registry.commit(commitment);
        
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
        console.log("  UPDATE_SECRET=", vm.toString(secret));
        console.log("");
        console.log("=======================================================");
        console.log("NEXT STEPS:");
        console.log("=======================================================");
        console.log("1. WAIT AT LEAST 60 SECONDS");
        console.log("");
        console.log("2. Run:");
        console.log("   export UPDATE_SECRET=", vm.toString(secret));
        console.log("   forge script script/UpdateResolverAddress.s.sol \\");
        console.log("     --rpc-url $SEPOLIA_RPC_URL \\");
        console.log("     --broadcast -vv");
        console.log("=======================================================");
    }
}

