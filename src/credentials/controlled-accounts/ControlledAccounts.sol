// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../../ICredentialResolver.sol";

/**
 * @title ControlledAccounts
 * @dev A credential resolver for managing controlled accounts on Base blockchain.
 * Controllers can declare multiple accounts they control, and controlled accounts 
 * can verify their controller relationship.
 * Credential key: "eth.ecs.controlled-accounts.accounts"
 */
contract ControlledAccounts is ICredentialResolver, AccessControl {
    
    /* --- Roles --- */
    
    bytes32 public constant ADMIN_ROLE = keccak256(bytes("ADMIN_ROLE"));
    
    /* --- Events --- */

    event ControlledAccountsDeclared(address indexed controller, address[] accounts);
    event ControlledAccountRemoved(address indexed controller, address indexed account);
    event ControllerSet(address indexed controlledAccount, address indexed controller);
    event ControllerRemoved(address indexed controlledAccount, address indexed previousController);
    event TextRecordKeyUpdated(string oldKey, string newKey);
    event MaxControlledAccountsUpdated(uint256 oldMax, uint256 newMax);

    /* --- Storage --- */

    // Constants
    uint256 public constant MIN_MAX_CONTROLLED_ACCOUNTS = 100;
    
    // The configurable text record key
    string public textRecordKey = "eth.ecs.controlled-accounts.accounts";
    
    // Maximum number of controlled accounts per controller (configurable by admin)
    uint256 public maxControlledAccounts = 1000;
    
    // Controller -> array of controlled accounts
    mapping(address controller => address[] accounts) public controlledAccounts;
    
    // Controlled account -> controller (for verification)
    mapping(address controlled => address controller) public accountController;
    
    // Helper mapping for efficient removal: controller -> account -> index+1 (0 means not present)
    mapping(address controller => mapping(address account => uint256 indexPlusOne)) private accountIndex;

    /* --- Errors --- */

    error AccountAlreadyControlled();
    error AccountNotControlled();
    error InvalidDNSEncoding();
    error NotAuthorized();
    error TooManyControlledAccounts();
    error InvalidMaxControlledAccounts();

    /* --- Constructor --- */

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /* --- Control Functions --- */

    /**
     * @dev Declare multiple accounts as controlled by the caller
     * @param accounts Array of account addresses to declare as controlled
     */
    function declareControlledAccounts(address[] memory accounts) external {
        require(accounts.length > 0, "No accounts provided");
        
        // Check if adding these accounts would exceed the maximum
        uint256 currentCount = controlledAccounts[msg.sender].length;
        if (currentCount + accounts.length > maxControlledAccounts) {
            revert TooManyControlledAccounts();
        }
        
        for (uint256 i = 0; i < accounts.length; i++) {
            address account = accounts[i];
            require(account != address(0), "Invalid account address");
            require(account != msg.sender, "Cannot control self");
            
            // Check if account is already controlled by this controller
            if (accountIndex[msg.sender][account] > 0) {
                revert AccountAlreadyControlled();
            }
            
            // Add to controlled accounts array
            controlledAccounts[msg.sender].push(account);
            accountIndex[msg.sender][account] = controlledAccounts[msg.sender].length; // Store index+1
        }
        
        emit ControlledAccountsDeclared(msg.sender, accounts);
    }

    /**
     * @dev Remove a controlled account
     * @param account The account address to remove from controlled accounts
     */
    function removeControlledAccount(address account) external {
        uint256 indexPlusOne = accountIndex[msg.sender][account];
        if (indexPlusOne == 0) {
            revert AccountNotControlled();
        }
        
        uint256 index = indexPlusOne - 1;
        address[] storage accounts = controlledAccounts[msg.sender];
        
        // Move the last element to the deleted spot and remove the last element
        if (index < accounts.length - 1) {
            address lastAccount = accounts[accounts.length - 1];
            accounts[index] = lastAccount;
            accountIndex[msg.sender][lastAccount] = index + 1; // Update index
        }
        
        accounts.pop();
        delete accountIndex[msg.sender][account];
        
        emit ControlledAccountRemoved(msg.sender, account);
    }

    /**
     * @dev Set the controller for the calling account (verification from controlled account side)
     * @param controller The controller address to set
     */
    function setController(address controller) external {
        require(controller != address(0), "Invalid controller address");
        require(controller != msg.sender, "Cannot set self as controller");
        
        address previousController = accountController[msg.sender];
        accountController[msg.sender] = controller;
        
        if (previousController != address(0)) {
            emit ControllerRemoved(msg.sender, previousController);
        }
        emit ControllerSet(msg.sender, controller);
    }

    /**
     * @dev Remove the controller for the calling account
     */
    function removeController() external {
        address previousController = accountController[msg.sender];
        require(previousController != address(0), "No controller set");
        
        delete accountController[msg.sender];
        emit ControllerRemoved(msg.sender, previousController);
    }

    /* --- View Functions --- */

    /**
     * @dev Get all controlled accounts for a controller
     * @param controller The controller address
     * @return Array of controlled account addresses
     */
    function getControlledAccounts(address controller) external view returns (address[] memory) {
        return controlledAccounts[controller];
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
     * @dev Check if an account is controlled by a specific controller
     * @param controller The controller address
     * @param account The account address to check
     * @return True if the account is controlled by the controller
     */
    function isControlledAccount(address controller, address account) external view returns (bool) {
        return accountIndex[controller][account] > 0;
    }

    /**
     * @dev Returns controlled accounts as a string for credential resolution
     * @param identifier The DNS-encoded identifier containing the controller address and coin type
     * @param _credential The credential key to look up
     * @return The controlled accounts as a string (one address per line), empty string if key doesn't match
     */
    function credential(bytes calldata identifier, string calldata _credential) external view override returns (string memory) {
        if (keccak256(bytes(_credential)) != keccak256(bytes(textRecordKey))) {
            return "";
        }

        // Parse the identifier: address.cointype.addr.ecs.eth
        (address controllerAddress, ) = _parseIdentifier(identifier);
        
        return _formatAccountsAsString(controlledAccounts[controllerAddress]);
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

    /**
     * @dev Set the maximum number of controlled accounts per controller (admin only)
     * @param newMax The new maximum number of controlled accounts (must be >= 100)
     */
    function setMaxControlledAccounts(uint256 newMax) external onlyRole(ADMIN_ROLE) {
        if (newMax < MIN_MAX_CONTROLLED_ACCOUNTS) {
            revert InvalidMaxControlledAccounts();
        }
        
        uint256 oldMax = maxControlledAccounts;
        maxControlledAccounts = newMax;
        
        emit MaxControlledAccountsUpdated(oldMax, newMax);
    }

    /* --- Internal Helper Functions --- */

    /**
     * @dev Parse DNS-encoded identifier to extract address and cointype
     * Expected format: hexaddress.hexcointype (DNS encoded, no suffix)
     * DNS encoding: length-prefixed labels
     * @param identifier The DNS-encoded identifier
     * @return controllerAddress The parsed controller address
     * @return coinType The parsed coin type
     */
    function _parseIdentifier(bytes calldata identifier) internal pure returns (address controllerAddress, uint256 coinType) {
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
        controllerAddress = _hexStringToAddress(addressHex);
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
        
        return (controllerAddress, coinType);
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
}
