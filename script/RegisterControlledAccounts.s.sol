// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/ECSRegistry.sol";
import "../src/ECSRegistrar.sol";

/**
 * @title RegisterControlledAccounts - Step 2 of 2
 * @notice Registers "controlled-accounts.ecs.eth" after commitment period
 * 
 * USAGE:
 *   forge script script/RegisterControlledAccounts.s.sol:RegisterControlledAccounts \
 *     --rpc-url $SEPOLIA_RPC_URL \
 *     --broadcast \
 *     -vv
 * 
 * REQUIRED ENV VARS:
 *   - DEPLOYER_PRIVATE_KEY
 *   - ECS_REGISTRY_ADDRESS
 *   - ECS_REGISTRAR_ADDRESS
 *   - REGISTRATION_SECRET (from Step 1)
 * 
 * OPTIONAL ENV VARS:
 *   - CC_RESOLVER_ADDRESS (default: 0xCE943F957FC46a8d048505E6949e32201a128f84)
 * 
 * PREREQUISITES:
 *   1. Must have run CommitControlledAccounts.s.sol (Step 1)
 *   2. Must wait at least 60 seconds after commitment
 *   3. Must use the same REGISTRATION_SECRET from Step 1
 * 
 * WHAT IT DOES:
 *   1. Verifies the commitment exists and enough time has passed
 *   2. Registers controlled-accounts.ecs.eth with CCResolver
 *   3. Verifies the registration
 * 
 * AFTER RUNNING:
 *   Test with: npm run test-cc
 */
contract RegisterControlledAccounts is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address ccResolverAddress = vm.envAddress("CC_RESOLVER_ADDRESS");
        bytes32 secret = vm.envBytes32("REGISTRATION_SECRET");
        string memory label = "controlled-accounts";
        uint256 duration = 365 days * 10;
        
        ECSRegistry registry = ECSRegistry(vm.envAddress("ECS_REGISTRY_ADDRESS"));
        ECSRegistrar registrar = ECSRegistrar(vm.envAddress("ECS_REGISTRAR_ADDRESS"));
        
        _printHeader(address(registry), address(registrar), ccResolverAddress, duration);
        _verifyCommitment(registrar, label, deployerPrivateKey, ccResolverAddress, duration, secret);
        
        address deployerAddress = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);
        _executeRegistration(registrar, label, deployerAddress, ccResolverAddress, duration, secret);
        vm.stopBroadcast();
        
        _printSuccess(registry, label);
    }
    
    function _printHeader(address registry, address registrar, address resolver, uint256 duration) internal view {
        console.log("=======================================================");
        console.log("STEP 2: REGISTER controlled-accounts.ecs.eth");
        console.log("=======================================================");
        console.log("This completes the registration after the 60-second");
        console.log("commitment period from Step 1.");
        console.log("");
        console.log("Configuration:");
        console.log("  ECS Registry:", registry);
        console.log("  ECS Registrar:", registrar);
        console.log("  CCResolver:", resolver);
        console.log("  Duration:", duration / 365 days, "years");
        console.log("=======================================================");
    }
    
    function _verifyCommitment(
        ECSRegistrar registrar,
        string memory label,
        uint256 privateKey,
        address resolver,
        uint256 duration,
        bytes32 secret
    ) internal view {
        bytes32 commitment = registrar.createCommitment(
            label,
            vm.addr(privateKey),
            resolver,
            duration,
            secret
        );
        
        uint256 commitmentTimestamp = registrar.commitments(commitment);
        console.log("");
        console.log("Verifying commitment...");
        
        if (commitmentTimestamp == 0) {
            console.log("ERROR: Commitment not found!");
            revert("Commitment not found");
        }
        
        console.log("  [OK] Commitment found at:", commitmentTimestamp);
        
        uint256 timeElapsed = block.timestamp - commitmentTimestamp;
        console.log("  Time elapsed:", timeElapsed, "seconds");
        
        if (timeElapsed < registrar.MIN_COMMITMENT_AGE()) {
            console.log("ERROR: Not enough time has passed!");
            revert("Commitment too new");
        }
        
        console.log("  [OK] Commitment period satisfied");
    }
    
    function _executeRegistration(
        ECSRegistrar registrar,
        string memory label,
        address owner,
        address resolver,
        uint256 duration,
        bytes32 secret
    ) internal {
        uint256 price = registrar.rentPrice(label, duration);
        console.log("");
        console.log("Registering controlled-accounts.ecs.eth...");
        console.log("  Cost:", price, "wei");
        
        registrar.register{value: price}(label, owner, resolver, duration, secret);
        console.log("  [OK] Registration complete!");
    }
    
    function _printSuccess(ECSRegistry registry, string memory label) internal view {
        bytes32 labelhash = keccak256(bytes(label));
        
        console.log("");
        console.log("=======================================================");
        console.log("SUCCESS! Registration Complete");
        console.log("=======================================================");
        console.log("Name: controlled-accounts.ecs.eth");
        console.log("Owner:", registry.owner(labelhash));
        console.log("Resolver:", registry.resolver(labelhash));
        console.log("Expires:", registry.getExpiration(labelhash));
        console.log("=======================================================");
        console.log("");
        console.log("Test with: npm run test-cc");
        console.log("Query key: eth.ecs.controlled-accounts:<id>");
        console.log("=======================================================");
    }
}
