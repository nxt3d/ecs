// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/credentials/ethstars/StarResolver.sol";

contract StarResolverTest is Test {
    StarResolver public starResolver;
    
    /* --- Test Accounts --- */
    
    address admin = address(0x1001);
    address user1 = address(0x1002);
    address user2 = address(0x1003);
    address user3 = address(0x1004);
    address newAdmin = address(0x1005);
    
    /* --- Test Constants --- */
    
    uint256 constant DEFAULT_STAR_PRICE = 0.000001 ether; // Testnet price
    string constant DEFAULT_TEXT_RECORD_KEY = "eth.ecs.ethstars.stars";
    
    // Test addresses for starring
    address constant TARGET_ADDRESS_1 = address(0x1234567890123456789012345678901234567890);
    address constant TARGET_ADDRESS_2 = address(0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD);
    address constant TARGET_ADDRESS_3 = address(0x9876543210987654321098765432109876543210);
    
    // Test chain IDs
    uint256 constant ETHEREUM_MAINNET = 1;
    uint256 constant POLYGON_MAINNET = 137;
    uint256 constant ARBITRUM_MAINNET = 42161;
    
    /* --- DNS Name Helpers --- */
    
    /**
     * @dev Create DNS-encoded name for address.cointype.addr.ecs.eth
     * @param addr The address
     * @param coinType The coin type
     * @return The DNS-encoded name
     */
    function _createDNSName(address addr, uint256 coinType) internal pure returns (bytes memory) {
        // Convert address to hex string (without 0x prefix)
        string memory addressHex = _uint256ToHexString(uint256(uint160(addr)));
        
        // Convert cointype to hex string
        string memory coinTypeHex = _uint256ToHexString(coinType);
        
        // Build dynamic part: address label + cointype label
        bytes memory addressBytes = bytes(addressHex);
        bytes memory coinTypeBytes = bytes(coinTypeHex);
        
        // Calculate total length needed
        uint256 totalLength = 1 + addressBytes.length + // address label
                             1 + coinTypeBytes.length + // cointype label  
                             1 + 4 + // "addr" label
                             1 + 3 + // "ecs" label
                             1 + 3 + // "eth" label
                             1;      // null terminator
        
        bytes memory result = new bytes(totalLength);
        uint256 offset = 0;
        
        // Address label: length + hex chars
        result[offset++] = bytes1(uint8(addressBytes.length));
        for (uint256 i = 0; i < addressBytes.length; i++) {
            result[offset++] = addressBytes[i];
        }
        
        // CoinType label: length + hex chars
        result[offset++] = bytes1(uint8(coinTypeBytes.length));
        for (uint256 i = 0; i < coinTypeBytes.length; i++) {
            result[offset++] = coinTypeBytes[i];
        }
        
        // "addr" label
        result[offset++] = bytes1(uint8(4));
        result[offset++] = bytes1(uint8(bytes1('a')));
        result[offset++] = bytes1(uint8(bytes1('d')));
        result[offset++] = bytes1(uint8(bytes1('d')));
        result[offset++] = bytes1(uint8(bytes1('r')));
        
        // "ecs" label
        result[offset++] = bytes1(uint8(3));
        result[offset++] = bytes1(uint8(bytes1('e')));
        result[offset++] = bytes1(uint8(bytes1('c')));
        result[offset++] = bytes1(uint8(bytes1('s')));
        
        // "eth" label
        result[offset++] = bytes1(uint8(3));
        result[offset++] = bytes1(uint8(bytes1('e')));
        result[offset++] = bytes1(uint8(bytes1('t')));
        result[offset++] = bytes1(uint8(bytes1('h')));
        
        // Null terminator
        result[offset++] = bytes1(uint8(0));
        
        return result;
    }
    
    function _addressToHexString(address addr) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(40);
        
        uint256 value = uint256(uint160(addr));
        for (uint256 i = 0; i < 20; i++) {
            uint256 byteIndex = 19 - i;
            str[i * 2] = alphabet[(value >> (byteIndex * 8 + 4)) & 0xf];
            str[i * 2 + 1] = alphabet[(value >> (byteIndex * 8)) & 0xf];
        }
        
        return string(str);
    }
    
    function _uint256ToHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        
        bytes memory alphabet = "0123456789abcdef";
        uint256 temp = value;
        uint256 length = 0;
        
        // Calculate length
        while (temp != 0) {
            length++;
            temp >>= 4;
        }
        
        bytes memory str = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            str[length - 1 - i] = alphabet[value & 0xf];
            value >>= 4;
        }
        
        return string(str);
    }
    
    /* --- Setup --- */
    
    function setUp() public {
        vm.startPrank(admin);
        starResolver = new StarResolver();
        vm.stopPrank();
        
        // Fund test accounts
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        vm.deal(admin, 10 ether);
    }
    
    /* --- Test Dividers --- */
    
    function test1000________________________________________________________________________________() public pure {}
    function test1100____________________STAR_RESOLVER_TESTS____________________________________() public pure {}
    function test1200________________________________________________________________________________() public pure {}
    
    /* --- Constructor Tests --- */
    
    function test_001____constructor_________________InitializesCorrectly() public view {
        // Test default values
        assertEq(starResolver.textRecordKey(), DEFAULT_TEXT_RECORD_KEY);
        assertEq(starResolver.starPrice(), DEFAULT_STAR_PRICE);
        
        // Test role assignments
        assertTrue(starResolver.hasRole(starResolver.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(starResolver.hasRole(starResolver.ADMIN_ROLE(), admin));
        
        // Test initial balances
        assertEq(address(starResolver).balance, 0);
    }
    
    /* --- buyStar Function Tests --- */
    
    function test_002____buyStar_____________________PurchasesStarSuccessfully() public {
        uint256 initialBalance = address(starResolver).balance;
        
        vm.startPrank(user1);
        
        vm.expectEmit(true, true, true, true);
        emit StarResolver.StarPurchased(TARGET_ADDRESS_1, ETHEREUM_MAINNET, user1, 1);
        
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        
        vm.stopPrank();
        
        // Verify star count incremented
        assertEq(starResolver.starCounts(TARGET_ADDRESS_1, ETHEREUM_MAINNET), 1);
        
        // Verify hasStarred tracking
        assertTrue(starResolver.hasStarred(user1, TARGET_ADDRESS_1, ETHEREUM_MAINNET));
        
        // Verify contract balance increased
        assertEq(address(starResolver).balance, initialBalance + DEFAULT_STAR_PRICE);
    }
    
    function test_003____buyStar_____________________AllowsMultipleUsersSameTarget() public {
        // User1 buys star
        vm.startPrank(user1);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        vm.stopPrank();
        
        // User2 buys star for same target
        vm.startPrank(user2);
        
        vm.expectEmit(true, true, true, true);
        emit StarResolver.StarPurchased(TARGET_ADDRESS_1, ETHEREUM_MAINNET, user2, 2);
        
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        
        vm.stopPrank();
        
        // Verify star count is 2
        assertEq(starResolver.starCounts(TARGET_ADDRESS_1, ETHEREUM_MAINNET), 2);
        
        // Verify both users have starred
        assertTrue(starResolver.hasStarred(user1, TARGET_ADDRESS_1, ETHEREUM_MAINNET));
        assertTrue(starResolver.hasStarred(user2, TARGET_ADDRESS_1, ETHEREUM_MAINNET));
        
        // Verify contract balance increased by both payments
        assertEq(address(starResolver).balance, DEFAULT_STAR_PRICE * 2);
    }
    
    function test_004____buyStar_____________________AllowsSameUserMultipleTargets() public {
        vm.startPrank(user1);
        
        // Buy star for first target
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        
        // Buy star for second target, same chain
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_2, ETHEREUM_MAINNET);
        
        // Buy star for first target, different chain
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_1, POLYGON_MAINNET);
        
        vm.stopPrank();
        
        // Verify all combinations work
        assertEq(starResolver.starCounts(TARGET_ADDRESS_1, ETHEREUM_MAINNET), 1);
        assertEq(starResolver.starCounts(TARGET_ADDRESS_2, ETHEREUM_MAINNET), 1);
        assertEq(starResolver.starCounts(TARGET_ADDRESS_1, POLYGON_MAINNET), 1);
        
        // Verify hasStarred tracking
        assertTrue(starResolver.hasStarred(user1, TARGET_ADDRESS_1, ETHEREUM_MAINNET));
        assertTrue(starResolver.hasStarred(user1, TARGET_ADDRESS_2, ETHEREUM_MAINNET));
        assertTrue(starResolver.hasStarred(user1, TARGET_ADDRESS_1, POLYGON_MAINNET));
        
        // Verify contract balance
        assertEq(address(starResolver).balance, DEFAULT_STAR_PRICE * 3);
    }
    
    function test_005____buyStar_____________________RevertsForInsufficientPayment() public {
        vm.startPrank(user1);
        
        // Too little payment
        vm.expectRevert(StarResolver.InsufficientPayment.selector);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE - 1}(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        
        // Too much payment
        vm.expectRevert(StarResolver.InsufficientPayment.selector);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE + 1}(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        
        // Zero payment
        vm.expectRevert(StarResolver.InsufficientPayment.selector);
        starResolver.buyStar{value: 0}(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        
        vm.stopPrank();
        
        // Verify no changes occurred
        assertEq(starResolver.starCounts(TARGET_ADDRESS_1, ETHEREUM_MAINNET), 0);
        assertFalse(starResolver.hasStarred(user1, TARGET_ADDRESS_1, ETHEREUM_MAINNET));
        assertEq(address(starResolver).balance, 0);
    }
    
    function test_006____buyStar_____________________RevertsForDuplicateStarring() public {
        vm.startPrank(user1);
        
        // First star purchase succeeds
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        
        // Second star purchase by same user for same target/chain fails
        vm.expectRevert(StarResolver.AlreadyStarred.selector);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        
        vm.stopPrank();
        
        // Verify star count didn't increase
        assertEq(starResolver.starCounts(TARGET_ADDRESS_1, ETHEREUM_MAINNET), 1);
        
        // Verify contract balance only increased once
        assertEq(address(starResolver).balance, DEFAULT_STAR_PRICE);
    }
    
    function test_007____buyStar_____________________WorksWithUpdatedStarPrice() public {
        uint256 newPrice = 0.002 ether;
        
        // Admin updates star price
        vm.startPrank(admin);
        starResolver.updateStarPrice(newPrice);
        vm.stopPrank();
        
        vm.startPrank(user1);
        
        // Old price should fail
        vm.expectRevert(StarResolver.InsufficientPayment.selector);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        
        // New price should work
        starResolver.buyStar{value: newPrice}(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        
        vm.stopPrank();
        
        assertEq(starResolver.starCounts(TARGET_ADDRESS_1, ETHEREUM_MAINNET), 1);
        assertEq(address(starResolver).balance, newPrice);
    }
    
    /* --- credential Function Tests --- */
    
    function test_008____credential___________________ReturnsStarCountForValidKey() public {
        // Buy some stars
        vm.startPrank(user1);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        vm.stopPrank();
        
        vm.startPrank(user2);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        vm.stopPrank();
        
        // Create DNS name
        bytes memory dnsName = _createDNSName(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        
        // Test with correct key
        string memory result = starResolver.credential(dnsName, DEFAULT_TEXT_RECORD_KEY);
        assertEq(result, "2");
    }
    
    function test_009____credential___________________ReturnsEmptyForInvalidKey() public {
        // Buy a star
        vm.startPrank(user1);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        vm.stopPrank();
        
        bytes memory dnsName = _createDNSName(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        
        // Test with wrong key
        string memory result = starResolver.credential(dnsName, "wrong.key");
        assertEq(result, "");
        
        // Test with similar but incorrect key
        string memory result2 = starResolver.credential(dnsName, "eth.ecs.ethstars.star"); // missing 's'
        assertEq(result2, "");
    }
    
    function test_010____credential___________________ReturnsZeroForNewAddress() public {
        bytes memory dnsName = _createDNSName(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        
        // New address should return "0"
        string memory result = starResolver.credential(dnsName, DEFAULT_TEXT_RECORD_KEY);
        assertEq(result, "0");
    }
    
    function test_011____credential___________________WorksWithMultipleAddressesAndChains() public {
        // Buy stars for different combinations
        vm.startPrank(user1);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_2, ETHEREUM_MAINNET);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_1, POLYGON_MAINNET);
        vm.stopPrank();
        
        vm.startPrank(user2);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_1, ETHEREUM_MAINNET); // Second star
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_2, POLYGON_MAINNET); // Different combo
        vm.stopPrank();
        
        // Test all combinations
        bytes memory dnsName1 = _createDNSName(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        string memory result1 = starResolver.credential(dnsName1, DEFAULT_TEXT_RECORD_KEY);
        assertEq(result1, "2");
        
        bytes memory dnsName2 = _createDNSName(TARGET_ADDRESS_2, ETHEREUM_MAINNET);
        string memory result2 = starResolver.credential(dnsName2, DEFAULT_TEXT_RECORD_KEY);
        assertEq(result2, "1");
        
        bytes memory dnsName3 = _createDNSName(TARGET_ADDRESS_1, POLYGON_MAINNET);
        string memory result3 = starResolver.credential(dnsName3, DEFAULT_TEXT_RECORD_KEY);
        assertEq(result3, "1");
        
        bytes memory dnsName4 = _createDNSName(TARGET_ADDRESS_2, POLYGON_MAINNET);
        string memory result4 = starResolver.credential(dnsName4, DEFAULT_TEXT_RECORD_KEY);
        assertEq(result4, "1");
    }
    
    function test_012____credential___________________RevertsForInvalidDNSNames() public {
        // Empty DNS name
        bytes memory emptyName = new bytes(0);
        vm.expectRevert(StarResolver.InvalidDNSEncoding.selector);
        starResolver.credential(emptyName, DEFAULT_TEXT_RECORD_KEY);
        
        // Very short DNS name
        bytes memory shortName = hex"01";
        vm.expectRevert(StarResolver.InvalidDNSEncoding.selector);
        starResolver.credential(shortName, DEFAULT_TEXT_RECORD_KEY);
        
        // Invalid format DNS name
        bytes memory invalidName = hex"ff";
        vm.expectRevert(StarResolver.InvalidDNSEncoding.selector);
        starResolver.credential(invalidName, DEFAULT_TEXT_RECORD_KEY);
        
        // Invalid hex characters in address (uppercase)
        bytes memory invalidHexName = abi.encodePacked(
            bytes1(0x28), // 40 bytes for address
            "123456789012345678901234567890123456789A", // Contains uppercase 'A'
            bytes1(0x01), // 1 byte for chain
            "1",
            hex"0461646472036563730365746800" // addr.ecs.eth
        );
        vm.expectRevert(StarResolver.InvalidDNSEncoding.selector);
        starResolver.credential(invalidHexName, DEFAULT_TEXT_RECORD_KEY);
        
        // Invalid hex characters in chain ID (invalid char)
        bytes memory invalidChainName = abi.encodePacked(
            bytes1(0x28), // 40 bytes for address
            "1234567890123456789012345678901234567890",
            bytes1(0x01), // 1 byte for chain
            "g", // Invalid hex char
            hex"0461646472036563730365746800" // addr.ecs.eth
        );
        vm.expectRevert(StarResolver.InvalidDNSEncoding.selector);
        starResolver.credential(invalidChainName, DEFAULT_TEXT_RECORD_KEY);
    }
    
    function test_013____credential___________________WorksWithUpdatedTextRecordKey() public {
        string memory newKey = "custom.key.stars";
        
        // Buy a star
        vm.startPrank(user1);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        vm.stopPrank();
        
        bytes memory dnsName = _createDNSName(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        
        // Old key should work initially
        string memory result1 = starResolver.credential(dnsName, DEFAULT_TEXT_RECORD_KEY);
        assertEq(result1, "1");
        
        // Update text record key
        vm.startPrank(admin);
        starResolver.setTextRecordKey(newKey);
        vm.stopPrank();
        
        // New key should work
        string memory result2 = starResolver.credential(dnsName, newKey);
        assertEq(result2, "1");
        
        // Old key should now return empty
        string memory result3 = starResolver.credential(dnsName, DEFAULT_TEXT_RECORD_KEY);
        assertEq(result3, "");
    }
    
    /* --- setTextRecordKey Function Tests --- */
    
    function test_014____setTextRecordKey____________UpdatesKeySuccessfully() public {
        string memory newKey = "new.custom.key";
        
        vm.startPrank(admin);
        
        vm.expectEmit(false, false, false, true);
        emit StarResolver.TextRecordKeyUpdated(DEFAULT_TEXT_RECORD_KEY, newKey);
        
        starResolver.setTextRecordKey(newKey);
        
        vm.stopPrank();
        
        assertEq(starResolver.textRecordKey(), newKey);
    }
    
    function test_015____setTextRecordKey____________RevertsForNonAdmin() public {
        vm.startPrank(user1);
        
        vm.expectRevert();
        starResolver.setTextRecordKey("unauthorized.key");
        
        vm.stopPrank();
        
        // Key should remain unchanged
        assertEq(starResolver.textRecordKey(), DEFAULT_TEXT_RECORD_KEY);
    }
    
    function test_016____setTextRecordKey____________AllowsNewAdminToUpdate() public {
        // Add new admin
        vm.startPrank(admin);
        starResolver.grantRole(starResolver.ADMIN_ROLE(), newAdmin);
        vm.stopPrank();
        
        // New admin can update key
        string memory newKey = "admin.updated.key";
        
        vm.startPrank(newAdmin);
        starResolver.setTextRecordKey(newKey);
        vm.stopPrank();
        
        assertEq(starResolver.textRecordKey(), newKey);
    }
    
    /* --- updateStarPrice Function Tests --- */
    
    function test_017____updateStarPrice_____________UpdatesPriceSuccessfully() public {
        uint256 newPrice = 0.005 ether;
        
        vm.startPrank(admin);
        
        vm.expectEmit(false, false, false, true);
        emit StarResolver.StarPriceUpdated(DEFAULT_STAR_PRICE, newPrice);
        
        starResolver.updateStarPrice(newPrice);
        
        vm.stopPrank();
        
        assertEq(starResolver.starPrice(), newPrice);
    }
    
    function test_018____updateStarPrice_____________RevertsForNonAdmin() public {
        vm.startPrank(user1);
        
        vm.expectRevert();
        starResolver.updateStarPrice(0.002 ether);
        
        vm.stopPrank();
        
        // Price should remain unchanged
        assertEq(starResolver.starPrice(), DEFAULT_STAR_PRICE);
    }
    
    function test_019____updateStarPrice_____________AllowsZeroPrice() public {
        vm.startPrank(admin);
        starResolver.updateStarPrice(0);
        vm.stopPrank();
        
        assertEq(starResolver.starPrice(), 0);
        
        // Should allow free star purchases
        vm.startPrank(user1);
        starResolver.buyStar{value: 0}(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        vm.stopPrank();
        
        assertEq(starResolver.starCounts(TARGET_ADDRESS_1, ETHEREUM_MAINNET), 1);
    }
    
    function test_020____updateStarPrice_____________AllowsVeryHighPrice() public {
        uint256 highPrice = 100 ether;
        
        vm.startPrank(admin);
        starResolver.updateStarPrice(highPrice);
        vm.stopPrank();
        
        assertEq(starResolver.starPrice(), highPrice);
        
        // Fund user with enough ETH
        vm.deal(user1, 200 ether);
        
        vm.startPrank(user1);
        starResolver.buyStar{value: highPrice}(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        vm.stopPrank();
        
        assertEq(starResolver.starCounts(TARGET_ADDRESS_1, ETHEREUM_MAINNET), 1);
        assertEq(address(starResolver).balance, highPrice);
    }
    
    /* --- Role Management Tests --- */
    
    function test_021____grantRole___________________AddsNewAdminSuccessfully() public {
        vm.startPrank(admin);
        starResolver.grantRole(starResolver.ADMIN_ROLE(), newAdmin);
        vm.stopPrank();
        
        assertTrue(starResolver.hasRole(starResolver.ADMIN_ROLE(), newAdmin));
        
        // New admin should be able to perform admin functions
        vm.startPrank(newAdmin);
        starResolver.updateStarPrice(0.002 ether);
        vm.stopPrank();
        
        assertEq(starResolver.starPrice(), 0.002 ether);
    }
    
    function test_022____grantRole___________________RevertsForNonDefaultAdmin() public {
        bytes32 adminRole = starResolver.ADMIN_ROLE(); // Get role before expectRevert
        
        vm.startPrank(user1);
        
        vm.expectRevert();
        starResolver.grantRole(adminRole, newAdmin);
        
        vm.stopPrank();
        
        assertFalse(starResolver.hasRole(adminRole, newAdmin));
    }
    
    function test_023____revokeRole__________________RemovesAdminSuccessfully() public {
        // Add admin first
        vm.startPrank(admin);
        starResolver.grantRole(starResolver.ADMIN_ROLE(), newAdmin);
        vm.stopPrank();
        
        assertTrue(starResolver.hasRole(starResolver.ADMIN_ROLE(), newAdmin));
        
        // Remove admin
        vm.startPrank(admin);
        starResolver.revokeRole(starResolver.ADMIN_ROLE(), newAdmin);
        vm.stopPrank();
        
        assertFalse(starResolver.hasRole(starResolver.ADMIN_ROLE(), newAdmin));
        
        // Removed admin should not be able to perform admin functions
        vm.startPrank(newAdmin);
        vm.expectRevert();
        starResolver.updateStarPrice(0.003 ether);
        vm.stopPrank();
    }
    
    function test_024____revokeRole__________________RevertsForNonDefaultAdmin() public {
        bytes32 adminRole = starResolver.ADMIN_ROLE(); // Get role before expectRevert
        
        // Add admin first
        vm.startPrank(admin);
        starResolver.grantRole(adminRole, newAdmin);
        vm.stopPrank();
        
        // Regular user cannot remove admin
        vm.startPrank(user1);
        vm.expectRevert();
        starResolver.revokeRole(adminRole, newAdmin);
        vm.stopPrank();
        
        // Admin should still exist
        assertTrue(starResolver.hasRole(adminRole, newAdmin));
    }
    
    /* --- withdraw Function Tests --- */
    
    function test_025____withdraw____________________WithdrawsBalanceSuccessfully() public {
        // Buy some stars to accumulate balance
        vm.startPrank(user1);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        vm.stopPrank();
        
        vm.startPrank(user2);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_2, ETHEREUM_MAINNET);
        vm.stopPrank();
        
        uint256 contractBalance = address(starResolver).balance;
        uint256 adminBalanceBefore = admin.balance;
        
        assertEq(contractBalance, DEFAULT_STAR_PRICE * 2);
        
        // Withdraw
        vm.startPrank(admin);
        starResolver.withdraw();
        vm.stopPrank();
        
        // Contract balance should be zero
        assertEq(address(starResolver).balance, 0);
        
        // Admin balance should increase
        assertEq(admin.balance, adminBalanceBefore + contractBalance);
    }
    
    function test_026____withdraw____________________RevertsForNonAdmin() public {
        // Buy star to accumulate balance
        vm.startPrank(user1);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        vm.stopPrank();
        
        uint256 contractBalance = address(starResolver).balance;
        
        vm.startPrank(user1);
        vm.expectRevert();
        starResolver.withdraw();
        vm.stopPrank();
        
        // Contract balance should remain unchanged
        assertEq(address(starResolver).balance, contractBalance);
    }
    
    function test_027____withdraw____________________AllowsNewAdminToWithdraw() public {
        // Add new admin
        vm.startPrank(admin);
        starResolver.grantRole(starResolver.ADMIN_ROLE(), newAdmin);
        vm.stopPrank();
        
        // Buy star to accumulate balance
        vm.startPrank(user1);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        vm.stopPrank();
        
        uint256 contractBalance = address(starResolver).balance;
        uint256 newAdminBalanceBefore = newAdmin.balance;
        
        // New admin can withdraw
        vm.startPrank(newAdmin);
        starResolver.withdraw();
        vm.stopPrank();
        
        assertEq(address(starResolver).balance, 0);
        assertEq(newAdmin.balance, newAdminBalanceBefore + contractBalance);
    }
    
    function test_028____withdraw____________________HandlesZeroBalance() public {
        uint256 adminBalanceBefore = admin.balance;
        
        // Withdraw with zero balance
        vm.startPrank(admin);
        starResolver.withdraw();
        vm.stopPrank();
        
        // Admin balance should remain unchanged
        assertEq(admin.balance, adminBalanceBefore);
        assertEq(address(starResolver).balance, 0);
    }
    
    /* --- Complex Integration Tests --- */
    
    function test_029____complexStarringWorkflow_____ManagesComplexStarringScenario() public {
        uint256 initialContractBalance = address(starResolver).balance;
        
        // Multiple users buy stars for various address/chain combinations
        vm.startPrank(user1);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_2, ETHEREUM_MAINNET);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_1, POLYGON_MAINNET);
        vm.stopPrank();
        
        vm.startPrank(user2);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_1, ETHEREUM_MAINNET); // Second star
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_3, ARBITRUM_MAINNET);
        vm.stopPrank();
        
        vm.startPrank(user3);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_1, ETHEREUM_MAINNET); // Third star
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_2, POLYGON_MAINNET);
        vm.stopPrank();
        
        // Verify star counts
        assertEq(starResolver.starCounts(TARGET_ADDRESS_1, ETHEREUM_MAINNET), 3);
        assertEq(starResolver.starCounts(TARGET_ADDRESS_2, ETHEREUM_MAINNET), 1);
        assertEq(starResolver.starCounts(TARGET_ADDRESS_1, POLYGON_MAINNET), 1);
        assertEq(starResolver.starCounts(TARGET_ADDRESS_3, ARBITRUM_MAINNET), 1);
        assertEq(starResolver.starCounts(TARGET_ADDRESS_2, POLYGON_MAINNET), 1);
        
        // Verify hasStarred tracking
        assertTrue(starResolver.hasStarred(user1, TARGET_ADDRESS_1, ETHEREUM_MAINNET));
        assertTrue(starResolver.hasStarred(user2, TARGET_ADDRESS_1, ETHEREUM_MAINNET));
        assertTrue(starResolver.hasStarred(user3, TARGET_ADDRESS_1, ETHEREUM_MAINNET));
        assertFalse(starResolver.hasStarred(user1, TARGET_ADDRESS_3, ARBITRUM_MAINNET));
        
        // Verify contract balance
        assertEq(address(starResolver).balance, initialContractBalance + (DEFAULT_STAR_PRICE * 7));
        
        // Test credential resolution for all combinations
        bytes memory dnsName1 = _createDNSName(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        assertEq(starResolver.credential(dnsName1, DEFAULT_TEXT_RECORD_KEY), "3");
        
        bytes memory dnsName2 = _createDNSName(TARGET_ADDRESS_2, ETHEREUM_MAINNET);
        assertEq(starResolver.credential(dnsName2, DEFAULT_TEXT_RECORD_KEY), "1");
        
        bytes memory dnsName3 = _createDNSName(TARGET_ADDRESS_3, ARBITRUM_MAINNET);
        assertEq(starResolver.credential(dnsName3, DEFAULT_TEXT_RECORD_KEY), "1");
    }
    
    function test_030____adminWorkflow_______________ManagesAdminFunctionsAndWithdrawal() public {
        // Initial setup with stars
        vm.startPrank(user1);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_2, ETHEREUM_MAINNET);
        vm.stopPrank();
        
        uint256 balanceAfterStars = address(starResolver).balance;
        
        // Admin updates star price
        uint256 newPrice = 0.002 ether;
        vm.startPrank(admin);
        starResolver.updateStarPrice(newPrice);
        vm.stopPrank();
        
        // User buys star at new price
        vm.startPrank(user2);
        starResolver.buyStar{value: newPrice}(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        vm.stopPrank();
        
        // Admin updates text record key
        string memory newKey = "custom.star.key";
        vm.startPrank(admin);
        starResolver.setTextRecordKey(newKey);
        vm.stopPrank();
        
        // Test credential resolution with new key
        bytes memory dnsName = _createDNSName(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        assertEq(starResolver.credential(dnsName, newKey), "2");
        assertEq(starResolver.credential(dnsName, DEFAULT_TEXT_RECORD_KEY), ""); // Old key returns empty
        
        // Admin adds new admin
        vm.startPrank(admin);
        starResolver.grantRole(starResolver.ADMIN_ROLE(), newAdmin);
        vm.stopPrank();
        
        // New admin can perform admin functions
        vm.startPrank(newAdmin);
        starResolver.updateStarPrice(0.003 ether);
        vm.stopPrank();
        
        // Original admin withdraws funds
        uint256 finalContractBalance = address(starResolver).balance;
        uint256 adminBalanceBefore = admin.balance;
        
        vm.startPrank(admin);
        starResolver.withdraw();
        vm.stopPrank();
        
        assertEq(address(starResolver).balance, 0);
        assertEq(admin.balance, adminBalanceBefore + finalContractBalance);
        assertEq(finalContractBalance, balanceAfterStars + newPrice);
    }
    
    function test_031____edgeCases___________________HandlesEdgeCasesCorrectly() public {
        // Test with zero address - now properly supported
        vm.startPrank(user1);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(address(0), ETHEREUM_MAINNET);
        vm.stopPrank();
        
        assertEq(starResolver.starCounts(address(0), ETHEREUM_MAINNET), 1);
        
        // Test with very high chain ID
        uint256 highCoinType = type(uint256).max;
        vm.startPrank(user1);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_1, highCoinType);
        vm.stopPrank();
        
        assertEq(starResolver.starCounts(TARGET_ADDRESS_1, highCoinType), 1);
        
        // Test credential resolution with edge cases
        // address(0) now returns actual star count
        bytes memory dnsName1 = _createDNSName(address(0), ETHEREUM_MAINNET);
        assertEq(starResolver.credential(dnsName1, DEFAULT_TEXT_RECORD_KEY), "1");
        
        bytes memory dnsName2 = _createDNSName(TARGET_ADDRESS_1, highCoinType);
        assertEq(starResolver.credential(dnsName2, DEFAULT_TEXT_RECORD_KEY), "1");
        
        // Test with address that has maximum uint160 value
        address maxAddress = address(type(uint160).max);
        vm.startPrank(user2);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(maxAddress, 0);
        vm.stopPrank();
        
        bytes memory dnsName3 = _createDNSName(maxAddress, 0);
        assertEq(starResolver.credential(dnsName3, DEFAULT_TEXT_RECORD_KEY), "1");
    }

    function test_038____variableLengthAddress___HandlesDifferentAddressLengths() public {
        // Test with a 32-byte (64 hex chars) address instead of standard 20-byte
        string memory longAddressHex = "1234567890123456789012345678901234567890123456789012345678901234";
        string memory coinTypeHex = "3c";
        
        // Build dynamic part: address label + cointype label
        bytes memory addressBytes = bytes(longAddressHex);
        bytes memory coinTypeBytes = bytes(coinTypeHex);
        
        // Calculate total length needed
        uint256 totalLength = 1 + addressBytes.length + // address label
                             1 + coinTypeBytes.length + // cointype label  
                             1 + 4 + // "addr" label
                             1 + 3 + // "ecs" label
                             1 + 3 + // "eth" label
                             1;      // null terminator
        
        bytes memory result = new bytes(totalLength);
        uint256 offset = 0;
        
        // Address label: length + hex chars
        result[offset++] = bytes1(uint8(addressBytes.length));
        for (uint256 i = 0; i < addressBytes.length; i++) {
            result[offset++] = addressBytes[i];
        }
        
        // CoinType label: length + hex chars
        result[offset++] = bytes1(uint8(coinTypeBytes.length));
        for (uint256 i = 0; i < coinTypeBytes.length; i++) {
            result[offset++] = coinTypeBytes[i];
        }
        
        // "addr" label
        result[offset++] = bytes1(uint8(4));
        result[offset++] = bytes1(uint8(bytes1('a')));
        result[offset++] = bytes1(uint8(bytes1('d')));
        result[offset++] = bytes1(uint8(bytes1('d')));
        result[offset++] = bytes1(uint8(bytes1('r')));
        
        // "ecs" label
        result[offset++] = bytes1(uint8(3));
        result[offset++] = bytes1(uint8(bytes1('e')));
        result[offset++] = bytes1(uint8(bytes1('c')));
        result[offset++] = bytes1(uint8(bytes1('s')));
        
        // "eth" label
        result[offset++] = bytes1(uint8(3));
        result[offset++] = bytes1(uint8(bytes1('e')));
        result[offset++] = bytes1(uint8(bytes1('t')));
        result[offset++] = bytes1(uint8(bytes1('h')));
        
        // Null terminator
        result[offset++] = bytes1(uint8(0));
        
        // Test that the DNS parsing works with long addresses
        string memory credential = starResolver.credential(result, DEFAULT_TEXT_RECORD_KEY);
        assertEq(credential, "0"); // Should return "0" for new address
    }
    
    /* --- hasStarredAddress Function Tests --- */
    
    function test_039____hasStarredAddress___________ReturnsFalseForNewAddress() public view {
        // Test with unstarred address
        assertFalse(starResolver.hasStarredAddress(user1, TARGET_ADDRESS_1, ETHEREUM_MAINNET));
        assertFalse(starResolver.hasStarredAddress(user2, TARGET_ADDRESS_2, POLYGON_MAINNET));
        assertFalse(starResolver.hasStarredAddress(user3, TARGET_ADDRESS_3, ARBITRUM_MAINNET));
    }
    
    function test_040____hasStarredAddress___________ReturnsTrueAfterStarring() public {
        // User1 stars TARGET_ADDRESS_1
        vm.startPrank(user1);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        vm.stopPrank();
        
        // Should return true for user1
        assertTrue(starResolver.hasStarredAddress(user1, TARGET_ADDRESS_1, ETHEREUM_MAINNET));
        
        // Should return false for other users
        assertFalse(starResolver.hasStarredAddress(user2, TARGET_ADDRESS_1, ETHEREUM_MAINNET));
        assertFalse(starResolver.hasStarredAddress(user3, TARGET_ADDRESS_1, ETHEREUM_MAINNET));
        
        // Should return false for same user with different address/cointype
        assertFalse(starResolver.hasStarredAddress(user1, TARGET_ADDRESS_2, ETHEREUM_MAINNET));
        assertFalse(starResolver.hasStarredAddress(user1, TARGET_ADDRESS_1, POLYGON_MAINNET));
    }
    
    function test_041____hasStarredAddress___________HandlesMultipleUsersAndTargets() public {
        // Multiple users star different targets
        vm.startPrank(user1);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_2, POLYGON_MAINNET);
        vm.stopPrank();
        
        vm.startPrank(user2);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_1, ETHEREUM_MAINNET);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(TARGET_ADDRESS_3, ARBITRUM_MAINNET);
        vm.stopPrank();
        
        // Check user1 starred addresses
        assertTrue(starResolver.hasStarredAddress(user1, TARGET_ADDRESS_1, ETHEREUM_MAINNET));
        assertTrue(starResolver.hasStarredAddress(user1, TARGET_ADDRESS_2, POLYGON_MAINNET));
        assertFalse(starResolver.hasStarredAddress(user1, TARGET_ADDRESS_3, ARBITRUM_MAINNET));
        
        // Check user2 starred addresses
        assertTrue(starResolver.hasStarredAddress(user2, TARGET_ADDRESS_1, ETHEREUM_MAINNET));
        assertFalse(starResolver.hasStarredAddress(user2, TARGET_ADDRESS_2, POLYGON_MAINNET));
        assertTrue(starResolver.hasStarredAddress(user2, TARGET_ADDRESS_3, ARBITRUM_MAINNET));
        
        // Check user3 (no stars)
        assertFalse(starResolver.hasStarredAddress(user3, TARGET_ADDRESS_1, ETHEREUM_MAINNET));
        assertFalse(starResolver.hasStarredAddress(user3, TARGET_ADDRESS_2, POLYGON_MAINNET));
        assertFalse(starResolver.hasStarredAddress(user3, TARGET_ADDRESS_3, ARBITRUM_MAINNET));
    }
    
    function test_042____hasStarredAddress___________HandlesEdgeCases() public {
        // Test with zero address
        vm.startPrank(user1);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(address(0), ETHEREUM_MAINNET);
        vm.stopPrank();
        
        assertTrue(starResolver.hasStarredAddress(user1, address(0), ETHEREUM_MAINNET));
        assertFalse(starResolver.hasStarredAddress(user2, address(0), ETHEREUM_MAINNET));
        
        // Test with maximum values
        address maxAddress = address(type(uint160).max);
        uint256 maxCoinType = type(uint256).max;
        
        vm.startPrank(user2);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(maxAddress, maxCoinType);
        vm.stopPrank();
        
        assertTrue(starResolver.hasStarredAddress(user2, maxAddress, maxCoinType));
        assertFalse(starResolver.hasStarredAddress(user1, maxAddress, maxCoinType));
    }
} 