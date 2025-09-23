// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/credentials/controlled-accounts/OffchainCCAddr.sol";
import "../src/ECSRegistry.sol";
import "../src/ECSRegistrarController.sol";
import "../src/ECSAddressResolver.sol";
import "../src/utils/NameCoder.sol";
import {IGatewayVerifier} from "../lib/unruggable-gateways/contracts/IGatewayVerifier.sol";

/**
 * @title DeployOffchainCCAddr
 * @dev Deploy the OffchainCCAddr credential resolver for cross-chain controlled accounts
 * 
 * This script deploys the OffchainCCAddr contract which provides offchain resolution
 * for cross-chain controlled accounts using gateway fetching. The contract can be
 * configured with different program bytes to customize the gateway execution logic.
 * 
 * The script also registers the controlled-accounts.ecs.eth and accounts.controlled-accounts.ecs.eth
 * namespaces with the ECS system and sets up the credential resolver to enable ENS-based 
 * resolution of controlled accounts.
 * 
 * Usage:
 * forge script script/DeployOffchainCCAddr.s.sol:DeployOffchainCCAddr --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
 */
contract DeployOffchainCCAddr is Script {
    
    /* --- State Variables --- */
    
    OffchainCCAddr public offchainCCAddr;
    
    /* --- Environment Variables --- */
    
    // Deployment addresses
    address public deployer;
    
    // Gateway configuration
    address public GATEWAY_VERIFIER;
    address public TARGET_L2_ADDRESS;
    
    // ECS system addresses (from deployment-report-2025-08-25-02.md)
    address constant ECS_REGISTRY = 0x360728b13Dfc832333beF3E4171dd42BdfCedC92;
    address constant ECS_REGISTRAR_CONTROLLER = 0xd351637f9544A51979BFD0ae4D809C56b6acDe9F;
    address constant ECS_ADDRESS_RESOLVER = 0x2FFdF34Ed40171ccE860020Ea37c9F1854e0995e;
    
    // Default addresses for Ethereum Sepolia
    address constant DEFAULT_GATEWAY_VERIFIER = 0x8e77b311bed6906799BD3CaFBa34c13b64CAF460;
    address constant DEFAULT_TARGET_L2_ADDRESS = 0x558a0235FEdEAB967b56da2d35c23A142A449303; // ControlledAccountsCrosschain on Base Sepolia
    
    /* --- Setup --- */
    
    function setUp() public {
        deployer = vm.envAddress("PUBLIC_DEPLOYER_ADDRESS");
        
        // Set gateway configuration from environment variables or use defaults
        _setGatewayConfiguration();
    }
    
    /* --- Main Deployment --- */
    
    function run() public {
        vm.startBroadcast(deployer);
        
        console.log("[DEPLOY] Deploying OffchainCCAddr Credential Resolver");
        console.log("=====================================================");
        console.log("");
        
        // Step 1: Deploy OffchainCCAddr contract
        console.log("Step 1: Deploying OffchainCCAddr contract...");
        offchainCCAddr = new OffchainCCAddr(IGatewayVerifier(GATEWAY_VERIFIER), TARGET_L2_ADDRESS);
        console.log("[SUCCESS] OffchainCCAddr deployed at:", address(offchainCCAddr));
        console.log("");
        
        // Step 2: Set up initial program bytes (optional)
        console.log("Step 2: Setting up initial program bytes...");
        _setupInitialProgram();
        console.log("");
        
        // Step 3: Register credentials with ECS system
        console.log("Step 3: Registering credentials with ECS system...");
        _registerCredentialsWithECS();
        console.log("");
        
        // Step 4: Print deployment summary
        console.log("Step 4: Deployment Summary");
        _printDeploymentSummary();
        
        vm.stopBroadcast();
    }
    
    /* --- Gateway Configuration --- */
    
    function _setGatewayConfiguration() internal {
        // Set gateway verifier
        try vm.envAddress("GATEWAY_VERIFIER") returns (address envVerifier) {
            GATEWAY_VERIFIER = envVerifier;
        } catch {
            GATEWAY_VERIFIER = DEFAULT_GATEWAY_VERIFIER;
        }
        
        // Set target L2 address
        try vm.envAddress("TARGET_L2_ADDRESS") returns (address envTarget) {
            TARGET_L2_ADDRESS = envTarget;
        } catch {
            TARGET_L2_ADDRESS = DEFAULT_TARGET_L2_ADDRESS;
        }
        
        console.log("Gateway Configuration:");
        console.log("  - Gateway Verifier:", GATEWAY_VERIFIER);
        console.log("  - Target L2 Address:", TARGET_L2_ADDRESS);
    }
    
    /* --- Program Setup --- */
    
    function _setupInitialProgram() internal {
        // Set up initial program bytes if needed
        // This is a placeholder - in practice, you would set up the actual program bytes
        // that define the gateway execution logic for cross-chain controlled accounts
        
        if (TARGET_L2_ADDRESS != address(0)) {
            console.log("Setting up initial program bytes for cross-chain controlled accounts...");
            
            // Example: Set up a basic program that handles cross-chain controlled accounts
            // In practice, this would be the actual program bytes for your specific use case
            bytes memory initialProgram = _createInitialProgram();
            
            if (initialProgram.length > 0) {
                // Set program for Base Sepolia coin type (0x80000000 | 84532 = 2147568180)
                uint256 baseSepoliaCoinType = 2147568180;
                offchainCCAddr.updateProgram(baseSepoliaCoinType, initialProgram);
                console.log("[SUCCESS] Initial program bytes set for Base Sepolia");
                console.log("  Coin Type:", baseSepoliaCoinType);
                console.log("  Program length:", initialProgram.length, "bytes");
            } else {
                console.log("[INFO] No initial program set - can be updated later via updateProgram()");
            }
        } else {
            console.log("[INFO] No target L2 address configured - program setup skipped");
            console.log("[INFO] Set TARGET_L2_ADDRESS environment variable to enable program setup");
        }
    }
    
    /**
     * @dev Create initial program bytes for cross-chain controlled accounts
     * @return program The initial program bytes
     * @notice This is a placeholder implementation - replace with actual program logic
     */
    function _createInitialProgram() internal pure returns (bytes memory program) {
        // This is a placeholder - in practice, you would create the actual program bytes
        // that define how to fetch cross-chain controlled accounts data
        
        // For now, return empty bytes to indicate no initial program
        // The program can be set later via updateProgram() function
        return new bytes(0);
    }
    
    /* --- ECS Credential Registration --- */
    
    /**
     * @dev Register the controlled-accounts credentials with the ECS system
     * This enables ECS resolution of controlled accounts via ENS names
     */
    function _registerCredentialsWithECS() internal {
        console.log("Registering controlled-accounts credentials with ECS system...");
        
        // Create ECS registry, controller, and resolver instances
        ECSRegistry registry = ECSRegistry(ECS_REGISTRY);
        ECSRegistrarController controller = ECSRegistrarController(ECS_REGISTRAR_CONTROLLER);
        ECSAddressResolver addressResolver = ECSAddressResolver(ECS_ADDRESS_RESOLVER);
        
        // Step 1: Register controlled-accounts.ecs.eth namespace if it doesn't exist
        console.log("   Step 1: Checking controlled-accounts.ecs.eth namespace...");
        bytes32 controlledAccountsNamespace = NameCoder.namehash(NameCoder.encode("controlled-accounts.ecs.eth"), 0);
        
        if (registry.owner(controlledAccountsNamespace) == address(0)) {
            console.log("   [INFO] controlled-accounts.ecs.eth namespace does not exist, registering it...");
            
            // Calculate registration fee (1 year duration)
            uint256 registrationDuration = 365 days;
            uint256 registrationFee = controller.calculateFee(registrationDuration);
            console.log("   [INFO] Registration fee:", registrationFee, "wei");
            
            // Register the controlled-accounts namespace using the controller
            bytes32 registeredNamespace = controller.registerNamespace{value: registrationFee}(
                "controlled-accounts", 
                registrationDuration
            );
            console.log("   [SUCCESS] controlled-accounts.ecs.eth namespace registered:", vm.toString(registeredNamespace));
        } else {
            console.log("   [INFO] controlled-accounts.ecs.eth namespace already exists");
        }
        
        // Step 2: Register accounts.controlled-accounts.ecs.eth sub-namespace
        console.log("   Step 2: Creating accounts.controlled-accounts.ecs.eth sub-namespace...");
        bytes32 accountsNamespace = registry.setSubnameOwner(
            "accounts",
            "controlled-accounts.ecs.eth",
            deployer,
            type(uint256).max, // Never expire
            false
        );
        console.log("   [SUCCESS] accounts.controlled-accounts.ecs.eth sub-namespace created:", vm.toString(accountsNamespace));
        
        // Step 3: Register the credential resolver
        console.log("   Step 3: Registering OffchainCCAddr as credential resolver...");
        addressResolver.setCredentialResolver("accounts.controlled-accounts.ecs.eth", address(offchainCCAddr));
        console.log("   [SUCCESS] OffchainCCAddr registered for accounts.controlled-accounts.ecs.eth");
        
        console.log("[SUCCESS] Credential registration complete!");
        console.log("   Namespace: accounts.controlled-accounts.ecs.eth");
        console.log("   Resolver:", address(offchainCCAddr));
    }
    
    /* --- Deployment Summary --- */
    
    function _printDeploymentSummary() internal view {
        console.log("[SUMMARY] Deployment Summary");
        console.log("====================");
        console.log("");
        console.log("[CONTRACTS] Contracts Deployed:");
        console.log("   OffchainCCAddr:", address(offchainCCAddr));
        console.log("");
        console.log("[CONFIGURATION] Gateway Configuration:");
        console.log("   Gateway Verifier:", GATEWAY_VERIFIER);
        console.log("   Target L2 Address:", TARGET_L2_ADDRESS);
        console.log("");
        console.log("[FUNCTIONALITY] Contract Features:");
        console.log("   - Offchain credential resolution for cross-chain controlled accounts");
        console.log("   - Dynamic program bytes updates (ADMIN_ROLE required)");
        console.log("   - Gateway-based data fetching from L2 networks");
        console.log("   - Access control for program management");
        console.log("");
        console.log("[USAGE] How to Use:");
        console.log("   1. Set up program bytes via updateProgram() (requires ADMIN_ROLE)");
        console.log("   2. Configure credential resolution in ECS system");
        console.log("   3. Resolve cross-chain controlled accounts via ENS");
        console.log("");
        console.log("[ADMIN] Admin Functions:");
        console.log("   # Update program bytes (requires ADMIN_ROLE)");
        console.log("   cast send", address(offchainCCAddr));
        console.log("   updateProgram(bytes)", "0x...");
        console.log("   --private-key $ADMIN_PRIVATE_KEY");
        console.log("   --rpc-url $SEPOLIA_RPC_URL");
        console.log("");
        console.log("   # Update gateway verifier (requires ADMIN_ROLE)");
        console.log("   cast send", address(offchainCCAddr));
        console.log("   updateVerifier(address)", "0x...");
        console.log("   --private-key $ADMIN_PRIVATE_KEY");
        console.log("   --rpc-url $SEPOLIA_RPC_URL");
        console.log("");
        console.log("   # Update target L2 address (requires ADMIN_ROLE)");
        console.log("   cast send", address(offchainCCAddr));
        console.log("   updateTargetL2Address(address)", "0x...");
        console.log("   --private-key $ADMIN_PRIVATE_KEY");
        console.log("   --rpc-url $SEPOLIA_RPC_URL");
        console.log("");
        console.log("   # Grant ADMIN_ROLE to another address");
        console.log("   cast send", address(offchainCCAddr));
        console.log("   grantRole(bytes32,address)", "0x...", "0x...");
        console.log("   --private-key $ADMIN_PRIVATE_KEY");
        console.log("   --rpc-url $SEPOLIA_RPC_URL");
        console.log("");
        console.log("[VERIFICATION] Contract Verification:");
        console.log("   # Check if address has ADMIN_ROLE");
        console.log("   cast call", address(offchainCCAddr));
        console.log("   hasRole(bytes32,address)", "0x...", "0x...");
        console.log("   --rpc-url $SEPOLIA_RPC_URL");
        console.log("");
        console.log("   # Get current program bytes");
        console.log("   cast call", address(offchainCCAddr));
        console.log("   programBytes()");
        console.log("   --rpc-url $SEPOLIA_RPC_URL");
        console.log("");
        console.log("   # Get current gateway verifier");
        console.log("   cast call", address(offchainCCAddr));
        console.log("   gatewayVerifier()");
        console.log("   --rpc-url $SEPOLIA_RPC_URL");
        console.log("");
        console.log("   # Get current target L2 address");
        console.log("   cast call", address(offchainCCAddr));
        console.log("   targetL2Address()");
        console.log("   --rpc-url $SEPOLIA_RPC_URL");
        console.log("");
        console.log("[INTEGRATION] ECS Integration:");
        console.log("   [SUCCESS] Namespace registered: controlled-accounts.ecs.eth");
        console.log("   [SUCCESS] Sub-namespace created: accounts.controlled-accounts.ecs.eth");
        console.log("   [SUCCESS] Resolver registered in ECSAddressResolver");
        console.log("   [SUCCESS] Ready for ECS resolution via ENS names");
        console.log("");
        console.log("[CREDENTIAL] Credential Resolution:");
        console.log("   Namespace: accounts.controlled-accounts.ecs.eth");
        console.log("   Resolver:", address(offchainCCAddr));
        console.log("   Usage: {address}.3c.addr.ecs.eth");
        console.log("   Credential Key: eth.ecs.controlled-accounts.accounts");
        console.log("");
        console.log("[VERIFICATION] ECS Registration Verification:");
        console.log("   # Check if controlled-accounts.ecs.eth namespace exists");
        console.log("   cast call", ECS_REGISTRY);
        console.log("   owner(bytes32)", "0xba3253aeb6fb45cbdb6a1244cb6109046b66693a2ade9bcdf3f7dea2e4c889ea");
        console.log("   --rpc-url $SEPOLIA_RPC_URL");
        console.log("");
        console.log("   # Check if accounts.controlled-accounts.ecs.eth namespace exists");
        console.log("   cast call", ECS_REGISTRY);
        console.log("   owner(bytes32)", "0x76445ed192980e4286850ef79ac920ef6d9883e477dd04c1c73ece8daee3be1b");
        console.log("   --rpc-url $SEPOLIA_RPC_URL");
        console.log("");
        console.log("   # Check if credential resolver is registered");
        console.log("   cast call", ECS_ADDRESS_RESOLVER);
        console.log("   credentialResolvers(bytes32)", "0x76445ed192980e4286850ef79ac920ef6d9883e477dd04c1c73ece8daee3be1b");
        console.log("   --rpc-url $SEPOLIA_RPC_URL");
        console.log("");
        console.log("[SUCCESS] OffchainCCAddr deployment and ECS registration complete!");
        console.log("[INFO] Use this contract for offchain resolution of cross-chain controlled accounts");
        console.log("[INFO] Credentials are now registered in the ECS system for ENS resolution");
    }
}
