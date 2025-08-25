// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../../ICredentialResolver.sol";

/**
 * @title StarResolver
 * @dev A star counting resolver with address+cointype mapping.
 * Anyone can buy stars for any address on any chain.
 * Name format: hexaddress.hexcointype.addr.ecs.eth (DNS encoded)
 */
contract StarResolver is ICredentialResolver, AccessControl {
    
    /* --- Roles --- */
    
    bytes32 public constant ADMIN_ROLE = keccak256(bytes("ADMIN_ROLE"));
    
    /* --- Events --- */

    event StarPurchased(address indexed targetAddress, uint256 indexed coinType, address indexed buyer, uint256 newStarCount);
    event TextRecordKeyUpdated(string oldKey, string newKey);
    event StarPriceUpdated(uint256 oldPrice, uint256 newPrice);

    /* --- Storage --- */

    // The configurable text record key
    string public textRecordKey = "eth.ecs.ethstars.stars"; // Slot 1 * Access Control uses slot 0
    
    // The star price (updateable by admin)
    uint256 public starPrice = 0.000001 ether; // Testnet: 1000x cheaper // Slot 2
    
    // The star counts: address -> cointype -> count
    mapping(address targetAddress => mapping(uint256 coinType => uint256 count)) public starCounts; // Slot 3
    
    // Track if a buyer has already starred a target address + coin type
    mapping(address buyer => mapping(address targetAddress => mapping(uint256 coinType => bool hasStarred))) public hasStarred; // Slot 4

    /* --- Errors --- */

    error InsufficientPayment();
    error AlreadyStarred();
    error InvalidDNSEncoding();
    error WithdrawalFailed();

    /* --- Constructor --- */

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /* --- Star Functions --- */

    /**
     * @dev Buy a star for a specific address and cointype
     * @param targetAddress The address to buy a star for
     * @param coinType The coin type
     */
    function buyStar(address targetAddress, uint256 coinType) external payable {
        if (msg.value != starPrice) revert InsufficientPayment();

        if (hasStarred[msg.sender][targetAddress][coinType]) {
            revert AlreadyStarred();
        }

        starCounts[targetAddress][coinType]++;
        hasStarred[msg.sender][targetAddress][coinType] = true;
        uint256 newCount = starCounts[targetAddress][coinType];

        emit StarPurchased(targetAddress, coinType, msg.sender, newCount);
    }

    /* --- View Functions --- */

    /**
     * @dev Check if a buyer has already starred a target address with a specific coin type
     * @param buyer The buyer address to check
     * @param targetAddress The target address to check
     * @param coinType The coin type to check
     * @return True if the buyer has already starred this address with this coin type
     */
    function hasStarredAddress(address buyer, address targetAddress, uint256 coinType) external view returns (bool) {
        return hasStarred[buyer][targetAddress][coinType];
    }

    /**
     * @dev Returns the star count for an address and coin type
     * @param identifier The DNS-encoded identifier containing address and coin type
     * @param _credential The credential key to look up
     * @return The star count as a string if key matches, empty string otherwise
     */
    function credential(bytes calldata identifier, string calldata _credential) external view override returns (string memory) {
        if (keccak256(bytes(_credential)) != keccak256(bytes(textRecordKey))) {
            return "";
        }

        // Parse the identifier: address.cointype.addr.ecs.eth
        (address targetAddress, uint256 coinType) = _parseIdentifier(identifier);
        
        return _uint256ToString(starCounts[targetAddress][coinType]);
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
     * @dev Update the star price (admin only)
     * @param newPrice The new star price in wei
     */
    function updateStarPrice(uint256 newPrice) external onlyRole(ADMIN_ROLE) {
        uint256 oldPrice = starPrice;
        starPrice = newPrice;
        emit StarPriceUpdated(oldPrice, newPrice);
    }

    /* --- Internal Helper Functions --- */

    /**
     * @dev Parse DNS-encoded identifier to extract address and cointype
     * Expected format: hexaddress.hexcointype (DNS encoded, no suffix)
     * DNS encoding: length-prefixed labels
     * @param identifier The DNS-encoded identifier
     * @return targetAddress The parsed address
     * @return coinType The parsed coin type
     */
    function _parseIdentifier(bytes calldata identifier) internal pure returns (address targetAddress, uint256 coinType) {
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

    function _uint256ToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        
        return string(buffer);
    }

    /* --- Withdrawal --- */

    /**
     * @dev Withdraw collected ETH (admin only)
     */
    function withdraw() external onlyRole(ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        if (!success) revert WithdrawalFailed();
    }
} 