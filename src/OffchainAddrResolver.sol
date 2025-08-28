// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {GatewayFetcher, GatewayRequest} from "@unruggable/contracts/GatewayFetcher.sol";
import {GatewayFetchTarget, IGatewayVerifier} from "@unruggable/contracts/GatewayFetchTarget.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./utils/HexUtils.sol";
import "./ICredentialResolverOffchain.sol";

/**
 * @title OffchainAddrResolver
 * @dev Abstract base contract for offchain address-based resolvers
 * @notice This contract provides common functionality for resolving address-based ENS names
 * using gateway fetching. Concrete implementations only need to implement the credential
 * function and optionally override _fetchCredential for custom logic.
 */
abstract contract OffchainAddrResolver is GatewayFetchTarget, ICredentialResolverOffchain, AccessControl {
    
    using GatewayFetcher for GatewayRequest;

    /* --- Errors --- */

    error UnsupportedFunction(bytes4 selector);
    error UnauthorizedNamespaceAccess(address caller, bytes32 namespace);
    error NamespaceExpired(bytes32 namespace);
    error InvalidAddressEncoding();
    error InvalidDNSEncoding();

    /* --- Events --- */

    event TextRecordKeyUpdated(string oldKey, string newKey);

    /* --- Roles --- */

    bytes32 public constant ADMIN_ROLE = keccak256(bytes("ADMIN_ROLE"));

    /* --- Storage --- */

    IGatewayVerifier immutable _verifier;
    address immutable _targetL2Address;

    /* --- Constructor --- */
    
    /// @dev Initialize with the verifier and target L2 address.
    /// @param verifier The gateway verifier contract.
    /// @param targetL2Address The target L2 address for offchain resolution.
    /// @notice This contract is designed to be used with a specific verifier and target address.
    constructor(IGatewayVerifier verifier, address targetL2Address) {
        _verifier = verifier;
        _targetL2Address = targetL2Address;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }
    
    /* --- Resolution --- */

    /**
     * @dev Abstract credential function that must be implemented by concrete contracts
     * @param identifier The DNS-encoded identifier (already extracted address.cointype)
     * @param _credential The credential key for the text record
     * @return The result of the credential resolution
     */
    function credential(bytes calldata identifier, string calldata _credential) external view virtual returns (string memory);
    
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
        
        // Validate address label length and bounds
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
     * @dev Convert hex string (no 0x prefix) to address using HexUtils
     * @param hexBytes The hex string as bytes
     * @return addr The parsed address
     */
    function _hexStringToAddress(bytes memory hexBytes) internal pure returns (address addr) {
        if (hexBytes.length == 0 || hexBytes.length != 40) revert InvalidDNSEncoding(); // 40 chars = 20 bytes address
        
        // Use HexUtils to parse the address
        (address parsed, bool valid) = HexUtils.hexToAddress(hexBytes, 0, hexBytes.length);
        if (!valid) revert InvalidDNSEncoding();
        return parsed;
    }

    /**
     * @dev Convert hex string to uint256 using HexUtils
     * @param hexBytes The hex string as bytes
     * @return result The parsed uint256
     */
    function _hexStringToUint256(bytes memory hexBytes) internal pure returns (uint256 result) {
        if (hexBytes.length == 0) revert InvalidDNSEncoding();
        
        // Use HexUtils to parse the uint256
        (bytes32 parsed, bool valid) = HexUtils.hexStringToBytes32(hexBytes, 0, hexBytes.length);
        if (!valid) revert InvalidDNSEncoding();
        return uint256(parsed);
    }
    
    /**
     * @dev Extract the address identifier from a DNS-encoded name
     * Expected format: address.cointype.namespace.eth
     * Returns: DNS-encoded address identifier
     */
    function _extractAddressIdentifier(bytes calldata name) internal pure returns (bytes memory) {
        
        uint256 offset = 0;
        uint256 labelCount = 0;
        uint256 identifierEnd = 0;
        
        // We need to find where the address+cointype part ends
        // Format: address.cointype.namespace.eth
        // We want to extract address.cointype
        
        // Parse through the labels
        while (offset < name.length) {
            uint8 labelLength = uint8(name[offset]);
            if (labelLength == 0) break; // End of DNS name
            
            offset += 1 + labelLength; // Skip length byte + label data
            labelCount++;
            
            // After reading two labels (address.cointype), we should be at the namespace
            if (labelCount == 2) {
                identifierEnd = offset;
                break;
            }
        }
        
        if (identifierEnd == 0 || labelCount < 2) {
            revert InvalidAddressEncoding();
        }
        
        // Extract the address identifier with proper null termination
        bytes memory identifier = new bytes(identifierEnd + 1);
        for (uint256 i = 0; i < identifierEnd; i++) {
            identifier[i] = name[i];
        }
        identifier[identifierEnd] = 0x00; // Null terminator
        
        return identifier;
    }

    /**
     * @dev Abstract callback function that must be implemented by concrete contracts
     * @param values The values returned from the gateway
     * @param extraData Additional data from the gateway
     * @return The encoded result
     */
    function credentialCallback(bytes[] calldata values, uint8, bytes calldata extraData) external view virtual returns (bytes memory);
    
    /* --- ERC165 Support --- */
    
    function supportsInterface(bytes4 interfaceId) public override view virtual returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
