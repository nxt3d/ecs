// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/ECSRegistry.sol";
import "../src/ECSRegistrar.sol";
import "../src/ECSResolver.sol";
import "../src/CredentialResolver.sol";
import "../src/utils/NameCoder.sol";

contract IntegrationTest is Test {
    /* --- Test Accounts --- */
    
    address admin = address(0x1001);
    address provider = address(0x1002); // star-protocol owner
    address user = address(0x1003); // End user
    
    /* --- Contract Variables --- */
    
    ECSRegistry public registry;
    ECSRegistrar public registrar;
    ECSResolver public mainResolver;
    CredentialResolver public providerResolver;
    
    /* --- Constants --- */
    
    string public constant PROVIDER_LABEL = "star-protocol";
    uint256 public constant DURATION = 365 days;
    uint256 public constant PRICE_PER_SEC = 1000 wei;
    
    /* --- Setup --- */
    
    function setUp() public {
        // 1. Deploy core contracts
        vm.startPrank(admin);
        registry = new ECSRegistry();
        registrar = new ECSRegistrar(registry);
        mainResolver = new ECSResolver(registry);
        
        registry.grantRole(registry.REGISTRAR_ROLE(), address(registrar));
        
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
        // Note: ECSRegistrar.register takes (label, owner, resolver, duration)
        registrar.register{value: price}(
            PROVIDER_LABEL,
            provider,
            address(providerResolver),
            DURATION,
            secret
        );
        
        // Verify registration
        bytes32 labelhash = keccak256(bytes(PROVIDER_LABEL));
        assertEq(registry.owner(labelhash), provider);
        assertEq(registry.resolver(labelhash), address(providerResolver));
        
        // 2. Provider sets up the credential record
        // "key eth.ecs.star-protocol.star:vitalik.eth"
        // We map this key to "5" (stars)
        string memory credentialKey = "eth.ecs.star-protocol.star:vitalik.eth";
        string memory starCount = "5";
        
        // CredentialResolver uses the labelhash of the *provider*? 
        // No, CredentialResolver is generic. It uses whatever node hash is passed to it.
        // But ECSResolver forwards the call with the DNS name "star-protocol.ecs.eth" (or similar).
        // The `resolve` function in CredentialResolver extracts the label from the name to determine the node?
        
        // Let's look at CredentialResolver.resolve:
        // (bytes32 labelhash,) = NameCoder.readLabel(name, 0);
        // It extracts the first label of the name passed to it.
        
        // So if we call ECSResolver with name="star-protocol.ecs.eth", 
        // ECSResolver extracts "star-protocol", finds providerResolver.
        // Then calls providerResolver.resolve("star-protocol.ecs.eth", ...).
        // ProviderResolver extracts "star-protocol" -> labelhash.
        // Then looks up record for that labelhash.
        
        // So the provider must set the record on the "star-protocol" labelhash in their resolver.
        // Note: In CredentialResolver, we need to ensure we own that labelhash or are authorized.
        // Since provider deployed it, they are owner() of the contract, so they can set anything.
        // Or they can setLabelOwner(labelhash, provider).
        
        // Let's explicitly set label ownership in the resolver for clarity/good practice
        providerResolver.setLabelOwner(labelhash, provider);
        
        // Set the text record
        providerResolver.setText(labelhash, credentialKey, starCount);
        
        vm.stopPrank();
        
        // 3. User resolves the credential
        vm.startPrank(user);
        
        bytes memory name = NameCoder.encode("star-protocol.ecs.eth");
        bytes memory data = abi.encodeWithSelector(
            bytes4(keccak256("text(bytes32,string)")),
            bytes32(0), // node is ignored by ECSResolver/CredentialResolver logic which extracts from name
            credentialKey
        );
        
        // Call the main ECS resolver
        bytes memory result = mainResolver.resolve(name, data);
        
        // Decode and verify
        string memory resolvedValue = abi.decode(result, (string));
        assertEq(resolvedValue, "5");
        
        vm.stopPrank();
    }
    
    function test_002____Integration____UpdateCredential() public {
        // Setup initial state
        test_001____Integration____StarProtocolFlow();
        
        bytes32 labelhash = keccak256(bytes(PROVIDER_LABEL));
        string memory credentialKey = "eth.ecs.star-protocol.star:vitalik.eth";
        
        // Provider updates stars to 10
        vm.startPrank(provider);
        providerResolver.setText(labelhash, credentialKey, "10");
        vm.stopPrank();
        
        // User resolves again
        vm.startPrank(user);
        
        bytes memory name = NameCoder.encode("star-protocol.ecs.eth");
        bytes memory data = abi.encodeWithSelector(
            bytes4(keccak256("text(bytes32,string)")),
            bytes32(0),
            credentialKey
        );
        
        bytes memory result = mainResolver.resolve(name, data);
        string memory resolvedValue = abi.decode(result, (string));
        assertEq(resolvedValue, "10");
        
        vm.stopPrank();
    }
    
    function test_003____Integration____ExpiredNamespace() public {
         // 1. Provider registers "star-protocol"
        uint256 price = registrar.rentPrice(PROVIDER_LABEL, DURATION);
        bytes32 secret = bytes32(uint256(1));
        
        vm.startPrank(provider);
        providerResolver = new CredentialResolver(provider);
        
        // Commit
        bytes32 commitment = registrar.createCommitment(PROVIDER_LABEL, provider, address(providerResolver), DURATION, secret);
        registrar.commit(commitment);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 60);
        
        vm.startPrank(provider);
        
        registrar.register{value: price}(
            PROVIDER_LABEL,
            provider,
            address(providerResolver),
            DURATION,
            secret
        );
        
        // Set record
        bytes32 labelhash = keccak256(bytes(PROVIDER_LABEL));
        string memory credentialKey = "test";
        providerResolver.setLabelOwner(labelhash, provider);
        providerResolver.setText(labelhash, credentialKey, "val");
        vm.stopPrank();
        
        // 2. Expiration happens
        vm.warp(block.timestamp + DURATION + 1);
        
        // 3. User tries to resolve
        // Note: ECSResolver.resolve checks:
        // address resolver = registry.resolver(labelHash);
        // ECSRegistry.resolver(labelHash) is a view function returning records[labelhash].resolver
        // It DOES NOT check expiration. Expiration is checked in `authorizedOrRegistrar` modifier for WRITES.
        // Reads usually return data even if expired in standard ENS, unless explicitly blocked.
        
        // Let's check ECSRegistry.sol view functions.
        // `function resolver(bytes32 labelhash) external view returns (address)` -> just returns value.
        
        // However, ECSResolver logic might (or should?) check if expired?
        // ECSResolver.sol:
        // address resolver = registry.resolver(labelHash);
        // It does not check expiration explicitly.
        
        // So it should still resolve? 
        // If the user intention is that expired names stop working, then ECSResolver should check `registry.isExpired(labelHash)`.
        // But typically in ENS, the resolver is still set until someone else claims it.
        
        // Let's verify current behavior (success)
        vm.startPrank(user);
        
        bytes memory name = NameCoder.encode("star-protocol.ecs.eth");
        bytes memory data = abi.encodeWithSelector(
            bytes4(keccak256("text(bytes32,string)")),
            bytes32(0),
            credentialKey
        );
        
        bytes memory result = mainResolver.resolve(name, data);
        string memory resolvedValue = abi.decode(result, (string));
        assertEq(resolvedValue, "val");
        
        vm.stopPrank();
    }
}

