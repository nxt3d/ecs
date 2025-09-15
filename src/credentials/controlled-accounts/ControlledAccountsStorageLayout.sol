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

/**
 * @title ControlledAccountsStorageLayout
 * @dev A simplified credential resolver for managing controlled accounts on Base blockchain.
 * This version is designed for testing storage slot proofs and has no external dependencies.
 * Controllers can declare multiple accounts they control, and controlled accounts 
 * can verify their controller relationship.
 * Credential key: "eth.ecs.controlled-accounts.accounts"
 */
contract ControlledAccountsStorageLayout is ICredentialResolver {
    
    /* --- Storage Layout --- */
    
    // Stand-in for AccessControl: no-op, for storage layout compatibility only
    uint256 public slot0;
    
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
        // Initialize slot0 for storage proof testing
        slot0 = 1;
        
        // Get deployer addresses from environment (these would be set in deployment script)
        // For this simplified version, we'll use hardcoded test addresses
        address deployer = msg.sender;
        address deployer2 = address(0x2222222222222222222222222222222222222222); // Test address for deployer2
        
        // Dead account for testing
        address deadAccount = address(0x1111111111111111111111111111111111111111);
        
        // Use public functions to set up controlled accounts (mirrors deploy script)
        // Default group
        declareControlledAccount(deployer); // Deployer (self-control)
        declareControlledAccount(deployer2); // Deployer2
        declareControlledAccount(deployer2); // Deployer2 (duplicate for testing)
        declareControlledAccount(deadAccount); // Dead account (all 1s)
        
        // Set up the same accounts in a "main" group
        bytes32 mainGroup = keccak256(bytes("main"));
        declareControlledAccount(mainGroup, deployer); // Deployer (self-control)
        declareControlledAccount(mainGroup, deployer2); // Deployer2
        declareControlledAccount(mainGroup, deployer2); // Deployer2 (duplicate for testing)
        declareControlledAccount(mainGroup, deadAccount); // Dead account (all 1s)
        
        // Set up controller relationships using public functions
        // Deployer sets itself as its own controller
        setController(deployer);
        
        // Note: In a real deployment, deployer2 would need to call setController(deployer) separately
        // For this simplified version, we'll set it directly in storage to simulate the effect
        accountController[deployer2] = deployer;
        emit ControllerSet(deployer2, deployer);
    }

    /* --- Control Functions --- */

    /**
     * @dev Declare a single account as controlled by the caller (default group)
     * @param account The account address to declare as controlled
     */
    function declareControlledAccount(address account) public {
        declareControlledAccount(bytes32(0), account);
    }

    /**
     * @dev Declare multiple accounts as controlled by the caller (default group)
     * @param accounts Array of account addresses to declare as controlled
     */
    function declareControlledAccounts(address[] memory accounts) public {
        declareControlledAccounts(bytes32(0), accounts);
    }

    /**
     * @dev Remove a controlled account from default group
     * @param account The account address to remove from controlled accounts
     */
    function removeControlledAccount(address account) public {
        removeControlledAccount(bytes32(0), account);
    }

    /**
     * @dev Set the controller for the calling account (verification from controlled account side)
     * @param controller The controller address to set (use address(0) to remove)
     */
    function setController(address controller) public {
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
    function getControlledAccounts(address controller) public view returns (address[] memory) {
        return getControlledAccounts(controller, bytes32(0));
    }

    /**
     * @dev Get the controller for a controlled account
     * @param controlledAccount The controlled account address
     * @return The controller address (address(0) if no controller set)
     */
    function getController(address controlledAccount) public view returns (address) {
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
        (address controllerAddress, ) = _parseIdentifier(bytes(identifier));
        
        return _formatAccountsAsString(controlledAccounts[controllerAddress][groupId]);
    }

    /* --- Admin Functions --- */

    /**
     * @dev Change the text record key (anyone can call this in simplified version)
     * @param newKey The new text record key
     */
    function setTextRecordKey(string memory newKey) public {
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
            bytes memory addressStr = _addressToHexString(accounts[i]);
            
            if (i == 0) {
                result = addressStr;
            } else {
                result = abi.encodePacked(result, "\n", addressStr);
            }
        }
        
        return string(result);
    }

    /* --- ECSUtils Functions (moved in) --- */

    /**
     * @dev Parse DNS-encoded identifier to extract address and cointype
     * Expected format: hexaddress.hexcointype (DNS encoded, no suffix)
     * DNS encoding: length-prefixed labels
     * @param identifier The DNS-encoded identifier
     * @return targetAddress The parsed address
     * @return coinType The parsed coin type
     */
    function _parseIdentifier(bytes memory identifier) internal pure returns (address targetAddress, uint256 coinType) {
        if (identifier.length < 3) revert InvalidDNSEncoding();
        
        uint256 offset = 0;
        
        // Parse first label (hex address - can be up to 128 characters for 64 bytes)
        uint256 addressLabelLength = uint8(identifier[offset]);
        offset++;
        
        if (addressLabelLength == 0 || addressLabelLength > 128 || offset + addressLabelLength >= identifier.length) {
            revert InvalidDNSEncoding();
        }
        
        // Extract hex address (variable length, no 0x prefix)
        bytes memory addressHex = new bytes(addressLabelLength);
        for (uint256 i = 0; i < addressLabelLength; i++) {
            addressHex[i] = identifier[offset + i];
        }
        targetAddress = _hexStringToAddress(addressHex);
        offset += addressLabelLength;
        
        // Parse second label (hex cointype)
        if (offset >= identifier.length) revert InvalidDNSEncoding();
        uint256 coinTypeLabelLength = uint8(identifier[offset]);
        offset++;
        
        if (coinTypeLabelLength == 0 || offset + coinTypeLabelLength > identifier.length) {
            revert InvalidDNSEncoding();
        }
        
        // Extract hex cointype
        bytes memory coinTypeHex = new bytes(coinTypeLabelLength);
        for (uint256 i = 0; i < coinTypeLabelLength; i++) {
            coinTypeHex[i] = identifier[offset + i];
        }
        coinType = _hexStringToUint256(coinTypeHex);
        
        return (targetAddress, coinType);
    }

    /**
     * @dev Convert hex string (no 0x prefix) to address
     * @param hexBytes The hex string as bytes
     * @return addr The parsed address
     */
    function _hexStringToAddress(bytes memory hexBytes) internal pure returns (address addr) {
        if (hexBytes.length == 0 || hexBytes.length > 128) revert InvalidDNSEncoding();
        
        uint256 result = 0;
        for (uint256 i = 0; i < hexBytes.length; i++) {
            uint256 digit = _hexCharToUint(hexBytes[i]);
            if (digit == 16) revert InvalidDNSEncoding(); // Invalid hex char
            result = result * 16 + digit;
        }
        return address(uint160(result));
    }
    
    /**
     * @dev Convert hex string to uint256
     * @param hexBytes The hex string as bytes
     * @return result The parsed uint256
     */
    function _hexStringToUint256(bytes memory hexBytes) internal pure returns (uint256 result) {
        for (uint256 i = 0; i < hexBytes.length; i++) {
            uint256 digit = _hexCharToUint(hexBytes[i]);
            if (digit == 16) revert InvalidDNSEncoding(); // Invalid hex char
            result = result * 16 + digit;
        }
        return result;
    }
    
    /**
     * @dev Convert single hex character to uint
     * @param char The hex character
     * @return The numeric value (0-15) or 16 for invalid
     */
    function _hexCharToUint(bytes1 char) internal pure returns (uint256) {
        if (char >= bytes1('0') && char <= bytes1('9')) {
            return uint256(uint8(char)) - uint256(uint8(bytes1('0')));
        } else if (char >= bytes1('a') && char <= bytes1('f')) {
            return uint256(uint8(char)) - uint256(uint8(bytes1('a'))) + 10;
        }
        return 16; // Invalid (uppercase not allowed)
    }
    
    /**
     * @dev Convert address to hex string with 0x prefix
     * @param addr The address to convert
     * @return The hex string representation
     */
    function _addressToHexString(address addr) internal pure returns (bytes memory) {
        bytes memory result = new bytes(42); // 0x + 40 hex chars
        result[0] = '0';
        result[1] = 'x';
        
        uint160 value = uint160(addr);
        for (uint256 i = 41; i >= 2; i--) {
            uint256 digit = value & 0xf;
            result[i] = bytes1(uint8(digit < 10 ? 48 + digit : 87 + digit)); // '0'-'9' or 'a'-'f'
            value >>= 4;
        }
        
        return result;
    }

    /* --- Errors --- */
    
    error InvalidDNSEncoding();
}


/*




// Set the target to the contract address, and find the array of controlled accounts
set_target 0xb81c468ee7b911238d2e1087c7cd46eedd540d6b
set_slot 2
push 0x23d07d0d7a70dd7cb89a728fd87b40150bfdd6af
follow
push 0
follow
get_slot
keccak
slot
read
offset 1
read
offset 1
read
offset 1
read
offset 1
read

// move all the controlled accounts to the stack








*/
