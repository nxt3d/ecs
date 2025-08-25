// SPDX-License-Identifier: MIT
// Based on ENS StringUtils.sol
// https://github.com/ensdomains/ens-contracts/blob/master/contracts/ethregistrar/StringUtils.sol
pragma solidity ^0.8.27;

/**
 * @title ECSStringUtils
 * @dev String utility functions for ECS protocol
 */
library ECSStringUtils {
    
    /**
     * @dev Returns the length of a given string in characters (not bytes)
     * Handles UTF-8 multi-byte characters correctly
     * @param s The string to measure the length of
     * @return The length of the input string in characters
     */
    function strlen(string memory s) internal pure returns (uint256) {
        uint256 len;
        uint256 i = 0;
        uint256 bytelength = bytes(s).length;
        
        for (len = 0; i < bytelength; len++) {
            bytes1 b = bytes(s)[i];
            if (b < 0x80) {
                i += 1;
            } else if (b < 0xE0) {
                i += 2;
            } else if (b < 0xF0) {
                i += 3;
            } else if (b < 0xF8) {
                i += 4;
            } else if (b < 0xFC) {
                i += 5;
            } else {
                i += 6;
            }
        }
        return len;
    }

    /**
     * @dev Splits a string by dots into an array of labels, stopping at ":" parameter divider.
     * @param str The string to split.
     * @return labels Array of label strings.
     */
    function splitByDotsStopAtColon(string memory str) internal pure returns (string[] memory) {
        bytes memory strBytes = bytes(str);
        uint256 dotCount = 0;
        uint256 endIndex = strBytes.length;
        
        // Find the end index (stop at ":" if found) and count dots
        for (uint256 i = 0; i < strBytes.length; i++) {
            if (strBytes[i] == ':') {
                endIndex = i;
                break;
            }
            if (strBytes[i] == '.') {
                dotCount++;
            }
        }
        
        string[] memory labels = new string[](dotCount + 1);
        uint256 labelIndex = 0;
        uint256 start = 0;
        
        for (uint256 i = 0; i <= endIndex; i++) {
            if (i == endIndex || strBytes[i] == '.') {
                if (i > start) {
                    labels[labelIndex] = substring(str, start, i);
                    labelIndex++;
                }
                start = i + 1;
            }
        }
        
        return labels;
    }

    /**
     * @dev Builds a namespace string from labels array in proper domain order.
     * Labels are in reverse order: ["eth", "namespace", "cool"]
     * Builds: eth -> namespace.eth -> cool.namespace.eth
     * @param labels Array of label strings in reverse order.
     * @param count Number of labels to include from the start.
     * @return The built namespace string in proper domain order.
     */
    function buildNamespaceLeftToRight(string[] memory labels, uint256 count) internal pure returns (string memory) {
        if (count == 0 || count > labels.length) {
            return "";
        }
        
        if (count == 1) {
            return labels[0]; // Just "eth"
        }
        
        // Build from right to left to get proper domain order
        // Start with the rightmost label (index count-1)
        string memory result = labels[count - 1];
        
        // Add labels from right to left, separated by dots
        for (uint256 i = count - 1; i > 0; i--) {
            result = string(abi.encodePacked(result, ".", labels[i - 1]));
        }
        
        return result;
    }

    /**
     * @dev Returns a substring of the given string.
     * @param str The source string.
     * @param start The start index (inclusive).
     * @param end The end index (exclusive).
     * @return The substring.
     */
    function substring(string memory str, uint256 start, uint256 end) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(end - start);
        
        for (uint256 i = start; i < end; i++) {
            result[i - start] = strBytes[i];
        }
        
        return string(result);
    }

    /**
     * @dev Computes the namehash for a namespace using the ENS namehash algorithm.
     * @param namespace The namespace string (e.g., "eth", "ecs.eth", "name.ecs.eth").
     * @return The computed namehash.
     */
    function computeNamespaceHash(string memory namespace) internal pure returns (bytes32) {
        return namehash(namespace);
    }

    /**
     * @dev Computes the ENS namehash of a domain name.
     * @param name The domain name (e.g., "ecs.eth").
     * @return The namehash of the domain.
     */
    function namehash(string memory name) internal pure returns (bytes32) {
        bytes32 node = 0x00;
        
        if (bytes(name).length == 0) {
            return node;
        }
        
        // Split the name by dots and process from right to left
        string[] memory labels = splitByDots(name);
        
        // Process labels from right to left (reverse order)
        for (uint256 i = labels.length; i > 0; i--) {
            bytes32 labelHash = keccak256(bytes(labels[i - 1]));
            node = keccak256(abi.encodePacked(node, labelHash));
        }
        
        return node;
    }

    /**
     * @dev Splits a string by dots into an array of labels.
     * @param str The string to split.
     * @return labels Array of label strings.
     */
    function splitByDots(string memory str) internal pure returns (string[] memory) {
        bytes memory strBytes = bytes(str);
        uint256 dotCount = 0;
        
        // Count dots
        for (uint256 i = 0; i < strBytes.length; i++) {
            if (strBytes[i] == '.') {
                dotCount++;
            }
        }
        
        string[] memory labels = new string[](dotCount + 1);
        uint256 labelIndex = 0;
        uint256 start = 0;
        
        for (uint256 i = 0; i <= strBytes.length; i++) {
            if (i == strBytes.length || strBytes[i] == '.') {
                if (i > start) {
                    labels[labelIndex] = substring(str, start, i);
                    labelIndex++;
                }
                start = i + 1;
            }
        }
        
        // Resize array to actual size
        string[] memory result = new string[](labelIndex);
        for (uint256 i = 0; i < labelIndex; i++) {
            result[i] = labels[i];
        }
        
        return result;
    }

    /**
     * @dev Checks if two strings are equal.
     * @param a First string.
     * @param b Second string.
     * @return True if strings are equal, false otherwise.
     */
    function equal(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    /**
     * @dev Checks if a string contains only valid label characters.
     * Valid: lowercase letters (a-z), digits (0-9), hyphens (not at start/end).
     * @param label The label to validate.
     * @param minLength Minimum allowed length.
     * @param maxLength Maximum allowed length.
     * @return True if valid, false otherwise.
     */
    function isValidLabel(string memory label, uint256 minLength, uint256 maxLength) internal pure returns (bool) {
        bytes memory labelBytes = bytes(label);
        uint256 length = labelBytes.length;

        if (length < minLength || length > maxLength) {
            return false;
        }

        // Check for valid characters (lowercase letters, digits, and hyphens, no leading/trailing hyphens)
        for (uint256 i = 0; i < length; i++) {
            bytes1 char = labelBytes[i];
            bool isValidChar = (char >= 0x30 && char <= 0x39) || // 0-9
                              (char >= 0x61 && char <= 0x7A) || // a-z
                              (char == 0x2D && i > 0 && i < length - 1); // hyphen not at start/end

            if (!isValidChar) {
                return false;
            }
        }
        
        return true;
    }
} 