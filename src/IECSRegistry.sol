// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title IECSRegistry
 * @dev Interface for the ECS (Ethereum Credential Service) Registry
 * @notice Manages ownership of ECS nodes and operator delegation
 */
interface IECSRegistry {
    // Logged when the owner of a node transfers ownership to a new account.
    event Transfer(bytes32 indexed namespace, address owner);

    // Logged when a node-specific operator is added or removed.
    event ApprovalForNamespace(
        bytes32 indexed namespace,
        address indexed owner,
        address indexed operator,
        bool approved
    );

    // Logged when expiration time is set for a namespace.
    event ExpirationSet(bytes32 indexed namespace, uint256 expirationTime);

    // Logged when DNS encoded name is set for a namespace.
    event DnsNameSet(bytes32 indexed namespace, bytes dnsEncodedName);

    /**
     * @dev Transfers ownership of a subnamespace to a new address using label and parent domain name.
     * @param label The label string (e.g., "ecs" for "ecs.eth")
     * @param parentDomainName The parent domain name as string (e.g., "eth")
     * @param newOwner The address of the new owner.
     * @param expirationTime The expiration timestamp for the subnamespace.
     * @param protected Whether the namespace should be protected from expiration.
     */
    function setSubnameOwner(
        string memory label,
        string memory parentDomainName,
        address newOwner,
        uint256 expirationTime,
        bool protected
    ) external returns (bytes32);

    /**
     * @dev Transfers ownership of a node to a new address.
     * @param namespace The namespace to transfer ownership of.
     * @param newOwner The address of the new owner.
     */
    function setOwner(bytes32 namespace, address newOwner) external;

    /**
     * @dev Enable or disable approval for a third party ("operator") to manage
     *      a specific namespace owned by `msg.sender`. Emits the ApprovalForNamespace event.
     * @param namespace The specific namespace to approve for.
     * @param operator Address to add to the set of authorized operators for this namespace.
     * @param approved True if the operator is approved, false to revoke approval.
     */
    function setApprovalForNamespace(bytes32 namespace, address operator, bool approved) external;

    /**
     * @dev Sets namespace registration data using DNS-encoded name. Only callable by controllers.
     * @param dnsEncodedName The DNS-encoded domain name.
     * @param expirationTime The expiration timestamp.
     * @param newOwner The owner address.
     * @return namespace The calculated namespace hash.
     */
    function setNamespaceData(
        bytes calldata dnsEncodedName,
        uint256 expirationTime,
        address newOwner
    ) external returns (bytes32);

    /**
     * @dev Sets namespace expiration time. Only callable by controllers.
     * @param namespace The namespace hash.
     * @param newExpirationTime The new expiration timestamp.
     */
    function setExpiration(bytes32 namespace, uint256 newExpirationTime) external;

    /**
     * @dev Returns the address that owns the specified namespace.
     * @param namespace The specified namespace.
     * @return The address of the owner.
     */
    function owner(bytes32 namespace) external view returns (address);

    /**
     * @dev Returns whether a record has been imported to the registry.
     * @param namespace The specified namespace.
     * @return Bool if record exists.
     */
    function recordExists(bytes32 namespace) external view returns (bool);

    /**
     * @dev Query if an address is an authorized operator for a specific namespace.
     * @param namespace The specific namespace to check.
     * @param operator The address that acts on behalf of the owner.
     * @return True if `operator` is an approved operator for this namespace, false otherwise.
     */
    function isApprovedForNamespace(
        bytes32 namespace,
        address operator
    ) external view returns (bool);

    /**
     * @dev Query if an address is authorized for a specific namespace (owner or namespace-approved).
     * @param namespace The specific namespace to check.
     * @param operator The address to check authorization for.
     * @return True if `operator` is authorized for this namespace, false otherwise.
     */
    function isAuthorizedForNamespace(
        bytes32 namespace,
        address operator
    ) external view returns (bool);

    /**
     * @dev Check if a namespace is currently active (not expired).
     * @param namespace The namespace to check.
     * @return True if namespace is active, false if expired or not registered.
     */
    function isNamespaceActive(bytes32 namespace) external view returns (bool);

    /**
     * @dev Get the expiration time for a namespace.
     * @param namespace The namespace to check.
     * @return The expiration timestamp.
     */
    function getExpiration(bytes32 namespace) external view returns (uint256);

    /**
     * @dev Get namespace data including expiration and stored domain name.
     * @param namespace The namespace to query.
     * @return expirationTime The expiration timestamp.
     * @return storedDomainName The stored domain name as string.
     */
    function getNamespace(bytes32 namespace) external view returns (uint256 expirationTime, string memory storedDomainName);

    /**
     * @dev Check if a namespace is expired.
     * @param namespace The namespace to check.
     * @return True if namespace is expired, false otherwise.
     */
    function isExpired(bytes32 namespace) external view returns (bool);

    /**
     * @dev Adds a new controller. Only callable by admins.
     * @param controller The address of the new controller.
     */
    function addController(address controller) external;

    /**
     * @dev Removes a controller. Only callable by admins.
     * @param controller The address of the controller to remove.
     */
    function removeController(address controller) external;
}