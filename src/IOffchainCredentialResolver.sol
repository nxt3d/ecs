// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./ICredentialResolver.sol";

/**
 * @title ICredentialResolverOffchain
 * @dev Interface for offchain credential resolvers that use gateway fetching
 * @notice Extends ICredentialResolver with the callback function required for gateway responses
 */
interface ICredentialResolverOffchain is ICredentialResolver {
    /**
     * @dev Callback function to process gateway response
     * @param values The values returned from the gateway
     * @param extraData Additional data from the gateway
     * @return The encoded result
     */
    function credentialCallback(bytes[] calldata values, uint8, bytes calldata extraData) 
        external view returns (bytes memory);
}
