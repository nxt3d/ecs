// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/ECSRegistry.sol";
import "../src/ECSRegistrarController.sol";
import "../src/ECSAddressResolver.sol";
import "../src/ECSNameResolver.sol";
import "../src/RootController.sol";
import "../src/credentials/ethstars/OffchainStarAddr.sol";
import "../src/credentials/ethstars/OffchainStarName.sol";
import {IGatewayVerifier} from "../lib/unruggable-gateways/contracts/IGatewayVerifier.sol";

import "../src/utils/NameCoder.sol";

/**
 * @title DeployECS
 * @dev Updated deployment script for ECS system with unified architecture
 * 
 * Usage: 
 * forge script source .env && forge script script/DeployECS.s.sol:DeployECS --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEYscript/DeployECS.s.sol:DeployECS --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
 */
contract DeployECS is Script {
    
    /* --- Deployed Contracts --- */
    
    ECSRegistry public registry;
    ECSRegistrarController public controller;
    ECSAddressResolver public addressResolver;
    ECSNameResolver public nameResolver;
    RootController public rootController;
    OffchainStarAddr public starResolver;
    OffchainStarName public starNameResolver;
    
    /* --- Configuration --- */
    
    // Configurable ECS domain (can be "ecs", "test3", etc.)
    string public ECS_DOMAIN;
    
    // Node hashes for deployment
    bytes32 constant ROOT_NODE = bytes32(0);
    
    // Registration duration for testing (1 year)
    uint256 constant REGISTRATION_DURATION = 365 days;
    
    // Gateway configuration for offchain resolvers
    // These should be configured based on the target network
    address constant GATEWAY_VERIFIER = 0x8e77b311bed6906799BD3CaFBa34c13b64CAF460; // Base Sepolia verifier
    address constant BASE_ADDR_TARGET = 0x4dbccAF1dc6c878EBe3CE8041886dDb36D339cA7;  // StarResolver on Base Sepolia
    address constant BASE_NAME_TARGET = 0x69f3E82bA7c4B640a3b2c0FD5eA67cDA86bE8F88;  // StarNameResolver on Base Sepolia
    
    /* --- Deployment Function --- */
    
    function run() external {
        // Set ECS domain from environment variable or use default
        try vm.envString("ECS_DOMAIN") returns (string memory envDomain) {
            ECS_DOMAIN = envDomain;
        } catch {
            ECS_DOMAIN = "ecs"; // Default
        }
        
        vm.startBroadcast();
        
        // Get deployer address from msg.sender after broadcast starts
        address deployer = msg.sender;
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);
        console.log("ECS Domain:", ECS_DOMAIN);
        
        console.log("\n=== DEPLOYING ECS UNIFIED ARCHITECTURE ===\n");
        
        // Step 1: Deploy core registry
        console.log("1. Deploying ECSRegistry...");
        registry = new ECSRegistry();
        console.log("   ECSRegistry deployed at:", address(registry));
        
        // Step 2: Deploy root controller and set up permissions
        console.log("\n2. Deploying RootController...");
        rootController = new RootController(registry);
        console.log("   RootController deployed at:", address(rootController));
        
        console.log("   Setting up root node permissions...");
        registry.setApprovalForNamespace(ROOT_NODE, address(rootController), true);
        
        // Step 3: Set up .eth TLD and subdomain
        console.log("\n3. Setting up domain structure...");
        bytes32 ethNode = NameCoder.namehash(NameCoder.encode("eth"), 0);
        console.log("   Creating .eth TLD...");
        rootController.setSubnameOwner(string("eth"), deployer);
        
        bytes32 ecsNode = NameCoder.namehash(NameCoder.encode(string.concat(ECS_DOMAIN, ".eth")), 0);
        console.log("   Creating", string.concat(ECS_DOMAIN, ".eth"), "subdomain...");
        registry.setSubnameOwner(
            ECS_DOMAIN,
            "eth",
            deployer,
            type(uint256).max, // Set to far future (never expire)
            false
        );
        
        // Step 4: Deploy controller with base domain
        console.log("\n4. Deploying ECSRegistrarController...");
        string memory baseDomain = string.concat(ECS_DOMAIN, ".eth");
        controller = new ECSRegistrarController(registry, baseDomain);
        console.log("   ECSRegistrarController deployed at:", address(controller));
        
        // Grant controller role to controller
        console.log("   Granting controller role to ECSRegistrarController...");
        registry.grantRole(registry.CONTROLLER_ROLE(), address(controller));
        
        // Grant approval for controller to create subnamespaces under ecs.eth
        console.log("   Granting approval for controller to create subnamespaces...");
        registry.setApprovalForNamespace(ecsNode, address(controller), true);
        
        // Step 5: Deploy resolvers
        console.log("\n5. Deploying resolvers...");
        addressResolver = new ECSAddressResolver(registry);
        console.log("   ECSAddressResolver deployed at:", address(addressResolver));
        
        nameResolver = new ECSNameResolver(registry);
        console.log("   ECSNameResolver deployed at:", address(nameResolver));
        
        // Step 6: Deploy offchain star credential resolvers
        console.log("\n6. Deploying offchain star credential resolvers...");
        starResolver = new OffchainStarAddr(IGatewayVerifier(GATEWAY_VERIFIER), BASE_ADDR_TARGET);
        console.log("   OffchainStarAddr deployed at:", address(starResolver));
        console.log("   -> Points to StarResolver on Base:", BASE_ADDR_TARGET);
        
        starNameResolver = new OffchainStarName(IGatewayVerifier(GATEWAY_VERIFIER), BASE_NAME_TARGET);
        console.log("   OffchainStarName deployed at:", address(starNameResolver));
        console.log("   -> Points to StarNameResolver on Base:", BASE_NAME_TARGET);
        
        // Step 7: Register ethstars namespace
        console.log("\n7. Registering ethstars namespace...");
        uint256 registrationCost = controller.calculateFee(REGISTRATION_DURATION);
        console.log("   Registration cost:", registrationCost);
        bytes32 ethstarsNamespace = controller.registerNamespace{value: registrationCost}("ethstars", REGISTRATION_DURATION);
        console.log("   Namespace 'ethstars' registered for 1 year");
        console.log("   Ethstars namespace hash:", vm.toString(ethstarsNamespace));
        
        // Step 8: Set up credential resolvers
        console.log("\n8. Setting up credential resolvers...");
        
        // First create the stars.ethstars.ecs.eth namespace
        console.log("   Creating stars.ethstars.ecs.eth namespace...");
        bytes32 starsCredentialNamespace = registry.setSubnameOwner(
            "stars", 
            "ethstars.ecs.eth", 
            msg.sender, 
            type(uint256).max, 
            false
        );
        console.log("   Stars credential namespace created:", vm.toString(starsCredentialNamespace));
        
        addressResolver.setCredentialResolver("stars.ethstars.ecs.eth", address(starResolver));
        console.log("   StarResolver set in ECSAddressResolver for stars.ethstars.ecs.eth");
        
        nameResolver.setCredentialResolver("stars.ethstars.ecs.eth", address(starNameResolver));
        console.log("   StarNameResolver set in ECSNameResolver for stars.ethstars.ecs.eth");
        
        // Step 9: Note about offchain resolution
        console.log("\n9. Offchain resolution configured...");
        console.log("   Resolvers will fetch data from Base Sepolia via gateway verifier");
        console.log("   Gateway verifier:", GATEWAY_VERIFIER);
        
        vm.stopBroadcast();
        
        // Step 10: Print deployment summary
        _printDeploymentSummary(deployer, ethNode, ecsNode, ethstarsNamespace);
        
        console.log("\n=== DEPLOYMENT COMPLETE ===\n");
    }
    
    /* --- Helper Functions --- */
    
    function _printDeploymentSummary(address deployer, bytes32 ethNode, bytes32 ecsNode, bytes32 ethstarsNamespace) internal view {
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Network: Ethereum Sepolia");
        console.log("Deployer:", deployer);
        console.log("Base Domain:", string.concat(ECS_DOMAIN, ".eth"));
        console.log("\nCore Contracts:");
        console.log("  - ECSRegistry:", address(registry));
        console.log("  - RootController:", address(rootController));
        console.log("  - ECSRegistrarController:", address(controller));
        
        console.log("\nResolvers:");
        console.log("  - ECSAddressResolver:", address(addressResolver));
        console.log("  - ECSNameResolver:", address(nameResolver));
        
        console.log("\nOffchain Star Credential Resolvers:");
        console.log("  - OffchainStarAddr (address-based):", address(starResolver));
        console.log("  - OffchainStarName (name-based):", address(starNameResolver));
        
        console.log("\nDomain Structure:");
        console.log("  - Root node (0x0000...): owned by RootController");
        console.log("  - .eth node:", vm.toString(ethNode), "owned by deployer");
        console.log(string.concat("  - ", ECS_DOMAIN, ".eth node:"), vm.toString(ecsNode), "owned by deployer");
        
        console.log("\nNamespace Setup:");
        console.log("  - ethstars namespace:", vm.toString(ethstarsNamespace), "registered for 1 year");
        console.log("  - OffchainStarAddr set in ECSAddressResolver for ethstars");
        console.log("  - OffchainStarName set in ECSNameResolver for ethstars");
        
        string memory textRecordKey = string.concat("eth.", ECS_DOMAIN, ".ethstars.stars");
        console.log("\nReady to Use:");
        console.log("1. Query address stars via offchain resolution: OffchainStarAddr.resolve()");
        console.log("2. Query domain stars via offchain resolution: OffchainStarName.resolve()");
        console.log(string.concat("3. Query stars via ENS: resolver.text(node, '", textRecordKey, "')"));
        console.log("4. Data is fetched from Base Sepolia L2 via gateway verifier");
        
        console.log("\nContract Verification:");
        console.log("All contracts deployed with verification enabled.");
        console.log("Check Etherscan for verification status.");
    }
} 