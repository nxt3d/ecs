// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../../ICredentialResolver.sol";
import "../../utils/NameCoder.sol";

/**
 * @title StarNameResolver
 * @dev A star counting resolver for domain names.
 * Anyone can buy stars for any domain name.
 * Name format: domain.com.name.ecs.eth (DNS encoded)
 */
contract StarNameResolver is ICredentialResolver, AccessControl {
    
    /* --- Roles --- */
    
    bytes32 public constant ADMIN_ROLE = keccak256(bytes("ADMIN_ROLE"));
    
    /* --- Events --- */

    event StarPurchased(bytes32 indexed namehash, bytes domainIdentifier, address indexed buyer, uint256 newStarCount);
    event TextRecordKeyUpdated(string oldKey, string newKey);
    event StarPriceUpdated(uint256 oldPrice, uint256 newPrice);

    /* --- Storage --- */

    // The configurable text record key
    string public textRecordKey = "eth.ecs.ethstars.stars";     // Slot 1 * Accesess Control uses slot 0
    
    // The star price (updateable by admin)
    uint256 public starPrice = 0.000001 ether; // Testnet: 1000x cheaper // Slot 2
    
    // The star counts: namehash -> count
    mapping(bytes32 namehash => uint256 count) public starCounts; // Slot 3
    
    // Track if a buyer has already starred a domain
    mapping(address buyer => mapping(bytes32 namehash => bool hasStarred)) public hasStarred; // Slot 4

    /* --- Errors --- */

    error InsufficientPayment();
    error AlreadyStarred();
    error WithdrawalFailed();

    /* --- Constructor --- */

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /* --- Star Functions --- */

    /**
     * @dev Buy a star for a specific domain identifier
     * @param domainIdentifier The DNS-encoded domain identifier (e.g., "example.com")
     */
    function buyStar(bytes calldata domainIdentifier) external payable {
        if (msg.value != starPrice) revert InsufficientPayment();

        // Compute namehash from the domain identifier
        bytes32 namehash = NameCoder.namehash(domainIdentifier, 0);
        
        if (hasStarred[msg.sender][namehash]) {
            revert AlreadyStarred();
        }

        starCounts[namehash]++;
        hasStarred[msg.sender][namehash] = true;
        uint256 newCount = starCounts[namehash];

        emit StarPurchased(namehash, domainIdentifier, msg.sender, newCount);
    }

    /* --- View Functions --- */

    /**
     * @dev Check if an address has already starred a specific domain identifier
     * @param addr The address to check
     * @param domainIdentifier The DNS-encoded domain identifier to check
     * @return True if the address has already starred this domain
     */
    function hasStarredName(address addr, bytes memory domainIdentifier) external view returns (bool) {
        bytes32 namehash = NameCoder.namehash(domainIdentifier, 0);
        return hasStarred[addr][namehash];
    }

    /**
     * @dev Returns the star count for a domain identifier
     * @param identifier The DNS-encoded domain identifier
     * @param _credential The credential name to look up
     * @return The star count as a string, or empty string if not found
     */
    function credential(bytes calldata identifier, string calldata _credential) external view override returns (string memory) {
        // Only respond to the configured text record key
        if (keccak256(bytes(_credential)) != keccak256(bytes(textRecordKey))) {
            return "";
        }
        
        // Compute namehash directly from DNS-encoded identifier using NameCoder
        bytes32 namehash = NameCoder.namehash(identifier, 0);
        
        // Return the star count as a string
        return _uint256ToString(starCounts[namehash]);
    }

    /* --- Admin Functions --- */

    /**
     * @dev Change the text record key (admin only)
     * @param newKey The new text record key
     */
    function setTextRecordKey(string memory newKey) external onlyRole(ADMIN_ROLE) {
        string memory oldKey = textRecordKey;
        textRecordKey = newKey;
        
        emit TextRecordKeyUpdated(oldKey, newKey);
    }

    /**
     * @dev Update the star price (admin only)
     * @param newPrice The new star price in wei
     */
    function updateStarPrice(uint256 newPrice) external onlyRole(ADMIN_ROLE) {
        uint256 oldPrice = starPrice;
        starPrice = newPrice;
        emit StarPriceUpdated(oldPrice, newPrice);
    }

    /* --- Withdrawal --- */

    /**
     * @dev Withdraw collected ETH (admin only)
     */
    function withdraw() external onlyRole(ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        if (!success) revert WithdrawalFailed();
    }

    /* --- Internal Helper Functions --- */



    /**
     * @dev Convert uint256 to string
     * @param value The number to convert
     * @return The string representation
     */
    function _uint256ToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        
        return string(buffer);
    }
} 