// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./ECSRegistry.sol";
import "./IExtendedResolver.sol";
import "./utils/CCIPReader.sol";
import "./utils/NameCoder.sol";

/**
 * @title ECSResolver
 * @dev Resolver for ECS name-based credentials using CCIP-Read pattern
 */
contract ECSResolver is IExtendedResolver, CCIPReader {
    
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
    

    
    /* --- Resolution --- */
    
    /**
     * @dev Resolve credentials for a name-based ENS name
     * @param name The DNS-encoded name
     * @param data The resolver function call data
     * @return The result of the resolver call
     */
    function resolve(bytes calldata name, bytes calldata data) external view returns (bytes memory) {
        // Decode DNS name to get the labelhash (node in registry)
        (bytes32 labelHash, ) = NameCoder.readLabel(name, 0);
        
        // Lookup resolver in registry
        address resolver = registry.resolver(labelHash);
        
        if (resolver == address(0)) {
            return abi.encode("");
        }
        
        // Call the credential resolver
        return _callCredentialResolver(resolver, name, data);
    }
    
    /* --- Internal Functions --- */
    
    /**
     * @dev Call a credential resolver with CCIP-Read support
     * @param resolver The resolver address
     * @param name The DNS-encoded name
     * @param data The resolver data
     * @return The result of the resolver call
     */
    function _callCredentialResolver(address resolver, bytes calldata name, bytes calldata data) internal view returns (bytes memory) {
        ccipRead(
            resolver,
            abi.encodeWithSelector(
                IExtendedResolver.resolve.selector,
                name,
                data
            ),
            this.resolverCallback.selector,
            this.onResolveFailure.selector,
            ""
        );
    }
    
    /**
     * @dev Success callback for CCIPReader when credential resolver returns onchain result
     * @param response The raw return data from the credential resolver
     * @return The ABI-encoded credential result
     */
    function resolverCallback(
        bytes memory response,
        bytes memory /* extraData */
    ) external pure returns (bytes memory) {
        return abi.decode(response, (bytes));
    }
    
    /**
     * @dev Failure callback for CCIPReader when credential resolver call fails
     * @param response The error data from the failed call
     * @return Never returns - always reverts with the original error
     */
    function onResolveFailure(
        bytes memory response,
        bytes memory /* extraData */
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