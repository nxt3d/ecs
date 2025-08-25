// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./ECSRegistry.sol";
import "./utils/NameCoder.sol";
import "./utils/ECSStringUtils.sol";

/**
 * @title ECSRegistrarController
 * @dev Controller for registering and managing ECS namespaces
 */
contract ECSRegistrarController is AccessControl {
    using ECSStringUtils for string;
    
    /* --- Roles --- */
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    /* --- Types --- */
    
    ECSRegistry public immutable registry;
    string public baseDomain = "ecs.eth";
    
    /* --- Constants --- */
    
    uint256 public feePerSecond = 1 wei; // 1 wei per second (can be set to 0 for free registrations)
    uint256 public constant MINIMUM_REGISTRATION_DURATION = 30 days;
    uint256 public constant MAXIMUM_REGISTRATION_DURATION = 10 * 365 days;

    // min and max label length (updateable by admin)
    uint256 public minLabelLength = 3;
    uint256 public maxLabelLength = 63;
    
    /* --- Events --- */
    
    event NamespaceRegistered(string indexed label, bytes32 indexed namespace, address indexed owner, uint256 duration);
    event NamespaceRenewed(bytes32 indexed namespace, address indexed owner, uint256 duration);
    event FeePerSecondUpdated(uint256 oldFee, uint256 newFee);
    
    /* --- Errors --- */
    
    error InvalidDuration(uint256 duration);
    error InvalidName(string name);
    error InsufficientFee(uint256 required, uint256 provided);
    error NamespaceNotExpired(bytes32 namespace);
    error UnauthorizedAccess(address caller, bytes32 namespace);
    error UnauthorizedFeeUpdate(address caller);
    error NamespaceExpired(bytes32 namespace);
    
    /* --- Constructor --- */
    
    constructor(ECSRegistry _registry, string memory _baseDomain) {
        registry = _registry;
        baseDomain = _baseDomain;
        
        // Grant the deployer the admin role
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /* --- Registration Functions --- */

    /**
     * @dev Register a new namespace
     * @param label The namespace label (label only)
     * @param duration Registration duration in seconds
     * @return namespace The namespace hash
     */
    function registerNamespace(string calldata label, uint256 duration) external payable returns (bytes32) {

        // validate duration
        if (duration < MINIMUM_REGISTRATION_DURATION || duration > MAXIMUM_REGISTRATION_DURATION) {
            revert InvalidDuration(duration);
        }

        // Validate label (only a-z, 0-9, hyphens allowed, no hyphens at ends)
        if (bytes(label).length == 0 || !_isValidLabel(label)) {
            revert InvalidName(label);
        }

        // validate fee
        uint256 fee = calculateFee(duration);
        if (msg.value < fee) {
            revert InsufficientFee(fee, msg.value);
        }

        // Set namespace data in registry
        uint256 expirationTime = block.timestamp + duration;

        // Set namespace data in registry, set the expiration time, and set the protection to true. This will create a protected namespace.
        bytes32 namespace = registry.setSubnameOwner(label, baseDomain, msg.sender, expirationTime, true);

        emit NamespaceRegistered(label, namespace, msg.sender, duration);
        
        return namespace;
    }

    /**
     * @dev Renew an existing namespace
     * @param namespace The namespace hash
     * @param duration Additional duration in seconds
     */
    function renewNamespace(bytes32 namespace, uint256 duration) external payable {

        // make sure the name is not expired
        if (registry.isExpired(namespace)) {
            revert NamespaceExpired(namespace);
        }

        // validate duration
        if (duration < MINIMUM_REGISTRATION_DURATION || duration > MAXIMUM_REGISTRATION_DURATION) {
            revert InvalidDuration(duration);
        }

        // Allow only authorized addresses to renew a namespace
        if (!registry.isAuthorizedForNamespace(namespace, msg.sender)) {
            revert UnauthorizedAccess(msg.sender, namespace);
        }

        // validate fee
        uint256 fee = calculateFee(duration);
        if (msg.value < fee) {
            revert InsufficientFee(fee, msg.value);
        }

        // Extend expiration time
        uint256 currentExpiration = registry.getExpiration(namespace);
        uint256 newExpiration = currentExpiration + duration;

        registry.setExpiration(namespace, newExpiration);

        emit NamespaceRenewed(namespace, msg.sender, duration);
    }

    /* --- View Functions --- */

    /**
     * @dev Calculate registration fee for a duration
     * @param duration Registration duration in seconds
     * @return The fee amount
     * @notice If feePerSecond is 0, registrations will be free (fee = 0)
     */
    function calculateFee(uint256 duration) public view returns (uint256) {
        return duration * feePerSecond;
    }
    
    /**
     * @dev Check if a namespace is available for registration
     * @param label The namespace label (label only)
     * @return True if available
     */
    function isNamespaceAvailable(string calldata label) external view returns (bool) {
        // 1. Concatenate label with base domain as strings
        string memory fullName;
        if (bytes(baseDomain).length == 0) {
            // Base domain is root, just use the label
            fullName = label;
        } else {
            // Base domain is not root, concatenate with dot
            fullName = string(abi.encodePacked(label, ".", baseDomain));
        }
        
        // 2. Convert to DNS-encoded format and calculate namespace hash
        bytes memory fullDnsEncodedName = NameCoder.encode(fullName);
        bytes32 namespace = NameCoder.namehash(fullDnsEncodedName, 0);
        
        return registry.isExpired(namespace);
    }

    /* --- Admin Functions --- */

    /**
     * @dev Withdraw collected fees (only admin)
     */
    function withdrawFees() external onlyRole(ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = payable(msg.sender).call{value: balance}("");
            require(success, "Transfer failed");
        }
    }

    /**
     * @dev Update the fee per second (only admin)
     * @param newFeePerSecond The new fee per second amount
     */
    function updateFeePerSecond(uint256 newFeePerSecond) external onlyRole(ADMIN_ROLE) {
        uint256 oldFee = feePerSecond;
        feePerSecond = newFeePerSecond;
        
        emit FeePerSecondUpdated(oldFee, newFeePerSecond);
    }

    /**
     * @dev Update the minimum label length (only admin)
     * @param newMinLabelLength The new minimum label length
     */
    function updateMinLabelLength(uint256 newMinLabelLength) external onlyRole(ADMIN_ROLE) {
        minLabelLength = newMinLabelLength;
    }

    /**
     * @dev Update the maximum label length (only admin)
     * @param newMaxLabelLength The new maximum label length
     */
    function updateMaxLabelLength(uint256 newMaxLabelLength) external onlyRole(ADMIN_ROLE) {
        maxLabelLength = newMaxLabelLength;
    }

    /* --- Internal Functions --- */
    
    /**
     * @dev Validate a DNS label format
     * @param label The label to validate
     * @return True if the label is valid
     */
    function _isValidLabel(string calldata label) internal pure returns (bool) {
        bytes memory labelBytes = bytes(label);
        uint256 length = labelBytes.length;
        
        // Empty labels are invalid
        if (length == 0) {
            return false;
        }
        
        // Labels cannot start or end with hyphens
        if (labelBytes[0] == 0x2D || labelBytes[length - 1] == 0x2D) { // 0x2D is hyphen
            return false;
        }
        
        // Check each character
        for (uint256 i = 0; i < length; i++) {
            bytes1 char = labelBytes[i];
            
            // Allow a-z (0x61-0x7A)
            if (char >= 0x61 && char <= 0x7A) {
                continue;
            }
            
            // Allow 0-9 (0x30-0x39)
            if (char >= 0x30 && char <= 0x39) {
                continue;
            }
            
            // Allow hyphens (0x2D)
            if (char == 0x2D) {
                continue;
            }
            
            // Any other character is invalid
            return false;
        }
        
        return true;
    }


} 