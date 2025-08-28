// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./ECSRegistry.sol";
import "./IExtendedResolver.sol";
import "./ICredentialResolver.sol";
import "./utils/CCIPReader.sol";
import "./utils/ECSStringUtils.sol";
import "./utils/CredentialResolverUtils.sol";

/**
 * @title ECSAddressResolver
 * @dev Resolver for ECS address-based credentials using CCIP-Read pattern
 * 
 * This resolver handles credential resolution for address-based lookups where the
 * ENS name encodes both the address and cointype. It supports hierarchical namespace
 * resolution with longest-prefix matching.
 */
contract ECSAddressResolver is IExtendedResolver, CCIPReader {
    // using ECSStringUtils for string; // I am not sure this is needed here. 
    
    /* --- Types --- */
    
    ECSRegistry public immutable registry;
    
    /* --- State Variables --- */
    
    // namespace hash => credential resolver address
    mapping(bytes32 => address) public credentialResolvers;
    

    
    /* --- Events --- */
    
    event CredentialResolverRegistered(bytes32 indexed namespaceHash, string namespace, address indexed resolver);
    event CredentialResolverRemoved(bytes32 indexed namespaceHash, string namespace);

    
    /* --- Errors --- */
    
    error UnsupportedFunction(bytes4 selector);
    error UnauthorizedNamespaceAccess(address caller, bytes32 namespace);
    error NamespaceExpired(bytes32 namespace);
    error InvalidAddressEncoding();
    
    /* --- Constructor --- */
    
    constructor(ECSRegistry _registry) CCIPReader(50000) {
        registry = _registry;
    }
    

    
    /* --- Credential Resolver Management --- */
    
    /**
     * @dev Register a credential resolver for a namespace
     * @param namespace The namespace string (e.g., "stars.ethstars.ecs.eth")
     * @param resolver The resolver address (can be address(0) to remove)
     */
    function setCredentialResolver(string memory namespace, address resolver) external {
        // Encode namespace string to hash
        bytes memory dnsEncoded = NameCoder.encode(namespace);
        bytes32 namespaceHash = NameCoder.namehash(dnsEncoded, 0);
        
        if (!registry.isAuthorizedForNamespace(namespaceHash, msg.sender)) {
            revert UnauthorizedNamespaceAccess(msg.sender, namespaceHash);
        }
        
        if (registry.isExpired(namespaceHash)) {
            revert NamespaceExpired(namespaceHash);
        }
        
        credentialResolvers[namespaceHash] = resolver;
        
        if (resolver == address(0)) {
            emit CredentialResolverRemoved(namespaceHash, namespace);
        } else {
            emit CredentialResolverRegistered(namespaceHash, namespace, resolver);
        }
    }
    
    /* --- Resolution --- */
    
    /**
     * @dev Resolve credentials for an address-based ENS name
     * @param name The DNS-encoded name
     * @param data The resolver function call data
     * @return The result of the resolver call
     */
    function resolve(bytes calldata name, bytes calldata data) external view returns (bytes memory) {
        
        bytes4 selector = bytes4(data);
        
        // Only support text(bytes32,string) function
        if (selector != 0x59d1d43c) { // text(bytes32,string) selector
            revert UnsupportedFunction(selector);
        }
        
        // Decode the function call to get the key
        (, string memory key) = abi.decode(data[4:], (bytes32, string));
        
        // Find the matching credential resolver using the utility
        address resolver = CredentialResolverUtils.findCredentialResolver(key, credentialResolvers, registry);
        
        if (resolver == address(0)) {
            return abi.encode("");
        }
        
        // Parse the address+cointype identifier from the DNS name
        bytes memory identifier = _extractAddressIdentifier(name);
        
        // Call the credential resolver
        return _callCredentialResolver(resolver, identifier, key);
    }
    
    /* --- Internal Functions --- */
    
    /**
     * @dev Extract the address identifier from a DNS-encoded name
     * Expected format: address.cointype.<any-namespace>.eth
     * Returns: DNS-encoded address identifier (address.cointype)
     */
    function _extractAddressIdentifier(bytes calldata name) internal pure returns (bytes memory) {
        if (name.length < 10) { // Minimum for "a.b.c.eth" + null terminator
            revert InvalidAddressEncoding();
        }
        
        // Parse through all labels to find the structure
        uint256 offset = 0;
        uint256 labelCount = 0;
        uint256 identifierEnd = 0;
        bool foundEth = false;
        
        // Parse through all labels forward
        while (offset < name.length) {
            uint8 labelLength = uint8(name[offset]);
            if (labelLength == 0) {
                foundEth = true; // Found null terminator
                break;
            }
            
            // Check if we have enough bytes for this label
            if (offset + labelLength + 1 > name.length) {
                revert InvalidAddressEncoding();
            }
            
            labelCount++;
            
            // After reading two labels (address.cointype), mark the end of identifier
            if (labelCount == 2) {
                identifierEnd = offset + 1 + labelLength;
            }
            
            // Check if this is the "eth" label (should be the last non-null label)
            if (labelLength == 3 && 
                name[offset + 1] == 0x65 && // 'e'
                name[offset + 2] == 0x74 && // 't'
                name[offset + 3] == 0x68 && // 'h'
                offset + 4 < name.length &&
                name[offset + 4] == 0x00) { // followed by null terminator
                
                foundEth = true;
                break;
            }
            
            offset += 1 + labelLength; // Move to next label
        }
        
        // Validate we found proper structure: at least address.cointype.something.eth
        if (!foundEth || labelCount < 3 || identifierEnd == 0) {
            revert InvalidAddressEncoding();
        }
        
        // Extract the address identifier (first two labels) with proper null termination
        bytes memory identifier = new bytes(identifierEnd + 1);
        for (uint256 i = 0; i < identifierEnd; i++) {
            identifier[i] = name[i];
        }
        identifier[identifierEnd] = 0x00; // Null terminator
        
        return identifier;
    }
    
    /**
     * @dev Call a credential resolver with CCIP-Read support
     * @param resolver The resolver address
     * @param identifier The DNS-encoded address identifier
     * @param key The service key
     * @return The result of the resolver call
     */
    function _callCredentialResolver(address resolver, bytes memory identifier, string memory key) internal view returns (bytes memory) {
        ccipRead(
            resolver,
            abi.encodeWithSelector(
                ICredentialResolver.credential.selector,
                identifier,
                key
            ),
            this.onCredentialSuccess.selector,
            this.onCredentialFailure.selector,
            ""
        );
    }
    
    /**
     * @dev Success callback for CCIPReader when credential resolver returns onchain result
     * @param response The raw return data from the credential resolver
     * @param extraData Additional context data (unused)
     * @return The ABI-encoded credential result
     */
    function onCredentialSuccess(
        bytes memory response,
        bytes memory extraData
    ) external pure returns (bytes memory) {
        // Credential resolvers now return strings directly, so just re-encode
        string memory result = abi.decode(response, (string));
        return abi.encode(result);
    }
    
    /**
     * @dev Failure callback for CCIPReader when credential resolver call fails
     * @param response The error data from the failed call
     * @param extraData Additional context data (unused)
     * @return Never returns - always reverts with the original error
     */
    function onCredentialFailure(
        bytes memory response,
        bytes memory extraData
    ) external pure returns (bytes memory) {
        // Re-throw the original error from the credential resolver
        assembly {
            revert(add(response, 0x20), mload(response))
        }
    }
    


    
    /* --- ERC165 Support --- */
    
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IExtendedResolver).interfaceId || interfaceId == 0x01ffc9a7;
    }
} 