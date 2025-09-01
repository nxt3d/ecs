// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title ECSUtils
 * @dev Utility library for ECS credential parsing functions
 * Handles DNS-encoded identifiers and name extraction
 */
library ECSUtils {
    
    /* --- Errors --- */
    
    error InvalidDNSEncoding();
    
    /* --- Address-based Identifier Parsing --- */
    
    /**
     * @dev Parse DNS-encoded identifier to extract address and cointype
     * Expected format: hexaddress.hexcointype (DNS encoded, no suffix)
     * DNS encoding: length-prefixed labels
     * @param identifier The DNS-encoded identifier
     * @return targetAddress The parsed address
     * @return coinType The parsed coin type
     */
    function parseIdentifier(bytes memory identifier) internal pure returns (address targetAddress, uint256 coinType) {
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
        targetAddress = hexStringToAddress(addressHex);
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
        coinType = hexStringToUint256(coinTypeHex);
        
        return (targetAddress, coinType);
    }
    
    /* --- Name-based Identifier Parsing --- */
    
    /**
     * @dev Extract name identifier from DNS-encoded name
     * Looking for pattern: <domain labels>...[4]name[?]<anything>[3]eth[0]
     * @param name The DNS-encoded name
     * @return The extracted name identifier
     */
    function extractNameIdentifier(bytes memory name) internal pure returns (bytes memory) {
        if (name.length < 10) { // Minimum for "name.x.eth" + null terminator
            revert InvalidDNSEncoding();
        }
        
        // Parse DNS name forward through labels
        // DNS format: [length][label][length][label]...[0]
        // Looking for pattern: <domain labels>...[4]name[?]<anything>[3]eth[0]
        
        uint256 pos = 0;
        uint256 namePosition = 0;
        bool foundName = false;
        
        // Parse forward through labels
        while (pos < name.length) {
            // Check for null terminator
            if (name[pos] == 0x00) {
                break;
            }
            
            uint8 labelLength = uint8(name[pos]);
            
            // Check if we have enough bytes for this label
            if (pos + labelLength + 1 > name.length) {
                revert InvalidDNSEncoding();
            }
            
            // Check if this is the "name" label
            if (labelLength == 4 && 
                name[pos + 1] == 0x6e && // 'n'
                name[pos + 2] == 0x61 && // 'a'
                name[pos + 3] == 0x6d && // 'm'
                name[pos + 4] == 0x65) { // 'e'
                
                namePosition = pos;
                foundName = true;
                pos += labelLength + 1; // Move past "name" label
                
                // Skip the next label (can be anything)
                if (pos >= name.length || name[pos] == 0x00) {
                    revert InvalidDNSEncoding();
                }
                
                uint8 nextLabelLength = uint8(name[pos]);
                if (pos + nextLabelLength + 1 > name.length) {
                    revert InvalidDNSEncoding();
                }
                pos += nextLabelLength + 1; // Move past the next label
                
                // Check if the following label is "eth" and terminal
                if (pos + 4 <= name.length && 
                    name[pos] == 0x03 && // length 3
                    name[pos + 1] == 0x65 && // 'e'
                    name[pos + 2] == 0x74 && // 't'
                    name[pos + 3] == 0x68 && // 'h'
                    pos + 4 < name.length && 
                    name[pos + 4] == 0x00) { // null terminator
                    
                    // Found valid pattern: extract domain identifier
                    bytes memory identifier = new bytes(namePosition + 1);
                    for (uint256 i = 0; i < namePosition; i++) {
                        identifier[i] = name[i];
                    }
                    identifier[namePosition] = 0x00; // Add null terminator
                    
                    return identifier;
                }
                break;
            } else {
                // Move to next label
                pos += labelLength + 1;
            }
        }
        
        // If we get here, we didn't find a valid name pattern
        revert InvalidDNSEncoding();
    }
    
    /* --- Hex Conversion Utilities --- */
    
    /**
     * @dev Convert hex string (no 0x prefix) to address
     * @param hexBytes The hex string as bytes
     * @return addr The parsed address
     */
    function hexStringToAddress(bytes memory hexBytes) internal pure returns (address addr) {
        if (hexBytes.length == 0 || hexBytes.length > 128) revert InvalidDNSEncoding();
        
        uint256 result = 0;
        for (uint256 i = 0; i < hexBytes.length; i++) {
            uint256 digit = hexCharToUint(hexBytes[i]);
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
    function hexStringToUint256(bytes memory hexBytes) internal pure returns (uint256 result) {
        for (uint256 i = 0; i < hexBytes.length; i++) {
            uint256 digit = hexCharToUint(hexBytes[i]);
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
    function hexCharToUint(bytes1 char) internal pure returns (uint256) {
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
    function addressToHexString(address addr) internal pure returns (bytes memory) {
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
