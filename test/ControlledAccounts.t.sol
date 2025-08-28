// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/credentials/controlled-accounts/ControlledAccounts.sol";

contract ControlledAccountsTest is Test {
    ControlledAccounts public controlledAccounts;
    
    /* --- Test Accounts --- */
    
    address admin = address(0x1001);
    address user1 = address(0x1002);
    address user2 = address(0x1003);
    address user3 = address(0x1004);
    address newAdmin = address(0x1005);
    
    /* --- Test Constants --- */
    
    uint256 constant DEFAULT_MAX_CONTROLLED_ACCOUNTS = 1000;
    uint256 constant MIN_MAX_CONTROLLED_ACCOUNTS = 100;
    string constant DEFAULT_TEXT_RECORD_KEY = "eth.ecs.controlled-accounts.accounts";
    
    // Test addresses for controlled accounts
    address constant CONTROLLED_ACCOUNT_1 = address(0x1234567890123456789012345678901234567890);
    address constant CONTROLLED_ACCOUNT_2 = address(0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD);
    address constant CONTROLLED_ACCOUNT_3 = address(0x9876543210987654321098765432109876543210);
    address constant CONTROLLED_ACCOUNT_4 = address(0x1111111111111111111111111111111111111111);
    address constant CONTROLLED_ACCOUNT_5 = address(0x2222222222222222222222222222222222222222);
    
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
        controlledAccounts = new ControlledAccounts();
        vm.stopPrank();
        
        // Fund test accounts
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        vm.deal(admin, 10 ether);
    }
    
    /* --- Test Dividers --- */
    
    function test1000________________________________________________________________________________() public pure {}
    function test1100____________________CONTROLLED_ACCOUNTS_TESTS____________________________________() public pure {}
    function test1200________________________________________________________________________________() public pure {}
    
    /* --- Constructor Tests --- */
    
    function test_001____constructor_________________InitializesCorrectly() public view {
        // Test default values
        assertEq(controlledAccounts.textRecordKey(), DEFAULT_TEXT_RECORD_KEY);
        assertEq(controlledAccounts.maxControlledAccounts(), DEFAULT_MAX_CONTROLLED_ACCOUNTS);
        assertEq(controlledAccounts.MIN_MAX_CONTROLLED_ACCOUNTS(), MIN_MAX_CONTROLLED_ACCOUNTS);
        
        // Test role assignments
        assertTrue(controlledAccounts.hasRole(controlledAccounts.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(controlledAccounts.hasRole(controlledAccounts.ADMIN_ROLE(), admin));
    }
    
    /* --- declareControlledAccounts Function Tests --- */
    
    function test_002____declareControlledAccounts___DeclaresSingleAccountSuccessfully() public {
        address[] memory accounts = new address[](1);
        accounts[0] = CONTROLLED_ACCOUNT_1;
        
        vm.startPrank(user1);
        
        vm.expectEmit(true, false, false, true);
        emit ControlledAccounts.ControlledAccountsDeclared(user1, accounts);
        
        controlledAccounts.declareControlledAccounts(accounts);
        
        vm.stopPrank();
        
        // Verify controlled accounts
        address[] memory declaredAccounts = controlledAccounts.getControlledAccounts(user1);
        assertEq(declaredAccounts.length, 1);
        assertEq(declaredAccounts[0], CONTROLLED_ACCOUNT_1);
        
        // Verify isControlledAccount
        assertTrue(controlledAccounts.isControlledAccount(user1, CONTROLLED_ACCOUNT_1));
    }
    
    function test_003____declareControlledAccounts___DeclaresMultipleAccountsSuccessfully() public {
        address[] memory accounts = new address[](3);
        accounts[0] = CONTROLLED_ACCOUNT_1;
        accounts[1] = CONTROLLED_ACCOUNT_2;
        accounts[2] = CONTROLLED_ACCOUNT_3;
        
        vm.startPrank(user1);
        
        vm.expectEmit(true, false, false, true);
        emit ControlledAccounts.ControlledAccountsDeclared(user1, accounts);
        
        controlledAccounts.declareControlledAccounts(accounts);
        
        vm.stopPrank();
        
        // Verify controlled accounts
        address[] memory declaredAccounts = controlledAccounts.getControlledAccounts(user1);
        assertEq(declaredAccounts.length, 3);
        assertEq(declaredAccounts[0], CONTROLLED_ACCOUNT_1);
        assertEq(declaredAccounts[1], CONTROLLED_ACCOUNT_2);
        assertEq(declaredAccounts[2], CONTROLLED_ACCOUNT_3);
        
        // Verify isControlledAccount for all
        assertTrue(controlledAccounts.isControlledAccount(user1, CONTROLLED_ACCOUNT_1));
        assertTrue(controlledAccounts.isControlledAccount(user1, CONTROLLED_ACCOUNT_2));
        assertTrue(controlledAccounts.isControlledAccount(user1, CONTROLLED_ACCOUNT_3));
    }
    
    function test_004____declareControlledAccounts___AllowsMultipleControllers() public {
        address[] memory accounts1 = new address[](2);
        accounts1[0] = CONTROLLED_ACCOUNT_1;
        accounts1[1] = CONTROLLED_ACCOUNT_2;
        
        address[] memory accounts2 = new address[](2);
        accounts2[0] = CONTROLLED_ACCOUNT_3;
        accounts2[1] = CONTROLLED_ACCOUNT_4;
        
        // User1 declares accounts
        vm.startPrank(user1);
        controlledAccounts.declareControlledAccounts(accounts1);
        vm.stopPrank();
        
        // User2 declares different accounts
        vm.startPrank(user2);
        controlledAccounts.declareControlledAccounts(accounts2);
        vm.stopPrank();
        
        // Verify user1's accounts
        address[] memory user1Accounts = controlledAccounts.getControlledAccounts(user1);
        assertEq(user1Accounts.length, 2);
        assertEq(user1Accounts[0], CONTROLLED_ACCOUNT_1);
        assertEq(user1Accounts[1], CONTROLLED_ACCOUNT_2);
        
        // Verify user2's accounts
        address[] memory user2Accounts = controlledAccounts.getControlledAccounts(user2);
        assertEq(user2Accounts.length, 2);
        assertEq(user2Accounts[0], CONTROLLED_ACCOUNT_3);
        assertEq(user2Accounts[1], CONTROLLED_ACCOUNT_4);
        
        // Verify isControlledAccount
        assertTrue(controlledAccounts.isControlledAccount(user1, CONTROLLED_ACCOUNT_1));
        assertTrue(controlledAccounts.isControlledAccount(user1, CONTROLLED_ACCOUNT_2));
        assertTrue(controlledAccounts.isControlledAccount(user2, CONTROLLED_ACCOUNT_3));
        assertTrue(controlledAccounts.isControlledAccount(user2, CONTROLLED_ACCOUNT_4));
        
        // Verify cross-controller relationships don't exist
        assertFalse(controlledAccounts.isControlledAccount(user1, CONTROLLED_ACCOUNT_3));
        assertFalse(controlledAccounts.isControlledAccount(user2, CONTROLLED_ACCOUNT_1));
    }
    
    function test_005____declareControlledAccounts___RevertsForEmptyArray() public {
        address[] memory accounts = new address[](0);
        
        vm.startPrank(user1);
        
        vm.expectRevert("No accounts provided");
        controlledAccounts.declareControlledAccounts(accounts);
        
        vm.stopPrank();
        
        // Verify no accounts were added
        address[] memory declaredAccounts = controlledAccounts.getControlledAccounts(user1);
        assertEq(declaredAccounts.length, 0);
    }
    
    function test_006____declareControlledAccounts___RevertsForZeroAddress() public {
        address[] memory accounts = new address[](1);
        accounts[0] = address(0);
        
        vm.startPrank(user1);
        
        vm.expectRevert("Invalid account address");
        controlledAccounts.declareControlledAccounts(accounts);
        
        vm.stopPrank();
        
        // Verify no accounts were added
        address[] memory declaredAccounts = controlledAccounts.getControlledAccounts(user1);
        assertEq(declaredAccounts.length, 0);
    }
    
    function test_007____declareControlledAccounts___RevertsForSelfControl() public {
        address[] memory accounts = new address[](1);
        accounts[0] = user1; // User trying to control themselves
        
        vm.startPrank(user1);
        
        vm.expectRevert("Cannot control self");
        controlledAccounts.declareControlledAccounts(accounts);
        
        vm.stopPrank();
        
        // Verify no accounts were added
        address[] memory declaredAccounts = controlledAccounts.getControlledAccounts(user1);
        assertEq(declaredAccounts.length, 0);
    }
    
    function test_008____declareControlledAccounts___RevertsForDuplicateAccounts() public {
        address[] memory accounts = new address[](2);
        accounts[0] = CONTROLLED_ACCOUNT_1;
        accounts[1] = CONTROLLED_ACCOUNT_1; // Duplicate
        
        vm.startPrank(user1);
        
        vm.expectRevert(ControlledAccounts.AccountAlreadyControlled.selector);
        controlledAccounts.declareControlledAccounts(accounts);
        
        vm.stopPrank();
        
        // Verify no accounts were added
        address[] memory declaredAccounts = controlledAccounts.getControlledAccounts(user1);
        assertEq(declaredAccounts.length, 0);
    }
    
    function test_009____declareControlledAccounts___RevertsForAlreadyControlledAccount() public {
        address[] memory accounts1 = new address[](1);
        accounts1[0] = CONTROLLED_ACCOUNT_1;
        
        address[] memory accounts2 = new address[](1);
        accounts2[0] = CONTROLLED_ACCOUNT_1; // Same account
        
        // First declaration succeeds
        vm.startPrank(user1);
        controlledAccounts.declareControlledAccounts(accounts1);
        vm.stopPrank();
        
        // Second declaration by same user fails
        vm.startPrank(user1);
        vm.expectRevert(ControlledAccounts.AccountAlreadyControlled.selector);
        controlledAccounts.declareControlledAccounts(accounts2);
        vm.stopPrank();
        
        // Verify only one account was added
        address[] memory declaredAccounts = controlledAccounts.getControlledAccounts(user1);
        assertEq(declaredAccounts.length, 1);
        assertEq(declaredAccounts[0], CONTROLLED_ACCOUNT_1);
    }
    
    /* --- removeControlledAccount Function Tests --- */
    
    function test_010____removeControlledAccount_____RemovesAccountSuccessfully() public {
        // First declare accounts
        address[] memory accounts = new address[](2);
        accounts[0] = CONTROLLED_ACCOUNT_1;
        accounts[1] = CONTROLLED_ACCOUNT_2;
        
        vm.startPrank(user1);
        controlledAccounts.declareControlledAccounts(accounts);
        vm.stopPrank();
        
        // Remove one account
        vm.startPrank(user1);
        
        vm.expectEmit(true, true, false, false);
        emit ControlledAccounts.ControlledAccountRemoved(user1, CONTROLLED_ACCOUNT_1);
        
        controlledAccounts.removeControlledAccount(CONTROLLED_ACCOUNT_1);
        
        vm.stopPrank();
        
        // Verify account was removed
        address[] memory remainingAccounts = controlledAccounts.getControlledAccounts(user1);
        assertEq(remainingAccounts.length, 1);
        assertEq(remainingAccounts[0], CONTROLLED_ACCOUNT_2);
        
        // Verify isControlledAccount
        assertFalse(controlledAccounts.isControlledAccount(user1, CONTROLLED_ACCOUNT_1));
        assertTrue(controlledAccounts.isControlledAccount(user1, CONTROLLED_ACCOUNT_2));
    }
    
    function test_011____removeControlledAccount_____RemovesLastAccountSuccessfully() public {
        // Declare single account
        address[] memory accounts = new address[](1);
        accounts[0] = CONTROLLED_ACCOUNT_1;
        
        vm.startPrank(user1);
        controlledAccounts.declareControlledAccounts(accounts);
        vm.stopPrank();
        
        // Remove the account
        vm.startPrank(user1);
        controlledAccounts.removeControlledAccount(CONTROLLED_ACCOUNT_1);
        vm.stopPrank();
        
        // Verify no accounts remain
        address[] memory remainingAccounts = controlledAccounts.getControlledAccounts(user1);
        assertEq(remainingAccounts.length, 0);
        
        // Verify isControlledAccount
        assertFalse(controlledAccounts.isControlledAccount(user1, CONTROLLED_ACCOUNT_1));
    }
    
    function test_012____removeControlledAccount_____RevertsForNonExistentAccount() public {
        vm.startPrank(user1);
        
        vm.expectRevert(ControlledAccounts.AccountNotControlled.selector);
        controlledAccounts.removeControlledAccount(CONTROLLED_ACCOUNT_1);
        
        vm.stopPrank();
    }
    
    function test_013____removeControlledAccount_____RevertsForAccountControlledByOther() public {
        // User1 declares account
        address[] memory accounts = new address[](1);
        accounts[0] = CONTROLLED_ACCOUNT_1;
        
        vm.startPrank(user1);
        controlledAccounts.declareControlledAccounts(accounts);
        vm.stopPrank();
        
        // User2 tries to remove account controlled by user1
        vm.startPrank(user2);
        vm.expectRevert(ControlledAccounts.AccountNotControlled.selector);
        controlledAccounts.removeControlledAccount(CONTROLLED_ACCOUNT_1);
        vm.stopPrank();
        
        // Verify account still exists under user1
        address[] memory user1Accounts = controlledAccounts.getControlledAccounts(user1);
        assertEq(user1Accounts.length, 1);
        assertEq(user1Accounts[0], CONTROLLED_ACCOUNT_1);
    }
    
    function test_014____removeControlledAccount_____MaintainsArrayOrderAfterRemoval() public {
        // Declare 3 accounts
        address[] memory accounts = new address[](3);
        accounts[0] = CONTROLLED_ACCOUNT_1;
        accounts[1] = CONTROLLED_ACCOUNT_2;
        accounts[2] = CONTROLLED_ACCOUNT_3;
        
        vm.startPrank(user1);
        controlledAccounts.declareControlledAccounts(accounts);
        vm.stopPrank();
        
        // Remove middle account (CONTROLLED_ACCOUNT_2)
        vm.startPrank(user1);
        controlledAccounts.removeControlledAccount(CONTROLLED_ACCOUNT_2);
        vm.stopPrank();
        
        // Verify remaining accounts maintain order
        address[] memory remainingAccounts = controlledAccounts.getControlledAccounts(user1);
        assertEq(remainingAccounts.length, 2);
        assertEq(remainingAccounts[0], CONTROLLED_ACCOUNT_1);
        assertEq(remainingAccounts[1], CONTROLLED_ACCOUNT_3);
        
        // Verify isControlledAccount
        assertTrue(controlledAccounts.isControlledAccount(user1, CONTROLLED_ACCOUNT_1));
        assertFalse(controlledAccounts.isControlledAccount(user1, CONTROLLED_ACCOUNT_2));
        assertTrue(controlledAccounts.isControlledAccount(user1, CONTROLLED_ACCOUNT_3));
    }
    
    /* --- setController Function Tests --- */
    
    function test_015____setController_______________SetsControllerSuccessfully() public {
        vm.startPrank(CONTROLLED_ACCOUNT_1);
        
        vm.expectEmit(true, true, false, false);
        emit ControlledAccounts.ControllerSet(CONTROLLED_ACCOUNT_1, user1);
        
        controlledAccounts.setController(user1);
        
        vm.stopPrank();
        
        // Verify controller was set
        assertEq(controlledAccounts.getController(CONTROLLED_ACCOUNT_1), user1);
    }
    
    function test_016____setController_______________ReplacesExistingController() public {
        // Set initial controller
        vm.startPrank(CONTROLLED_ACCOUNT_1);
        controlledAccounts.setController(user1);
        vm.stopPrank();
        
        // Replace with new controller
        vm.startPrank(CONTROLLED_ACCOUNT_1);
        
        vm.expectEmit(true, true, false, false);
        emit ControlledAccounts.ControllerRemoved(CONTROLLED_ACCOUNT_1, user1);
        
        vm.expectEmit(true, true, false, false);
        emit ControlledAccounts.ControllerSet(CONTROLLED_ACCOUNT_1, user2);
        
        controlledAccounts.setController(user2);
        
        vm.stopPrank();
        
        // Verify new controller was set
        assertEq(controlledAccounts.getController(CONTROLLED_ACCOUNT_1), user2);
    }
    
    function test_017____setController_______________RevertsForZeroAddress() public {
        vm.startPrank(CONTROLLED_ACCOUNT_1);
        
        vm.expectRevert("Invalid controller address");
        controlledAccounts.setController(address(0));
        
        vm.stopPrank();
        
        // Verify no controller was set
        assertEq(controlledAccounts.getController(CONTROLLED_ACCOUNT_1), address(0));
    }
    
    function test_018____setController_______________RevertsForSelfControl() public {
        vm.startPrank(CONTROLLED_ACCOUNT_1);
        
        vm.expectRevert("Cannot set self as controller");
        controlledAccounts.setController(CONTROLLED_ACCOUNT_1);
        
        vm.stopPrank();
        
        // Verify no controller was set
        assertEq(controlledAccounts.getController(CONTROLLED_ACCOUNT_1), address(0));
    }
    
    /* --- removeController Function Tests --- */
    
    function test_019____removeController_____________RemovesControllerSuccessfully() public {
        // Set controller first
        vm.startPrank(CONTROLLED_ACCOUNT_1);
        controlledAccounts.setController(user1);
        vm.stopPrank();
        
        // Remove controller
        vm.startPrank(CONTROLLED_ACCOUNT_1);
        
        vm.expectEmit(true, true, false, false);
        emit ControlledAccounts.ControllerRemoved(CONTROLLED_ACCOUNT_1, user1);
        
        controlledAccounts.removeController();
        
        vm.stopPrank();
        
        // Verify controller was removed
        assertEq(controlledAccounts.getController(CONTROLLED_ACCOUNT_1), address(0));
    }
    
    function test_020____removeController_____________RevertsForNoControllerSet() public {
        vm.startPrank(CONTROLLED_ACCOUNT_1);
        
        vm.expectRevert("No controller set");
        controlledAccounts.removeController();
        
        vm.stopPrank();
        
        // Verify no controller was set
        assertEq(controlledAccounts.getController(CONTROLLED_ACCOUNT_1), address(0));
    }
    
    /* --- View Function Tests --- */
    
    function test_021____getControlledAccounts_______ReturnsEmptyForNewController() public view {
        address[] memory accounts = controlledAccounts.getControlledAccounts(user1);
        assertEq(accounts.length, 0);
    }
    
    function test_022____getControlledAccounts_______ReturnsCorrectAccounts() public {
        // Declare accounts
        address[] memory accounts = new address[](3);
        accounts[0] = CONTROLLED_ACCOUNT_1;
        accounts[1] = CONTROLLED_ACCOUNT_2;
        accounts[2] = CONTROLLED_ACCOUNT_3;
        
        vm.startPrank(user1);
        controlledAccounts.declareControlledAccounts(accounts);
        vm.stopPrank();
        
        // Get controlled accounts
        address[] memory retrievedAccounts = controlledAccounts.getControlledAccounts(user1);
        assertEq(retrievedAccounts.length, 3);
        assertEq(retrievedAccounts[0], CONTROLLED_ACCOUNT_1);
        assertEq(retrievedAccounts[1], CONTROLLED_ACCOUNT_2);
        assertEq(retrievedAccounts[2], CONTROLLED_ACCOUNT_3);
    }
    
    function test_023____getControlledAccounts_______ReturnsEmptyAfterRemoval() public {
        // Declare and then remove account
        address[] memory accounts = new address[](1);
        accounts[0] = CONTROLLED_ACCOUNT_1;
        
        vm.startPrank(user1);
        controlledAccounts.declareControlledAccounts(accounts);
        controlledAccounts.removeControlledAccount(CONTROLLED_ACCOUNT_1);
        vm.stopPrank();
        
        // Get controlled accounts
        address[] memory retrievedAccounts = controlledAccounts.getControlledAccounts(user1);
        assertEq(retrievedAccounts.length, 0);
    }
    
    function test_024____getController_______________ReturnsZeroAddressForNewAccount() public view {
        address controller = controlledAccounts.getController(CONTROLLED_ACCOUNT_1);
        assertEq(controller, address(0));
    }
    
    function test_025____getController_______________ReturnsCorrectController() public {
        // Set controller
        vm.startPrank(CONTROLLED_ACCOUNT_1);
        controlledAccounts.setController(user1);
        vm.stopPrank();
        
        // Get controller
        address controller = controlledAccounts.getController(CONTROLLED_ACCOUNT_1);
        assertEq(controller, user1);
    }
    
    function test_026____getController_______________ReturnsZeroAddressAfterRemoval() public {
        // Set and then remove controller
        vm.startPrank(CONTROLLED_ACCOUNT_1);
        controlledAccounts.setController(user1);
        controlledAccounts.removeController();
        vm.stopPrank();
        
        // Get controller
        address controller = controlledAccounts.getController(CONTROLLED_ACCOUNT_1);
        assertEq(controller, address(0));
    }
    
    function test_027____isControlledAccount_________ReturnsFalseForNewAccount() public view {
        assertFalse(controlledAccounts.isControlledAccount(user1, CONTROLLED_ACCOUNT_1));
    }
    
    function test_028____isControlledAccount_________ReturnsTrueForControlledAccount() public {
        // Declare account
        address[] memory accounts = new address[](1);
        accounts[0] = CONTROLLED_ACCOUNT_1;
        
        vm.startPrank(user1);
        controlledAccounts.declareControlledAccounts(accounts);
        vm.stopPrank();
        
        // Check isControlledAccount
        assertTrue(controlledAccounts.isControlledAccount(user1, CONTROLLED_ACCOUNT_1));
    }
    
    function test_029____isControlledAccount_________ReturnsFalseAfterRemoval() public {
        // Declare and then remove account
        address[] memory accounts = new address[](1);
        accounts[0] = CONTROLLED_ACCOUNT_1;
        
        vm.startPrank(user1);
        controlledAccounts.declareControlledAccounts(accounts);
        controlledAccounts.removeControlledAccount(CONTROLLED_ACCOUNT_1);
        vm.stopPrank();
        
        // Check isControlledAccount
        assertFalse(controlledAccounts.isControlledAccount(user1, CONTROLLED_ACCOUNT_1));
    }
    
    /* --- credential Function Tests --- */
    
    function test_030____credential___________________ReturnsEmptyForInvalidKey() public {
        // Declare some accounts
        address[] memory accounts = new address[](1);
        accounts[0] = CONTROLLED_ACCOUNT_1;
        
        vm.startPrank(user1);
        controlledAccounts.declareControlledAccounts(accounts);
        vm.stopPrank();
        
        // Create DNS name
        bytes memory dnsName = _createDNSName(user1, ETHEREUM_MAINNET);
        
        // Test with wrong key
        string memory result = controlledAccounts.credential(dnsName, "wrong.key");
        assertEq(result, "");
        
        // Test with similar but incorrect key
        string memory result2 = controlledAccounts.credential(dnsName, "eth.ecs.controlled-accounts.account"); // missing 's'
        assertEq(result2, "");
    }
    
    function test_031____credential___________________ReturnsEmptyForNewController() public {
        bytes memory dnsName = _createDNSName(user1, ETHEREUM_MAINNET);
        
        // New controller should return empty string
        string memory result = controlledAccounts.credential(dnsName, DEFAULT_TEXT_RECORD_KEY);
        assertEq(result, "");
    }
    
    function test_032____credential___________________ReturnsCorrectFormatForSingleAccount() public {
        // Declare single account
        address[] memory accounts = new address[](1);
        accounts[0] = CONTROLLED_ACCOUNT_1;
        
        vm.startPrank(user1);
        controlledAccounts.declareControlledAccounts(accounts);
        vm.stopPrank();
        
        // Create DNS name
        bytes memory dnsName = _createDNSName(user1, ETHEREUM_MAINNET);
        
        // Test credential resolution
        string memory result = controlledAccounts.credential(dnsName, DEFAULT_TEXT_RECORD_KEY);
        assertEq(result, "0x1234567890123456789012345678901234567890");
    }
    
    function test_033____credential___________________ReturnsCorrectFormatForMultipleAccounts() public {
        // Declare multiple accounts
        address[] memory accounts = new address[](3);
        accounts[0] = CONTROLLED_ACCOUNT_1;
        accounts[1] = CONTROLLED_ACCOUNT_2;
        accounts[2] = CONTROLLED_ACCOUNT_3;
        
        vm.startPrank(user1);
        controlledAccounts.declareControlledAccounts(accounts);
        vm.stopPrank();
        
        // Create DNS name
        bytes memory dnsName = _createDNSName(user1, ETHEREUM_MAINNET);
        
        // Test credential resolution
        string memory result = controlledAccounts.credential(dnsName, DEFAULT_TEXT_RECORD_KEY);
        string memory expected = "0x1234567890123456789012345678901234567890\n0xabcdefabcdefabcdefabcdefabcdefabcdefabcd\n0x9876543210987654321098765432109876543210";
        assertEq(result, expected);
    }
    
    function test_034____credential___________________WorksWithDifferentCoinTypes() public {
        // Declare accounts
        address[] memory accounts = new address[](1);
        accounts[0] = CONTROLLED_ACCOUNT_1;
        
        vm.startPrank(user1);
        controlledAccounts.declareControlledAccounts(accounts);
        vm.stopPrank();
        
        // Test with different coin types
        bytes memory dnsName1 = _createDNSName(user1, ETHEREUM_MAINNET);
        string memory result1 = controlledAccounts.credential(dnsName1, DEFAULT_TEXT_RECORD_KEY);
        assertEq(result1, "0x1234567890123456789012345678901234567890");
        
        bytes memory dnsName2 = _createDNSName(user1, POLYGON_MAINNET);
        string memory result2 = controlledAccounts.credential(dnsName2, DEFAULT_TEXT_RECORD_KEY);
        assertEq(result2, "0x1234567890123456789012345678901234567890");
    }
    
    function test_035____credential___________________RevertsForInvalidDNSNames() public {
        // Empty DNS name
        bytes memory emptyName = new bytes(0);
        vm.expectRevert(ControlledAccounts.InvalidDNSEncoding.selector);
        controlledAccounts.credential(emptyName, DEFAULT_TEXT_RECORD_KEY);
        
        // Very short DNS name
        bytes memory shortName = hex"01";
        vm.expectRevert(ControlledAccounts.InvalidDNSEncoding.selector);
        controlledAccounts.credential(shortName, DEFAULT_TEXT_RECORD_KEY);
        
        // Invalid format DNS name
        bytes memory invalidName = hex"ff";
        vm.expectRevert(ControlledAccounts.InvalidDNSEncoding.selector);
        controlledAccounts.credential(invalidName, DEFAULT_TEXT_RECORD_KEY);
    }
    
    /* --- Admin Function Tests --- */
    
    function test_036____setTextRecordKey____________UpdatesKeySuccessfully() public {
        string memory newKey = "new.custom.key";
        
        vm.startPrank(admin);
        
        vm.expectEmit(false, false, false, true);
        emit ControlledAccounts.TextRecordKeyUpdated(DEFAULT_TEXT_RECORD_KEY, newKey);
        
        controlledAccounts.setTextRecordKey(newKey);
        
        vm.stopPrank();
        
        assertEq(controlledAccounts.textRecordKey(), newKey);
    }
    
    function test_037____setTextRecordKey____________RevertsForNonAdmin() public {
        vm.startPrank(user1);
        
        vm.expectRevert();
        controlledAccounts.setTextRecordKey("unauthorized.key");
        
        vm.stopPrank();
        
        // Key should remain unchanged
        assertEq(controlledAccounts.textRecordKey(), DEFAULT_TEXT_RECORD_KEY);
    }
    
    function test_038____setMaxControlledAccounts____UpdatesLimitSuccessfully() public {
        uint256 newLimit = 2000;
        
        vm.startPrank(admin);
        
        vm.expectEmit(false, false, false, true);
        emit ControlledAccounts.MaxControlledAccountsUpdated(DEFAULT_MAX_CONTROLLED_ACCOUNTS, newLimit);
        
        controlledAccounts.setMaxControlledAccounts(newLimit);
        
        vm.stopPrank();
        
        assertEq(controlledAccounts.maxControlledAccounts(), newLimit);
    }
    
    function test_039____setMaxControlledAccounts____RevertsForBelowMinimum() public {
        uint256 belowMinimum = 50; // Below MIN_MAX_CONTROLLED_ACCOUNTS (100)
        
        vm.startPrank(admin);
        
        vm.expectRevert(ControlledAccounts.InvalidMaxControlledAccounts.selector);
        controlledAccounts.setMaxControlledAccounts(belowMinimum);
        
        vm.stopPrank();
        
        // Limit should remain unchanged
        assertEq(controlledAccounts.maxControlledAccounts(), DEFAULT_MAX_CONTROLLED_ACCOUNTS);
    }
    
    function test_040____setMaxControlledAccounts____RevertsForNonAdmin() public {
        vm.startPrank(user1);
        
        vm.expectRevert();
        controlledAccounts.setMaxControlledAccounts(1500);
        
        vm.stopPrank();
        
        // Limit should remain unchanged
        assertEq(controlledAccounts.maxControlledAccounts(), DEFAULT_MAX_CONTROLLED_ACCOUNTS);
    }
    
    function test_041____setMaxControlledAccounts____AllowsMinimumValue() public {
        vm.startPrank(admin);
        controlledAccounts.setMaxControlledAccounts(MIN_MAX_CONTROLLED_ACCOUNTS);
        vm.stopPrank();
        
        assertEq(controlledAccounts.maxControlledAccounts(), MIN_MAX_CONTROLLED_ACCOUNTS);
    }
    
    /* --- Role Management Tests --- */
    
    function test_042____grantRole___________________AddsNewAdminSuccessfully() public {
        vm.startPrank(admin);
        controlledAccounts.grantRole(controlledAccounts.ADMIN_ROLE(), newAdmin);
        vm.stopPrank();
        
        assertTrue(controlledAccounts.hasRole(controlledAccounts.ADMIN_ROLE(), newAdmin));
        
        // New admin should be able to perform admin functions
        vm.startPrank(newAdmin);
        controlledAccounts.setTextRecordKey("new.admin.key");
        vm.stopPrank();
        
        assertEq(controlledAccounts.textRecordKey(), "new.admin.key");
    }
    
    function test_043____grantRole___________________RevertsForNonDefaultAdmin() public {
        bytes32 adminRole = controlledAccounts.ADMIN_ROLE();
        
        vm.startPrank(user1);
        
        vm.expectRevert();
        controlledAccounts.grantRole(adminRole, newAdmin);
        
        vm.stopPrank();
        
        assertFalse(controlledAccounts.hasRole(adminRole, newAdmin));
    }
    
    function test_044____revokeRole__________________RemovesAdminSuccessfully() public {
        // Add admin first
        vm.startPrank(admin);
        controlledAccounts.grantRole(controlledAccounts.ADMIN_ROLE(), newAdmin);
        vm.stopPrank();
        
        assertTrue(controlledAccounts.hasRole(controlledAccounts.ADMIN_ROLE(), newAdmin));
        
        // Remove admin
        vm.startPrank(admin);
        controlledAccounts.revokeRole(controlledAccounts.ADMIN_ROLE(), newAdmin);
        vm.stopPrank();
        
        assertFalse(controlledAccounts.hasRole(controlledAccounts.ADMIN_ROLE(), newAdmin));
        
        // Removed admin should not be able to perform admin functions
        vm.startPrank(newAdmin);
        vm.expectRevert();
        controlledAccounts.setTextRecordKey("unauthorized.key");
        vm.stopPrank();
    }
    
    /* --- Limit Enforcement Tests --- */
    
    function test_045____declareControlledAccounts___RespectsMaxLimit() public {
        // Set a low limit (minimum is 100, so we'll use 101)
        vm.startPrank(admin);
        controlledAccounts.setMaxControlledAccounts(101);
        vm.stopPrank();
        
        // Try to declare 102 accounts (exceeds limit)
        address[] memory accounts = new address[](102);
        for (uint256 i = 0; i < 102; i++) {
            accounts[i] = address(uint160(0x5000 + i)); // Generate unique addresses starting from 0x5000
        }
        
        vm.startPrank(user1);
        
        vm.expectRevert(ControlledAccounts.TooManyControlledAccounts.selector);
        controlledAccounts.declareControlledAccounts(accounts);
        
        vm.stopPrank();
        
        // Verify no accounts were added
        address[] memory declaredAccounts = controlledAccounts.getControlledAccounts(user1);
        assertEq(declaredAccounts.length, 0);
    }
    
    function test_046____declareControlledAccounts___WorksWithinLimit() public {
        // Set a limit of 101 (just above minimum)
        vm.startPrank(admin);
        controlledAccounts.setMaxControlledAccounts(101);
        vm.stopPrank();
        
        // Declare 100 accounts (within limit)
        address[] memory accounts = new address[](100);
        for (uint256 i = 0; i < 100; i++) {
            accounts[i] = address(uint160(0x5000 + i)); // Generate unique addresses starting from 0x5000
        }
        
        vm.startPrank(user1);
        controlledAccounts.declareControlledAccounts(accounts);
        vm.stopPrank();
        
        // Verify accounts were added
        address[] memory declaredAccounts = controlledAccounts.getControlledAccounts(user1);
        assertEq(declaredAccounts.length, 100);
    }
    
    function test_047____declareControlledAccounts___RespectsLimitAfterRemoval() public {
        // Set a limit of 101 (just above minimum)
        vm.startPrank(admin);
        controlledAccounts.setMaxControlledAccounts(101);
        vm.stopPrank();
        
        // Declare 100 accounts
        address[] memory accounts = new address[](100);
        for (uint256 i = 0; i < 100; i++) {
            accounts[i] = address(uint160(0x5000 + i)); // Generate unique addresses starting from 0x5000
        }
        
        vm.startPrank(user1);
        controlledAccounts.declareControlledAccounts(accounts);
        vm.stopPrank();
        
        // Remove one account
        vm.startPrank(user1);
        controlledAccounts.removeControlledAccount(address(0x5000)); // Remove first account
        vm.stopPrank();
        
        // Should be able to add 1 more account (total 100, within limit of 101)
        address[] memory newAccounts = new address[](1);
        newAccounts[0] = address(0x2000);
        
        vm.startPrank(user1);
        controlledAccounts.declareControlledAccounts(newAccounts);
        vm.stopPrank();
        
        // Verify total accounts is 100 (within limit)
        address[] memory allAccounts = controlledAccounts.getControlledAccounts(user1);
        assertEq(allAccounts.length, 100);
    }
    
    /* --- Complex Integration Tests --- */
    
    function test_048____bidirectionalVerification___CompleteWorkflow() public {
        // User1 declares controlled accounts
        address[] memory accounts = new address[](2);
        accounts[0] = CONTROLLED_ACCOUNT_1;
        accounts[1] = CONTROLLED_ACCOUNT_2;
        
        vm.startPrank(user1);
        controlledAccounts.declareControlledAccounts(accounts);
        vm.stopPrank();
        
        // Controlled accounts verify their controller
        vm.startPrank(CONTROLLED_ACCOUNT_1);
        controlledAccounts.setController(user1);
        vm.stopPrank();
        
        vm.startPrank(CONTROLLED_ACCOUNT_2);
        controlledAccounts.setController(user1);
        vm.stopPrank();
        
        // Verify bidirectional relationships
        assertTrue(controlledAccounts.isControlledAccount(user1, CONTROLLED_ACCOUNT_1));
        assertTrue(controlledAccounts.isControlledAccount(user1, CONTROLLED_ACCOUNT_2));
        assertEq(controlledAccounts.getController(CONTROLLED_ACCOUNT_1), user1);
        assertEq(controlledAccounts.getController(CONTROLLED_ACCOUNT_2), user1);
        
        // Test credential resolution
        bytes memory dnsName = _createDNSName(user1, ETHEREUM_MAINNET);
        string memory result = controlledAccounts.credential(dnsName, DEFAULT_TEXT_RECORD_KEY);
        string memory expected = "0x1234567890123456789012345678901234567890\n0xabcdefabcdefabcdefabcdefabcdefabcdefabcd";
        assertEq(result, expected);
    }
    
    function test_049____complexScenario______________MultipleControllersAndAccounts() public {
        // User1 declares accounts
        address[] memory accounts1 = new address[](2);
        accounts1[0] = CONTROLLED_ACCOUNT_1;
        accounts1[1] = CONTROLLED_ACCOUNT_2;
        
        vm.startPrank(user1);
        controlledAccounts.declareControlledAccounts(accounts1);
        vm.stopPrank();
        
        // User2 declares different accounts
        address[] memory accounts2 = new address[](2);
        accounts2[0] = CONTROLLED_ACCOUNT_3;
        accounts2[1] = CONTROLLED_ACCOUNT_4;
        
        vm.startPrank(user2);
        controlledAccounts.declareControlledAccounts(accounts2);
        vm.stopPrank();
        
        // Some controlled accounts verify their controllers
        vm.startPrank(CONTROLLED_ACCOUNT_1);
        controlledAccounts.setController(user1);
        vm.stopPrank();
        
        vm.startPrank(CONTROLLED_ACCOUNT_3);
        controlledAccounts.setController(user2);
        vm.stopPrank();
        
        // Verify all relationships
        assertTrue(controlledAccounts.isControlledAccount(user1, CONTROLLED_ACCOUNT_1));
        assertTrue(controlledAccounts.isControlledAccount(user1, CONTROLLED_ACCOUNT_2));
        assertTrue(controlledAccounts.isControlledAccount(user2, CONTROLLED_ACCOUNT_3));
        assertTrue(controlledAccounts.isControlledAccount(user2, CONTROLLED_ACCOUNT_4));
        
        assertEq(controlledAccounts.getController(CONTROLLED_ACCOUNT_1), user1);
        assertEq(controlledAccounts.getController(CONTROLLED_ACCOUNT_3), user2);
        assertEq(controlledAccounts.getController(CONTROLLED_ACCOUNT_2), address(0)); // Not verified
        assertEq(controlledAccounts.getController(CONTROLLED_ACCOUNT_4), address(0)); // Not verified
        
        // Test credential resolution for both controllers
        bytes memory dnsName1 = _createDNSName(user1, ETHEREUM_MAINNET);
        string memory result1 = controlledAccounts.credential(dnsName1, DEFAULT_TEXT_RECORD_KEY);
        string memory expected1 = "0x1234567890123456789012345678901234567890\n0xabcdefabcdefabcdefabcdefabcdefabcdefabcd";
        assertEq(result1, expected1);
        
        bytes memory dnsName2 = _createDNSName(user2, ETHEREUM_MAINNET);
        string memory result2 = controlledAccounts.credential(dnsName2, DEFAULT_TEXT_RECORD_KEY);
        string memory expected2 = "0x9876543210987654321098765432109876543210\n0x1111111111111111111111111111111111111111";
        assertEq(result2, expected2);
    }
    
    /* --- Edge Cases and Boundary Tests --- */
    
    function test_050____edgeCases___________________HandlesZeroAddress() public {
        // Test with zero address (should be rejected)
        address[] memory accounts = new address[](1);
        accounts[0] = address(0);
        
        vm.startPrank(user1);
        
        vm.expectRevert("Invalid account address");
        controlledAccounts.declareControlledAccounts(accounts);
        
        vm.stopPrank();
        
        assertFalse(controlledAccounts.isControlledAccount(user1, address(0)));
    }
    
    function test_051____edgeCases___________________HandlesMaximumValues() public {
        // Test with maximum address value
        address maxAddress = address(type(uint160).max);
        address[] memory accounts = new address[](1);
        accounts[0] = maxAddress;
        
        vm.startPrank(user1);
        controlledAccounts.declareControlledAccounts(accounts);
        vm.stopPrank();
        
        assertTrue(controlledAccounts.isControlledAccount(user1, maxAddress));
        
        // Test credential resolution with max address
        bytes memory dnsName = _createDNSName(user1, ETHEREUM_MAINNET);
        string memory result = controlledAccounts.credential(dnsName, DEFAULT_TEXT_RECORD_KEY);
        assertEq(result, "0xffffffffffffffffffffffffffffffffffffffff");
    }
    
    function test_052____edgeCases___________________HandlesLargeCoinTypes() public {
        // Declare account
        address[] memory accounts = new address[](1);
        accounts[0] = CONTROLLED_ACCOUNT_1;
        
        vm.startPrank(user1);
        controlledAccounts.declareControlledAccounts(accounts);
        vm.stopPrank();
        
        // Test with very large coin type
        uint256 largeCoinType = type(uint256).max;
        bytes memory dnsName = _createDNSName(user1, largeCoinType);
        string memory result = controlledAccounts.credential(dnsName, DEFAULT_TEXT_RECORD_KEY);
        assertEq(result, "0x1234567890123456789012345678901234567890");
    }
    
    function test_053____edgeCases___________________HandlesVariableLengthDNS() public {
        // Test with a 32-byte (64 hex chars) address instead of standard 20-byte
        string memory longAddressHex = "1234567890123456789012345678901234567890123456789012345678901234";
        string memory coinTypeHex = "3c";
        
        // Build DNS name manually for long address
        bytes memory addressBytes = bytes(longAddressHex);
        bytes memory coinTypeBytes = bytes(coinTypeHex);
        
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
        string memory credential = controlledAccounts.credential(result, DEFAULT_TEXT_RECORD_KEY);
        assertEq(credential, ""); // Should return empty for new address
    }
}
