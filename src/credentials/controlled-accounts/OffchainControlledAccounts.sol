// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "../../OffchainAddrResolver.sol";
import {GatewayFetcher} from "@unruggable/contracts/GatewayFetcher.sol";

/**
 * @title OffchainControlledAccounts
 * @dev Offchain credential resolver for controlled accounts
 * @notice This contract resolves controlled accounts for address-based ENS names
 * using offchain gateway fetching. It inherits all common functionality from
 * OffchainAddrResolver and only implements the credential-specific logic.
 */
contract OffchainControlledAccounts is OffchainAddrResolver {
    
    using GatewayFetcher for GatewayRequest;

    /* --- Constructor --- */
    
    /// @dev Initialize with the verifier and target L2 address.
    /// @param verifier The gateway verifier contract.
    /// @param _targetL2Address The target L2 address for offchain resolution.
    constructor(IGatewayVerifier verifier, address _targetL2Address) 
        OffchainAddrResolver(verifier, _targetL2Address) {
    }
    
    /* --- Credential Resolution --- */

    /**
     * @dev Credential function for controlled accounts
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
            .setTarget(targetL2Address)
            .setSlot(3)
            .push(targetAddress)
            .follow()
            .push(coinType)
            .follow()
            .read()
            .setOutput(0);

        fetch(gatewayVerifier, r, this.credentialCallback.selector);
    }

    /**
     * @dev Callback function to process gateway response for controlled accounts
     * @param values The values returned from the gateway
     * @param extraData Additional data from the gateway (unused)
     * @return The encoded result as a string of controlled accounts
     */
    function credentialCallback(bytes[] calldata values, uint8, bytes calldata extraData) 
        external pure override returns (bytes memory) {
        require(values.length > 0, "No values provided");
        
        // The gateway should return controlled accounts data
        // For controlled accounts, we expect the data to be formatted as addresses
        // separated by newlines, which we'll return as-is
        bytes memory accountsData = values[0];
        string memory accountsString = string(accountsData);
        
        return abi.encode(accountsString);
    }
}