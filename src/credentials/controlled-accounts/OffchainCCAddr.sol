// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../../OffchainAddrResolver.sol";
import {GatewayFetcher} from "@unruggable/contracts/GatewayFetcher.sol";
import {IGatewayVerifier} from "@unruggable/contracts/GatewayFetchTarget.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title OffchainCCAddr
 * @dev Offchain credential resolver for cross-chain controlled accounts
 * @notice This contract resolves cross-chain controlled accounts for address-based ENS names
 * using offchain gateway fetching. It inherits all common functionality from
 * OffchainAddrResolver and only implements the credential-specific logic.
 */
contract OffchainCCAddr is OffchainAddrResolver {
    
    using GatewayFetcher for GatewayRequest;

    /* --- State Variables --- */
    
    // Program bytes that can be updated per coinType
    mapping(uint256 coinType => bytes programs) public programBytes;

    /* --- Constructor --- */
    
    /// @dev Initialize with the verifier and target L2 address.
    /// @param verifier The gateway verifier contract.
    /// @param _targetL2Address The target L2 address for offchain resolution.
    constructor(IGatewayVerifier verifier, address _targetL2Address) 
        OffchainAddrResolver(verifier, _targetL2Address) {
    }
    
    /* --- Program Management --- */

    /**
     * @dev Update the program bytes for gateway execution
     * @param newProgramBytes The new program bytes to use
     * @notice Only accounts with ADMIN_ROLE can update the program
     */
    function updateProgram(uint256 coinType, bytes calldata newProgramBytes) external onlyRole(ADMIN_ROLE) {
        programBytes[coinType] = newProgramBytes;
    }
    
    /* --- Credential Resolution --- */

    /**
     * @dev Credential function for cross-chain controlled accounts
     * @param identifier The DNS-encoded identifier (already extracted address.cointype)
     * @param _credential The credential key for the text record
     * @return The result of the credential resolution
     */
    function credential(bytes calldata identifier, string calldata _credential) 
        external view override returns (string memory) {
        // Hardcoded test response to verify ECS resolution is working
        return "0x000000000000000000000000000000000000000000000000000000000000000211111111111111111111111111111111111111112222222222222222222222222222222222222222";
    }

    /**
     * @dev Internal function to fetch credential using gateway
     * @param identifier The DNS-encoded address.cointype identifier
     * @param key The credential key for the text record
     * @return The result of the gateway fetch
     * @notice Can be overridden by concrete contracts for custom logic
     */
    function _fetchCredential(bytes memory identifier, string calldata key) internal view virtual returns (bytes memory) {
        // Parse address and cointype from DNS-encoded identifier (reverts on invalid format)
        // The identifier contains the Base Sepolia coin type, which we should use
        (address targetAddress, uint256 identifierCoinType) = _parseIdentifier(identifier);
        
        // Parse the credential key to extract coin type and group ID
        (string memory baseKey, uint256 groupCoinType, bytes32 groupId) = _parseCredentialKey(key);
        
        // Create gateway request using pushBytes method
        GatewayRequest memory r = GatewayFetcher.newRequest(1);

        // Push the group id
        r = r.push(groupId);
        // Push the final coin type
        r = r.push(groupCoinType).concat();
        // push the address
        r = r.push(targetAddress).concat();
        // Push the program bytes (program handles target and slots internally)
        r = r.push(programBytes[identifierCoinType]);
        // Execute the program
        r = r.evalLoop(uint8(0), 1);
        r = r.setOutput(0);

        fetch(gatewayVerifier, r, this.credentialCallback.selector);
    }

    /**
     * @dev Callback function to process gateway response for cross-chain controlled accounts
     * @param values The values returned from the gateway
     * @param extraData Additional data from the gateway (unused)
     * @return The encoded result as a string of controlled accounts
     */
    function credentialCallback(bytes[] calldata values, uint8, bytes calldata extraData) 
        external pure override returns (bytes memory) {
        // Hardcoded test response to verify callback is working
        string memory testResponse = "0x000000000000000000000000000000000000000000000000000000000000000211111111111111111111111111111111111111112222222222222222222222222222222222222222";
        return abi.encode(testResponse);
    }
    
    /* --- Credential Key Parsing --- */
    
    /**
     * @dev Parse credential key to extract base key, coin type, and group ID
     * Format: "key[:coinType[:groupID]]" - unambiguous format
     * - "key" - just the key, use identifier coin type and default group
     * - "key:coinType" - key with specific coin type, default group
     * - "key:coinType:groupID" - key with specific coin type and group ID
     * @param _credential The credential key to parse
     * @return baseKey The base credential key without coin type and group ID
     * @return coinType The coin type (identifier coin type if not specified)
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
            // No colon found, use entire string as base key, identifier coin type, default group
            return (_credential, 0, bytes32(0)); // 0 means use identifier coin type
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
            // Only one colon found - this is coinType (unambiguous format)
            uint256 remainingLength = credentialBytes.length - firstColon - 1;
            if (remainingLength > 0) {
                bytes memory remainingBytes = new bytes(remainingLength);
                for (uint256 j = 0; j < remainingLength; j++) {
                    remainingBytes[j] = credentialBytes[firstColon + 1 + j];
                }
                string memory remaining = string(remainingBytes);
                
                // Parse as coin type (must be numeric)
                coinType = _parseUint256(remaining);
                groupId = bytes32(0); // default group
            } else {
                coinType = 0; // use identifier coin type
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
     * @dev Check if a string is numeric
     * @param str The string to check
     * @return True if the string contains only digits
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
}
