// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {GatewayFetcher, GatewayRequest} from "@unruggable/contracts/GatewayFetcher.sol";
import {GatewayFetchTarget, IGatewayVerifier} from "@unruggable/contracts/GatewayFetchTarget.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./utils/NameCoder.sol";
import "./ICredentialResolverOffchain.sol";
import "./ICredentialResolver.sol";

/**
 * @title OffchainNameResolver
 * @dev Abstract base contract for offchain name-based resolvers
 * @notice This contract provides common functionality for resolving name-based ENS names
 * using gateway fetching. Concrete implementations only need to implement the credential
 * function and optionally override _fetchCredential for custom logic.
 */
abstract contract OffchainNameResolver is GatewayFetchTarget, ICredentialResolverOffchain, AccessControl {
    
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
     * @param identifier The DNS-encoded identifier (already extracted domain)
     * @param _credential The credential key for the text record
     * @return The result of the credential resolution
     */
    function credential(bytes calldata identifier, string calldata _credential) external view virtual returns (string memory);
    
    /**
     * @dev Extract domain identifier from DNS name
     * Expected format: domain.com.name.ecs.eth
     * Returns: DNS-encoded domain.com
     * @param name The full DNS-encoded name
     * @return identifier The DNS-encoded domain identifier
     */
    function _extractNameIdentifier(bytes calldata name) internal pure returns (bytes memory) {
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
                
                // If we reach here, pattern doesn't match - continue searching
                foundName = false;
            } else {
                // Move to next label
                pos += labelLength + 1;
            }
        }
        
        // If we reach here, no valid pattern was found
        revert InvalidDNSEncoding();
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
        return interfaceId == type(ICredentialResolverOffchain).interfaceId || 
               interfaceId == type(ICredentialResolver).interfaceId || 
               super.supportsInterface(interfaceId);
    }
}
