// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title CredentialResolver
 * @author Unruggable
 * @notice A simple ENS resolver with text, addr, contenthash, and data support.
 */
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IExtendedResolver} from "./IExtendedResolver.sol";
import {NameCoder} from "./utils/NameCoder.sol";

contract CredentialResolver is Initializable, OwnableUpgradeable, IERC165, IExtendedResolver {

    // ENS method selectors
    bytes4 public constant ADDR_SELECTOR = bytes4(keccak256("addr(bytes32)"));
    bytes4 public constant ADDR_COINTYPE_SELECTOR = bytes4(keccak256("addr(bytes32,uint256)"));
    bytes4 public constant CONTENTHASH_SELECTOR = bytes4(keccak256("contenthash(bytes32)"));
    bytes4 public constant TEXT_SELECTOR = bytes4(keccak256("text(bytes32,string)"));
    bytes4 public constant DATA_SELECTOR = bytes4(keccak256("data(bytes32,string)"));

    // Coin type constants
    uint256 public constant ETHEREUM_COIN_TYPE = 60;

    // ENS record storage (single label resolver)
    mapping(uint256 coinType => bytes value) private addressRecords;
    bytes private contenthashRecord;
    mapping(string key => string value) private textRecords;
    mapping(string key => bytes data) private dataRecords;

    // Events
    event AddrChanged(address a);
    event AddressChanged(uint256 coinType, bytes newAddress);
    event ContenthashChanged(bytes hash);
    event TextChanged(string indexed key, string value);
    event DataChanged(string indexed key, bytes data);

    /**
     * @notice Constructor for implementation contract
     * @dev Implementation can be initialized for testing, but clones are the intended usage
     */
    constructor() {
        // Empty constructor - initializer modifier prevents double initialization
    }

    /**
     * @notice Initialize a cloned resolver (only callable once per clone)
     * @param _owner The address to set as the owner
     */
    function initialize(address _owner) external initializer {
        __Ownable_init(_owner);
    }

    /**
     * @notice Resolve data for a DNS-encoded name using ENSIP-10 interface.
     * @param name The DNS-encoded name.
     * @param data The ABI-encoded ENS method calldata.
     * @return The resolved data based on the method selector.
     */
    function resolve(bytes calldata name, bytes calldata data) external view override returns (bytes memory) {
        // Single label resolver - name parameter is ignored, this resolver serves one label only

        // Get the method selector (first 4 bytes)
        bytes4 selector = bytes4(data);

        if (selector == ADDR_SELECTOR) {
            bytes memory v = addressRecords[ETHEREUM_COIN_TYPE];
            if (v.length == 0) {
                return abi.encode(payable(0));
            }
            return abi.encode(bytesToAddress(v));
        } else if (selector == ADDR_COINTYPE_SELECTOR) {
            (, uint256 coinType) = abi.decode(data[4:], (bytes32, uint256));
            bytes memory a = addressRecords[coinType];
            return abi.encode(a);
        } else if (selector == CONTENTHASH_SELECTOR) {
            // contenthash(bytes32) - return content hash
            return abi.encode(contenthashRecord);
        } else if (selector == TEXT_SELECTOR) {
            // text(bytes32,string) - decode key and return text value
            (, string memory key) = abi.decode(data[4:], (bytes32, string));
            string memory value = textRecords[key];
            return abi.encode(value);
        } else if (selector == DATA_SELECTOR) {
            // data(bytes32,string) - decode key and return data value
            (, string memory keyStr) = abi.decode(data[4:], (bytes32, string));
            bytes memory dataValue = dataRecords[keyStr];
            return abi.encode(dataValue);
        }

        // Return empty bytes if no selector matches
        return abi.encode("");
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IExtendedResolver).interfaceId;
    }

    // ============ ENS Resolver Functions ============

    /**
     * @notice Set the ETH address (coin type 60).
     * @param _addr The EVM address to set.
     */
    function setAddr(address _addr) external onlyOwner {
        addressRecords[ETHEREUM_COIN_TYPE] = abi.encodePacked(_addr);
        emit AddrChanged(_addr);
    }

    /**
     * @notice Set a multi-coin address for a given coin type.
     * @param _coinType The coin type (per ENSIP-11).
     * @param _value The raw address bytes encoded for that coin type.
     */
    function setAddr(uint256 _coinType, bytes calldata _value) external onlyOwner {
        addressRecords[_coinType] = _value;
        emit AddressChanged(_coinType, _value);
        if (_coinType == ETHEREUM_COIN_TYPE) {
            emit AddrChanged(bytesToAddress(_value));
        }
    }

    /**
     * @notice Set the content hash.
     * @param _hash The content hash to set.
     */
    function setContenthash(bytes calldata _hash) external onlyOwner {
        contenthashRecord = _hash;
        emit ContenthashChanged(_hash);
    }

    /**
     * @notice Set a text record.
     * @param _key The text record key.
     * @param _value The text record value.
     */
    function setText(string calldata _key, string calldata _value) external onlyOwner {
        textRecords[_key] = _value;
        emit TextChanged(_key, _value);
    }

    /**
     * @notice Set a data record.
     * @param _key The data record key.
     * @param _data The data record value.
     */
    function setData(string calldata _key, bytes calldata _data) external onlyOwner {
        dataRecords[_key] = _data;
        emit DataChanged(_key, _data);
    }

    /**
     * @notice Get the address with a specific coin type.
     * @param _coinType The coin type (default: 60 for Ethereum).
     * @return The address for this coin type.
     */
    function addr(bytes32, uint256 _coinType) external view returns (bytes memory) {
        return addressRecords[_coinType];
    }

    /**
     * @notice Get the content hash.
     * @return The content hash.
     */
    function contenthash(bytes32) external view returns (bytes memory) {
        return contenthashRecord;
    }

    /**
     * @notice Get a text record.
     * @param _key The text record key.
     * @return The text record value.
     */
    function text(bytes32, string calldata _key) external view returns (string memory) {
        return textRecords[_key];
    }

    /**
     * @notice Get a data record.
     * @param _key The data record key.
     * @return The data record value.
     */
    function data(bytes32, string calldata _key) external view returns (bytes memory) {
        return dataRecords[_key];
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

}