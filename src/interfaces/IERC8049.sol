// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// @title IERC8049
/// @notice Interface for ERC-8049 Contract-Level Onchain Metadata
interface IERC8049 {
    /// @notice Emitted when contract metadata is updated
    /// @param indexedKey The indexed key for filtering
    /// @param key The metadata key
    /// @param value The metadata value
    event ContractMetadataUpdated(string indexed indexedKey, string key, bytes value);

    /// @notice Get contract-level metadata
    /// @param key The metadata key
    /// @return The metadata value as bytes
    function getContractMetadata(string memory key) external view returns (bytes memory);
}






