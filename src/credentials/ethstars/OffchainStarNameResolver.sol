// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

 
import {GatewayFetcher, GatewayRequest} from "@unruggable/contracts/GatewayFetcher.sol";
import {GatewayFetchTarget, IGatewayVerifier} from "@unruggable/contracts/GatewayFetchTarget.sol";
import {IExtendedResolver} from "../../IExtendedResolver.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../../utils/NameCoder.sol";

contract OffchainStarNameResolver is GatewayFetchTarget, AccessControl, IExtendedResolver {

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
     * @dev Credential function that directly uses the provided identifier
     * @param identifier The DNS-encoded identifier (already extracted domain)
     * @param _credential The credential key for the text record
     * @return The result of the credential resolution
     */
    function credential(bytes calldata identifier, string calldata _credential) external view returns (bytes memory) {
        // Use the identifier directly for gateway fetch
        return _fetchCredential(identifier, _credential);
    }

    /**
     * @dev Resolve credentials for an address-based ENS name
     * @param name The DNS-encoded name
     * @param data The resolver function call data
     * @return The result of the resolver call
     */
    function resolve(bytes calldata name, bytes calldata data) external view returns (bytes memory) {
        
        bytes4 selector = bytes4(data);
        
        // Only support text(bytes32,string) function
        if (selector != 0x59d1d43c) { // text(bytes32,string) selector
            revert UnsupportedFunction(selector);
        }
        
        // Decode the function call to get the key
        (, string memory key) = abi.decode(data[4:], (bytes32, string));
        
        
        // Extract the name identifier from the DNS name
        bytes memory nameIdentifier = _extractNameIdentifier(name);

        // Use the extracted identifier for gateway fetch
        return _fetchCredential(nameIdentifier, key);    

    }

    /**
     * @dev Internal function to fetch credential using gateway
     * @param nameIdentifier The DNS-encoded domain identifier
     * @param key The credential key for the text record
     * @return The result of the gateway fetch
     */
    function _fetchCredential(bytes memory nameIdentifier, string memory key) internal view returns (bytes memory) {
        // Compute namehash directly from DNS-encoded identifier using NameCoder
        bytes32 namehash = NameCoder.namehash(nameIdentifier, 0);

        GatewayRequest memory r = GatewayFetcher
            .newRequest(1)
            .setTarget(_targetL2Address)
            .setSlot(3)
            .push(namehash)
            .follow()
            .read()
            .setOutput(0);

		fetch(_verifier, r, this.resolveCallback.selector);
    }

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

    /* --- Callback --- */

    /**
     * @dev Callback function for the gateway fetcher
     * @param values The values returned from the gateway fetcher
     * @param extraData The extra data passed to the callback
     * @return The result of the callback
     */
    function resolveCallback(bytes[] calldata values, uint8, bytes calldata extraData) external pure returns (bytes memory) {
        require(values.length > 0, "No values provided");
        
        // Convert bytes to uint256, then to string
        uint256 value = uint256(bytes32(values[0]));
        string memory stars = Strings.toString(value);
        return abi.encode(stars);
	}
    


    /* --- ERC165 Support --- */
    
    function supportsInterface(bytes4 interfaceId) public override view virtual returns (bool) {
        return interfaceId == type(IExtendedResolver).interfaceId || super.supportsInterface(interfaceId); // ERC165 interface ID

    }
}