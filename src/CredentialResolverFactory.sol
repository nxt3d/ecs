// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {CredentialResolver} from "./CredentialResolver.sol";

/**
 * @title CredentialResolverFactory
 * @notice Factory for deploying minimal clones of CredentialResolver
 * @dev Uses EIP-1167 minimal proxy pattern for gas-efficient deployments
 */
contract CredentialResolverFactory {
    using Clones for address;

    // The implementation contract address
    address public immutable implementation;

    // Track deployed clones
    mapping(address clone => bool isClone) public isClone;
    address[] public clones;

    // Events
    event ResolverCloneDeployed(address indexed clone, address indexed owner);
    
    // Errors
    error InvalidOwner();

    /**
     * @notice Constructor
     * @param _implementation The CredentialResolver implementation address
     */
    constructor(address _implementation) {
        implementation = _implementation;
    }

    /**
     * @notice Deploy a new minimal clone of CredentialResolver
     * @param owner The owner address for the new resolver
     * @return clone The address of the deployed clone
     */
    function createResolver(address owner) external returns (address clone) {
        if (owner == address(0)) revert InvalidOwner();
        
        // Deploy minimal clone
        clone = implementation.clone();
        
        // Initialize the clone with the owner
        CredentialResolver(clone).initialize(owner);
        
        // Track the clone
        isClone[clone] = true;
        clones.push(clone);
        
        emit ResolverCloneDeployed(clone, owner);
        
        return clone;
    }

    /**
     * @notice Deploy a new minimal clone with deterministic address
     * @param owner The owner address for the new resolver
     * @param salt The salt for deterministic deployment
     * @return clone The address of the deployed clone
     */
    function createResolverDeterministic(address owner, bytes32 salt) external returns (address clone) {
        if (owner == address(0)) revert InvalidOwner();
        
        // Deploy minimal clone with deterministic address
        clone = implementation.cloneDeterministic(salt);
        
        // Initialize the clone with the owner
        CredentialResolver(clone).initialize(owner);
        
        // Track the clone
        isClone[clone] = true;
        clones.push(clone);
        
        emit ResolverCloneDeployed(clone, owner);
        
        return clone;
    }

    /**
     * @notice Predict the address of a deterministic clone
     * @param salt The salt for deterministic deployment
     * @return predicted The predicted clone address
     */
    function predictDeterministicAddress(bytes32 salt) external view returns (address predicted) {
        return implementation.predictDeterministicAddress(salt);
    }

    /**
     * @notice Get the total number of clones deployed
     * @return The number of clones
     */
    function getCloneCount() external view returns (uint256) {
        return clones.length;
    }

    /**
     * @notice Get a clone address by index
     * @param index The index
     * @return The clone address
     */
    function getClone(uint256 index) external view returns (address) {
        return clones[index];
    }
}

