// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/ECSRegistry.sol";

/**
 * @title UpdateResolverAddress - Step 2 of 2
 * @notice Updates the resolver for controlled-accounts.ecs.eth after commitment
 * 
 * USAGE:
 *   forge script script/UpdateResolverAddress.s.sol:UpdateResolverAddress \
 *     --rpc-url $SEPOLIA_RPC_URL \
 *     --broadcast \
 *     -vv
 * 
 * REQUIRED ENV VARS:
 *   - DEPLOYER_PRIVATE_KEY (must be the owner)
 *   - ECS_REGISTRY_ADDRESS
 *   - NEW_CC_RESOLVER_ADDRESS
 *   - UPDATE_SECRET (from Step 1)
 */
contract UpdateResolverAddress is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address registryAddress = vm.envAddress("ECS_REGISTRY_ADDRESS");
        address newResolverAddress = vm.envAddress("NEW_CC_RESOLVER_ADDRESS");
        bytes32 secret = vm.envBytes32("UPDATE_SECRET");
        
        string memory label = "controlled-accounts";
        bytes32 labelhash = keccak256(bytes(label));
        address deployerAddress = vm.addr(deployerPrivateKey);
        
        ECSRegistry registry = ECSRegistry(registryAddress);
        
        console.log("=======================================================");
        console.log("STEP 2: UPDATE Resolver Address");
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
        
        // Verify commitment exists
        bytes32 commitment = registry.createCommitment(labelhash, currentOwner, newResolverAddress, secret);
        uint256 commitmentTimestamp = registry.commitments(commitment);
        
        console.log("Verifying commitment...");
        console.log("  Hash:", vm.toString(commitment));
        
        if (commitmentTimestamp == 0) {
            console.log("");
            console.log("ERROR: Commitment not found!");
            console.log("Run CommitResolverUpdate.s.sol first");
            revert("Commitment not found");
        }
        
        console.log("  [OK] Found at:", commitmentTimestamp);
        
        // Check if enough time has passed
        uint256 timeElapsed = block.timestamp - commitmentTimestamp;
        console.log("  Time elapsed:", timeElapsed, "seconds");
        
        if (timeElapsed < 60) {
            console.log("");
            console.log("ERROR: Not enough time has passed!");
            console.log("Please wait", 60 - timeElapsed, "more seconds");
            revert("Commitment too new");
        }
        
        console.log("  [OK] Commitment period satisfied");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Update resolver
        console.log("");
        console.log("Updating resolver...");
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
        console.log("Query resolver-info:");
        console.log("  cast call", updatedResolver, "\\");
        console.log("    \"text(bytes32,string)(string)\" \\");
        console.log("    0x0000000000000000000000000000000000000000000000000000000000000000 \\");
        console.log("    \"resolver-info\" \\");
        console.log("    --rpc-url $SEPOLIA_RPC_URL");
        console.log("=======================================================");
    }
}

