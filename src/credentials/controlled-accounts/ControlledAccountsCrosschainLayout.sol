// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title ICredentialResolver
 * @dev Interface for ECS credential resolvers that handle credential resolution.
 */
interface ICredentialResolver {
    function credential(bytes calldata identifier, string calldata _credential) external view returns (string memory);
}

/**
 * @title ControlledAccountsCrosschainLayout
 * @dev A simplified credential resolver for managing controlled accounts across multiple chains.
 * This version removes AccessControl and includes required utilities inline for storage slot testing.
 * Controllers can declare multiple accounts they control on different chains, and controlled accounts 
 * can verify their controller relationship across chains.
 * Credential key: "eth.ecs.controlled-accounts.accounts"
 * Supports chain-specific groups and cross-chain controller verification.
 */
contract ControlledAccountsCrosschainLayout is ICredentialResolver {
    
    /* --- Storage Slot 0 --- */
    
    uint256 public slot0;
    
    /* --- Events --- */

    event ControlledAccountsDeclaredInGroup(address indexed controller, uint256 indexed chainId, bytes32 indexed groupId, address[] accounts);
    event ControlledAccountRemovedFromGroup(address indexed controller, uint256 indexed chainId, bytes32 indexed groupId, address account);
    event ControllerSet(address indexed controlledAccount, uint256 indexed chainId, address indexed controller);
    event ControllerRemoved(address indexed controlledAccount, uint256 indexed chainId, address previousController);

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
        // Initialize slot0 for storage proof testing
        slot0 = 1;
        
        // Setup dummy accounts for testing
        _setupDummyAccounts();
    }

    /* --- Setup Functions --- */

    /**
     * @dev Setup dummy accounts for testing storage proofs
     * - Deployer controls itself and 2 dummy accounts on L1 Ethereum (chain ID 1)
     * - 4th account doesn't set deployer as controller on L1
     * - 2 Base accounts (chain ID 8453) set controller for default chain ID 0
     */
    function _setupDummyAccounts() internal {
        // Define test addresses
        address deployer = msg.sender;
        address dummy1 = 0x1111111111111111111111111111111111111111;
        address dummy2 = 0x2222222222222222222222222222222222222222;
        address dummy3 = 0x3333333333333333333333333333333333333333;
        address dummy4 = 0x4444444444444444444444444444444444444444;
        address baseAccount1 = 0x5555555555555555555555555555555555555555;
        address baseAccount2 = 0x6666666666666666666666666666666666666666;
        
        // L1 Ethereum chain ID
        uint256 L1_CHAIN_ID = 1;
        // Base chain ID
        uint256 BASE_CHAIN_ID = 8453;
        // Default chain ID for cross-chain verification
        uint256 DEFAULT_CHAIN_ID = 0;
        
        // Deployer declares controlled accounts on L1 Ethereum (default group)
        declareControlledAccount(L1_CHAIN_ID, bytes32(0), deployer); // Deployer controls itself
        declareControlledAccount(L1_CHAIN_ID, bytes32(0), dummy1);   // Deployer controls dummy1
        declareControlledAccount(L1_CHAIN_ID, bytes32(0), dummy2);   // Deployer controls dummy2
        
        // Deployer declares dummy3 on L1 and dummy3 sets deployer as controller for default chain ID 0
        declareControlledAccount(L1_CHAIN_ID, bytes32(0), dummy3);
        
        // Deployer declares dummy4 on L1 but dummy4 doesn't set deployer as controller
        declareControlledAccount(L1_CHAIN_ID, bytes32(0), dummy4);
        
        // Deployer declares 2 accounts on Base chain (default group)
        declareControlledAccount(BASE_CHAIN_ID, bytes32(0), baseAccount1);
        declareControlledAccount(BASE_CHAIN_ID, bytes32(0), baseAccount2);
        
        // Note: In a real scenario, the controlled accounts would call setController themselves
        // For testing purposes, we simulate this by directly setting the controller relationships
        
        // Simulate deployer setting itself as controller on L1 (self-verification)
        // (In real usage, the deployer would call setController itself)
        accountController[deployer][L1_CHAIN_ID][deployer] = true;
        
        // Simulate dummy1 and dummy2 setting deployer as their controller on L1
        // (In real usage, these accounts would call setController themselves)
        accountController[dummy1][L1_CHAIN_ID][deployer] = true;
        accountController[dummy2][L1_CHAIN_ID][deployer] = true;
        
        // Simulate base accounts setting deployer as controller for default chain ID 0
        // (In real usage, these accounts would call setControllerWithSignature or setController)
        accountController[baseAccount1][DEFAULT_CHAIN_ID][deployer] = true;
        accountController[baseAccount2][DEFAULT_CHAIN_ID][deployer] = true;
        
        // Simulate dummy3 setting deployer as controller for default chain ID 0
        // (In real usage, dummy3 would call setControllerWithSignature or setController)
        accountController[dummy3][DEFAULT_CHAIN_ID][deployer] = true;
        
        // dummy4 does NOT set deployer as controller (as requested)
        // This creates the scenario where deployer declares control but dummy4 doesn't verify it
    }

    /* --- Core Functions --- */

    /**
     * @dev Declare a single account as controlled by the caller in a specific group on a specific chain
     * @param chainId The chain ID where the controlled account exists
     * @param groupId The group identifier (use bytes32(0) for default group)
     * @param account The account address to declare as controlled
     */
    function declareControlledAccount(uint256 chainId, bytes32 groupId, address account) public {
        controlledAccounts[msg.sender][chainId][groupId].push(account);
        
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
     * Examples: 
     *   "eth.ecs.controlled-accounts.accounts" (default group, current chain)
     *   "eth.ecs.controlled-accounts.accounts:1" (group 1, current chain)
     *   "eth.ecs.controlled-accounts.accounts:8453" (default group, Base chain)
     *   "eth.ecs.controlled-accounts.accounts:8453:main" (main group, Base chain)
     * @param identifier The controller address (as bytes)
     * @param _credential The credential key to look up (can include chain ID and group ID after colons)
     * @return The controlled accounts as a string (one address per line), empty string if key doesn't match
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
        
        return _formatAccountsAsString(controlledAccounts[controllerAddress][chainId][groupId]);
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
                    groupId = bytes32(0); // Default group
                } else {
                    // Treat as group ID, use current chain
                    chainId = block.chainid;
                    groupId = keccak256(bytes(remaining));
                }
            } else {
                // Empty after colon, use current chain and default group
                chainId = block.chainid;
                groupId = bytes32(0);
            }
        } else {
            // Two colons found - first is chain ID, second is group ID
            uint256 chainIdLength = secondColon - firstColon - 1;
            uint256 groupIdLength = credentialBytes.length - secondColon - 1;
            
            if (chainIdLength > 0) {
                bytes memory chainIdBytes = new bytes(chainIdLength);
                for (uint256 j = 0; j < chainIdLength; j++) {
                    chainIdBytes[j] = credentialBytes[firstColon + 1 + j];
                }
                string memory chainIdStr = string(chainIdBytes);
                
                if (_isNumeric(chainIdStr)) {
                    chainId = _parseUint256(chainIdStr);
                } else {
                    // Invalid chain ID, use current chain
                    chainId = block.chainid;
                }
            } else {
                chainId = block.chainid;
            }
            
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
    }

    /**
     * @dev Check if a string is numeric
     * @param str The string to check
     * @return True if the string contains only digits
     */
    function _isNumeric(string memory str) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        if (strBytes.length == 0) return false;
        
        for (uint256 i = 0; i < strBytes.length; i++) {
            if (strBytes[i] < 0x30 || strBytes[i] > 0x39) {
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
     * @dev Format an array of addresses as a string (one address per line)
     * @param accounts The array of addresses to format
     * @return The formatted string
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

    /**
     * @dev Convert an address to a hex string with 0x prefix
     * @param addr The address to convert
     * @return The hex string representation
     */
    function _addressToHexString(address addr) internal pure returns (bytes memory) {
        bytes memory data = abi.encodePacked(addr);
        bytes memory alphabet = "0123456789abcdef";
        bytes memory result = new bytes(42); // 0x + 40 hex chars
        
        result[0] = '0';
        result[1] = 'x';
        
        for (uint256 i = 0; i < 20; i++) {
            result[2 + i * 2] = alphabet[uint8(data[i] >> 4)];
            result[3 + i * 2] = alphabet[uint8(data[i] & 0x0f)];
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

/*
REGISTRY = 0xf72fb70d87c9db355b9f21e36b3eba6bcf346539
DEPLOYER = 0x005e8cd1c94d88032d76f718f8835db7e868dccb
DEFAULT_GROUP = 0
ETHEREUM_ID = 0x01
CONTROLLED_ACCOUNTS_SLOT = 2
ACCOUNT_CONTROLLER_SLOT = 3


# Set target contract address
SET_TARGET REGISTRY
SET_SLOT CONTROLLED_ACCOUNTS_SLOT
push_0
set_output 0
push DEPLOYER
follow
push_1 ETHEREUM_ID
follow
push DEFAULT_GROUP
follow
read # array length
set_output 0

# setup the loop indexes
push 5
push 4
push 3
push 2
push 1
push 0

program concat_out
  push_output 0
  push_output 1
  CONCAT
  set_output 0

program for_each_item
  follow_index
  read
  dup
  dup
  require_nonzero
  set_output 1
  # check the to see if the account accepts the deployer as a account controller on L1
  SET_SLOT ACCOUNT_CONTROLLER_SLOT
  follow
  push ETHEREUM_ID
  follow
  push DEPLOYER
  follow
  read
  push_program concat_out
  swap
  eval_if
  # check the to see if the account accepts the deployer as a account controller on chainID 0 (Default)
  SET_SLOT ACCOUNT_CONTROLLER_SLOT
  follow
  push DEFAULT_GROUP
  follow
  push DEPLOYER
  follow
  read
  push_program concat_out
  swap
  eval_if
  push_0
  set_output 1

push_program for_each_item
eval_loop 6 0b0010

*/
