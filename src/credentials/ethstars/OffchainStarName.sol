// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "../../OffchainNameResolver.sol";
import {GatewayFetcher} from "@unruggable/contracts/GatewayFetcher.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title OffchainStarName
 * @dev Offchain credential resolver for star ratings by domain name
 * @notice This contract resolves star ratings for domain-based ENS names
 * using offchain gateway fetching. It inherits all common functionality from
 * OffchainNameResolver and only implements the credential-specific logic.
 */
contract OffchainStarName is OffchainNameResolver {
    
    using GatewayFetcher for GatewayRequest;

    /* --- Constructor --- */
    
    /// @dev Initialize with the verifier and target L2 address.
    /// @param verifier The gateway verifier contract.
    /// @param targetL2Address The target L2 address for offchain resolution.
    constructor(IGatewayVerifier verifier, address targetL2Address) 
        OffchainNameResolver(verifier, targetL2Address) {
    }
    
    /* --- Credential Resolution --- */

    /**
     * @dev Credential function for domain name star ratings
     * @param identifier The DNS-encoded identifier (already extracted domain)
     * @param _credential The credential key for the text record
     * @return The result of the credential resolution
     */
    function credential(bytes calldata identifier, string calldata _credential) 
        external view override returns (string memory) {
        // Use the identifier directly for gateway fetch
        bytes memory result = _fetchCredential(identifier, _credential);
        return abi.decode(result, (string));
    }

    /**
     * @dev Internal function to fetch credential using gateway
     * @param nameIdentifier The DNS-encoded domain identifier
     * @param key The credential key for the text record
     * @return The result of the gateway fetch
     * @notice Can be overridden by concrete contracts for custom logic
     */
    function _fetchCredential(bytes memory nameIdentifier, string memory key) internal view virtual returns (bytes memory) {
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

        fetch(_verifier, r, this.credentialCallback.selector);
    }

    /**
     * @dev Callback function to process gateway response for domain name star ratings
     * @param values The values returned from the gateway
     * @param extraData Additional data from the gateway (unused)
     * @return The encoded result as a string of star ratings
     */
    function credentialCallback(bytes[] calldata values, uint8, bytes calldata extraData) 
        external pure override returns (bytes memory) {
        require(values.length > 0, "No values provided");
        
        // Convert bytes to uint256, then to string
        uint256 value = uint256(bytes32(values[0]));
        string memory stars = Strings.toString(value);
        return abi.encode(stars);
    }
}
