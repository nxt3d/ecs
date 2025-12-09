// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/ECSRegistry.sol";

/**
 * @title UpdateCCResolver
 * @notice Updates the resolver for controlled-accounts.ecs.eth
 * 
 * USAGE:
 *   forge script script/UpdateCCResolver.s.sol:UpdateCCResolver \
 *     --rpc-url $SEPOLIA_RPC_URL \
 *     --broadcast \
 *     -vv
 * 
 * REQUIRED ENV VARS:
 *   - DEPLOYER_PRIVATE_KEY (must be the owner of controlled-accounts.ecs.eth)
 *   - ECS_REGISTRY_ADDRESS
 *   - NEW_CC_RESOLVER_ADDRESS (the new CCResolver v0.1.0 address)
 * 
 * WHAT IT DOES:
 *   Updates the resolver address for controlled-accounts.ecs.eth
 *   to point to the new CCResolver v0.1.0 deployment
 */
contract UpdateCCResolver is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address registryAddress = vm.envAddress("ECS_REGISTRY_ADDRESS");
        address newResolverAddress = vm.envAddress("NEW_CC_RESOLVER_ADDRESS");
        
        string memory label = "controlled-accounts";
        bytes32 labelhash = keccak256(bytes(label));
        
        ECSRegistry registry = ECSRegistry(registryAddress);
        
        console.log("=======================================================");
        console.log("UPDATING: controlled-accounts.ecs.eth");
        console.log("=======================================================");
        console.log("ECS Registry:", registryAddress);
        console.log("Label:", label);
        console.log("Labelhash:", vm.toString(labelhash));
        console.log("New Resolver:", newResolverAddress);
        console.log("=======================================================");
        
        // Check current registration
        address currentOwner = registry.owner(labelhash);
        address currentResolver = registry.resolver(labelhash);
        uint256 expiration = registry.getExpiration(labelhash);
        
        console.log("");
        console.log("Current Registration:");
        console.log("  Owner:", currentOwner);
        console.log("  Current Resolver:", currentResolver);
        console.log("  Expires:", expiration);
        console.log("");
        
        // Verify caller is the owner
        address callerAddress = vm.addr(deployerPrivateKey);
        if (currentOwner != callerAddress) {
            console.log("ERROR: Caller is not the owner!");
            console.log("  Owner:", currentOwner);
            console.log("  Caller:", callerAddress);
            revert("Not owner");
        }
        
        console.log("Caller verified as owner:", callerAddress);
        
        // Generate or use provided secret
        bytes32 secret;
        try vm.envBytes32("UPDATE_SECRET") returns (bytes32 envSecret) {
            secret = envSecret;
            console.log("Using UPDATE_SECRET from environment");
        } catch {
            secret = keccak256(abi.encodePacked("update-resolver-", block.timestamp, callerAddress));
            console.log("Generated new UPDATE_SECRET");
        }
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Create and submit commitment
        bytes32 commitment = registry.createCommitment(labelhash, currentOwner, newResolverAddress, secret);
        
        uint256 existingCommitment = registry.commitments(commitment);
        if (existingCommitment == 0) {
            console.log("");
            console.log("Step 1: Creating commitment...");
            registry.commit(commitment);
            console.log("  [OK] Commitment submitted");
            console.log("  Hash:", vm.toString(commitment));
            console.log("  Secret:", vm.toString(secret));
            console.log("");
            console.log("Waiting for commitment period (60 seconds)...");
            
            // Wait for minimum commitment age
            vm.warp(block.timestamp + 61);
            console.log("  [OK] Commitment period complete");
        } else {
            console.log("Commitment already exists, verifying time has passed...");
            if (block.timestamp < existingCommitment + 60) {
                uint256 timeToWait = (existingCommitment + 61) - block.timestamp;
                console.log("Waiting", timeToWait, "more seconds...");
                vm.warp(block.timestamp + timeToWait);
            }
            console.log("  [OK] Commitment period satisfied");
        }
        
        // Step 2: Update resolver
        console.log("");
        console.log("Step 2: Updating resolver...");
        registry.setResolver(labelhash, newResolverAddress, secret);
        console.log("  [OK] Resolver updated!");
        
        vm.stopBroadcast();
        
        // Verify update
        address updatedResolver = registry.resolver(labelhash);
        
        console.log("");
        console.log("=======================================================");
        console.log("SUCCESS! Resolver Updated");
        console.log("=======================================================");
        console.log("Name: controlled-accounts.ecs.eth");
        console.log("Owner:", currentOwner);
        console.log("Old Resolver:", currentResolver);
        console.log("New Resolver:", updatedResolver);
        console.log("=======================================================");
        console.log("");
        console.log("The name now points to CCResolver v0.1.0");
        console.log("Query resolver-info:");
        console.log("  cast call", newResolverAddress, "\\");
        console.log("    \"text(bytes32,string)(string)\" \\");
        console.log("    0x0000000000000000000000000000000000000000000000000000000000000000 \\");
        console.log("    \"resolver-info\" \\");
        console.log("    --rpc-url $SEPOLIA_RPC_URL");
        console.log("=======================================================");
    }
}

