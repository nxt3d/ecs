// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./utils/NameCoder.sol";

/// The ECS registry contract - manages namespace ownership, registration, and expiration.
contract ECSRegistry is AccessControl {

    /* --- Roles --- */
    
    bytes32 public constant ADMIN_ROLE = keccak256(bytes("ADMIN_ROLE"));
    bytes32 public constant CONTROLLER_ROLE = keccak256(bytes("CONTROLLER_ROLE"));

    /* --- Errors --- */
    
    error Unauthorized(bytes32 namespace, address caller);
    error OnlyNamespaceOwner(bytes32 namespace, address caller, address namespaceOwner);
    error NamespaceExpired(bytes32 namespace);
    error UnauthorizedNamespaceAccess(address caller, bytes32 namespace);
    error NameSpaceNotExpired(bytes32 namespace);
    error ProtectedNamespace(bytes32 namespace);

    /* --- Events --- */

    event Transfer(bytes32 indexed namespace, address owner);
    event ApprovalForNamespace(bytes32 indexed namespace, address indexed owner, address indexed operator, bool approved);
    event ExpirationSet(bytes32 indexed namespace, uint256 expirationTime);
    event DnsNameSet(bytes32 indexed namespace, bytes dnsEncodedName);
    
    /* --- Storage --- */

    // Namespace ownership
    mapping(bytes32 namespace => address owner) public owners;
    
    // Namespace-specific approvals: namespace => owner => operator => approved
    mapping(bytes32 namespace => mapping(address owner => mapping(address operator => bool isApproved))) public namespaceOperators;

    // Registration data
    mapping(bytes32 namespace => uint256 expirationTime) public expirationTimes;
    mapping(bytes32 namespace => bool isProtected) public isProtected;
    mapping(bytes32 namespace => bytes dnsEncodedName) public dnsEncodedNames;

    /* --- Modifiers --- */

    // Permits modifications only by the owner of the specified namespace.
    modifier authorized(bytes32 namespace) {
        if (!_isAuthorized(namespace, msg.sender)) {
            revert Unauthorized(namespace, msg.sender);
        }
        _;
    }

    /* --- Private Functions --- */

    /// @dev Private function to check if an address is authorized for a namespace (owner or approved operator).
    /// @param namespace The namespace to check authorization for.
    /// @param operator The address to check authorization for.
    /// @return True if the operator is authorized, false otherwise.
    function _isAuthorized(bytes32 namespace, address operator) private view returns (bool) {
        address namespaceOwner = owners[namespace];
        return namespaceOwner == operator || 
               namespaceOperators[namespace][namespaceOwner][operator];
    }

    /* --- Constructor --- */

    constructor() {
        owners[0x0] = msg.sender;
        expirationTimes[0x0] = type(uint256).max; // Root namespace never expires
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /* --- Ownership Management --- */

    /// @dev Transfers ownership of a namespace to a new address. May only be called by the current owner of the namespace.
    /// @param namespace The namespace to transfer ownership of.
    /// @param newOwner The address of the new owner.
    function setOwner(
        bytes32 namespace,
        address newOwner
    ) public virtual authorized(namespace) {
        owners[namespace] = newOwner;
        emit Transfer(namespace, newOwner);
    }

    /// @dev Transfers ownership of a subnamespace to a new address using label and parent domain name.
    /// @param label The label string (e.g., "ecs" for "ecs.eth")
    /// @param parentDomainName The parent domain name as string (e.g., "eth")
    /// @param newOwner The address of the new owner.
    /// @param expirationTime The expiration timestamp for the subnamespace.
    function setSubnameOwner(
        string memory label,
        string memory parentDomainName,
        address newOwner,
        uint256 expirationTime,
        bool protected
    ) public virtual returns (bytes32) {

        // Create full domain name and encode to DNS format
        string memory fullDomainName;
        if (bytes(parentDomainName).length == 0) {
            // Parent is root, just use the label
            fullDomainName = label;
        } else {
            // Parent is not root, concatenate with dot
            fullDomainName = string(abi.encodePacked(label, ".", parentDomainName));
        }
        bytes memory fullDnsName = NameCoder.encode(fullDomainName);
        
        // Calculate parent namespace hash from DNS-encoded parent name
        bytes memory parentDnsName = NameCoder.encode(parentDomainName);
        bytes32 parentNamespace = NameCoder.namehash(parentDnsName, 0);
        
        // Verify caller is authorized for parent namespace
        if (!_isAuthorized(parentNamespace, msg.sender)) {
            revert Unauthorized(parentNamespace, msg.sender);
        }

        // Make sure the parent namespace is not expired
        if (expirationTimes[parentNamespace] <= block.timestamp) {
            revert NamespaceExpired(parentNamespace);
        }

        // Calculate full namespace hash from full DNS name
        bytes32 fullNamespace = NameCoder.namehash(fullDnsName, 0);

        // Make sure the full namespace is not protected and not expired
        if (isProtected[fullNamespace] && expirationTimes[fullNamespace] >= block.timestamp) {
            revert ProtectedNamespace(fullNamespace);
        }
        
        // Set ownership
        owners[fullNamespace] = newOwner;
        
        // Set expiration time
        expirationTimes[fullNamespace] = expirationTime;

        // Set protection
        isProtected[fullNamespace] = protected;
        
        // Store DNS-encoded name
        dnsEncodedNames[fullNamespace] = fullDnsName;
        
        // Emit atomic events
        emit Transfer(fullNamespace, newOwner);
        emit ExpirationSet(fullNamespace, expirationTime);
        emit DnsNameSet(fullNamespace, fullDnsName);
        
        return fullNamespace;
    }

    /// @dev Enable or disable approval for a third party ("operator") to manage
    ///      a specific namespace owned by `msg.sender`. Emits the ApprovalForNamespace event.
    /// @param namespace The specific namespace to approve for.
    /// @param operator Address to add to the set of authorized operators for this namespace.
    /// @param approved True if the operator is approved, false to revoke approval.
    function setApprovalForNamespace(
        bytes32 namespace,
        address operator,
        bool approved
    ) external virtual {
        address namespaceOwner = owners[namespace];
        if (namespaceOwner != msg.sender) {
            revert OnlyNamespaceOwner(namespace, msg.sender, namespaceOwner);
        }
        
        namespaceOperators[namespace][msg.sender][operator] = approved;
        emit ApprovalForNamespace(namespace, msg.sender, operator, approved);
    }

    /* --- Registration Management --- */

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
    ) external returns (bytes32){
        // Calculate namespace hash from DNS-encoded name
        bytes32 namespace = NameCoder.namehash(dnsEncodedName, 0);

        // only authorized addresses can set namespace data if the name is not expired
        if (block.timestamp < expirationTime) {
            if (!_isAuthorized(namespace, msg.sender)) {
                revert Unauthorized(namespace, msg.sender);
            }
        }

        // Set ownership
        owners[namespace] = newOwner;
        
        // Set expiration time
        expirationTimes[namespace] = expirationTime;
        
        // Store DNS-encoded name
        dnsEncodedNames[namespace] = dnsEncodedName;
        
        // Emit atomic events
        emit Transfer(namespace, newOwner);
        emit ExpirationSet(namespace, expirationTime);
        emit DnsNameSet(namespace, dnsEncodedName);
        
        return namespace;
    }
    
    /**
     * @dev Sets namespace expiration time. Only callable by controllers.
     * @param namespace The namespace hash.
     * @param newExpirationTime The new expiration timestamp.
     */
    function setExpiration(
        bytes32 namespace, 
        uint256 newExpirationTime
    ) external onlyRole(CONTROLLER_ROLE) {
        expirationTimes[namespace] = newExpirationTime;
        
        // Emit atomic event
        emit ExpirationSet(namespace, newExpirationTime);
    }

    /* --- View Functions --- */

    /// @dev Returns the address that owns the specified namespace.
    /// @param namespace The specified namespace.
    /// @return address of the owner.
    function owner(
        bytes32 namespace
    ) public view virtual returns (address) {
        address addr = owners[namespace];
        if (addr == address(this)) {
            return address(0x0);
        }
        return addr;
    }

    /// @dev Returns whether a record has been imported to the registry.
    /// @param namespace The specified namespace.
    /// @return Bool if record exists
    function recordExists(
        bytes32 namespace
    ) public view virtual returns (bool) {
        return owners[namespace] != address(0x0);
    }

    /// @dev Query if an address is an authorized operator for a specific namespace.
    /// @param namespace The specific namespace to check.
    /// @param operator The address that acts on behalf of the owner.
    /// @return True if `operator` is an approved operator for this namespace, false otherwise.
    function isApprovedForNamespace(
        bytes32 namespace,
        address operator
    ) external view virtual returns (bool) {
        address namespaceOwner = owners[namespace];
        return namespaceOperators[namespace][namespaceOwner][operator];
    }

    /// @dev Query if an address is authorized for a specific namespace (owner or namespace-approved).
    /// @param namespace The specific namespace to check.
    /// @param operator The address to check authorization for.
    /// @return True if `operator` is authorized for this namespace, false otherwise.
    function isAuthorizedForNamespace(
        bytes32 namespace,
        address operator
    ) external view virtual returns (bool) {
        return _isAuthorized(namespace, operator);
    }

    function isNamespaceActive(bytes32 namespace) external view returns (bool) {
        uint256 expiration = expirationTimes[namespace];
        return expiration > 0 && block.timestamp < expiration;
    }

    function getExpiration(bytes32 namespace) external view returns (uint256) {
        return expirationTimes[namespace];
    }

    function getNamespace(bytes32 namespace) external view returns (uint256 expirationTime, string memory storedDomainName) {
        bytes memory storedDnsEncoded = dnsEncodedNames[namespace];
        if (storedDnsEncoded.length == 0) {
            return (expirationTimes[namespace], "");
        }
        return (expirationTimes[namespace], NameCoder.decode(storedDnsEncoded));
    }

    function isExpired(bytes32 namespace) external view returns (bool) {
        uint256 expiration = expirationTimes[namespace];
        return block.timestamp > expiration;
    }

    /* --- Admin Functions --- */

    /**
     * @dev Adds a new controller. Only callable by admins.
     * @param controller The address of the new controller.
     */
    function addController(address controller) external onlyRole(ADMIN_ROLE) {
        _grantRole(CONTROLLER_ROLE, controller);
    }

    /**
     * @dev Removes a controller. Only callable by admins.
     * @param controller The address of the controller to remove.
     */
    function removeController(address controller) external onlyRole(ADMIN_ROLE) {
        _revokeRole(CONTROLLER_ROLE, controller);
    }


}