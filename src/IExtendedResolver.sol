// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IExtendedResolver {
    /**
     * @dev Performs ENS name resolution for the supplied name and resolution data.
     * @param name The name to resolve, in normalised and DNS-encoded form.
     * @param data The resolution data, as specified in ENSIP-10.
     * @return The result of resolving the name.
     */
    function resolve(
        bytes memory name,
        bytes memory data
    ) external view returns (bytes memory);
} 