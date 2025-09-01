// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../../ICredentialResolver.sol";
import "../../utils/ECSUtils.sol";

/**
 * @title ControlledAccounts
 * @dev A credential resolver for managing controlled accounts on Base blockchain.
 * Controllers can declare multiple accounts they control, and controlled accounts 
 * can verify their controller relationship.
 * Credential key: "eth.ecs.controlled-accounts.accounts"
 */
contract ControlledAccounts is ICredentialResolver, AccessControl {
    using ECSUtils for bytes;
    
    /* --- Roles --- */
    
    bytes32 public constant ADMIN_ROLE = keccak256(bytes("ADMIN_ROLE"));
    
    /* --- Events --- */

    event ControlledAccountsDeclaredInGroup(address indexed controller, bytes32 indexed groupId, address[] accounts);
    event ControlledAccountRemovedFromGroup(address indexed controller, bytes32 indexed groupId, address indexed account);
    event ControllerSet(address indexed controlledAccount, address indexed controller);
    event ControllerRemoved(address indexed controlledAccount, address indexed previousController);
    event TextRecordKeyUpdated(string oldKey, string newKey);


    /* --- Storage --- */

    // The configurable text record key
    string public textRecordKey = "eth.ecs.controlled-accounts.accounts";
    
    // Controller -> groupId -> array of controlled accounts (what the controller declares)
    // bytes32(0) is the default group
    mapping(address controller => mapping(bytes32 groupId => address[] accounts)) public controlledAccounts;
    
    // Controlled account -> controller (what the controlled account declares)
    mapping(address controlled => address controller) public accountController;



    /* --- Constructor --- */

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /* --- Control Functions --- */

    /**
     * @dev Declare a single account as controlled by the caller (default group)
     * @param account The account address to declare as controlled
     */
    function declareControlledAccount(address account) external {
        declareControlledAccount(bytes32(0), account);
    }

    /**
     * @dev Declare multiple accounts as controlled by the caller (default group)
     * @param accounts Array of account addresses to declare as controlled
     */
    function declareControlledAccounts(address[] memory accounts) external {
        declareControlledAccounts(bytes32(0), accounts);
    }

    /**
     * @dev Remove a controlled account from default group
     * @param account The account address to remove from controlled accounts
     */
    function removeControlledAccount(address account) external {
        removeControlledAccount(bytes32(0), account);
    }

    /**
     * @dev Set the controller for the calling account (verification from controlled account side)
     * @param controller The controller address to set (use address(0) to remove)
     */
    function setController(address controller) external {
        address previousController = accountController[msg.sender];
        accountController[msg.sender] = controller;
        
        if (controller == address(0)) {
            emit ControllerRemoved(msg.sender, previousController);
        } else {
            emit ControllerSet(msg.sender, controller);
        }
    }

    /* --- Group Functions --- */

    /**
     * @dev Declare a single account as controlled by the caller in a specific group
     * @param groupId The group identifier (use bytes32(0) for default group)
     * @param account The account address to declare as controlled
     */
    function declareControlledAccount(bytes32 groupId, address account) public {
        controlledAccounts[msg.sender][groupId].push(account);
        
        // Emit event with single account array for consistency
        address[] memory accounts = new address[](1);
        accounts[0] = account;
        
        emit ControlledAccountsDeclaredInGroup(msg.sender, groupId, accounts);
    }

    /**
     * @dev Declare multiple accounts as controlled by the caller in a specific group
     * @param groupId The group identifier (use bytes32(0) for default group)
     * @param accounts Array of account addresses to declare as controlled
     */
    function declareControlledAccounts(bytes32 groupId, address[] memory accounts) public {
        for (uint256 i = 0; i < accounts.length; i++) {
            controlledAccounts[msg.sender][groupId].push(accounts[i]);
        }
        
        emit ControlledAccountsDeclaredInGroup(msg.sender, groupId, accounts);
    }

    /**
     * @dev Remove a controlled account from a specific group
     * @param groupId The group identifier (use bytes32(0) for default group)
     * @param account The account address to remove from controlled accounts
     */
    function removeControlledAccount(bytes32 groupId, address account) public {
        address[] storage accounts = controlledAccounts[msg.sender][groupId];
        
        // Find and remove the account (simple linear search)
        for (uint256 i = 0; i < accounts.length; i++) {
            if (accounts[i] == account) {
                // Move the last element to this position and pop
                accounts[i] = accounts[accounts.length - 1];
                accounts.pop();
                
                emit ControlledAccountRemovedFromGroup(msg.sender, groupId, account);
                return;
            }
        }
        // If we get here, account wasn't found - that's fine, just do nothing
    }

    /* --- View Functions --- */

    /**
     * @dev Get all controlled accounts for a controller (default group)
     * @param controller The controller address
     * @return Array of controlled account addresses
     */
    function getControlledAccounts(address controller) external view returns (address[] memory) {
        return getControlledAccounts(controller, bytes32(0));
    }

    /**
     * @dev Get the controller for a controlled account
     * @param controlledAccount The controlled account address
     * @return The controller address (address(0) if no controller set)
     */
    function getController(address controlledAccount) external view returns (address) {
        return accountController[controlledAccount];
    }

    /**
     * @dev Get all controlled accounts for a controller in a specific group
     * @param controller The controller address
     * @param groupId The group identifier (use bytes32(0) for default group)
     * @return Array of controlled account addresses
     */
    function getControlledAccounts(address controller, bytes32 groupId) public view returns (address[] memory) {
        return controlledAccounts[controller][groupId];
    }



    /**
     * @dev Returns controlled accounts as a string for credential resolution
     * Supports group-specific resolution using credential key format: "key:groupId"
     * Examples: "eth.ecs.controlled-accounts.accounts" (default group) or "eth.ecs.controlled-accounts.accounts:1" (group 1)
     * @param identifier The DNS-encoded identifier containing the controller address and coin type
     * @param _credential The credential key to look up (can include group ID after colon)
     * @return The controlled accounts as a string (one address per line), empty string if key doesn't match
     */
    function credential(bytes calldata identifier, string calldata _credential) external view override returns (string memory) {
        // Parse the credential key to extract group ID
        (string memory baseKey, bytes32 groupId) = _parseCredentialKey(_credential);
        
        if (keccak256(bytes(baseKey)) != keccak256(bytes(textRecordKey))) {
            return "";
        }

        // Parse the identifier: address.cointype.addr.ecs.eth
        (address controllerAddress, ) = ECSUtils.parseIdentifier(bytes(identifier));
        
        return _formatAccountsAsString(controlledAccounts[controllerAddress][groupId]);
    }

    /* --- Admin Functions --- */

    /**
     * @dev Change the text record key (admin only)
     * @param newKey The new text record key
     */
    function setTextRecordKey(string memory newKey) external onlyRole(ADMIN_ROLE) {
        string memory oldKey = textRecordKey;
        textRecordKey = newKey;
        
        emit TextRecordKeyUpdated(oldKey, newKey);
    }

    /* --- Internal Helper Functions --- */

    /**
     * @dev Parse credential key to extract base key and group ID
     * Format: "key:groupId" or just "key" (default group)
     * @param _credential The credential key to parse
     * @return baseKey The base credential key without group ID
     * @return groupId The group ID (bytes32(0) for default group)
     */
    function _parseCredentialKey(string calldata _credential) internal pure returns (string memory baseKey, bytes32 groupId) {
        bytes memory credentialBytes = bytes(_credential);
        
        // Find the colon separator
        for (uint256 i = 0; i < credentialBytes.length; i++) {
            if (credentialBytes[i] == ":") {
                // Extract base key (everything before colon)
                bytes memory baseKeyBytes = new bytes(i);
                for (uint256 j = 0; j < i; j++) {
                    baseKeyBytes[j] = credentialBytes[j];
                }
                baseKey = string(baseKeyBytes);
                
                // Extract group ID (everything after colon)
                uint256 groupIdLength = credentialBytes.length - i - 1;
                if (groupIdLength > 0) {
                    bytes memory groupIdBytes = new bytes(groupIdLength);
                    for (uint256 j = 0; j < groupIdLength; j++) {
                        groupIdBytes[j] = credentialBytes[i + 1 + j];
                    }
                    groupId = keccak256(groupIdBytes);
                } else {
                    groupId = bytes32(0);
                }
                
                return (baseKey, groupId);
            }
        }
        
        // No colon found, use entire string as base key and default group
        return (_credential, bytes32(0));
    }

    /**
     * @dev Format an array of addresses as a string with one address per line
     * @param accounts Array of account addresses
     * @return Formatted string with addresses (one per line)
     */
    function _formatAccountsAsString(address[] memory accounts) internal pure returns (string memory) {
        if (accounts.length == 0) {
            return "";
        }
        
        bytes memory result;
        
        for (uint256 i = 0; i < accounts.length; i++) {
            // Convert address to hex string with 0x prefix
            bytes memory addressStr = ECSUtils.addressToHexString(accounts[i]);
            
            if (i == 0) {
                result = addressStr;
            } else {
                result = abi.encodePacked(result, "\n", addressStr);
            }
        }
        
        return string(result);
    }
}
