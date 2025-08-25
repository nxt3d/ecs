// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./ECSRegistry.sol";
import "./IExtendedResolver.sol";
import "./ICredentialResolver.sol";
import "./utils/CCIPReader.sol";
import "./utils/ECSStringUtils.sol";
import "./utils/NameCoder.sol";
import "./utils/CredentialResolverUtils.sol";

/**
 * @title ECSNameResolver
 * @dev Resolver for ECS name-based credentials using CCIP-Read pattern
 */
contract ECSNameResolver is IExtendedResolver, CCIPReader {
    using ECSStringUtils for string;
    
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
    error InvalidDNSEncoding();
    
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
     * @dev Resolve credentials for a name-based ENS name
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
        
        // Extract the name identifier from the DNS name
        bytes memory nameIdentifier = _extractNameIdentifier(name);
        
        // Call the credential resolver
        return _callCredentialResolver(resolver, nameIdentifier, key);
    }
    
    /* --- Internal Functions --- */
    
    /**
     * @dev Extract domain identifier from DNS name
     * Expected format: domain.com.name.<anything>.eth
     * Returns: DNS-encoded domain.com
     * @param name The full DNS-encoded name
     * @return identifier The DNS-encoded domain identifier
     */
    function _extractNameIdentifier(bytes calldata name) internal pure returns (bytes memory) {
        if (name.length < 10) { // Minimum for "name.x.eth" + null terminator
            revert InvalidDNSEncoding();
        }
        
        // Parse DNS name forward through labels
        // DNS format: [length][label][length][label]...[0]
        // Looking for pattern: <domain labels>...[4]name[?]<anything>[3]eth[0]
        
        uint256 pos = 0;
        uint256 namePosition = 0;
        bool foundName = false;
        
        // Parse forward through labels
        while (pos < name.length) {
            // Check for null terminator
            if (name[pos] == 0x00) {
                break;
            }
            
            uint8 labelLength = uint8(name[pos]);
            
            // Check if we have enough bytes for this label
            if (pos + labelLength + 1 > name.length) {
                revert InvalidDNSEncoding();
            }
            
            // Check if this is the "name" label
            if (labelLength == 4 && 
                name[pos + 1] == 0x6e && // 'n'
                name[pos + 2] == 0x61 && // 'a'
                name[pos + 3] == 0x6d && // 'm'
                name[pos + 4] == 0x65) { // 'e'
                
                namePosition = pos;
                foundName = true;
                pos += labelLength + 1; // Move past "name" label
                
                // Skip the next label (can be anything)
                if (pos >= name.length || name[pos] == 0x00) {
                    revert InvalidDNSEncoding();
                }
                
                uint8 nextLabelLength = uint8(name[pos]);
                if (pos + nextLabelLength + 1 > name.length) {
                    revert InvalidDNSEncoding();
                }
                pos += nextLabelLength + 1; // Move past the next label
                
                // Check if the following label is "eth" and terminal
                if (pos + 4 <= name.length && 
                    name[pos] == 0x03 && // length 3
                    name[pos + 1] == 0x65 && // 'e'
                    name[pos + 2] == 0x74 && // 't'
                    name[pos + 3] == 0x68 && // 'h'
                    pos + 4 < name.length && 
                    name[pos + 4] == 0x00) { // null terminator
                    
                    // Found valid pattern: extract domain identifier
                    bytes memory identifier = new bytes(namePosition + 1);
                    for (uint256 i = 0; i < namePosition; i++) {
                        identifier[i] = name[i];
                    }
                    identifier[namePosition] = 0x00; // Add null terminator
                    
                    return identifier;
                }
                
                // If we reach here, pattern doesn't match - continue searching
                foundName = false;
            } else {
                // Move to next label
                pos += labelLength + 1;
            }
        }
        
        // If we reach here, no valid pattern was found
        revert InvalidDNSEncoding();
    }
    
    /**
     * @dev Call a credential resolver with CCIP-Read support
     * @param resolver The resolver address
     * @param nameIdentifier The DNS-encoded name identifier
     * @param key The service key
     * @return The result of the resolver call
     */
    function _callCredentialResolver(address resolver, bytes memory nameIdentifier, string memory key) internal view returns (bytes memory) {
        ccipRead(
            resolver,
            abi.encodeWithSelector(
                ICredentialResolver.credential.selector,
                nameIdentifier,
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
        // Decode the string result from the credential resolver
        string memory result = abi.decode(response, (string));
        // Re-encode it for the resolve function
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