// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/ECSRegistry.sol";
import "../src/ECSRegistrar.sol";
import "../src/CredentialResolver.sol";
import "../src/ENS.sol";
import "../src/utils/NameCoder.sol";

contract RegisterAndSetup is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        
        // Load deployer address from env (should match the CredentialResolver owner)
        address deployerAddress = vm.envAddress("PUBLIC_DEPLOYER_ADDRESS");
        
        // Load deployed contract addresses from environment
        address registryAddress = vm.envAddress("ECS_REGISTRY_ADDRESS");
        address registrarAddress = vm.envAddress("ECS_REGISTRAR_ADDRESS");
        address credentialResolverAddress = vm.envAddress("CREDENTIAL_RESOLVER_ADDRESS");
        
        // Load root node
        bytes32 rootNode = vm.envBytes32("ROOT_NODE");
        
        // Registration parameters (must match DeployAndCommit)
        string memory subnameLabel = "name-stars";
        uint256 duration = 365 days;
        bytes32 secret = vm.envBytes32("REGISTRATION_SECRET");
        
        // Connect to deployed contracts
        ECSRegistry registry = ECSRegistry(registryAddress);
        ECSRegistrar registrar = ECSRegistrar(registrarAddress);
        CredentialResolver credentialResolver = CredentialResolver(credentialResolverAddress);
        
        // Verify CredentialResolver owner matches deployer
        address resolverOwner = credentialResolver.owner();
        console.log("--------------------------------------------------");
        console.log("Loaded from environment variables:");
        console.log("ECS Registry:", registryAddress);
        console.log("ECS Registrar:", registrarAddress);
        console.log("Credential Resolver:", credentialResolverAddress);
        console.log("Deployer Address (from env):", deployerAddress);
        console.log("CredentialResolver Owner:", resolverOwner);
        console.log("Root Node:", vm.toString(rootNode));
        console.log("Registration Secret:", vm.toString(secret));
        console.log("--------------------------------------------------");
        
        if (resolverOwner != deployerAddress) {
            console.log("WARNING: CredentialResolver owner does not match deployer address!");
            console.log("Will use vm.startPrank to impersonate the owner");
        }

        vm.startBroadcast(deployerPrivateKey);
        
        // If owner doesn't match, we need to use prank for setting records
        // But first, complete the registration which should work with the private key
        
        // 1. Register the name (paying the fee)
        uint256 price = registrar.rentPrice(subnameLabel, duration);
        console.log("Registering '%s' for %s days. Cost: %s wei", subnameLabel, duration / 1 days, price);
        
        registrar.register{value: price}(
            subnameLabel,
            msg.sender,
            address(credentialResolver),
            duration,
            secret
        );
        console.log("Successfully registered 'name-stars.ecs.eth'");

        // 2. Set Records on CredentialResolver
        // CredentialResolver is a single-label resolver (no labelhash parameter needed)
        string memory recordKey = "eth.ecs.name-stars.starts:vitalik.eth";
        string memory textValue = "100";
        bytes memory dataValue = abi.encode(uint256(100));
        
        // The contract owner can set records
        console.log("Setting records as msg.sender (should be owner):", msg.sender);
        credentialResolver.setText(recordKey, textValue);
        credentialResolver.setData(recordKey, dataValue);
        
        console.log("--------------------------------------------------");
        console.log("Set credential records:");
        console.log("  Key:", recordKey);
        console.log("  Text Value:", textValue);
        console.log("  Data Value (uint256): 100");
        
        vm.stopBroadcast();
        
        console.log("--------------------------------------------------");
        console.log("Registration and Setup Complete!");
        console.log("--------------------------------------------------");
        console.log("Registry:", address(registry));
        console.log("Registrar:", address(registrar));
        console.log("Credential Resolver:", address(credentialResolver));
        console.log("Registered: name-stars.ecs.eth");
        console.log("--------------------------------------------------");
    }
}

