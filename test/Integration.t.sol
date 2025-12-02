// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/ECSRegistry.sol";
import "../src/ECSRegistrar.sol";
import "../src/CredentialResolver.sol";
import "../src/ENSRegistry.sol";
import "../src/ENS.sol";

interface ITextResolver {
    function text(bytes32 node, string calldata key) external view returns (string memory);
}

contract IntegrationTest is Test {
    /* --- Test Accounts --- */
    
    address admin = address(0x1001);
    address provider = address(0x1002); // star-protocol owner
    address user = address(0x1003); // End user
    
    /* --- Contract Variables --- */
    
    ECSRegistry public registry;
    ECSRegistrar public registrar;
    ENSRegistry public ensRegistry;
    CredentialResolver public providerResolver;
    
    bytes32 public rootNode;
    
    /* --- Constants --- */
    
    string public constant PROVIDER_LABEL = "star-protocol";
    uint256 public constant DURATION = 365 days;
    uint256 public constant PRICE_PER_SEC = 1000 wei;
    
    /* --- Setup --- */
    
    function setUp() public {
        vm.startPrank(admin);
        
        // 1. Deploy ENS Registry
        ensRegistry = new ENSRegistry();
        
        // 2. Setup ecs.eth node
        bytes32 ethNode = ensRegistry.setSubnodeOwner(bytes32(0), keccak256("eth"), admin);
        rootNode = ensRegistry.setSubnodeOwner(ethNode, keccak256("ecs"), admin);
        
        // 3. Deploy ECS Registry
        registry = new ECSRegistry(ensRegistry, rootNode);
        
        // 4. Deploy Registrar
        registrar = new ECSRegistrar(registry);
        registry.grantRole(registry.REGISTRAR_ROLE(), address(registrar));
        
        // 5. Transfer ecs.eth ownership to ECS Registry
        ensRegistry.setOwner(rootNode, address(registry));
        
        // Setup pricing
        uint256[] memory prices = new uint256[](1);
        prices[0] = PRICE_PER_SEC;
        registrar.setPricingForAllLengths(prices);
        registrar.setParams(60, type(uint64).max, 3, 64);
        vm.stopPrank();
        
        // Fund provider
        vm.deal(provider, 10 ether);
    }
    
    /* --- Test Dividers --- */
    
    function test1000________________________________________________________________________________() public pure {}
    function test1100____________________INTEGRATION_TESTS____________________________________() public pure {}
    function test1200________________________________________________________________________________() public pure {}
    
    /* --- Integration Tests --- */
    
    function test_001____Integration____StarProtocolFlow() public {
        // 1. Provider registers "star-protocol"
        uint256 price = registrar.rentPrice(PROVIDER_LABEL, DURATION);
        bytes32 secret = bytes32(uint256(1));
        
        vm.startPrank(provider);
        
        // Provider creates their own specific resolver
        providerResolver = new CredentialResolver(provider);
        
        // Commit
        bytes32 commitment = registrar.createCommitment(PROVIDER_LABEL, provider, address(providerResolver), DURATION, secret);
        registrar.commit(commitment);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 60);
        
        vm.startPrank(provider);
        
        // Register the name with the provider's resolver
        registrar.register{value: price}(
            PROVIDER_LABEL,
            provider,
            address(providerResolver),
            DURATION,
            secret
        );
        
        // Verify registration in ECS Registry
        bytes32 labelhash = keccak256(bytes(PROVIDER_LABEL));
        assertEq(registry.owner(labelhash), provider);
        assertEq(registry.resolver(labelhash), address(providerResolver));
        
        // Verify registration in ENS Registry
        // node = keccak256(rootNode, labelhash)
        bytes32 providerNode = keccak256(abi.encodePacked(rootNode, labelhash));
        assertEq(ensRegistry.owner(providerNode), address(registry)); // Owned by ECS Registry
        assertEq(ensRegistry.resolver(providerNode), address(providerResolver)); // Resolver set to provider's resolver
        
        // 2. Provider sets up the credential record
        string memory credentialKey = "eth.ecs.star-protocol.star:vitalik.eth";
        string memory starCount = "5";
        
        // We need to set the record on the `providerNode`? 
        // The credential resolver receives the `node` in `text(bytes32 node, string key)`.
        // The node passed by standard ENS clients is the namehash of "star-protocol.ecs.eth".
        // This matches `providerNode`.
        
        // Provider sets the text record on their resolver (owner only, single-label resolver)
        vm.prank(provider);
        providerResolver.setText(credentialKey, starCount);
        
        vm.stopPrank();
        
        // 3. User resolves the credential via ENS
        vm.startPrank(user);
        
        // User looks up resolver from ENS
        address resolvedResolver = ensRegistry.resolver(providerNode);
        assertEq(resolvedResolver, address(providerResolver));
        
        // User calls resolver directly
        string memory resolvedValue = ITextResolver(resolvedResolver).text(providerNode, credentialKey);
        assertEq(resolvedValue, "5");
        
        vm.stopPrank();
    }
    
    function test_002____Integration____UpdateCredential() public {
        // Setup initial state
        test_001____Integration____StarProtocolFlow();
        
        bytes32 labelhash = keccak256(bytes(PROVIDER_LABEL));
        bytes32 providerNode = keccak256(abi.encodePacked(rootNode, labelhash));
        string memory credentialKey = "eth.ecs.star-protocol.star:vitalik.eth";
        
        // Provider updates stars to 10
        vm.startPrank(provider);
        vm.prank(provider);
        providerResolver.setText(credentialKey, "10");
        vm.stopPrank();
        
        // User resolves again
        vm.startPrank(user);
        
        string memory resolvedValue = ITextResolver(address(providerResolver)).text(providerNode, credentialKey);
        assertEq(resolvedValue, "10");
        
        vm.stopPrank();
    }
}
