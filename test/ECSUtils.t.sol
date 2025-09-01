// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/utils/ECSUtils.sol";

contract ECSUtilsTest is Test {
    using ECSUtils for bytes;
    
    /* --- Test Addresses --- */
    
    address constant TEST_ADDRESS = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045; // Vitalik's address
    uint256 constant ETHEREUM_COINTYPE = 60;
    
    /* --- parseIdentifier Tests --- */
    
    function test_parseIdentifier_success() public {
        // Create DNS-encoded identifier: address.cointype
        string memory addressHex = "d8da6bf26964af9d7eed9e03e53415d37aa96045";
        string memory cointypeHex = "3c"; // 60 in hex
        
        bytes memory identifier = _createDNSIdentifier(addressHex, cointypeHex);
        
        (address parsedAddress, uint256 parsedCointype) = _parseIdentifier(identifier);
        
        assertEq(parsedAddress, TEST_ADDRESS);
        assertEq(parsedCointype, ETHEREUM_COINTYPE);
    }
    
    function test_parseIdentifier_shortAddress() public {
        // Test with shorter address (20 bytes = 40 hex chars)
        string memory addressHex = "1234567890123456789012345678901234567890";
        string memory cointypeHex = "1"; // Bitcoin
        
        bytes memory identifier = _createDNSIdentifier(addressHex, cointypeHex);
        
        (address parsedAddress, uint256 parsedCointype) = _parseIdentifier(identifier);
        
        assertEq(parsedAddress, address(0x1234567890123456789012345678901234567890));
        assertEq(parsedCointype, 1);
    }
    
    /* --- hexStringToAddress Tests --- */
    
    function test_hexStringToAddress_success() public {
        bytes memory hexBytes = bytes("d8da6bf26964af9d7eed9e03e53415d37aa96045");
        
        address result = _hexStringToAddress(hexBytes);
        
        assertEq(result, TEST_ADDRESS);
    }
    
    function test_hexStringToAddress_shortAddress() public {
        bytes memory hexBytes = bytes("1234");
        
        address result = _hexStringToAddress(hexBytes);
        
        assertEq(result, address(0x1234));
    }
    
    /* --- hexStringToUint256 Tests --- */
    
    function test_hexStringToUint256_success() public {
        bytes memory hexBytes = bytes("3c"); // 60 in hex
        
        uint256 result = _hexStringToUint256(hexBytes);
        
        assertEq(result, 60);
    }
    
    function test_hexStringToUint256_large() public {
        bytes memory hexBytes = bytes("ff"); // 255 in hex
        
        uint256 result = _hexStringToUint256(hexBytes);
        
        assertEq(result, 255);
    }
    
    /* --- hexCharToUint Tests --- */
    
    function test_hexCharToUint_digits() public {
        assertEq(_hexCharToUint(bytes1('0')), 0);
        assertEq(_hexCharToUint(bytes1('5')), 5);
        assertEq(_hexCharToUint(bytes1('9')), 9);
    }
    
    function test_hexCharToUint_letters() public {
        assertEq(_hexCharToUint(bytes1('a')), 10);
        assertEq(_hexCharToUint(bytes1('f')), 15);
    }
    
    function test_hexCharToUint_invalid() public {
        assertEq(_hexCharToUint(bytes1('g')), 16); // Invalid
        assertEq(_hexCharToUint(bytes1('A')), 16); // Uppercase not allowed
    }
    

    
    /* --- addressToHexString Tests --- */
    
    function test_addressToHexString_success() public {
        bytes memory result = _addressToHexString(TEST_ADDRESS);
        
        assertEq(string(result), "0xd8da6bf26964af9d7eed9e03e53415d37aa96045");
    }
    
    function test_addressToHexString_zeroAddress() public {
        bytes memory result = _addressToHexString(address(0));
        
        assertEq(string(result), "0x0000000000000000000000000000000000000000");
    }
    
    /* --- Helper Functions --- */
    
    // Wrapper functions to test internal library functions
    function _parseIdentifier(bytes memory identifier) internal pure returns (address, uint256) {
        return ECSUtils.parseIdentifier(identifier);
    }
    
    function _hexStringToAddress(bytes memory hexBytes) internal pure returns (address) {
        return ECSUtils.hexStringToAddress(hexBytes);
    }
    
    function _hexStringToUint256(bytes memory hexBytes) internal pure returns (uint256) {
        return ECSUtils.hexStringToUint256(hexBytes);
    }
    
    function _hexCharToUint(bytes1 char) internal pure returns (uint256) {
        return ECSUtils.hexCharToUint(char);
    }
    
    function _addressToHexString(address addr) internal pure returns (bytes memory) {
        return ECSUtils.addressToHexString(addr);
    }
    
    function _createDNSIdentifier(string memory addressHex, string memory cointypeHex) internal pure returns (bytes memory) {
        bytes memory addressBytes = bytes(addressHex);
        bytes memory cointypeBytes = bytes(cointypeHex);
        
        // Calculate total length: address_length + address + cointype_length + cointype
        uint256 totalLength = 1 + addressBytes.length + 1 + cointypeBytes.length;
        
        bytes memory result = new bytes(totalLength);
        uint256 offset = 0;
        
        // Address label: length + hex chars
        result[offset++] = bytes1(uint8(addressBytes.length));
        for (uint256 i = 0; i < addressBytes.length; i++) {
            result[offset++] = addressBytes[i];
        }
        
        // Cointype label: length + hex chars
        result[offset++] = bytes1(uint8(cointypeBytes.length));
        for (uint256 i = 0; i < cointypeBytes.length; i++) {
            result[offset++] = cointypeBytes[i];
        }
        
        return result;
    }
}
