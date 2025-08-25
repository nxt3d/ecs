// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./ECSRegistry.sol";
import "./utils/NameCoder.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RootController
 * @dev Controls the root namespace (0x0) of the ECS registry
 * @notice Manages top-level domain creation and locking
 */
contract RootController is AccessControl {
    bytes32 private constant ROOT_NAMESPACE = bytes32(0);
    
    /* --- Roles --- */
    
    bytes32 public constant ADMIN_ROLE = keccak256(bytes("ADMIN_ROLE"));
    bytes32 public constant CONTROLLER_ROLE = keccak256(bytes("CONTROLLER_ROLE"));

    /* --- Events --- */

    event TLDLocked(bytes32 indexed label);

    /* --- Storage --- */

    ECSRegistry public ecs;
    mapping(string label => bool isLocked) public locked;

    /* --- Constructor --- */

    constructor(ECSRegistry _ecs) {
        ecs = _ecs;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(CONTROLLER_ROLE, msg.sender);
    }

    /* --- Controller Functions --- */

    /**
     * @dev Sets the owner of a top-level domain
     * @param label The domain label (e.g., "eth")  
     * @param owner The new owner address
     */
    function setSubnameOwner(string memory label, address owner) external {
        require(!locked[label], "TLD is locked");
        require(hasRole(CONTROLLER_ROLE, msg.sender), "Access denied");
        
        // For TLD creation, parent is root (empty string)
        string memory rootDomainName = "";
        
        // Set expiration to far future for TLDs (essentially never expire)
        uint256 expirationTime = type(uint256).max;
        
        ecs.setSubnameOwner(label, rootDomainName, owner, expirationTime, false);
    }

    /* --- Admin Functions --- */

    function lock(string memory label) external onlyRole(ADMIN_ROLE) {
        emit TLDLocked(keccak256(bytes(label)));
        locked[label] = true;
    }

    function addController(address controller) external onlyRole(ADMIN_ROLE) {
        _grantRole(CONTROLLER_ROLE, controller);
    }

    function removeController(address controller) external onlyRole(ADMIN_ROLE) {
        _revokeRole(CONTROLLER_ROLE, controller);
    }

    /* --- View Functions --- */

    function isLocked(string memory label) public view returns (bool) {
        return locked[label];
    }

    function supportsInterface(
        bytes4 interfaceID
    ) public view override returns (bool) {
        return super.supportsInterface(interfaceID);
    }
}