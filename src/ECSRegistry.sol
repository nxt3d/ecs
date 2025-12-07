// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title ECSRegistry
 * @notice An ENS Registry with no sub-subanames. 
 * 
 * @dev This contract provides a comprehensive system for managing subnames
 * with the following key features:
 * 1. Rental system: Names can be rented for a period of time.
 * 
 * @author @nxt3d
 */

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./ENS.sol";
import "./utils/NameCoder.sol";


contract ECSRegistry is ERC165, AccessControl {

    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");

    // ENS Integration
    ENS public immutable ens;
    bytes32 public immutable rootNode;

    // Custom Errors
    error NotAuthorised(bytes32 labelhash, address caller);
    error NotRegistrar(bytes32 labelhash, address caller);
    error labelhashDoesNotExist(bytes32 labelhash);
    error KeysArrayLengthMismatch(uint256 keysLength, uint256 valuesLength);
    error CoinTypesArrayLengthMismatch(uint256 coinTypesLength, uint256 addressesLength);
    error labelhashNotExpired(bytes32 labelhash, uint256 expiration);
    error CannotReduceExpirationTime(uint256 currentExpiration, uint256 newExpiration);
    error labelhashNotSet(bytes32 labelhash);

    // Events
    event NewLabelhashOwner(bytes32 indexed labelhash, string indexed label, address owner);
    event Transfer(bytes32 indexed labelhash, address owner);
    
    // Profile Events
    event ResolverChanged(bytes32 indexed labelhash, address resolver);
    event ResolverReviewUpdated(bytes32 indexed labelhash, string review);
    
    // Lock Events
    event labelhashRentalSet(bytes32 indexed labelhash, uint256 expiration);
    event ExpirationExtended(bytes32 indexed labelhash, uint256 newExpiration);
    
    // Approvals from owners to approved addresses
    mapping(address owner => mapping(address approved => bool)) public approvals;
    
    // Mapping of resolver addresses to labelhashes to ensure 1-to-1 binding
    mapping(address resolver => bytes32 labelhash) public resolverToLabelhash;

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    
    // Custom Errors (additional)
    error ResolverAlreadyInUse(address resolver, bytes32 labelhash);
    error CommitmentNotFound(bytes32 commitment);
    error CommitmentTooNew(bytes32 commitment);
    error CommitmentAlreadyExists(bytes32 commitment);

    // Commitments
    mapping(bytes32 => uint256) public commitments;
    uint256 public constant MIN_COMMITMENT_AGE = 60;

    struct Record {
        address owner;
        string label; // Store the original human-readable label
        uint128 expiration; // Expiration timestamp for the name
        uint128 resolverUpdated; // Timestamp of last resolver update
        string review; // Review string for the resolver (admin only)
    }

    mapping(bytes32 labelhash => Record record) records;

    modifier authorized(bytes32 labelhash) {
        address labelhashOwner = records[labelhash].owner;
        require(
            labelhashOwner == msg.sender || approvals[labelhashOwner][msg.sender],
            NotAuthorised(labelhash, msg.sender)
        );
        _;
    }

    modifier authorizedOrRegistrar(bytes32 labelhash) {
        address labelhashOwner = records[labelhash].owner;
        require(
            labelhashOwner == msg.sender || approvals[labelhashOwner][msg.sender] || hasRole(REGISTRAR_ROLE, msg.sender),
            NotAuthorised(labelhash, msg.sender)
        );

        // Make sure the name is not expired, expired names must be registered again
        require(
            block.timestamp <= records[labelhash].expiration,
            labelhashNotExpired(labelhash, records[labelhash].expiration)
        );
        _;
    }


    constructor(ENS _ens, bytes32 _rootNode) {
        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        
        ens = _ens;
        rootNode = _rootNode;
    }

    // Registry Functions

    /**
     * @dev Sets the owner of a labelhash
     * Can only be called when the labelhash is in transfer mode (secure state)
     */
    function setOwner(bytes32 labelhash, address newOwner) external authorized(labelhash) {
        records[labelhash].owner = newOwner;
        emit Transfer(labelhash, newOwner);
    }



    /**
     * @dev Sets a complete record for a labelhash using parent + label pattern
     * @param label The human-readable label for the subdomain (e.g., "alice", "subdomain")
     * @param newOwner The new owner for the labelhash
     * @param resolver_ The resolver address for the labelhash
     * @param expiration The expiration timestamp for the labelhash
     */
    function setLabelhashRecord(
        string memory label,
        address newOwner,
        address resolver_,
        uint256 expiration
    ) external onlyRole(REGISTRAR_ROLE) returns (bytes32) {
        bytes32 labelhash = keccak256(bytes(label));
        
        // Make sure the name is expired (prevents registration of unexpired names)
        require(
            block.timestamp >= records[labelhash].expiration,
            labelhashNotExpired(labelhash, records[labelhash].expiration)
        );
        
        // Set owner and expiration
        records[labelhash].owner = newOwner;
        records[labelhash].expiration = uint128(expiration);
        records[labelhash].resolverUpdated = uint128(block.timestamp);
        
        // Set resolver with unique check
        _updateResolver(labelhash, resolver_);
        
        emit Transfer(labelhash, newOwner);
        emit NewLabelhashOwner(labelhash, label, newOwner);
        
        // Only set label if it hasn't been set yet (label only needs to be set once)
        if (bytes(records[labelhash].label).length == 0) {
            records[labelhash].label = label;
        }
        
        return labelhash;
    }
    /**
     * @dev Commits a hash for future revealing
     * @param commitment The hash of the data to be revealed
     */
    function commit(bytes32 commitment) external {
        if (commitments[commitment] != 0) revert CommitmentAlreadyExists(commitment);
        commitments[commitment] = block.timestamp;
    }


    /**
     * @notice Sets multiple records for a specific labelhash, including owner and resolver.
     * @dev Only the authorized owner or an approved operator can call this function.
     *      The function allows updating the owner and resolver for a given labelhash.
     *      Only one owner and one resolver can be set at a time.
     * @param labelhash The labelhash of the record to update.
     * @param newOwner The new owner address.
     * @param resolver_ The new resolver address.
     * @param secret The secret used in the commitment
     */
    function setRecord(
        bytes32 labelhash,
        address newOwner,
        address resolver_,
        bytes32 secret
    ) external authorized(labelhash) {
        _consumeCommitment(labelhash, newOwner, resolver_, secret);

        // Make sure there is a name set for the labelhash
        require(
            bytes(records[labelhash].label).length > 0,
            labelhashNotSet(labelhash)
        );

        // Set owner
        records[labelhash].owner = newOwner;
        emit Transfer(labelhash, newOwner);
        
        // Set resolver with unique check
        _updateResolver(labelhash, resolver_);
    }


    /**
     * @dev Sets the resolver for a labelhash
     */
    function setResolver(bytes32 labelhash, address resolver_, bytes32 secret) external authorized(labelhash) {
        _consumeCommitment(labelhash, records[labelhash].owner, resolver_, secret);
        _updateResolver(labelhash, resolver_);
    }

    /**
     * @dev Sets or unsets the approval of a given operator
     * @param operator The address to approve or disapprove
     * @param approved The approval status to set
     */
    function setApprovalForAll(address operator, bool approved) external {
        approvals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /**
     * @dev Internal function to update the resolver and ensure 1-to-1 mapping
     */
    function _updateResolver(bytes32 labelhash, address newResolver) internal {
        bytes32 node = NameCoder.namehash(rootNode, labelhash);
        address oldResolver = address(0);
        
        if (address(ens) != address(0)) {
            oldResolver = ens.resolver(node);
        }
        
        // If the resolver is changing
        if (oldResolver != newResolver) {
            // Clean up old mapping
            if (oldResolver != address(0)) {
                delete resolverToLabelhash[oldResolver];
            }
            
            // Validate and set new mapping
            if (newResolver != address(0)) {
                // Check if new resolver is already used by another labelhash
                if (resolverToLabelhash[newResolver] != bytes32(0)) {
                    revert ResolverAlreadyInUse(newResolver, resolverToLabelhash[newResolver]);
                }
                resolverToLabelhash[newResolver] = labelhash;
            }
            
            // records[labelhash].resolver removed
            
            // Update ENS Registry
            if (address(ens) != address(0)) {
                ens.setSubnodeRecord(rootNode, labelhash, address(this), newResolver, 0);
            }
            
            records[labelhash].resolverUpdated = uint128(block.timestamp);
            emit ResolverChanged(labelhash, newResolver);
        }
    }

    /**
     * @dev Internal function to verify and consume a commitment
     */
    function _consumeCommitment(bytes32 labelhash, address owner, address resolver, bytes32 secret) internal {
        bytes32 commitment = keccak256(abi.encodePacked(labelhash, owner, resolver, secret));
        uint256 timestamp = commitments[commitment];
        
        if (timestamp == 0) revert CommitmentNotFound(commitment);
        if (block.timestamp < timestamp + MIN_COMMITMENT_AGE) revert CommitmentTooNew(commitment);
        
        delete commitments[commitment];
    }

    // View Functions

    /**
     * @dev Gets the owner of a labelhash
     */
    function owner(bytes32 labelhash) external view returns (address) {
        address labelhashOwner = records[labelhash].owner;
        return labelhashOwner;
    }

    /**
     * @dev Gets the resolver of a labelhash
     */
    function resolver(bytes32 labelhash) external view returns (address) {
        if (address(ens) == address(0)) return address(0);
        bytes32 node = NameCoder.namehash(rootNode, labelhash);
        return ens.resolver(node);
    }

    /**
     * @dev Returns the human-readable label for a labelhash
     * @param labelhash The labelhash to get the label for
     * @return string The human-readable label
     */
    function getLabel(bytes32 labelhash) external view returns (string memory) {
        return records[labelhash].label;
    }

    /**
     * @dev Returns the label string, last resolver update timestamp, and admin review associated with a resolver address
     * @param resolver_ The resolver address to look up
     * @return label The human-readable label
     * @return resolverUpdated The timestamp of the last resolver update
     * @return review The admin review string
     */
    function getResolverInfo(address resolver_) external view returns (string memory label, uint128 resolverUpdated, string memory review) {
        bytes32 labelhash = resolverToLabelhash[resolver_];
        if (labelhash == bytes32(0)) {
            return ("", 0, "");
        }
        return (records[labelhash].label, records[labelhash].resolverUpdated, records[labelhash].review);
    }

    /**
     * @dev Sets the review string for a resolver (admin only)
     * @param resolver_ The resolver address to review
     * @param review The review string
     */
    function setResolverReview(address resolver_, string calldata review) external onlyRole(ADMIN_ROLE) {
        bytes32 labelhash = resolverToLabelhash[resolver_];
        require(labelhash != bytes32(0), "Resolver not registered");
        
        records[labelhash].review = review;
        emit ResolverReviewUpdated(labelhash, review);
    }

    /**
     * @dev Extends the expiration time
     * @param labelhash The labelhash to extend lock for
     * @param newExpiration The new expiration timestamp (must be later than current)
     */
    function extendExpiration(bytes32 labelhash, uint256 newExpiration) external onlyRole(REGISTRAR_ROLE) {

        // Make sure the new expiration is greater than the current expiration. 
        require(
            newExpiration > records[labelhash].expiration,
            CannotReduceExpirationTime(records[labelhash].expiration, newExpiration)
        );
        
        records[labelhash].expiration = uint128(newExpiration);
        emit ExpirationExtended(labelhash, newExpiration);
    }

    /**
     * @dev Checks if a labelhash is currently expired
     * @param labelhash The labelhash to check
     * @return bool True if the labelhash is expired
     */
    function isExpired(bytes32 labelhash) external view returns (bool) {
        return block.timestamp > records[labelhash].expiration;
    }

    /**
     * @dev Helper to create a commitment hash
     */
    function createCommitment(bytes32 labelhash, address owner, address resolver, bytes32 secret) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(labelhash, owner, resolver, secret));
    }

    /**
     * @dev Gets the expiration timestamp for a labelhash
     * @param labelhash The labelhash to check
     * @return uint256 The expiration timestamp (0 if not locked)
     */
    function getExpiration(bytes32 labelhash) external view returns (uint256) {
        return records[labelhash].expiration;
    }

    // ERC165 Support
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
