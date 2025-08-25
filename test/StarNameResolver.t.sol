// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/credentials/ethstars/StarNameResolver.sol";
import "../src/utils/NameCoder.sol";

contract StarNameResolverTest is Test {
    StarNameResolver public starResolver;
    
    /* --- Test Accounts --- */
    
    address admin = address(0x1001);
    address user1 = address(0x1002);
    address user2 = address(0x1003);
    address user3 = address(0x1004);
    address newAdmin = address(0x1005);
    
    /* --- Test Constants --- */
    
    uint256 constant DEFAULT_STAR_PRICE = 0.000001 ether; // Testnet price
    string constant DEFAULT_TEXT_RECORD_KEY = "eth.ecs.ethstars.stars";
    
    // Test domain names
    string constant DOMAIN1 = "example.com";
    string constant DOMAIN2 = "subdomain.example.com";
    string constant DOMAIN3 = "another-domain.org";
    string constant DOMAIN4 = "test.io";
    
    /* --- DNS Name Helpers --- */
    
    
    /* --- Setup --- */
    
    function setUp() public {
        vm.startPrank(admin);
        starResolver = new StarNameResolver();
        vm.stopPrank();
        
        // Fund test accounts
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        vm.deal(admin, 10 ether);
    }
    
    /* --- Test Dividers --- */
    
    function test1000________________________________________________________________________________() public pure {}
    function test1100____________________STAR_NAME_RESOLVER_TESTS_________________________________() public pure {}
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
        bytes32 expectedNamehash = _computeNamehash(DOMAIN1);
        
        vm.startPrank(user1);
        
        vm.expectEmit(true, false, true, true);
        emit StarNameResolver.StarPurchased(expectedNamehash, _encodeDomain(DOMAIN1), user1, 1);
        
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(DOMAIN1));
        
        vm.stopPrank();
        
        // Verify star count incremented
        assertEq(starResolver.starCounts(expectedNamehash), 1);
        
        // Verify hasStarred tracking
        assertTrue(starResolver.hasStarred(user1, expectedNamehash));
        
        // Verify contract balance increased
        assertEq(address(starResolver).balance, initialBalance + DEFAULT_STAR_PRICE);
    }
    
    function test_003____buyStar_____________________AllowsMultipleUsersSameDomain() public {
        bytes32 namehash = _computeNamehash(DOMAIN1);
        
        // User1 buys star
        vm.startPrank(user1);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(DOMAIN1));
        vm.stopPrank();
        
        // User2 buys star for same domain
        vm.startPrank(user2);
        
        vm.expectEmit(true, false, true, true);
        emit StarNameResolver.StarPurchased(namehash, _encodeDomain(DOMAIN1), user2, 2);
        
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(DOMAIN1));
        
        vm.stopPrank();
        
        // Verify star count is 2
        assertEq(starResolver.starCounts(namehash), 2);
        
        // Verify both users have starred
        assertTrue(starResolver.hasStarred(user1, namehash));
        assertTrue(starResolver.hasStarred(user2, namehash));
        
        // Verify contract balance increased by both payments
        assertEq(address(starResolver).balance, DEFAULT_STAR_PRICE * 2);
    }
    
    function test_004____buyStar_____________________AllowsSameUserMultipleDomains() public {
        vm.startPrank(user1);
        
        // Buy stars for different domains
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(DOMAIN1));
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(DOMAIN2));
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(DOMAIN3));
        
        vm.stopPrank();
        
        // Verify all domains have stars
        assertEq(starResolver.starCounts(_computeNamehash(DOMAIN1)), 1);
        assertEq(starResolver.starCounts(_computeNamehash(DOMAIN2)), 1);
        assertEq(starResolver.starCounts(_computeNamehash(DOMAIN3)), 1);
        
        // Verify hasStarred tracking
        assertTrue(starResolver.hasStarred(user1, _computeNamehash(DOMAIN1)));
        assertTrue(starResolver.hasStarred(user1, _computeNamehash(DOMAIN2)));
        assertTrue(starResolver.hasStarred(user1, _computeNamehash(DOMAIN3)));
        
        // Verify contract balance
        assertEq(address(starResolver).balance, DEFAULT_STAR_PRICE * 3);
    }
    
    function test_005____buyStar_____________________RevertsForInsufficientPayment() public {
        vm.startPrank(user1);
        
        // Too little payment
        vm.expectRevert(StarNameResolver.InsufficientPayment.selector);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE - 1}(_encodeDomain(DOMAIN1));
        
        // Too much payment
        vm.expectRevert(StarNameResolver.InsufficientPayment.selector);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE + 1}(_encodeDomain(DOMAIN1));
        
        // Zero payment
        vm.expectRevert(StarNameResolver.InsufficientPayment.selector);
        starResolver.buyStar{value: 0}(_encodeDomain(DOMAIN1));
        
        vm.stopPrank();
        
        // Verify no changes occurred
        assertEq(starResolver.starCounts(_computeNamehash(DOMAIN1)), 0);
        assertFalse(starResolver.hasStarred(user1, _computeNamehash(DOMAIN1)));
        assertEq(address(starResolver).balance, 0);
    }
    
    function test_006____buyStar_____________________RevertsForDuplicateStarring() public {
        vm.startPrank(user1);
        
        // First star purchase succeeds
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(DOMAIN1));
        
        // Second star purchase by same user for same domain fails
        vm.expectRevert(StarNameResolver.AlreadyStarred.selector);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(DOMAIN1));
        
        vm.stopPrank();
        
        // Verify star count didn't increase
        assertEq(starResolver.starCounts(_computeNamehash(DOMAIN1)), 1);
        
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
        vm.expectRevert(StarNameResolver.InsufficientPayment.selector);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(DOMAIN1));
        
        // New price should work
        starResolver.buyStar{value: newPrice}(_encodeDomain(DOMAIN1));
        
        vm.stopPrank();
        
        assertEq(starResolver.starCounts(_computeNamehash(DOMAIN1)), 1);
        assertEq(address(starResolver).balance, newPrice);
    }
    
    function test_008____buyStar_____________________WorksWithVariousDomainFormats() public {
        vm.startPrank(user1);
        
        // Simple domain
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain("example.com"));
        
        // Subdomain
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain("sub.example.com"));
        
        // Deep subdomain
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain("deep.sub.example.com"));
        
        // Different TLD
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain("test.org"));
        
        // Single word domain
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain("localhost"));
        
        vm.stopPrank();
        
        // Verify all worked
        assertEq(starResolver.starCounts(_computeNamehash("example.com")), 1);
        assertEq(starResolver.starCounts(_computeNamehash("sub.example.com")), 1);
        assertEq(starResolver.starCounts(_computeNamehash("deep.sub.example.com")), 1);
        assertEq(starResolver.starCounts(_computeNamehash("test.org")), 1);
        assertEq(starResolver.starCounts(_computeNamehash("localhost")), 1);
        
        assertEq(address(starResolver).balance, DEFAULT_STAR_PRICE * 5);
    }
    
    /* --- credential Function Tests --- */
    
    function test_009____credential___________________ReturnsStarCountForValidKey() public {
        // Buy some stars
        vm.startPrank(user1);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(DOMAIN1));
        vm.stopPrank();
        
        vm.startPrank(user2);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(DOMAIN1));
        vm.stopPrank();
        
        // Create DNS name
        bytes memory dnsName = _encodeDomain(DOMAIN1);
        
        // Test with correct key
        string memory result = starResolver.credential(dnsName, DEFAULT_TEXT_RECORD_KEY);
        assertEq(result, "2");
    }
    
    function test_010____credential___________________ReturnsEmptyForInvalidKey() public {
        // Buy a star
        vm.startPrank(user1);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(DOMAIN1));
        vm.stopPrank();
        
        bytes memory dnsName = _encodeDomain(DOMAIN1);
        
        // Test with wrong key
        string memory result = starResolver.credential(dnsName, "wrong.key");
        assertEq(result, "");
        
        // Test with similar but incorrect key
        string memory result2 = starResolver.credential(dnsName, "eth.ecs.ethstars.star"); // missing 's'
        assertEq(result2, "");
    }
    
    function test_011____credential___________________ReturnsZeroForNewDomain() public {
        bytes memory dnsName = _encodeDomain(DOMAIN1);
        
        // New domain should return "0"
        string memory result = starResolver.credential(dnsName, DEFAULT_TEXT_RECORD_KEY);
        assertEq(result, "0");
    }
    
    function test_012____credential___________________WorksWithMultipleDomains() public {
        // Buy stars for different domains
        vm.startPrank(user1);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(DOMAIN1));
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(DOMAIN2));
        vm.stopPrank();
        
        vm.startPrank(user2);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(DOMAIN1)); // Second star for DOMAIN1
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(DOMAIN3)); // First star for DOMAIN3
        vm.stopPrank();
        
        // Test all domains
        bytes memory dnsName1 = _encodeDomain(DOMAIN1);
        string memory result1 = starResolver.credential(dnsName1, DEFAULT_TEXT_RECORD_KEY);
        assertEq(result1, "2");
        
        bytes memory dnsName2 = _encodeDomain(DOMAIN2);
        string memory result2 = starResolver.credential(dnsName2, DEFAULT_TEXT_RECORD_KEY);
        assertEq(result2, "1");
        
        bytes memory dnsName3 = _encodeDomain(DOMAIN3);
        string memory result3 = starResolver.credential(dnsName3, DEFAULT_TEXT_RECORD_KEY);
        assertEq(result3, "1");
        
        bytes memory dnsName4 = _encodeDomain(DOMAIN4);
        string memory result4 = starResolver.credential(dnsName4, DEFAULT_TEXT_RECORD_KEY);
        assertEq(result4, "0");
    }
    
    function test_013____credential___________________RevertsForInvalidDNSNames() public {
        // Empty DNS name
        bytes memory emptyName = new bytes(0);
        vm.expectRevert(); // NameCoder.DNSDecodingFailed
        starResolver.credential(emptyName, DEFAULT_TEXT_RECORD_KEY);
        
        // Malformed DNS name
        bytes memory malformedName = hex"ff";
        vm.expectRevert(); // NameCoder.DNSDecodingFailed
        starResolver.credential(malformedName, DEFAULT_TEXT_RECORD_KEY);
        
        // Invalid label length
        bytes memory invalidLength = hex"ff01020304";
        vm.expectRevert(); // NameCoder.DNSDecodingFailed  
        starResolver.credential(invalidLength, DEFAULT_TEXT_RECORD_KEY);
    }
    
    function test_014____credential___________________WorksWithUpdatedTextRecordKey() public {
        string memory newKey = "custom.key.stars";
        
        // Buy a star
        vm.startPrank(user1);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(DOMAIN1));
        vm.stopPrank();
        
        bytes memory dnsName = _encodeDomain(DOMAIN1);
        
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
    
    function test_015____setTextRecordKey____________UpdatesKeySuccessfully() public {
        string memory newKey = "new.custom.key";
        
        vm.startPrank(admin);
        
        vm.expectEmit(false, false, false, true);
        emit StarNameResolver.TextRecordKeyUpdated(DEFAULT_TEXT_RECORD_KEY, newKey);
        
        starResolver.setTextRecordKey(newKey);
        
        vm.stopPrank();
        
        assertEq(starResolver.textRecordKey(), newKey);
    }
    
    function test_016____setTextRecordKey____________RevertsForNonAdmin() public {
        vm.startPrank(user1);
        
        vm.expectRevert();
        starResolver.setTextRecordKey("unauthorized.key");
        
        vm.stopPrank();
        
        // Key should remain unchanged
        assertEq(starResolver.textRecordKey(), DEFAULT_TEXT_RECORD_KEY);
    }
    
    function test_017____setTextRecordKey____________AllowsNewAdminToUpdate() public {
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
    
    function test_018____updateStarPrice_____________UpdatesPriceSuccessfully() public {
        uint256 newPrice = 0.005 ether;
        
        vm.startPrank(admin);
        
        vm.expectEmit(false, false, false, true);
        emit StarNameResolver.StarPriceUpdated(DEFAULT_STAR_PRICE, newPrice);
        
        starResolver.updateStarPrice(newPrice);
        
        vm.stopPrank();
        
        assertEq(starResolver.starPrice(), newPrice);
    }
    
    function test_019____updateStarPrice_____________RevertsForNonAdmin() public {
        vm.startPrank(user1);
        
        vm.expectRevert();
        starResolver.updateStarPrice(0.002 ether);
        
        vm.stopPrank();
        
        // Price should remain unchanged
        assertEq(starResolver.starPrice(), DEFAULT_STAR_PRICE);
    }
    
    function test_020____updateStarPrice_____________AllowsZeroPrice() public {
        vm.startPrank(admin);
        starResolver.updateStarPrice(0);
        vm.stopPrank();
        
        assertEq(starResolver.starPrice(), 0);
        
        // Should allow free star purchases
        vm.startPrank(user1);
        starResolver.buyStar{value: 0}(_encodeDomain(DOMAIN1));
        vm.stopPrank();
        
        assertEq(starResolver.starCounts(_computeNamehash(DOMAIN1)), 1);
    }
    
    function test_021____updateStarPrice_____________AllowsVeryHighPrice() public {
        uint256 highPrice = 100 ether;
        
        vm.startPrank(admin);
        starResolver.updateStarPrice(highPrice);
        vm.stopPrank();
        
        assertEq(starResolver.starPrice(), highPrice);
        
        // Fund user with enough ETH
        vm.deal(user1, 200 ether);
        
        vm.startPrank(user1);
        starResolver.buyStar{value: highPrice}(_encodeDomain(DOMAIN1));
        vm.stopPrank();
        
        assertEq(starResolver.starCounts(_computeNamehash(DOMAIN1)), 1);
        assertEq(address(starResolver).balance, highPrice);
    }
    
    /* --- Role Management Tests --- */
    
    function test_022____grantRole___________________AddsNewAdminSuccessfully() public {
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
    
    function test_023____grantRole___________________RevertsForNonDefaultAdmin() public {
        bytes32 adminRole = starResolver.ADMIN_ROLE(); // Get role before expectRevert
        
        vm.startPrank(user1);
        
        vm.expectRevert();
        starResolver.grantRole(adminRole, newAdmin);
        
        vm.stopPrank();
        
        assertFalse(starResolver.hasRole(adminRole, newAdmin));
    }
    
    function test_024____revokeRole__________________RemovesAdminSuccessfully() public {
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
    
    function test_025____revokeRole__________________RevertsForNonDefaultAdmin() public {
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
    
    function test_026____withdraw____________________WithdrawsBalanceSuccessfully() public {
        // Buy some stars to accumulate balance
        vm.startPrank(user1);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(DOMAIN1));
        vm.stopPrank();
        
        vm.startPrank(user2);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(DOMAIN2));
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
    
    function test_027____withdraw____________________RevertsForNonAdmin() public {
        // Buy star to accumulate balance
        vm.startPrank(user1);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(DOMAIN1));
        vm.stopPrank();
        
        uint256 contractBalance = address(starResolver).balance;
        
        vm.startPrank(user1);
        vm.expectRevert();
        starResolver.withdraw();
        vm.stopPrank();
        
        // Contract balance should remain unchanged
        assertEq(address(starResolver).balance, contractBalance);
    }
    
    function test_028____withdraw____________________AllowsNewAdminToWithdraw() public {
        // Add new admin
        vm.startPrank(admin);
        starResolver.grantRole(starResolver.ADMIN_ROLE(), newAdmin);
        vm.stopPrank();
        
        // Buy star to accumulate balance
        vm.startPrank(user1);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(DOMAIN1));
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
    
    function test_029____withdraw____________________HandlesZeroBalance() public {
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
    
    function test_030____complexDomainWorkflow_______ManagesComplexDomainScenario() public {
        uint256 initialContractBalance = address(starResolver).balance;
        
        // Multiple users buy stars for various domains
        vm.startPrank(user1);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain("example.com"));
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain("subdomain.example.com"));
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain("test.org"));
        vm.stopPrank();
        
        vm.startPrank(user2);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain("example.com")); // Second star
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain("another.io"));
        vm.stopPrank();
        
        vm.startPrank(user3);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain("example.com")); // Third star
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain("deep.sub.domain.com"));
        vm.stopPrank();
        
        // Verify star counts
        assertEq(starResolver.starCounts(_computeNamehash("example.com")), 3);
        assertEq(starResolver.starCounts(_computeNamehash("subdomain.example.com")), 1);
        assertEq(starResolver.starCounts(_computeNamehash("test.org")), 1);
        assertEq(starResolver.starCounts(_computeNamehash("another.io")), 1);
        assertEq(starResolver.starCounts(_computeNamehash("deep.sub.domain.com")), 1);
        
        // Verify hasStarred tracking
        assertTrue(starResolver.hasStarred(user1, _computeNamehash("example.com")));
        assertTrue(starResolver.hasStarred(user2, _computeNamehash("example.com")));
        assertTrue(starResolver.hasStarred(user3, _computeNamehash("example.com")));
        assertFalse(starResolver.hasStarred(user1, _computeNamehash("another.io")));
        
        // Verify contract balance
        assertEq(address(starResolver).balance, initialContractBalance + (DEFAULT_STAR_PRICE * 7));
        
        // Test credential resolution for all domains
        bytes memory dnsName1 = _encodeDomain("example.com");
        assertEq(starResolver.credential(dnsName1, DEFAULT_TEXT_RECORD_KEY), "3");
        
        bytes memory dnsName2 = _encodeDomain("subdomain.example.com");
        assertEq(starResolver.credential(dnsName2, DEFAULT_TEXT_RECORD_KEY), "1");
        
        bytes memory dnsName3 = _encodeDomain("nonexistent.com");
        assertEq(starResolver.credential(dnsName3, DEFAULT_TEXT_RECORD_KEY), "0");
    }
    
    function test_031____adminWorkflow_______________ManagesAdminFunctionsAndWithdrawal() public {
        // Initial setup with stars
        vm.startPrank(user1);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(DOMAIN1));
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(DOMAIN2));
        vm.stopPrank();
        
        uint256 balanceAfterStars = address(starResolver).balance;
        
        // Admin updates star price
        uint256 newPrice = 0.002 ether;
        vm.startPrank(admin);
        starResolver.updateStarPrice(newPrice);
        vm.stopPrank();
        
        // User buys star at new price
        vm.startPrank(user2);
        starResolver.buyStar{value: newPrice}(_encodeDomain(DOMAIN1));
        vm.stopPrank();
        
        // Admin updates text record key
        string memory newKey = "custom.star.key";
        vm.startPrank(admin);
        starResolver.setTextRecordKey(newKey);
        vm.stopPrank();
        
        // Test credential resolution with new key
        bytes memory dnsName = _encodeDomain(DOMAIN1);
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
    
    function test_032____edgeCases___________________HandlesEdgeCasesCorrectly() public {
        // Test with empty domain string
        vm.startPrank(user1);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(""));
        vm.stopPrank();
        
        assertEq(starResolver.starCounts(_computeNamehash("")), 1);
        
        // Test with very long domain
        string memory longDomain = "very.very.very.very.very.very.long.subdomain.example.com";
        vm.startPrank(user1);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(longDomain));
        vm.stopPrank();
        
        assertEq(starResolver.starCounts(_computeNamehash(longDomain)), 1);
        
        // Test credential resolution with edge cases
        bytes memory dnsName1 = _encodeDomain("");
        assertEq(starResolver.credential(dnsName1, DEFAULT_TEXT_RECORD_KEY), "1");
        
        bytes memory dnsName2 = _encodeDomain(longDomain);
        assertEq(starResolver.credential(dnsName2, DEFAULT_TEXT_RECORD_KEY), "1");
        
        // Test with special characters in domain (only basic ASCII allowed in real domains)
        string memory specialDomain = "test-domain.example-site.com";
        vm.startPrank(user2);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(specialDomain));
        vm.stopPrank();
        
        bytes memory dnsName3 = _encodeDomain(specialDomain);
        assertEq(starResolver.credential(dnsName3, DEFAULT_TEXT_RECORD_KEY), "1");
    }
    
    /* --- hasStarredName Function Tests --- */
    
    function test_033____hasStarredName______________ReturnsFalseForNewDomain() public view {
        // Test with unstarred domains
        assertFalse(starResolver.hasStarredName(user1, _encodeDomain(DOMAIN1)));
        assertFalse(starResolver.hasStarredName(user2, _encodeDomain(DOMAIN2)));
        assertFalse(starResolver.hasStarredName(user3, _encodeDomain(DOMAIN3)));
    }
    
    function test_034____hasStarredName______________ReturnsTrueAfterStarring() public {
        // User1 stars DOMAIN1
        vm.startPrank(user1);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(DOMAIN1));
        vm.stopPrank();
        
        // Should return true for user1
        assertTrue(starResolver.hasStarredName(user1, _encodeDomain(DOMAIN1)));
        
        // Should return false for other users
        assertFalse(starResolver.hasStarredName(user2, _encodeDomain(DOMAIN1)));
        assertFalse(starResolver.hasStarredName(user3, _encodeDomain(DOMAIN1)));
        
        // Should return false for same user with different domain
        assertFalse(starResolver.hasStarredName(user1, _encodeDomain(DOMAIN2)));
        assertFalse(starResolver.hasStarredName(user1, _encodeDomain(DOMAIN3)));
    }
    
    function test_035____hasStarredName______________HandlesMultipleUsersAndDomains() public {
        // Multiple users star different domains
        vm.startPrank(user1);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(DOMAIN1));
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(DOMAIN2));
        vm.stopPrank();
        
        vm.startPrank(user2);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(DOMAIN1));
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(DOMAIN3));
        vm.stopPrank();
        
        // Check user1 starred domains
        assertTrue(starResolver.hasStarredName(user1, _encodeDomain(DOMAIN1)));
        assertTrue(starResolver.hasStarredName(user1, _encodeDomain(DOMAIN2)));
        assertFalse(starResolver.hasStarredName(user1, _encodeDomain(DOMAIN3)));
        
        // Check user2 starred domains
        assertTrue(starResolver.hasStarredName(user2, _encodeDomain(DOMAIN1)));
        assertFalse(starResolver.hasStarredName(user2, _encodeDomain(DOMAIN2)));
        assertTrue(starResolver.hasStarredName(user2, _encodeDomain(DOMAIN3)));
        
        // Check user3 (no stars)
        assertFalse(starResolver.hasStarredName(user3, _encodeDomain(DOMAIN1)));
        assertFalse(starResolver.hasStarredName(user3, _encodeDomain(DOMAIN2)));
        assertFalse(starResolver.hasStarredName(user3, _encodeDomain(DOMAIN3)));
    }
    
    function test_036____hasStarredName______________HandlesEdgeCases() public {
        // Test with empty domain
        vm.startPrank(user1);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(""));
        vm.stopPrank();
        
        assertTrue(starResolver.hasStarredName(user1, _encodeDomain("")));
        assertFalse(starResolver.hasStarredName(user2, _encodeDomain("")));
        
        // Test with very long domain
        string memory longDomain = "very.very.very.very.very.very.long.subdomain.example.com";
        vm.startPrank(user2);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(longDomain));
        vm.stopPrank();
        
        assertTrue(starResolver.hasStarredName(user2, _encodeDomain(longDomain)));
        assertFalse(starResolver.hasStarredName(user1, _encodeDomain(longDomain)));
        
        // Test with special characters domain
        string memory specialDomain = "test-domain.example-site.com";
        vm.startPrank(user3);
        starResolver.buyStar{value: DEFAULT_STAR_PRICE}(_encodeDomain(specialDomain));
        vm.stopPrank();
        
        assertTrue(starResolver.hasStarredName(user3, _encodeDomain(specialDomain)));
        assertFalse(starResolver.hasStarredName(user1, _encodeDomain(specialDomain)));
    }

    /* --- Helper Functions --- */
    
    /**
     * @dev Convert domain string to DNS-encoded identifier for star purchase
     */
    function _encodeDomain(string memory domain) internal pure returns (bytes memory) {
        return NameCoder.encode(domain);
    }
    
    /**
     * @dev Compute namehash for domain using NameCoder (same as contract)
     */
    function _computeNamehash(string memory domain) internal pure returns (bytes32) {
        bytes memory dnsEncoded = NameCoder.encode(domain);
        return NameCoder.namehash(dnsEncoded, 0);
    }
} 