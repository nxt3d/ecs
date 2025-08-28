// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "../../OffchainAddrResolver.sol";
import {GatewayFetcher} from "@unruggable/contracts/GatewayFetcher.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title OffchainStarAddr
 * @dev Offchain credential resolver for star ratings
 * @notice This contract resolves star ratings for address-based ENS names
 * using offchain gateway fetching. It inherits all common functionality from
 * OffchainAddrResolver and only implements the credential-specific logic.
 */
contract OffchainStarAddr is OffchainAddrResolver {
    
    using GatewayFetcher for GatewayRequest;

    /* --- Constructor --- */
    
    /// @dev Initialize with the verifier and target L2 address.
    /// @param verifier The gateway verifier contract.
    /// @param targetL2Address The target L2 address for offchain resolution.
    constructor(IGatewayVerifier verifier, address targetL2Address) 
        OffchainAddrResolver(verifier, targetL2Address) {
    }
    
    /* --- Credential Resolution --- */

    /**
     * @dev Credential function for star ratings
     * @param identifier The DNS-encoded identifier (already extracted address.cointype)
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
     * @param identifier The DNS-encoded address.cointype identifier
     * @param key The credential key for the text record
     * @return The result of the gateway fetch
     * @notice Can be overridden by concrete contracts for custom logic
     */
    function _fetchCredential(bytes memory identifier, string memory key) internal view virtual returns (bytes memory) {
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

        fetch(_verifier, r, this.credentialCallback.selector);
    }

    /**
     * @dev Callback function to process gateway response for star ratings
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
