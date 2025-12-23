// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IERC8049} from "../interfaces/IERC8049.sol";

/**
 * @title ERC8049
 * @author @nxt3d
 * @notice Abstract extension for ERC-8049 Contract-Level Onchain Metadata
 * @dev Uses Diamond Storage pattern for predictable storage locations.
 *      Implementing contracts must define their own authorization logic.
 */
abstract contract ERC8049 is IERC8049 {
    /// @custom:storage-location erc8049.contract.metadata.storage
    struct ERC8049Storage {
        mapping(string key => bytes value) metadata;
    }

    // keccak256("erc8049.contract.metadata.storage")
    bytes32 private constant ERC8049_STORAGE_LOCATION =
        0x7c6988a1b2cb39fbaff1c9413b7b80ed9241f1bdbe6602ef83baf9d6673fd50a;

    function _getERC8049Storage() private pure returns (ERC8049Storage storage $) {
        bytes32 location = ERC8049_STORAGE_LOCATION;
        assembly {
            $.slot := location
        }
    }

    /// @inheritdoc IERC8049
    function getContractMetadata(string memory key) public view virtual returns (bytes memory) {
        ERC8049Storage storage $ = _getERC8049Storage();
        return $.metadata[key];
    }

    /**
     * @notice Internal function to set contract metadata
     * @dev Call this from your public setContractMetadata function after checking authorization
     * @param key The metadata key
     * @param value The metadata value as bytes
     */
    function _setContractMetadata(string calldata key, bytes calldata value) internal virtual {
        ERC8049Storage storage $ = _getERC8049Storage();
        $.metadata[key] = value;
        emit ContractMetadataUpdated(key, key, value);
    }
}






