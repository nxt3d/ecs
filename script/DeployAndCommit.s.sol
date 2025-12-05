// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/ECSRegistry.sol";
import "../src/ECSRegistrar.sol";
import "../src/CredentialResolver.sol";
import "../src/ENS.sol";
import "../src/utils/NameCoder.sol";

contract DeployAndCommit is Script {
    // Standard ENS Registry address (same on Mainnet, Sepolia, Goerli)
    address constant ENS_REGISTRY = 0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        
        // Compute deployer address from private key
        address deployerAddress = vm.addr(deployerPrivateKey);
        console.log("Deployer address:", deployerAddress);
        
        // Optional: Allow overriding ROOT_NAME, default to "ecs.eth"
        string memory rootName = vm.envOr("ROOT_NAME", string("ecs.eth"));
        
        // Compute namehash for rootName using NameCoder
        bytes memory dnsName = NameCoder.encode(rootName);
        bytes32 rootNode = NameCoder.namehash(dnsName, 0);
        
        address ensAddress = ENS_REGISTRY;

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy ECSRegistry
        ECSRegistry registry = new ECSRegistry(ENS(ensAddress), rootNode);
        console.log("ECSRegistry deployed at:", address(registry));

        // 2. Deploy ECSRegistrar
        ECSRegistrar registrar = new ECSRegistrar(registry);
        console.log("ECSRegistrar deployed at:", address(registrar));

        // 3. Grant REGISTRAR_ROLE to ECSRegistrar
        registry.grantRole(registry.REGISTRAR_ROLE(), address(registrar));
        console.log("Granted REGISTRAR_ROLE to ECSRegistrar");
        
        // 4. Initialize Registrar Params (Default values)
        // minDuration: 60s, maxDuration: type(uint64).max, minLength: 3, maxLength: 64
        registrar.setParams(60, type(uint64).max, 3, 64);
        
        // Set pricing (approximately 0.001 ETH per year)
        uint256[] memory prices = new uint256[](1);
        prices[0] = 32000; // wei per second (~0.001 ETH/year)
        registrar.setPricingForAllLengths(prices);
        console.log("Set registrar pricing: ~0.001 ETH/year");
        
        // 5. Deploy CredentialResolver with explicit deployer address
        CredentialResolver credentialResolver = new CredentialResolver(deployerAddress);
        console.log("CredentialResolver deployed at:", address(credentialResolver));
        console.log("CredentialResolver owner:", deployerAddress);

        // 6. Commit registration for 'name-stars'
        string memory subnameLabel = "name-stars";
        uint256 duration = 365 days;
        bytes32 secret = keccak256(abi.encodePacked("test-secret-", block.timestamp));
        
        // Create and submit commitment
        bytes32 commitment = registrar.createCommitment(
            subnameLabel,
            msg.sender,
            address(credentialResolver),
            duration,
            secret
        );
        registrar.commit(commitment);
        console.log("Committed registration for:", subnameLabel);
        
        vm.stopBroadcast();
        
        console.log("--------------------------------------------------");
        console.log("Deployment Complete - Step 1 of 2");
        console.log("--------------------------------------------------");
        console.log("Network:", block.chainid);
        console.log("Root Name:", rootName);
        console.log("Root Node:", vm.toString(rootNode));
        console.log("ECS Registry:", address(registry));
        console.log("ECS Registrar:", address(registrar));
        console.log("Credential Resolver:", address(credentialResolver));
        console.log("--------------------------------------------------");
        console.log("Commitment Details:");
        console.log("  Label:", subnameLabel);
        console.log("  Duration:", duration);
        console.log("  Secret (for next step):", vm.toString(secret));
        console.log("  Commitment Hash:", vm.toString(commitment));
        console.log("--------------------------------------------------");
        console.log("NEXT STEPS:");
        console.log("1. WAIT AT LEAST 60 SECONDS");
        console.log("2. Run RegisterAndSetup.s.sol with the same SECRET");
        console.log("3. Update the Manager of ENS name '%s' to the new ECSRegistry:", rootName);
        console.log("   Manager Address: %s", address(registry));
        console.log("   (Use ENS app at app.ens.domains)");
        console.log("--------------------------------------------------");
    }
}

