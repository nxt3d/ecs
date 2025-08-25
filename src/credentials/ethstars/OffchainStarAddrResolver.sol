// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

 
import {GatewayFetcher, GatewayRequest} from "@unruggable/contracts/GatewayFetcher.sol";
import {GatewayFetchTarget, IGatewayVerifier} from "@unruggable/contracts/GatewayFetchTarget.sol";
import {IExtendedResolver} from "../../IExtendedResolver.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../../utils/HexUtils.sol";

contract OffchainStarAddrResolver is GatewayFetchTarget, IExtendedResolver, AccessControl {
    
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
     * @param identifier The DNS-encoded identifier (already extracted address.cointype)
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

        // Parse the address+cointype identifier from the DNS name
        bytes memory identifier = _extractAddressIdentifier(name);

        // Use the extracted identifier for gateway fetch
        return _fetchCredential(identifier, key);    

    }

    /**
     * @dev Internal function to fetch credential using gateway
     * @param identifier The DNS-encoded address.cointype identifier
     * @param key The credential key for the text record
     * @return The result of the gateway fetch
     */
    function _fetchCredential(bytes memory identifier, string memory key) internal view returns (bytes memory) {
        // Parse address and cointype from DNS-encoded identifier (reverts on invalid format)
        (address targetAddress, uint256 coinType) = _parseIdentifier(identifier);

        GatewayRequest memory r = GatewayFetcher
            .newRequest(1)
            .setTarget(_targetL2Address)
            .setSlot(3)
            .push(targetAddress)
            .follow()
            .push(coinType)
            .follow()
            .read()
            .setOutput(0);

		fetch(_verifier, r, this.resolveCallback.selector);
    }

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