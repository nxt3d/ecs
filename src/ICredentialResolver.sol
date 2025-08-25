// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title ICredentialResolver
 * @dev Interface for ECS credential resolvers that handle credential resolution.
 */
interface ICredentialResolver {
    /**
     * @dev Returns credential data for the given identifier and credential name.
     * @param identifier The DNS-encoded identifier to resolve.
     * @param _credential The credential name to look up (e.g., "eth.ecs.credential-name").
     * @return The credential data, or empty string if not found.
     */
    function credential(bytes calldata identifier, string calldata _credential) external view returns (string memory);
} 