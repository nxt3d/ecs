// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./ECSStringUtils.sol";
import "./NameCoder.sol";
import "../ECSRegistry.sol";

/**
 * @title CredentialResolverUtils
 * @dev Utility functions for credential resolver lookup
 */
library CredentialResolverUtils {
    
    /* --- Errors --- */
    
    error NamespaceExpired(bytes32 namespace);
    
    /**
     * @dev Find the credential resolver for a specific namespace
     * @param key The service key in reverse domain order (e.g., "eth.ecs.ethstars.stars")
     * @param credentialResolvers Mapping of namespace hash to resolver address
     * @param registry The ECS registry contract
     * @return The address of the matching credential resolver, or address(0) if none found
     */
    function findCredentialResolver(
        string memory key,
        mapping(bytes32 => address) storage credentialResolvers,
        ECSRegistry registry
    ) internal view returns (address) {
        // Split the key by dots, stopping at ":" parameter divider
        string[] memory keyLabels = ECSStringUtils.splitByDotsStopAtColon(key);
        
        if (keyLabels.length < 3) {
            return address(0); // Need at least "eth.ecs.namespace"
        }
        
        // Build namespace name from the key (skip first 2 labels: "eth.ecs")
        // Key format: "eth.ecs.namespace.credential" -> namespace: "namespace.ecs.eth"
        string memory namespaceName = "";
        for (uint256 i = keyLabels.length - 1; i >= 2; i--) {
            if (bytes(namespaceName).length == 0) {
                namespaceName = keyLabels[i];
            } else {
                namespaceName = string(abi.encodePacked(namespaceName, ".", keyLabels[i]));
            }
        }
        namespaceName = string(abi.encodePacked(namespaceName, ".ecs.eth"));
        
        // Calculate namespace hash using DNS encoding
        bytes memory dnsEncoded = NameCoder.encode(namespaceName);
        bytes32 namespaceHash = NameCoder.namehash(dnsEncoded, 0);
        
        // Check if this namespace has a resolver and is active
        address resolver = credentialResolvers[namespaceHash];
        
        if (resolver != address(0) && registry.isNamespaceActive(namespaceHash)) {
            return resolver;
        }
        
        return address(0);
    }
} 