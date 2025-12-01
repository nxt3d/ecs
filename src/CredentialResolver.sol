// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title CredentialResolver
 * @author Unruggable
 * @notice A simple ENS resolver with text, addr, contenthash, and data support.
 */
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IExtendedResolver} from "./IExtendedResolver.sol";
import {NameCoder} from "./utils/NameCoder.sol";

contract CredentialResolver is Ownable, IERC165, IExtendedResolver {
    /**
     * @notice Modifier to ensure only the label owner or authorized operator can call the function
     * @param _labelhash The labelhash to check authorization for
     */
    modifier onlyAuthorized(bytes32 _labelhash) {
        _authenticateCaller(msg.sender, _labelhash);
        _;
    }

    error NotAuthorized(address caller, bytes32 labelhash);

    // ENS method selectors
    bytes4 public constant ADDR_SELECTOR = bytes4(keccak256("addr(bytes32)"));
    bytes4 public constant ADDR_COINTYPE_SELECTOR = bytes4(keccak256("addr(bytes32,uint256)"));
    bytes4 public constant CONTENTHASH_SELECTOR = bytes4(keccak256("contenthash(bytes32)"));
    bytes4 public constant TEXT_SELECTOR = bytes4(keccak256("text(bytes32,string)"));
    bytes4 public constant DATA_SELECTOR = bytes4(keccak256("data(bytes32,string)"));

    // Coin type constants
    uint256 public constant ETHEREUM_COIN_TYPE = 60;

    // Chain data storage - REMOVED

    mapping(bytes32 _labelhash => address _owner) internal labelOwners;
    mapping(address _owner => mapping(address _operator => bool _isOperator)) internal operators;

    // ENS record storage
    mapping(bytes32 labelhash => mapping(uint256 coinType => bytes value)) private addressRecords;
    mapping(bytes32 labelhash => bytes contentHash) private contenthashRecords;
    mapping(bytes32 labelhash => mapping(string key => string value)) private textRecords;
    mapping(bytes32 labelhash => mapping(string key => bytes data)) private dataRecords;

    // Events
    event LabelOwnerSet(bytes32 indexed labelhash, address owner);
    event OperatorSet(address indexed owner, address indexed operator, bool approved);
    event AddrChanged(bytes32 indexed labelhash, address a);
    event AddressChanged(bytes32 indexed labelhash, uint256 coinType, bytes newAddress);
    event DataChanged(bytes32 indexed labelhash, string name, string key, bytes data);

    /**
     * @notice Constructor
     * @param _owner The address to set as the owner
     */
    constructor(address _owner) Ownable(_owner) {}

    /**
     * @notice Resolve data for a DNS-encoded name using ENSIP-10 interface.
     * @param name The DNS-encoded name.
     * @param data The ABI-encoded ENS method calldata.
     * @return The resolved data based on the method selector.
     */
    function resolve(bytes calldata name, bytes calldata data) external view override returns (bytes memory) {
        // Extract the first label from the DNS-encoded name
        (bytes32 labelhash,) = NameCoder.readLabel(name, 0);

        // Get the method selector (first 4 bytes)
        bytes4 selector = bytes4(data);

        if (selector == ADDR_SELECTOR) {
            bytes memory v = addressRecords[labelhash][ETHEREUM_COIN_TYPE];
            if (v.length == 0) {
                return abi.encode(payable(0));
            }
            return abi.encode(bytesToAddress(v));
        } else if (selector == ADDR_COINTYPE_SELECTOR) {
            (, uint256 coinType) = abi.decode(data[4:], (bytes32, uint256));
            bytes memory a = addressRecords[labelhash][coinType];
            return abi.encode(a);
        } else if (selector == CONTENTHASH_SELECTOR) {
            // contenthash(bytes32) - return content hash
            bytes memory contentHash = contenthashRecords[labelhash];
            return abi.encode(contentHash);
        } else if (selector == TEXT_SELECTOR) {
            // text(bytes32,string) - decode key and return text value
            (, string memory key) = abi.decode(data[4:], (bytes32, string));
            string memory value = textRecords[labelhash][key];
            return abi.encode(value);
        } else if (selector == DATA_SELECTOR) {
            // data(bytes32,string) - decode key and return data value
            (, string memory keyStr) = abi.decode(data[4:], (bytes32, string));
            bytes memory dataValue = dataRecords[labelhash][keyStr];
            return abi.encode(dataValue);
        }

        // Return empty bytes if no selector matches
        return abi.encode("");
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IExtendedResolver).interfaceId;
    }

    // ============ Access Control Functions ============

    /**
     * @notice Set the owner of a labelhash.
     */
    function setLabelOwner(bytes32 _labelhash, address _owner) external onlyAuthorized(_labelhash) {
        labelOwners[_labelhash] = _owner;
        emit LabelOwnerSet(_labelhash, _owner);
    }

    /**
     * @notice Set approval for an operator.
     */
    function setOperator(address _operator, bool _isOperator) external {
        operators[msg.sender][_operator] = _isOperator;
        emit OperatorSet(msg.sender, _operator, _isOperator);
    }

    /**
     * @notice Check if an address is authorized for a labelhash.
     */
    function isAuthorized(bytes32 _labelhash, address _address) external view returns (bool _authorized) {
        address _owner = labelOwners[_labelhash];
        return _owner == _address || operators[_owner][_address];
    }

    // ============ ENS Resolver Functions ============

    /**
     * @notice Set the ETH address (coin type 60) for a labelhash.
     * @param _labelhash The labelhash to update.
     * @param _addr The EVM address to set.
     */
    function setAddr(bytes32 _labelhash, address _addr) external onlyAuthorized(_labelhash) {
        addressRecords[_labelhash][ETHEREUM_COIN_TYPE] = abi.encodePacked(_addr);
        emit AddrChanged(_labelhash, _addr);
    }

    /**
     * @notice Set a multi-coin address for a given coin type.
     * @param _labelhash The labelhash to update.
     * @param _coinType The coin type (per ENSIP-11).
     * @param _value The raw address bytes encoded for that coin type.
     */
    function setAddr(bytes32 _labelhash, uint256 _coinType, bytes calldata _value)
        external
        onlyAuthorized(_labelhash)
    {
        addressRecords[_labelhash][_coinType] = _value;
        emit AddressChanged(_labelhash, _coinType, _value);
        if (_coinType == ETHEREUM_COIN_TYPE) {
            emit AddrChanged(_labelhash, bytesToAddress(_value));
        }
    }

    /**
     * @notice Set the content hash for a labelhash.
     * @param _labelhash The labelhash to update.
     * @param _hash The content hash to set.
     */
    function setContenthash(bytes32 _labelhash, bytes calldata _hash) external onlyAuthorized(_labelhash) {
        contenthashRecords[_labelhash] = _hash;
    }

    /**
     * @notice Set a text record for a labelhash.
     * @param _labelhash The labelhash to update.
     * @param _key The text record key.
     * @param _value The text record value.
     */
    function setText(bytes32 _labelhash, string calldata _key, string calldata _value)
        external
        onlyAuthorized(_labelhash)
    {
        textRecords[_labelhash][_key] = _value;
    }

    /**
     * @notice Set a data record for a labelhash.
     * @param _labelhash The labelhash to update.
     * @param _key The data record key.
     * @param _data The data record value.
     */
    function setData(bytes32 _labelhash, string calldata _key, bytes calldata _data)
        external
        onlyAuthorized(_labelhash)
    {
        dataRecords[_labelhash][_key] = _data;
        emit DataChanged(_labelhash, _key, _key, _data);
    }

    /**
     * @notice Get the address for a labelhash with a specific coin type.
     * @param _labelhash The labelhash to query.
     * @param _coinType The coin type (default: 60 for Ethereum).
     * @return The address for this label and coin type.
     */
    function getAddr(bytes32 _labelhash, uint256 _coinType) external view returns (bytes memory) {
        return addressRecords[_labelhash][_coinType];
    }

    /**
     * @notice Get the content hash for a labelhash.
     * @param _labelhash The labelhash to query.
     * @return The content hash for this label.
     */
    function getContenthash(bytes32 _labelhash) external view returns (bytes memory) {
        return contenthashRecords[_labelhash];
    }

    /**
     * @notice Get a text record for a labelhash.
     * @param _labelhash The labelhash to query.
     * @param _key The text record key.
     * @return The text record value.
     */
    function getText(bytes32 _labelhash, string calldata _key) external view returns (string memory) {
        return textRecords[_labelhash][_key];
    }

    /**
     * @notice Get a data record for a labelhash.
     * @param _labelhash The labelhash to query.
     * @param _key The data record key.
     * @return The data record value.
     */
    function getData(bytes32 _labelhash, string calldata _key) external view returns (bytes memory) {
        return dataRecords[_labelhash][_key];
    }

    /**
     * @notice Get the owner of a labelhash.
     * @param _labelhash The labelhash to query.
     * @return The owner address.
     */
    function getOwner(bytes32 _labelhash) external view returns (address) {
        return labelOwners[_labelhash];
    }

    /**
     * @notice Decodes a packed 20-byte value into an EVM address.
     * @param b The 20-byte sequence.
     * @return a The decoded payable address.
     * @dev Reverts if `b.length != 20`.
     */
    function bytesToAddress(bytes memory b) internal pure returns (address payable a) {
        require(b.length == 20);
        assembly {
            a := div(mload(add(b, 32)), exp(256, 12))
        }
    }

    /**
     * @notice Authenticates the caller for a given labelhash.
     * @param _caller The address to check.
     * @param _labelhash The labelhash to check.
     */
    function _authenticateCaller(address _caller, bytes32 _labelhash) internal view {
        // Allow contract owner to override
        if (_caller == owner()) return;

        address _owner = labelOwners[_labelhash];
        if (_owner != _caller && !operators[_owner][_caller]) {
            revert NotAuthorized(_caller, _labelhash);
        }
    }
}