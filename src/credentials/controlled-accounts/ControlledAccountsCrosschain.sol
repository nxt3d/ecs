// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../../ICredentialResolver.sol";
import "../../utils/ECSUtils.sol";

/**
 * @title ControlledAccountsCrosschain
 * @dev A credential resolver for managing controlled accounts across multiple chains.
 * Controllers can declare multiple accounts they control on different chains, and controlled accounts 
 * can verify their controller relationship across chains.
 * Credential key: "eth.ecs.controlled-accounts.accounts"
 * Supports chain-specific groups and cross-chain controller verification.
 */
contract ControlledAccountsCrosschain is ICredentialResolver, AccessControl {
    using ECSUtils for bytes;
    
    /* --- Roles --- */
    
    bytes32 public constant ADMIN_ROLE = keccak256(bytes("ADMIN_ROLE"));
    
    /* --- Events --- */

    event ControlledAccountsDeclaredInGroup(address indexed controller, uint256 indexed chainId, bytes32 indexed groupId, address[] accounts);
    event ControlledAccountRemovedFromGroup(address indexed controller, uint256 indexed chainId, bytes32 indexed groupId, address account);
    event ControllerSet(address indexed controlledAccount, uint256 indexed chainId, address indexed controller);
    event ControllerRemoved(address indexed controlledAccount, uint256 indexed chainId, address previousController);
    event TextRecordKeyUpdated(string oldKey, string newKey);


    /* --- Storage --- */

    // The configurable text record key
    string public textRecordKey = "eth.ecs.controlled-accounts.accounts";
    
    // Controller -> chainId -> groupId -> array of controlled accounts (what the controller declares)
    // bytes32(0) is the default group
    mapping(address controller => mapping(uint256 chainId => mapping(bytes32 groupId => address[] accounts))) public controlledAccounts;
    
    // Controlled account -> chainId -> controller -> isController (what the controlled account declares)
    mapping(address controlled => mapping(uint256 chainId => mapping(address controller => bool isController))) public accountController;



    /* --- Constructor --- */

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /* --- Control Functions --- */

    /**
     * @dev Declare a single account as controlled by the caller (default group, current chain)
     * @param account The account address to declare as controlled
     */
    function declareControlledAccount(address account) external {
        declareControlledAccount(block.chainid, bytes32(0), account);
    }

    /**
     * @dev Declare multiple accounts as controlled by the caller (default group, current chain)
     * @param accounts Array of account addresses to declare as controlled
     */
    function declareControlledAccounts(address[] memory accounts) external {
        declareControlledAccounts(block.chainid, bytes32(0), accounts);
    }

    /**
     * @dev Remove a controlled account from default group (current chain)
     * @param account The account address to remove from controlled accounts
     */
    function removeControlledAccount(address account) external {
        removeControlledAccount(block.chainid, bytes32(0), account);
    }

    /**
     * @dev Set the controller for the calling account (verification from controlled account side, current chain)
     * @param controller The controller address to set (use address(0) to remove)
     */
    function setController(address controller) external {
        setController(block.chainid, controller);
    }

    /* --- Group Functions --- */

    /**
     * @dev Declare a single account as controlled by the caller in a specific group on a specific chain
     * @param chainId The chain ID where the controlled account exists
     * @param groupId The group identifier (use bytes32(0) for default group)
     * @param account The account address to declare as controlled
     */
    function declareControlledAccount(uint256 chainId, bytes32 groupId, address account) public {
        controlledAccounts[msg.sender][chainId][groupId].push(account);
        
        // Emit event with single account array for consistency
        address[] memory accounts = new address[](1);
        accounts[0] = account;
        
        emit ControlledAccountsDeclaredInGroup(msg.sender, chainId, groupId, accounts);
    }

    /**
     * @dev Declare multiple accounts as controlled by the caller in a specific group on a specific chain
     * @param chainId The chain ID where the controlled accounts exist
     * @param groupId The group identifier (use bytes32(0) for default group)
     * @param accounts Array of account addresses to declare as controlled
     */
    function declareControlledAccounts(uint256 chainId, bytes32 groupId, address[] memory accounts) public {
        for (uint256 i = 0; i < accounts.length; i++) {
            controlledAccounts[msg.sender][chainId][groupId].push(accounts[i]);
        }
        
        emit ControlledAccountsDeclaredInGroup(msg.sender, chainId, groupId, accounts);
    }

    /**
     * @dev Remove a controlled account from a specific group on a specific chain
     * @param chainId The chain ID where the controlled account exists
     * @param groupId The group identifier (use bytes32(0) for default group)
     * @param account The account address to remove from controlled accounts
     */
    function removeControlledAccount(uint256 chainId, bytes32 groupId, address account) public {
        address[] storage accounts = controlledAccounts[msg.sender][chainId][groupId];
        
        // Find and remove the account (simple linear search)
        for (uint256 i = 0; i < accounts.length; i++) {
            if (accounts[i] == account) {
                // Move the last element to this position and pop
                accounts[i] = accounts[accounts.length - 1];
                accounts.pop();
                
                emit ControlledAccountRemovedFromGroup(msg.sender, chainId, groupId, account);
                return;
            }
        }
        // If we get here, account wasn't found - that's fine, just do nothing
    }

    /**
     * @dev Set the controller for the calling account on a specific chain (verification from controlled account side)
     * @param chainId The chain ID where the controller relationship exists
     * @param controller The controller address to set
     */
    function setController(uint256 chainId, address controller) public {
        require(controller != address(0), "Controller cannot be zero address");
        
        // Set this specific controller
        accountController[msg.sender][chainId][controller] = true;
        emit ControllerSet(msg.sender, chainId, controller);
    }

    /**
     * @dev Remove a specific controller for the calling account on a specific chain
     * @param chainId The chain ID where the controller relationship exists
     * @param controller The controller address to remove
     */
    function removeController(uint256 chainId, address controller) public {
        require(controller != address(0), "Controller cannot be zero address");
        
        // Remove this specific controller
        accountController[msg.sender][chainId][controller] = false;
        emit ControllerRemoved(msg.sender, chainId, controller);
    }

    /**
     * @dev Set the controller for an account using a signature (for smart accounts that can't directly call setController)
     * The signature must be from the controlled account's private key, and the relationship is stored with chain ID 0
     * @param controlledAccount The account that is being controlled
     * @param controller The controller address to set
     * @param signature The signature from the controlled account's private key
     */
    function setControllerWithSignature(address controlledAccount, address controller, bytes calldata signature) public {
        // Create the message hash that should be signed
        bytes32 messageHash = keccak256(abi.encodePacked(
            "ControlledAccounts: setControllerWithSignature",
            controlledAccount,
            controller,
            address(this)
        ));
        
        // Convert to Ethereum signed message hash
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            messageHash
        ));
        
        // Recover the signer
        address signer = _recoverSigner(ethSignedMessageHash, signature);
        
        // Verify that the signer is the controlled account
        require(signer == controlledAccount, "Invalid signature: signer must be the controlled account");
        
        // Set the controller relationship with chain ID 0 (default/cross-chain indicator)
        accountController[controlledAccount][0][controller] = true;
        emit ControllerSet(controlledAccount, 0, controller);
    }

    /* --- View Functions --- */

    /**
     * @dev Get all controlled accounts for a controller (default group, current chain)
     * @param controller The controller address
     * @return Array of controlled account addresses
     */
    function getControlledAccounts(address controller) external view returns (address[] memory) {
        return getControlledAccounts(controller, block.chainid, bytes32(0));
    }

    /**
     * @dev Check if a specific controller is set for a controlled account (current chain)
     * @param controlledAccount The controlled account address
     * @param controller The controller address to check
     * @return True if the controller is set for this account
     */
    function isController(address controlledAccount, address controller) external view returns (bool) {
        return isController(controlledAccount, block.chainid, controller);
    }

    /**
     * @dev Get all controlled accounts for a controller in a specific group on a specific chain
     * @param controller The controller address
     * @param chainId The chain ID where the controlled accounts exist
     * @param groupId The group identifier (use bytes32(0) for default group)
     * @return Array of controlled account addresses
     */
    function getControlledAccounts(address controller, uint256 chainId, bytes32 groupId) public view returns (address[] memory) {
        return controlledAccounts[controller][chainId][groupId];
    }

    /**
     * @dev Check if a specific controller is set for a controlled account on a specific chain
     * @param controlledAccount The controlled account address
     * @param chainId The chain ID where the controller relationship exists
     * @param controller The controller address to check
     * @return True if the controller is set for this account on this chain
     */
    function isController(address controlledAccount, uint256 chainId, address controller) public view returns (bool) {
        return accountController[controlledAccount][chainId][controller];
    }



    /**
     * @dev Returns controlled accounts as a string for credential resolution
     * Supports chain-specific and group-specific resolution using credential key format: "key:chainId:groupId"
     * Only returns accounts that have verified the controller relationship (either on the specified chain or default chain ID 0)
     * Examples: 
     *   "eth.ecs.controlled-accounts.accounts" (default group, current chain)
     *   "eth.ecs.controlled-accounts.accounts:1" (group 1, current chain)
     *   "eth.ecs.controlled-accounts.accounts:8453" (default group, Base chain)
     *   "eth.ecs.controlled-accounts.accounts:8453:main" (main group, Base chain)
     * @param identifier The controller address (as bytes)
     * @param _credential The credential key to look up (can include chain ID and group ID after colons)
     * @return The verified controlled accounts as a string (one address per line), empty string if key doesn't match
     */
    function credential(bytes calldata identifier, string calldata _credential) external view override returns (string memory) {
        // Parse the credential key to extract chain ID and group ID
        (string memory baseKey, uint256 chainId, bytes32 groupId) = _parseCredentialKey(_credential);

        // Check if the base key matches the text record key
        if (keccak256(bytes(baseKey)) != keccak256(bytes(textRecordKey))) {
            return "";
        }

        // Convert identifier bytes directly to address (assuming it's 20 bytes)
        require(identifier.length == 20, "Invalid identifier length");
        address controllerAddress = address(bytes20(identifier));
        
        // Get all accounts declared by the controller
        address[] memory declaredAccounts = controlledAccounts[controllerAddress][chainId][groupId];
        
        // Filter to only include accounts that have verified the controller relationship
        address[] memory verifiedAccounts = new address[](declaredAccounts.length);
        uint256 verifiedCount = 0;
        
        for (uint256 i = 0; i < declaredAccounts.length; i++) {
            address account = declaredAccounts[i];
            
            // Check if the account has verified the controller on the specified chain
            // OR on the default chain ID (0) for cross-chain verification
            if (accountController[account][chainId][controllerAddress] || 
                accountController[account][0][controllerAddress]) {
                verifiedAccounts[verifiedCount] = account;
                verifiedCount++;
            }
        }
        
        // Create a properly sized array for the verified accounts
        address[] memory resultAccounts = new address[](verifiedCount);
        for (uint256 i = 0; i < verifiedCount; i++) {
            resultAccounts[i] = verifiedAccounts[i];
        }
        
        return _formatAccountsAsString(resultAccounts);
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
     * @dev Parse credential key to extract base key, chain ID, and group ID
     * Format: "key:chainId:groupId" or "key:chainId" or "key:groupId" or just "key"
     * @param _credential The credential key to parse
     * @return baseKey The base credential key without chain ID and group ID
     * @return chainId The chain ID (block.chainid for current chain if not specified)
     * @return groupId The group ID (bytes32(0) for default group)
     */
    function _parseCredentialKey(string calldata _credential) internal view returns (string memory baseKey, uint256 chainId, bytes32 groupId) {
        bytes memory credentialBytes = bytes(_credential);
        
        // Find first colon separator
        uint256 firstColon = 0;
        for (uint256 i = 0; i < credentialBytes.length; i++) {
            if (credentialBytes[i] == ":") {
                firstColon = i;
                break;
            }
        }
        
        if (firstColon == 0) {
            // No colon found, use entire string as base key, current chain, default group
            return (_credential, block.chainid, bytes32(0));
        }
        
        // Extract base key (everything before first colon)
        bytes memory baseKeyBytes = new bytes(firstColon);
        for (uint256 j = 0; j < firstColon; j++) {
            baseKeyBytes[j] = credentialBytes[j];
        }
        baseKey = string(baseKeyBytes);
        
        // Find second colon separator
        uint256 secondColon = 0;
        for (uint256 i = firstColon + 1; i < credentialBytes.length; i++) {
            if (credentialBytes[i] == ":") {
                secondColon = i;
                break;
            }
        }
        
        if (secondColon == 0) {
            // Only one colon found - could be chain ID or group ID
            uint256 remainingLength = credentialBytes.length - firstColon - 1;
            if (remainingLength > 0) {
                bytes memory remainingBytes = new bytes(remainingLength);
                for (uint256 j = 0; j < remainingLength; j++) {
                    remainingBytes[j] = credentialBytes[firstColon + 1 + j];
                }
                string memory remaining = string(remainingBytes);
                
                // Try to parse as chain ID (numeric)
                if (_isNumeric(remaining)) {
                    chainId = _parseUint256(remaining);
                    groupId = bytes32(0); // default group
                } else {
                    // Treat as group ID
                    chainId = block.chainid; // current chain
                    groupId = keccak256(remainingBytes);
                }
            } else {
                chainId = block.chainid;
                groupId = bytes32(0);
            }
        } else {
            // Two colons found - first is chain ID, second is group ID
            uint256 chainIdLength = secondColon - firstColon - 1;
            if (chainIdLength > 0) {
                bytes memory chainIdBytes = new bytes(chainIdLength);
                for (uint256 j = 0; j < chainIdLength; j++) {
                    chainIdBytes[j] = credentialBytes[firstColon + 1 + j];
                }
                chainId = _parseUint256(string(chainIdBytes));
            } else {
                chainId = block.chainid;
            }
            
            uint256 groupIdLength = credentialBytes.length - secondColon - 1;
            if (groupIdLength > 0) {
                bytes memory groupIdBytes = new bytes(groupIdLength);
                for (uint256 j = 0; j < groupIdLength; j++) {
                    groupIdBytes[j] = credentialBytes[secondColon + 1 + j];
                }
                groupId = keccak256(groupIdBytes);
            } else {
                groupId = bytes32(0);
            }
        }
        
        return (baseKey, chainId, groupId);
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

    /**
     * @dev Check if a string is numeric (contains only digits)
     * @param str The string to check
     * @return True if the string is numeric
     */
    function _isNumeric(string memory str) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        if (strBytes.length == 0) return false;
        
        for (uint256 i = 0; i < strBytes.length; i++) {
            if (strBytes[i] < bytes1('0') || strBytes[i] > bytes1('9')) {
                return false;
            }
        }
        return true;
    }

    /**
     * @dev Parse a string to uint256
     * @param str The string to parse
     * @return The parsed uint256 value
     */
    function _parseUint256(string memory str) internal pure returns (uint256) {
        bytes memory strBytes = bytes(str);
        uint256 result = 0;
        
        for (uint256 i = 0; i < strBytes.length; i++) {
            result = result * 10 + (uint256(uint8(strBytes[i])) - uint256(uint8(bytes1('0'))));
        }
        
        return result;
    }

    /**
     * @dev Recover the signer address from a signature
     * @param ethSignedMessageHash The Ethereum signed message hash
     * @param signature The signature bytes
     * @return The recovered signer address
     */
    function _recoverSigner(bytes32 ethSignedMessageHash, bytes memory signature) internal pure returns (address) {
        require(signature.length == 65, "Invalid signature length");
        
        bytes32 r;
        bytes32 s;
        uint8 v;
        
        // Extract r, s, v from signature
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
        
        // Handle signature malleability
        if (v < 27) {
            v += 27;
        }
        
        require(v == 27 || v == 28, "Invalid signature v value");
        
        return ecrecover(ethSignedMessageHash, v, r, s);
    }
}
