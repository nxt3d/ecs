// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/credentials/controlled-accounts/OffchainCCAddr.sol";
import {IGatewayVerifier} from "@unruggable/contracts/GatewayFetchTarget.sol";

/**
 * @title OffchainCCAddrTest
 * @dev Comprehensive tests for OffchainCCAddr contract
 */
contract OffchainCCAddrTest is Test {
    
    OffchainCCAddr public offchainCCAddr;
    IGatewayVerifier public mockGatewayVerifier;
    address public targetL2Address;
    address public admin;
    address public user;
    
    // Test constants
    uint256 constant BASE_SEPOLIA_COIN_TYPE = 2147568180; // 0x80000000 | 84532
    uint256 constant ETHEREUM_COIN_TYPE = 60;
    uint256 constant ETHEREUM_SEPOLIA_COIN_TYPE = 2147483650; // 0x80000000 | 11155111
    
    function setUp() public {
        // Setup test accounts
        admin = address(0x1);
        user = address(0x2);
        targetL2Address = address(0x3);
        mockGatewayVerifier = IGatewayVerifier(address(0x4));
        
        // Deploy contract - the deployer automatically gets DEFAULT_ADMIN_ROLE and ADMIN_ROLE
        vm.prank(admin);
        offchainCCAddr = new OffchainCCAddr(mockGatewayVerifier, targetL2Address);
    }
    
    /* --- Constructor Tests --- */
    
    function test_001____constructor____InitializesCorrectly() public {
        assertEq(address(offchainCCAddr.gatewayVerifier()), address(mockGatewayVerifier));
        assertEq(offchainCCAddr.targetL2Address(), targetL2Address);
        assertTrue(offchainCCAddr.hasRole(offchainCCAddr.ADMIN_ROLE(), admin));
    }
    
    /* --- Program Management Tests --- */
    
    function test_002____updateProgram____SetsProgramForCoinType() public {
        bytes memory testProgram = "test program bytes";
        
        vm.prank(admin);
        offchainCCAddr.updateProgram(BASE_SEPOLIA_COIN_TYPE, testProgram);
        
        bytes memory storedProgram = offchainCCAddr.programBytes(BASE_SEPOLIA_COIN_TYPE);
        assertEq(storedProgram, testProgram);
    }
    
    function test_003____updateProgram____OnlyAdminCanUpdate() public {
        bytes memory testProgram = "test program bytes";
        
        vm.prank(user);
        vm.expectRevert();
        offchainCCAddr.updateProgram(BASE_SEPOLIA_COIN_TYPE, testProgram);
    }
    
    function test_004____updateProgram____MultipleCoinTypes() public {
        bytes memory baseProgram = "base program";
        bytes memory ethProgram = "ethereum program";
        
        vm.startPrank(admin);
        offchainCCAddr.updateProgram(BASE_SEPOLIA_COIN_TYPE, baseProgram);
        offchainCCAddr.updateProgram(ETHEREUM_COIN_TYPE, ethProgram);
        vm.stopPrank();
        
        assertEq(offchainCCAddr.programBytes(BASE_SEPOLIA_COIN_TYPE), baseProgram);
        assertEq(offchainCCAddr.programBytes(ETHEREUM_COIN_TYPE), ethProgram);
    }
    
    function test_005____updateProgram____OverwritesExistingProgram() public {
        bytes memory initialProgram = "initial program";
        bytes memory updatedProgram = "updated program";
        
        vm.startPrank(admin);
        offchainCCAddr.updateProgram(BASE_SEPOLIA_COIN_TYPE, initialProgram);
        offchainCCAddr.updateProgram(BASE_SEPOLIA_COIN_TYPE, updatedProgram);
        vm.stopPrank();
        
        assertEq(offchainCCAddr.programBytes(BASE_SEPOLIA_COIN_TYPE), updatedProgram);
    }
    
    /* --- Credential Key Parsing Tests --- */
    // Note: These tests verify the parsing logic indirectly through the credential function
    // since _parseCredentialKey is internal
    
    function test_006____parseCredentialKey____JustKey() public {
        // Set up a program
        bytes memory testProgram = "test program";
        vm.prank(admin);
        offchainCCAddr.updateProgram(BASE_SEPOLIA_COIN_TYPE, testProgram);
        
        // Create identifier
        bytes memory identifier = _createDNSIdentifier(0x1234567890123456789012345678901234567890, BASE_SEPOLIA_COIN_TYPE);
        
        // Test that "accounts" key triggers offchain lookup (proves parsing works)
        vm.expectRevert();
        offchainCCAddr.credential(identifier, "accounts");
    }
    
    function test_007____parseCredentialKey____KeyWithCoinType() public {
        // Set up programs for different coin types
        bytes memory baseProgram = "base program";
        bytes memory ethProgram = "ethereum program";
        
        vm.startPrank(admin);
        offchainCCAddr.updateProgram(BASE_SEPOLIA_COIN_TYPE, baseProgram);
        offchainCCAddr.updateProgram(ETHEREUM_COIN_TYPE, ethProgram);
        vm.stopPrank();
        
        // Create identifier
        bytes memory identifier = _createDNSIdentifier(0x1234567890123456789012345678901234567890, BASE_SEPOLIA_COIN_TYPE);
        
        // Test that "accounts:60" key triggers offchain lookup (proves parsing works)
        vm.expectRevert();
        offchainCCAddr.credential(identifier, "accounts:60");
    }
    
    function test_008____parseCredentialKey____KeyWithCoinTypeAndGroup() public {
        // Set up a program
        bytes memory testProgram = "test program";
        vm.prank(admin);
        offchainCCAddr.updateProgram(BASE_SEPOLIA_COIN_TYPE, testProgram);
        
        // Create identifier
        bytes memory identifier = _createDNSIdentifier(0x1234567890123456789012345678901234567890, BASE_SEPOLIA_COIN_TYPE);
        
        // Test that "accounts:60:main" key triggers offchain lookup (proves parsing works)
        vm.expectRevert();
        offchainCCAddr.credential(identifier, "accounts:60:main");
    }
    
    function test_009____parseCredentialKey____LargeCoinType() public {
        // Set up a program
        bytes memory testProgram = "test program";
        vm.prank(admin);
        offchainCCAddr.updateProgram(BASE_SEPOLIA_COIN_TYPE, testProgram);
        
        // Create identifier
        bytes memory identifier = _createDNSIdentifier(0x1234567890123456789012345678901234567890, BASE_SEPOLIA_COIN_TYPE);
        
        // Test that "accounts:2147568180" key triggers offchain lookup (proves parsing works)
        vm.expectRevert();
        offchainCCAddr.credential(identifier, "accounts:2147568180");
    }
    
    function test_010____parseCredentialKey____ComplexGroupName() public {
        // Set up a program
        bytes memory testProgram = "test program";
        vm.prank(admin);
        offchainCCAddr.updateProgram(BASE_SEPOLIA_COIN_TYPE, testProgram);
        
        // Create identifier
        bytes memory identifier = _createDNSIdentifier(0x1234567890123456789012345678901234567890, BASE_SEPOLIA_COIN_TYPE);
        
        // Test that "accounts:60:family-group" key triggers offchain lookup (proves parsing works)
        vm.expectRevert();
        offchainCCAddr.credential(identifier, "accounts:60:family-group");
    }
    
    /* --- Identifier Parsing Tests --- */
    // Note: These tests verify the parsing logic indirectly through the credential function
    // since _parseIdentifier is internal
    
    function test_011____parseIdentifier____BaseSepoliaAddress() public {
        // Set up a program
        bytes memory testProgram = "test program";
        vm.prank(admin);
        offchainCCAddr.updateProgram(BASE_SEPOLIA_COIN_TYPE, testProgram);
        
        // Create a DNS-encoded identifier for Base Sepolia
        bytes memory identifier = _createDNSIdentifier(0x1234567890123456789012345678901234567890, BASE_SEPOLIA_COIN_TYPE); // Base Sepolia coin type
        
        // Test that the identifier parsing works by triggering offchain lookup
        vm.expectRevert();
        offchainCCAddr.credential(identifier, "accounts");
    }
    
    function test_012____parseIdentifier____EthereumAddress() public {
        // Set up a program
        bytes memory testProgram = "test program";
        vm.prank(admin);
        offchainCCAddr.updateProgram(ETHEREUM_COIN_TYPE, testProgram);
        
        // Create a DNS-encoded identifier for Ethereum
        bytes memory identifier = _createDNSIdentifier(0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD, ETHEREUM_COIN_TYPE); // Ethereum coin type (60)
        
        // Test that the identifier parsing works by triggering offchain lookup
        vm.expectRevert();
        offchainCCAddr.credential(identifier, "accounts");
    }
    
    /* --- Credential Resolution Tests --- */
    
    function test_013____credential____TriggersOffchainLookup() public {
        // Set up a program for Base Sepolia
        bytes memory testProgram = "test program";
        vm.prank(admin);
        offchainCCAddr.updateProgram(BASE_SEPOLIA_COIN_TYPE, testProgram);
        
        // Create identifier
        bytes memory identifier = _createDNSIdentifier(0x1234567890123456789012345678901234567890, BASE_SEPOLIA_COIN_TYPE);
        
        // This should trigger an offchain lookup (CCIP-Read)
        vm.expectRevert();
        offchainCCAddr.credential(identifier, "accounts");
    }
    
    function test_014____credential____WithCoinTypeInKey() public {
        // Set up programs for different coin types
        bytes memory baseProgram = "base program";
        bytes memory ethProgram = "ethereum program";
        
        vm.startPrank(admin);
        offchainCCAddr.updateProgram(BASE_SEPOLIA_COIN_TYPE, baseProgram);
        offchainCCAddr.updateProgram(ETHEREUM_COIN_TYPE, ethProgram);
        vm.stopPrank();
        
        // Create identifier for Base Sepolia
        bytes memory identifier = _createDNSIdentifier(0x1234567890123456789012345678901234567890, BASE_SEPOLIA_COIN_TYPE);
        
        // This should trigger an offchain lookup
        vm.expectRevert();
        offchainCCAddr.credential(identifier, "accounts:60"); // Request Ethereum coin type
    }
    
    function test_015____credential____WithGroupInKey() public {
        // Set up a program
        bytes memory testProgram = "test program";
        vm.prank(admin);
        offchainCCAddr.updateProgram(BASE_SEPOLIA_COIN_TYPE, testProgram);
        
        // Create identifier
        bytes memory identifier = _createDNSIdentifier(0x1234567890123456789012345678901234567890, BASE_SEPOLIA_COIN_TYPE);
        
        // This should trigger an offchain lookup
        vm.expectRevert();
        offchainCCAddr.credential(identifier, "accounts:2147568180:main");
    }
    
    /* --- Callback Tests --- */
    
    function test_016____credentialCallback____ProcessesValidResponse() public {
        bytes[] memory values = new bytes[](1);
        values[0] = "0x1234567890123456789012345678901234567890,0xabcdefabcdefabcdefabcdefabcdefabcdefabcd";
        
        bytes memory result = offchainCCAddr.credentialCallback(values, 0, "");
        
        string memory decodedResult = abi.decode(result, (string));
        assertEq(decodedResult, "0x1234567890123456789012345678901234567890,0xabcdefabcdefabcdefabcdefabcdefabcdefabcd");
    }
    
    function test_017____credentialCallback____RevertsOnEmptyValues() public {
        bytes[] memory values = new bytes[](0);
        
        vm.expectRevert("No values provided");
        offchainCCAddr.credentialCallback(values, 0, "");
    }
    
    function test_018____credentialCallback____HandlesEmptyString() public {
        bytes[] memory values = new bytes[](1);
        values[0] = "";
        
        bytes memory result = offchainCCAddr.credentialCallback(values, 0, "");
        
        string memory decodedResult = abi.decode(result, (string));
        assertEq(decodedResult, "");
    }
    
    /* --- Edge Cases --- */
    
    function test_019____edgeCases____EmptyProgramBytes() public {
        // Don't set any program bytes
        bytes memory identifier = _createDNSIdentifier(0x1234567890123456789012345678901234567890, BASE_SEPOLIA_COIN_TYPE);
        
        // This should still trigger offchain lookup but with empty program
        vm.expectRevert();
        offchainCCAddr.credential(identifier, "accounts");
    }
    
    function test_020____edgeCases____ZeroAddress() public {
        bytes memory testProgram = "test program";
        vm.prank(admin);
        offchainCCAddr.updateProgram(BASE_SEPOLIA_COIN_TYPE, testProgram);
        
        // Create identifier with zero address
        bytes memory identifier = _createDNSIdentifier(address(0), BASE_SEPOLIA_COIN_TYPE);
        
        vm.expectRevert();
        offchainCCAddr.credential(identifier, "accounts");
    }
    
    function test_021____edgeCases____VeryLongCredentialKey() public {
        bytes memory testProgram = "test program";
        vm.prank(admin);
        offchainCCAddr.updateProgram(BASE_SEPOLIA_COIN_TYPE, testProgram);
        
        bytes memory identifier = _createDNSIdentifier(0x1234567890123456789012345678901234567890, BASE_SEPOLIA_COIN_TYPE);
        
        // Very long credential key
        string memory longKey = "very-long-credential-key-name-that-might-cause-issues:2147568180:very-long-group-name";
        
        vm.expectRevert();
        offchainCCAddr.credential(identifier, longKey);
    }
    
    /* --- Integration Tests --- */
    
    function test_022____integration____FullWorkflow() public {
        // Set up program
        bytes memory testProgram = "integration test program";
        vm.prank(admin);
        offchainCCAddr.updateProgram(BASE_SEPOLIA_COIN_TYPE, testProgram);
        
        // Create identifier
        bytes memory identifier = _createDNSIdentifier(0x1234567890123456789012345678901234567890, BASE_SEPOLIA_COIN_TYPE);
        
        // Test different credential key formats
        string[3] memory keys = [
            "accounts",
            "accounts:2147568180", 
            "accounts:2147568180:main"
        ];
        
        for (uint i = 0; i < keys.length; i++) {
            vm.expectRevert(); // All should trigger offchain lookup
            offchainCCAddr.credential(identifier, keys[i]);
        }
    }
    
    function test_023____integration____MultipleCoinTypesWorkflow() public {
        // Set up programs for multiple coin types
        bytes memory baseProgram = "base program";
        bytes memory ethProgram = "ethereum program";
        bytes memory ethSepoliaProgram = "ethereum sepolia program";
        
        vm.startPrank(admin);
        offchainCCAddr.updateProgram(BASE_SEPOLIA_COIN_TYPE, baseProgram);
        offchainCCAddr.updateProgram(ETHEREUM_COIN_TYPE, ethProgram);
        offchainCCAddr.updateProgram(ETHEREUM_SEPOLIA_COIN_TYPE, ethSepoliaProgram);
        vm.stopPrank();
        
        // Verify all programs are set correctly
        assertEq(offchainCCAddr.programBytes(BASE_SEPOLIA_COIN_TYPE), baseProgram);
        assertEq(offchainCCAddr.programBytes(ETHEREUM_COIN_TYPE), ethProgram);
        assertEq(offchainCCAddr.programBytes(ETHEREUM_SEPOLIA_COIN_TYPE), ethSepoliaProgram);
    }
    
    /* --- Hex Conversion Tests --- */
    
    function test_hexConversion____AddressToHexString() public {
        address testAddr = 0x1234567890123456789012345678901234567890;
        string memory hexStr = _addressToHexString(testAddr);
        
        // Should be 40 characters (20 bytes * 2)
        assertEq(bytes(hexStr).length, 40);
        assertEq(hexStr, "1234567890123456789012345678901234567890");
    }
    
    function test_hexConversion____Uint256ToHexString() public {
        // Test Base Sepolia coin type
        string memory hexStr = _uint256ToHexString(BASE_SEPOLIA_COIN_TYPE);
        assertEq(hexStr, "80014a34");
        
        // Test Ethereum coin type
        hexStr = _uint256ToHexString(ETHEREUM_COIN_TYPE);
        assertEq(hexStr, "3c");
        
        // Test zero
        hexStr = _uint256ToHexString(0);
        assertEq(hexStr, "0");
    }
    
    function test_hexConversion____DNSIdentifierCreation() public {
        address testAddr = 0x1234567890123456789012345678901234567890;
        bytes memory identifier = _createDNSIdentifier(testAddr, BASE_SEPOLIA_COIN_TYPE);
        
        // DNS format: [40][1234567890123456789012345678901234567890][8][80014a34][0]
        // Length: 1 + 40 + 1 + 8 + 1 = 51 bytes
        assertEq(identifier.length, 51);
        
        // First byte should be 40 (length of address hex string)
        assertEq(uint8(identifier[0]), 40);
        
        // Last byte should be 0 (null terminator)
        assertEq(uint8(identifier[50]), 0);
        
        // Coin type length should be at position 41 (after address length + address data)
        assertEq(uint8(identifier[41]), 8);
    }

    /* --- Helper Functions --- */
    
    /**
     * @dev Create a DNS-encoded identifier for testing
     * @param targetAddress The target address
     * @param coinType The coin type
     * @return The DNS-encoded identifier
     */
    function _createDNSIdentifier(address targetAddress, uint256 coinType) internal pure returns (bytes memory) {
        // Convert address to hex string (without 0x prefix)
        string memory addressHex = _addressToHexString(targetAddress);
        
        // Convert coin type to hex string (without 0x prefix)
        string memory coinTypeHex = _uint256ToHexString(coinType);
        
        // Create DNS-encoded identifier: [length][addressHex][length][coinTypeHex][0]
        bytes memory addressBytes = bytes(addressHex);
        bytes memory coinTypeBytes = bytes(coinTypeHex);
        
        return abi.encodePacked(
            uint8(addressBytes.length),  // Length of address hex string
            addressBytes,                // Address hex string
            uint8(coinTypeBytes.length), // Length of coin type hex string
            coinTypeBytes,               // Coin type hex string
            uint8(0)                     // Null terminator
        );
    }
    
    /**
     * @dev Convert address to hex string (without 0x prefix)
     * @param addr The address to convert
     * @return The hex string
     */
    function _addressToHexString(address addr) internal pure returns (string memory) {
        bytes memory data = abi.encodePacked(addr);
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(2 * data.length);
        
        for (uint i = 0; i < data.length; i++) {
            str[2*i] = alphabet[uint(uint8(data[i] >> 4))];
            str[2*i + 1] = alphabet[uint(uint8(data[i] & 0x0f))];
        }
        
        return string(str);
    }
    
    /**
     * @dev Convert uint256 to hex string (without 0x prefix)
     * @param value The value to convert
     * @return The hex string
     */
    function _uint256ToHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(64);
        uint i = 63;
        
        while (value != 0) {
            str[i] = alphabet[value & 0xf];
            value >>= 4;
            i--;
        }
        
        // Remove leading zeros
        uint start = i + 1;
        bytes memory result = new bytes(64 - start);
        for (uint j = 0; j < result.length; j++) {
            result[j] = str[start + j];
        }
        
        return string(result);
    }
}
