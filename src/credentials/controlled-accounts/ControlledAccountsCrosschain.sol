// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../../ICredentialResolver.sol";
import "../../utils/ECSUtils.sol";

/**
 * @title ControlledAccountsCrosschain
 * @dev A credential resolver for managing controlled accounts across multiple coin types.
 * Controllers can declare multiple accounts they control on different coin types, and controlled accounts 
 * can verify their controller relationship across coin types.
 * Credential key: "eth.ecs.controlled-accounts.accounts"
 * Supports coin-type-specific groups and cross-coin-type controller verification.
 */
contract ControlledAccountsCrosschain is ICredentialResolver, AccessControl {
    using ECSUtils for bytes;
    
    /* --- Roles --- */
    
    bytes32 public constant ADMIN_ROLE = keccak256(bytes("ADMIN_ROLE"));
    
    /* --- Events --- */

    event ControlledAccountsDeclaredInGroup(address indexed controller, uint256 indexed coinType, bytes32 indexed groupId, address[] accounts);
    event ControlledAccountRemovedFromGroup(address indexed controller, uint256 indexed coinType, bytes32 indexed groupId, address account);
    event ControllerSet(address indexed controlledAccount, uint256 indexed coinType, address indexed controller);
    event ControllerRemoved(address indexed controlledAccount, uint256 indexed coinType, address previousController);
    event TextRecordKeyUpdated(string oldKey, string newKey);


    /* --- Storage --- */

    // The configurable text record key
    string public textRecordKey = "eth.ecs.controlled-accounts.accounts";
    
    // Controller -> coinType -> groupId -> array of controlled accounts (what the controller declares)
    // bytes32(0) is the default group
    mapping(address controller => mapping(uint256 coinType => mapping(bytes32 groupId => address[] accounts))) public controlledAccounts;
    
    // Controlled account -> coinType -> controller -> isController (what the controlled account declares)
    mapping(address controlled => mapping(uint256 coinType => mapping(address controller => bool isController))) public accountController;



    /* --- Constructor --- */

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /* --- Chain ID to Coin Type Conversion --- */

    /**
     * @dev Convert a chain ID to its corresponding ENS coin type
     * @param chainId The EVM chain ID to convert
     * @return coinType The corresponding ENS coin type
     */
    function chainIdToCoinType(uint256 chainId) public pure returns (uint256 coinType) {
        // ENS EVM coin type formula: 0x80000000 | chainId
        // This ensures no collision with SLIP44 coin types
        require(chainId < 0x80000000, "Chain ID too large for EVM coin type conversion");
        return 0x80000000 | chainId;
    }

    /**
     * @dev Convert a coin type back to its corresponding chain ID
     * @param coinType The ENS coin type to convert
     * @return chainId The corresponding EVM chain ID
     */
    function coinTypeToChainId(uint256 coinType) public pure returns (uint256 chainId) {
        // Check if it's an EVM coin type (has the 0x80000000 bit set)
        require((coinType & 0x80000000) != 0, "Not an EVM coin type");
        return coinType & 0x7FFFFFFF; // Remove the MSB
    }

    /**
     * @dev Validate if a coin type is valid for msg.sender (current chain only)
     * @param coinType The coin type to validate
     * @return isValid True if the coin type matches current chain
     */
    function isValidCoinType(uint256 coinType) public view returns (bool isValid) {
        // Only allow current chain's coin type for msg.sender
        uint256 currentChainCoinType = chainIdToCoinType(block.chainid);
        return coinType == currentChainCoinType;
    }
    
    /**
     * @dev Validate if a coin type is valid for signed messages (current chain or coin type 0)
     * @param coinType The coin type to validate
     * @return isValid True if the coin type is current chain or coin type 0
     */
    function isValidCoinTypeForSignature(uint256 coinType) public view returns (bool isValid) {
        // Allow current chain's coin type
        uint256 currentChainCoinType = chainIdToCoinType(block.chainid);
        if (coinType == currentChainCoinType) {
            return true;
        }
        
        // Allow coin type 0 for cross-coin-type relationships
        return coinType == 0;
    }

    /* --- Control Functions --- */

    /**
     * @dev Declare a single account as controlled by the caller (default group, current coin type)
     * @param account The account address to declare as controlled
     */
    function declareControlledAccount(address account) external {
        declareControlledAccount(block.chainid, bytes32(0), account);
    }

    /**
     * @dev Declare multiple accounts as controlled by the caller (default group, current coin type)
     * @param accounts Array of account addresses to declare as controlled
     */
    function declareControlledAccounts(address[] memory accounts) external {
        declareControlledAccounts(block.chainid, bytes32(0), accounts);
    }

    /**
     * @dev Remove a controlled account from default group (current coin type)
     * @param account The account address to remove from controlled accounts
     */
    function removeControlledAccount(address account) external {
        removeControlledAccount(block.chainid, bytes32(0), account);
    }

    /**
     * @dev Set the controller for the calling account (verification from controlled account side, current coin type)
     * @param controller The controller address to set (use address(0) to remove)
     */
    function setController(address controller) external {
        setController(block.chainid, controller);
    }

    /* --- Group Functions --- */

    /**
     * @dev Declare a single account as controlled by the caller in a specific group on a specific coin type
     * @param coinType The coin type where the controlled account exists
     * @param groupId The group identifier (use bytes32(0) for default group)
     * @param account The account address to declare as controlled
     */
    function declareControlledAccount(uint256 coinType, bytes32 groupId, address account) public {
        require(isValidCoinType(coinType), "Invalid coin type for current chain");
        controlledAccounts[msg.sender][coinType][groupId].push(account);
        
        // Emit event with single account array for consistency
        address[] memory accounts = new address[](1);
        accounts[0] = account;
        
        emit ControlledAccountsDeclaredInGroup(msg.sender, coinType, groupId, accounts);
    }

    /**
     * @dev Declare multiple accounts as controlled by the caller in a specific group on a specific coin type
     * @param coinType The coin type where the controlled accounts exist
     * @param groupId The group identifier (use bytes32(0) for default group)
     * @param accounts Array of account addresses to declare as controlled
     */
    function declareControlledAccounts(uint256 coinType, bytes32 groupId, address[] memory accounts) public {
        require(isValidCoinType(coinType), "Invalid coin type for current chain");
        for (uint256 i = 0; i < accounts.length; i++) {
            controlledAccounts[msg.sender][coinType][groupId].push(accounts[i]);
        }
        
        emit ControlledAccountsDeclaredInGroup(msg.sender, coinType, groupId, accounts);
    }

    /**
     * @dev Remove a controlled account from a specific group on a specific coin type
     * @param coinType The coin type where the controlled account exists
     * @param groupId The group identifier (use bytes32(0) for default group)
     * @param account The account address to remove from controlled accounts
     */
    function removeControlledAccount(uint256 coinType, bytes32 groupId, address account) public {
        require(isValidCoinType(coinType), "Invalid coin type for current chain");
        address[] storage accounts = controlledAccounts[msg.sender][coinType][groupId];
        
        // Find and remove the account (simple linear search)
        for (uint256 i = 0; i < accounts.length; i++) {
            if (accounts[i] == account) {
                // Move the last element to this position and pop
                accounts[i] = accounts[accounts.length - 1];
                accounts.pop();
                
                emit ControlledAccountRemovedFromGroup(msg.sender, coinType, groupId, account);
                return;
            }
        }
        // If we get here, account wasn't found - that's fine, just do nothing
    }

    /**
     * @dev Set the controller for the calling account on a specific coin type (verification from controlled account side)
     * @param coinType The coin type where the controller relationship exists
     * @param controller The controller address to set
     */
    function setController(uint256 coinType, address controller) public {
        require(isValidCoinType(coinType), "Invalid coin type for current chain");
        require(controller != address(0), "Controller cannot be zero address");
        
        // Set this specific controller
        accountController[msg.sender][coinType][controller] = true;
        emit ControllerSet(msg.sender, coinType, controller);
    }

    /**
     * @dev Remove a specific controller for the calling account on a specific coin type
     * @param coinType The coin type where the controller relationship exists
     * @param controller The controller address to remove
     */
    function removeController(uint256 coinType, address controller) public {
        require(isValidCoinType(coinType), "Invalid coin type for current chain");
        require(controller != address(0), "Controller cannot be zero address");
        
        // Remove this specific controller
        accountController[msg.sender][coinType][controller] = false;
        emit ControllerRemoved(msg.sender, coinType, controller);
    }

    /**
     * @dev Set the controller for an account using a signature (for smart accounts that can't directly call setController)
     * The signature must be from the controlled account's private key
     * @param controlledAccount The account that is being controlled
     * @param coinType The coin type for the controller relationship (must be current chain or 0)
     * @param controller The controller address to set
     * @param signature The signature from the controlled account's private key
     */
    function setControllerWithSignature(address controlledAccount, uint256 coinType, address controller, bytes calldata signature) public {
        require(isValidCoinTypeForSignature(coinType), "Invalid coin type for signature-based controller setting");
        require(controller != address(0), "Controller cannot be zero address");
        
        // Create the message hash that should be signed
        bytes32 messageHash = keccak256(abi.encodePacked(
            "ControlledAccounts: setControllerWithSignature",
            controlledAccount,
            coinType,
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
        
        // Set the controller relationship
        accountController[controlledAccount][coinType][controller] = true;
        emit ControllerSet(controlledAccount, coinType, controller);
    }

    /* --- View Functions --- */

    /**
     * @dev Get all controlled accounts for a controller (default group, current coin type)
     * @param controller The controller address
     * @return Array of controlled account addresses
     */
    function getControlledAccounts(address controller) external view returns (address[] memory) {
        return getControlledAccounts(controller, block.chainid, bytes32(0));
    }

    /**
     * @dev Check if a specific controller is set for a controlled account (current coin type)
     * @param controlledAccount The controlled account address
     * @param controller The controller address to check
     * @return True if the controller is set for this account
     */
    function isController(address controlledAccount, address controller) external view returns (bool) {
        return isController(controlledAccount, block.chainid, controller);
    }

    /**
     * @dev Get all controlled accounts for a controller in a specific group on a specific coin type
     * @param controller The controller address
     * @param coinType The coin type where the controlled accounts exist
     * @param groupId The group identifier (use bytes32(0) for default group)
     * @return Array of controlled account addresses
     */
    function getControlledAccounts(address controller, uint256 coinType, bytes32 groupId) public view returns (address[] memory) {
        return controlledAccounts[controller][coinType][groupId];
    }

    /**
     * @dev Check if a specific controller is set for a controlled account on a specific coin type
     * @param controlledAccount The controlled account address
     * @param coinType The coin type where the controller relationship exists
     * @param controller The controller address to check
     * @return True if the controller is set for this account on this coin type
     */
    function isController(address controlledAccount, uint256 coinType, address controller) public view returns (bool) {
        return accountController[controlledAccount][coinType][controller];
    }



    /**
     * @dev Returns controlled accounts as a string for credential resolution
     * Supports coin-type-specific and group-specific resolution using credential key format: "key:coinType:groupId"
     * Only returns accounts that have verified the controller relationship (either on the specified coin type or default coin type 0)
     * Examples: 
     *   "eth.ecs.controlled-accounts.accounts" (default group, current coin type)
     *   "eth.ecs.controlled-accounts.accounts:1" (group 1, current coin type)
     *   "eth.ecs.controlled-accounts.accounts:60" (default group, Ethereum coin type)
     *   "eth.ecs.controlled-accounts.accounts:60:main" (main group, Ethereum coin type)
     * @param identifier The controller address (as bytes)
     * @param _credential The credential key to look up (can include coin type and group ID after colons)
     * @return The verified controlled accounts as a string (one address per line), empty string if key doesn't match
     */
    function credential(bytes calldata identifier, string calldata _credential) external view override returns (string memory) {
        // Parse the credential key to extract coin type and group ID
        (string memory baseKey, uint256 coinType, bytes32 groupId) = _parseCredentialKey(_credential);

        // Check if the base key matches the text record key
        if (keccak256(bytes(baseKey)) != keccak256(bytes(textRecordKey))) {
            return "";
        }

        // Convert identifier bytes directly to address (assuming it's 20 bytes)
        require(identifier.length == 20, "Invalid identifier length");
        address controllerAddress = address(bytes20(identifier));
        
        // Get all accounts declared by the controller
        address[] memory declaredAccounts = controlledAccounts[controllerAddress][coinType][groupId];
        
        // Filter to only include accounts that have verified the controller relationship
        address[] memory verifiedAccounts = new address[](declaredAccounts.length);
        uint256 verifiedCount = 0;
        
        for (uint256 i = 0; i < declaredAccounts.length; i++) {
            address account = declaredAccounts[i];
            
            // Check if the account has verified the controller on the specified coin type
            // OR on the default coin type (0) for cross-coin-type verification
            if (accountController[account][coinType][controllerAddress] || 
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
     * @dev Parse credential key to extract base key, coin type, and group ID
     * Format: "key:coinType:groupId" or "key:coinType" or "key:groupId" or just "key"
     * @param _credential The credential key to parse
     * @return baseKey The base credential key without coin type and group ID
     * @return coinType The coin type (block.chainid for current coin type if not specified)
     * @return groupId The group ID (bytes32(0) for default group)
     */
    function _parseCredentialKey(string calldata _credential) internal view returns (string memory baseKey, uint256 coinType, bytes32 groupId) {
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
            // No colon found, use entire string as base key, current coin type, default group
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
            // Only one colon found - could be coin type or group ID
            uint256 remainingLength = credentialBytes.length - firstColon - 1;
            if (remainingLength > 0) {
                bytes memory remainingBytes = new bytes(remainingLength);
                for (uint256 j = 0; j < remainingLength; j++) {
                    remainingBytes[j] = credentialBytes[firstColon + 1 + j];
                }
                string memory remaining = string(remainingBytes);
                
                // Try to parse as coin type (numeric)
                if (_isNumeric(remaining)) {
                    coinType = _parseUint256(remaining);
                    groupId = bytes32(0); // default group
                } else {
                    // Treat as group ID
                    coinType = block.chainid; // current coin type
                    groupId = keccak256(remainingBytes);
                }
            } else {
                coinType = block.chainid;
                groupId = bytes32(0);
            }
        } else {
            // Two colons found - first is coin type, second is group ID
            uint256 coinTypeLength = secondColon - firstColon - 1;
            if (coinTypeLength > 0) {
                bytes memory coinTypeBytes = new bytes(coinTypeLength);
                for (uint256 j = 0; j < coinTypeLength; j++) {
                    coinTypeBytes[j] = credentialBytes[firstColon + 1 + j];
                }
                coinType = _parseUint256(string(coinTypeBytes));
            } else {
                coinType = block.chainid;
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
        
        return (baseKey, coinType, groupId);
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
