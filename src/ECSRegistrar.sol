//SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {ECSRegistry} from "./ECSRegistry.sol";

error NameNotAvailable(bytes name);
error DurationTooShort(uint256 duration);
error InsufficientValue();
error WrongNumberOfChars(string label);
error CannotSetNewCharLengthAmounts();
error InvalidDuration(uint256 duration);

/**
 * @dev A registrar controller for registering and renewing names at fixed cost using ETH.
 */
contract ECSRegistrar is
    ERC165,
    AccessControl
{
    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Node for eth - keccak256(abi.encodePacked(0x0, keccak256("eth")))
    uint64 private constant MAX_EXPIRY = type(uint64).max;
    ECSRegistry public immutable ecsRegistry;
    
    // Commitments
    mapping(bytes32 => uint256) public commitments;
    uint256 public constant MIN_COMMITMENT_AGE = 60;
    
    error CommitmentNotFound(bytes32 commitment);
    error CommitmentTooNew(bytes32 commitment);
    error CommitmentAlreadyExists(bytes32 commitment);
    
    // The pricing and byte length requirements for subdomains
    uint64 public minRegistrationDuration;
    uint64 public maxRegistrationDuration;
    uint16 public minChars;
    uint16 public maxChars;
    uint256[] public charAmounts; // Price per second for each byte length (18 decimals precision)

    // Events
    event NameRegistered(
        string indexed label,
        address owner,
        uint256 cost,
        uint256 expires
    );
    
    event NameRenewed(
        string indexed label,
        uint256 cost,
        uint256 newExpiration
    );


    constructor(
        ECSRegistry _ecsRegistry
    ){
        ecsRegistry = _ecsRegistry;
        
        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Gets the total cost of registration in ETH
     * @param label The label to register (e.g., "alice")
     * @param duration The amount of time the name will be registered for in seconds
     * @return ethPrice The registration price in ETH (18 decimals)
     */
    function rentPrice(string memory label, uint256 duration)
        public
        view
        returns (uint256 ethPrice) 
    {
        // Use byte length instead of string length for more accurate pricing
        uint256 labelLength = bytes(label).length;

        // Get the length of the charAmounts array
        uint256 charAmountsLength = charAmounts.length;

        // The price per second for labels of this byte length (18 decimals precision)
        uint256 unitPrice;
        
        if (charAmountsLength > 0) {
            // Check to make sure the price for labelLength exists
            if(labelLength < charAmountsLength){
                // Get the unit price for the length of the label
                unitPrice = charAmounts[labelLength];

                // If the unit price is 0 then use the default amount
                if (unitPrice == 0){ 
                    unitPrice = charAmounts[0];
                } 
            } else {
                // Use the default amount
                unitPrice = charAmounts[0];
            }
        } else {
            // If there is no pricing data, return 0 (free)
            return 0;
        }

        // Calculate total price (18 decimals)
        return unitPrice * duration;
    }

    /**
     * @notice Checks if the length of the name is valid
     * @param label Label as a string
     */
    function validLength(string memory label) internal view returns (bool){
        // Use byte length instead of string length for more accurate validation
        uint256 labelLength = bytes(label).length;
        
        // The name is valid if the number of bytes is within limits
        if (labelLength >= minChars){
            // If the maximum characters is set then check the upper limit
            if (maxChars != 0 && labelLength > maxChars){
                return false; 
            } else {
                return true;
            }
        } else {
            return false; 
        }
    }

    /**
     * @notice Set the pricing parameters
     * @param _minRegistrationDuration The minimum duration a name can be registered for
     * @param _maxRegistrationDuration The maximum duration a name can be registered for
     * @param _minChars The minimum byte length a name can be
     * @param _maxChars The maximum byte length a name can be
     */
    function setParams(
        uint64 _minRegistrationDuration, 
        uint64 _maxRegistrationDuration,
        uint16 _minChars,
        uint16 _maxChars
    ) public onlyRole(ADMIN_ROLE) {
        minRegistrationDuration = _minRegistrationDuration;
        maxRegistrationDuration = _maxRegistrationDuration;
        minChars = _minChars;
        maxChars = _maxChars;
    }

    /**
     * @notice Set the pricing for all byte lengths
     * @param _charAmounts An array of prices per second for each byte length (18 decimals)
     */
    function setPricingForAllLengths(
        uint256[] calldata _charAmounts
    ) public onlyRole(ADMIN_ROLE) {
        // Clear the old dynamic array
        delete charAmounts;
        // Set the new pricing
        charAmounts = _charAmounts;
    }

    /**
     * @notice Get the price for a single byte length
     * @param charLength The byte length (use 0 for the default amount)
     */
    function getPriceDataForLength(uint16 charLength) public view returns (uint256){
        return charAmounts[charLength];
    }

    /**
     * @notice Set a price for a single byte length
     * @param charLength The byte length (use 0 for the default amount)
     * @param charAmount The price per second for labels of this byte length (18 decimals)
     */
    function updatePriceForCharLength(
        uint16 charLength,
        uint256 charAmount
    ) public onlyRole(ADMIN_ROLE) {
        // Check that the charLength is not greater than the last index
        if (charLength > charAmounts.length-1){
            revert CannotSetNewCharLengthAmounts();
        }
        charAmounts[charLength] = charAmount;
    }

    /**
     * @notice Adds a price for the next byte length
     * @param charAmount The price per second for labels of this byte length (18 decimals)
     */
    function addNextPriceForCharLength(
        uint256 charAmount
    ) public onlyRole(ADMIN_ROLE) {
        charAmounts.push(charAmount);
    }

    /**
     * @notice Get the last index for a byte length that has a price
     * @return The length of the last byte length that was set
     */
    function getLastCharIndex() public view returns (uint256) {
        return charAmounts.length - 1;
    }

    /**
     * @notice Check if a label is available for registration under the parent domain
     * @param label The label to check (e.g., "alice")
     */
    function available(string memory label) public view returns (bool) {
        bytes32 labelhash = keccak256(bytes(label));
        // The name is available if it is expired and is valid length
        return validLength(label) && ecsRegistry.isExpired(labelhash);
    }

    function commit(bytes32 commitment) external {
        if (commitments[commitment] != 0) revert CommitmentAlreadyExists(commitment);
        commitments[commitment] = block.timestamp;
    }

    function createCommitment(string memory label, address owner, address resolver, uint256 duration, bytes32 secret) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(label, owner, resolver, duration, secret));
    }

    function _consumeCommitment(string memory label, address owner, address resolver, uint256 duration, bytes32 secret) internal {
        bytes32 commitment = keccak256(abi.encodePacked(label, owner, resolver, duration, secret));
        uint256 timestamp = commitments[commitment];
        
        if (timestamp == 0) revert CommitmentNotFound(commitment);
        if (block.timestamp < timestamp + MIN_COMMITMENT_AGE) revert CommitmentTooNew(commitment);
        
        delete commitments[commitment];
    }

    /**
     * @notice Register a subdomain under the parent domain
     * @param label The label to register
     * @param owner The address that will own the name
     * @param resolver The resolver address for the name
     * @param duration The duration in seconds of the registration
     * @param secret The secret used in the commitment
     */
    function register(
        string calldata label,
        address owner,
        address resolver,
        uint256 duration,
        bytes32 secret
    ) public payable {
        _consumeCommitment(label, owner, resolver, duration, secret);

        // Check duration is within limits
        if (duration < minRegistrationDuration || duration > maxRegistrationDuration){
            revert InvalidDuration(duration); 
        }

        // Check label is valid length
        if(!validLength(label)){
            revert WrongNumberOfChars(label);
        }

        // Get the price in ETH using the label directly
        uint256 price = rentPrice(label, duration);

        // Check that sufficient ETH was sent
        if (msg.value < price) {
            revert InsufficientValue();
        }

        uint256 expires = block.timestamp + duration;

        // Register the subdomain in Registry
        ecsRegistry.setLabelhashRecord(
            label,
            owner,
            resolver,
            expires
        );

        // Refund excess ETH if any
        if (msg.value > price) {
            (bool success, ) = payable(msg.sender).call{value: msg.value - price}("");
            require(success, "Refund failed");
        }

        emit NameRegistered(
            label,
            owner,
            price,
            expires
        );
    }

    /**
    * @notice Renew a subdomain registration
    * @param label The name to be renewed
    * @param duration The duration to extend the registration
    */
    function renew(
        string calldata label, 
        uint256 duration
    ) public payable {
        bytes32 labelhash = keccak256(bytes(label));

        // Make sure the name is not expired
        require(!ecsRegistry.isExpired(labelhash), "Name is expired");

        // Get the price in ETH using the label directly
        uint256 price = rentPrice(label, duration);
        
        // Check that sufficient ETH was sent
        if (msg.value < price) {
            revert InsufficientValue();
        }

        // Extend the expiration in the registry
        uint256 currentExpiration = ecsRegistry.getExpiration(labelhash);
        uint256 newExpiration = currentExpiration + duration;
        ecsRegistry.extendExpiration(labelhash, newExpiration);

        // Refund excess ETH if any
        if (msg.value > price) {
            (bool success, ) = payable(msg.sender).call{value: msg.value - price}("");
            require(success, "Refund failed");
        }

        emit NameRenewed(label, price, newExpiration);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl, ERC165)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @notice Withdraw ETH from the contract (admin only)
     * @param amount Amount of ETH to withdraw
     */
    function withdraw(uint256 amount) external onlyRole(ADMIN_ROLE) {
        require(amount <= address(this).balance, "Insufficient contract balance");
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
    }

    /**
     * @notice Withdraw all ETH from the contract (admin only)
     */
    function withdrawAll() external onlyRole(ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "Transfer failed");
    }


} 