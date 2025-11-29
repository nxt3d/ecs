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


contract ECSRegistry is ERC165, AccessControl {

    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");

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
    event TextChanged(bytes32 indexed labelhash, string key, string value);
    event AddressChanged(bytes32 indexed labelhash, uint256 coinType, bytes newAddress);
    event ContenthashChanged(bytes32 indexed labelhash, bytes hash);
    
    // Lock Events
    event labelhashRentalSet(bytes32 indexed labelhash, uint256 expiration);
    event ExpirationExtended(bytes32 indexed labelhash, uint256 newExpiration);
    
    // Approvals from owners to approved addresses
    mapping(address owner => mapping(address approved => bool)) public approvals;
    
    struct Record {
        address owner;
        string label; // Store the original human-readable label
        uint256 expiration; // Expiration timestamp for the name
        mapping(string key => string value) textRecords;
        mapping(uint256 coinType => bytes addr) addressRecords;
        bytes contenthash;
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


    constructor() {
        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
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
     * @param keys Array of text record keys
     * @param values Array of text record values
     * @param coinTypes Array of coin types for address records
     * @param addresses Array of address records
     * @param contentHash Content hash
     */
    function setLabelhashRecord(
        string memory label,
        address newOwner,
        uint256 expiration,
        string[] memory keys,
        string[] memory values,
        uint256[] memory coinTypes,
        bytes[] memory addresses,
        bytes memory contentHash
    ) external onlyRole(REGISTRAR_ROLE) returns (bytes32) {
        bytes32 labelhash = keccak256(bytes(label));
        
        // Validate array lengths
        require(keys.length == values.length, KeysArrayLengthMismatch(keys.length, values.length));
        require(coinTypes.length == addresses.length, CoinTypesArrayLengthMismatch(coinTypes.length, addresses.length));
        
        // Make sure the name is expired (prevents registration of unexpired names)
        require(
            block.timestamp >= records[labelhash].expiration,
            labelhashNotExpired(labelhash, records[labelhash].expiration)
        );
        
        // Set owner and expiration
        records[labelhash].owner = newOwner;
        records[labelhash].expiration = expiration;
        emit Transfer(labelhash, newOwner);
        emit NewLabelhashOwner(labelhash, label, newOwner);
        
        // Only set label if it hasn't been set yet (label only needs to be set once)
        if (bytes(records[labelhash].label).length == 0) {
            records[labelhash].label = label;
        }
        
        // Set text records
        for (uint i = 0; i < keys.length; i++) {
            // Set text record only if it is changing
            if (keccak256(bytes(records[labelhash].textRecords[keys[i]])) != keccak256(bytes(values[i]))) {
                records[labelhash].textRecords[keys[i]] = values[i];
                emit TextChanged(labelhash, keys[i], values[i]);
            }
        }
        
        // Set address records
        for (uint i = 0; i < coinTypes.length; i++) {
            // Set address record only if it is changing
            if (keccak256(records[labelhash].addressRecords[coinTypes[i]]) != keccak256(addresses[i])) {
                records[labelhash].addressRecords[coinTypes[i]] = addresses[i];
                emit AddressChanged(labelhash, coinTypes[i], addresses[i]);
            }
        }
        
        // Set contenthash only if it is changing
        if (keccak256(records[labelhash].contenthash) != keccak256(contentHash)) {
            records[labelhash].contenthash = contentHash;
            emit ContenthashChanged(labelhash, contentHash);
        }
        
        return labelhash;
    }

    /**
     * @notice Sets multiple records for a specific labelhash, including owner, text records, address records, and contenthash.
     * @dev Only the authorized owner or an approved operator can call this function.
     *      The function allows updating the owner, text records, address records, and contenthash for a given labelhash.
     *      To skip updating the owner or contenthash, pass an empty array for `newOwners` or `contentHashs` respectively.
     *      Only one owner and one contenthash can be set at a time.
     * @param labelhash The labelhash of the record to update.
     * @param newOwner_s Array containing the new owner address. If empty, the owner is not updated.
     * @param expiration_s Array containing the new expiration. If empty, the expiration is not updated.
     * @param keys Array of text record keys to set.
     * @param values Array of text record values to set, corresponding to `keys`.
     * @param coinTypes Array of coin types for address records to set.
     * @param addresses Array of address records to set, corresponding to `coinTypes`.
     * @param contentHash_s Array containing the new contenthash. If empty, the contenthash is not updated.
     */
    function setRecord(
        bytes32 labelhash,
        address[] memory newOwner_s, // There is only one owner, but the empty array allows for not setting it. 
        uint256[] memory expiration_s, // There is only one expiration, but the empty array allows for not setting it. 
        string[] memory keys,
        string[] memory values,
        uint256[] memory coinTypes,  
        bytes[] memory addresses,
        bytes[] memory contentHash_s // There is only one contenthash, but the empty array allows for not setting it. 
    ) external authorized(labelhash) {

        // Make sure there is a name set for the labelhash
        require(
            bytes(records[labelhash].label).length > 0,
            labelhashNotSet(labelhash)
        );

        // Validate array lengths
        require(keys.length == values.length, KeysArrayLengthMismatch(keys.length, values.length));
        require(coinTypes.length == addresses.length, CoinTypesArrayLengthMismatch(coinTypes.length, addresses.length));
        require(newOwner_s.length <= 1, "Only one owner can be set");
        require(expiration_s.length <= 1, "Only one expiration can be set");
        require(contentHash_s.length <= 1, "Only one contenthash can be set");

        // Set owner (allows for not setting it with empty array)
        if (newOwner_s.length == 1) {
            records[labelhash].owner = newOwner_s[0];
            emit Transfer(labelhash, newOwner_s[0]);
        }

        // Set expiration (allows for not setting it with empty array)
        if (expiration_s.length == 1) {
            records[labelhash].expiration = expiration_s[0];
            emit ExpirationExtended(labelhash, expiration_s[0]);
        }
        
        // Set text records
        for (uint i = 0; i < keys.length; i++) {
                records[labelhash].textRecords[keys[i]] = values[i];
                emit TextChanged(labelhash, keys[i], values[i]);
        }
        
        // Set address records
        for (uint i = 0; i < coinTypes.length; i++) {
                records[labelhash].addressRecords[coinTypes[i]] = addresses[i];
                emit AddressChanged(labelhash, coinTypes[i], addresses[i]);
        }
        
        // Set contenthash (allows for not setting it with empty array)
        if (contentHash_s.length == 1) {
            records[labelhash].contenthash = contentHash_s[0];
            emit ContenthashChanged(labelhash, contentHash_s[0]);
        }
    }

    /**
     * @dev Sets a text record for a specific labelhash
     */
    function setText(
        bytes32 labelhash,
        string memory key,
        string memory value
    ) external authorized(labelhash) {
        
        records[labelhash].textRecords[key] = value;
        emit TextChanged(labelhash, key, value);
    }

    /**
     * @dev Sets an address record for a specific labelhash
     */
    function setAddr(
        bytes32 labelhash,
        uint256 coinType,
        bytes memory address_
    ) external authorized(labelhash) {
        
        records[labelhash].addressRecords[coinType] = address_;
        emit AddressChanged(labelhash, coinType, address_);
    }

    /**
     * @dev Sets ETH address for a labelhash (convenience function)
     */
    function setAddr(bytes32 labelhash, address address_) external authorized(labelhash) {
        
        records[labelhash].addressRecords[60] = abi.encodePacked(address_);
        emit AddressChanged(labelhash, 60, abi.encodePacked(address_));
    }

    /**
     * @dev Sets content hash for a specific labelhash
     */
    function setContenthash(
        bytes32 labelhash,
        bytes memory contentHash
    ) external authorized(labelhash) {
        
        records[labelhash].contenthash = contentHash;
        emit ContenthashChanged(labelhash, contentHash);
    }

    /**
     * @dev Sets approval for an operator to manage all caller's labelhashes
     * @param operator The address to approve or revoke approval for
     * @param approved Whether to approve or revoke approval
     */
    function setApprovalForAll(address operator, bool approved) external {
        // Users can only set approvals for themselves
        approvals[msg.sender][operator] = approved;
    }

    /**
     * @dev Checks if operator is approved for owner
     */
    function isApprovedForAll(address labelhashOwner, address operator) external view returns (bool) {
        return approvals[labelhashOwner][operator];
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
     * @dev Gets a text record
     */
    function text(bytes32 labelhash, string memory key) external view returns (string memory) {
        return records[labelhash].textRecords[key];
    }

    /**
     * @dev Gets an address record (with override priority)
     */
    function addr(bytes32 labelhash, uint256 coinType) external view returns (bytes memory) {
        return records[labelhash].addressRecords[coinType];
    }

    /**
     * @dev Gets ETH address for a labelhash (convenience function)
     */
    function addr(bytes32 labelhash) external view returns (address payable) {
        return payable(address(bytes20(records[labelhash].addressRecords[60])));
    }

    /**
     * @dev Gets content hash
     */
    function contenthash(bytes32 labelhash) external view returns (bytes memory) {
        return records[labelhash].contenthash;
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
        
        records[labelhash].expiration = newExpiration;
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
