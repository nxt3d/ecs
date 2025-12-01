// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/ECSRegistry.sol";
import "../src/ECSRegistrar.sol";

contract ECSRegistrarTest is Test {
    /* --- Test Accounts --- */
    
    address admin = address(0x1001);
    address user1 = address(0x1002);
    address user2 = address(0x1003);
    address resolver = address(0x1004);
    
    /* --- Contract Variables --- */
    
    ECSRegistry public registry;
    ECSRegistrar public registrar;
    
    /* --- Domain Variables --- */
    
    string public constant LABEL = "testlabel";
    uint256 public constant DURATION = 365 days;
    uint256 public constant PRICE_PER_SEC = 1000 wei;
    
    /* --- Setup --- */
    
    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy Registry
        registry = new ECSRegistry();
        
        // Deploy Registrar
        registrar = new ECSRegistrar(registry);
        
        // Grant Registrar Role
        registry.grantRole(registry.REGISTRAR_ROLE(), address(registrar));
        
        // Configure Registrar Params
        registrar.setParams(
            60, // min duration (1 min)
            type(uint64).max, // max duration
            3, // min chars
            20 // max chars
        );
        
        // Setup Pricing
        uint256[] memory prices = new uint256[](1);
        prices[0] = PRICE_PER_SEC; // Default price
        registrar.setPricingForAllLengths(prices);
        
        vm.stopPrank();
        
        // Fund users
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }
    
    /* --- Test Dividers --- */
    
    function test1000________________________________________________________________________________() public pure {}
    function test1100____________________ECS_REGISTRAR_TESTS___________________________________() public pure {}
    function test1200________________________________________________________________________________() public pure {}
    
    /* --- Pricing Tests --- */
    
    function test_001____rentPrice___________________CalculatesCorrectly() public view {
        uint256 expectedPrice = PRICE_PER_SEC * DURATION;
        assertEq(registrar.rentPrice(LABEL, DURATION), expectedPrice);
    }
    
    function test_002____rentPrice___________________ReturnsZeroIfNoPricing() public {
        vm.startPrank(admin);
        uint256[] memory empty = new uint256[](0);
        registrar.setPricingForAllLengths(empty);
        vm.stopPrank();
        
        assertEq(registrar.rentPrice(LABEL, DURATION), 0);
    }
    
    /* --- Availability Tests --- */
    
    function test_003____available___________________ReturnsTrueForUnregistered() public view {
        assertTrue(registrar.available(LABEL));
    }
    
    function test_004____available___________________ReturnsFalseForRegistered() public {
        uint256 price = registrar.rentPrice(LABEL, DURATION);
        bytes32 secret = bytes32(uint256(1));
        
        vm.startPrank(user1);
        bytes32 commitment = registrar.createCommitment(LABEL, user1, resolver, DURATION, secret);
        registrar.commit(commitment);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 60);
        
        vm.prank(user1);
        registrar.register{value: price}(LABEL, user1, resolver, DURATION, secret);
        
        assertFalse(registrar.available(LABEL));
    }
    
    function test_005____available___________________ReturnsFalseForInvalidLength() public view {
        assertFalse(registrar.available("ab")); // min chars is 3
    }
    
    /* --- Registration Tests --- */
    
    function test_006____register____________________RegistersNameSuccessfully() public {
        uint256 price = registrar.rentPrice(LABEL, DURATION);
        bytes32 labelhash = keccak256(bytes(LABEL));
        bytes32 secret = bytes32(uint256(1));
        
        vm.startPrank(user1);
        bytes32 commitment = registrar.createCommitment(LABEL, user1, resolver, DURATION, secret);
        registrar.commit(commitment);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 60);
        
        vm.startPrank(user1);
        
        uint256 balanceBefore = user1.balance;
        
        vm.expectEmit(true, true, false, true);
        emit ECSRegistrar.NameRegistered(LABEL, user1, price, block.timestamp + DURATION);
        
        registrar.register{value: price}(LABEL, user1, resolver, DURATION, secret);
        
        uint256 balanceAfter = user1.balance;
        
        vm.stopPrank();
        
        assertEq(balanceBefore - balanceAfter, price);
        assertEq(registry.owner(labelhash), user1);
        assertEq(registry.resolver(labelhash), resolver);
        assertEq(registry.getExpiration(labelhash), block.timestamp + DURATION);
    }
    
    function test_007____register____________________RefundsExcessEth() public {
        uint256 price = registrar.rentPrice(LABEL, DURATION);
        uint256 excess = 1 ether;
        bytes32 secret = bytes32(uint256(1));
        
        vm.startPrank(user1);
        bytes32 commitment = registrar.createCommitment(LABEL, user1, resolver, DURATION, secret);
        registrar.commit(commitment);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 60);
        
        vm.startPrank(user1);
        uint256 balanceBefore = user1.balance;
        
        registrar.register{value: price + excess}(LABEL, user1, resolver, DURATION, secret);
        
        uint256 balanceAfter = user1.balance;
        vm.stopPrank();
        
        assertEq(balanceBefore - balanceAfter, price); // Only price should be deducted
    }
    
    function test_008____register____________________RevertsInsufficientValue() public {
        uint256 price = registrar.rentPrice(LABEL, DURATION);
        bytes32 secret = bytes32(uint256(1));
        
        vm.startPrank(user1);
        bytes32 commitment = registrar.createCommitment(LABEL, user1, resolver, DURATION, secret);
        registrar.commit(commitment);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 60);
        
        vm.startPrank(user1);
        vm.expectRevert(InsufficientValue.selector);
        registrar.register{value: price - 1}(LABEL, user1, resolver, DURATION, secret);
        vm.stopPrank();
    }
    
    function test_009____register____________________RevertsInvalidDuration() public {
        uint256 price = registrar.rentPrice(LABEL, 10 seconds); // below min duration
        bytes32 secret = bytes32(uint256(1));
        
        vm.startPrank(user1);
        bytes32 commitment = registrar.createCommitment(LABEL, user1, resolver, 10 seconds, secret);
        registrar.commit(commitment);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 60);
        
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(InvalidDuration.selector, 10 seconds));
        registrar.register{value: price}(LABEL, user1, resolver, 10 seconds, secret);
        vm.stopPrank();
    }
    
    /* --- Renewal Tests --- */
    
    function test_010____renew_______________________RenewsNameSuccessfully() public {
        // Register first
        uint256 registerPrice = registrar.rentPrice(LABEL, DURATION);
        bytes32 secret = bytes32(uint256(1));
        
        vm.startPrank(user1);
        bytes32 commitment = registrar.createCommitment(LABEL, user1, resolver, DURATION, secret);
        registrar.commit(commitment);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 60);
        
        vm.prank(user1);
        registrar.register{value: registerPrice}(LABEL, user1, resolver, DURATION, secret);
        
        uint256 renewPrice = registrar.rentPrice(LABEL, DURATION);
        uint256 initialExpiration = registry.getExpiration(keccak256(bytes(LABEL)));
        
        vm.startPrank(user1);
        
        vm.expectEmit(true, false, false, true);
        emit ECSRegistrar.NameRenewed(LABEL, renewPrice, initialExpiration + DURATION);
        
        // Wait a bit to ensure timestamp difference
        vm.warp(block.timestamp + 1000);
        
        uint256 expectedNewExpiration = initialExpiration + DURATION;
        
        registrar.renew{value: renewPrice}(LABEL, DURATION);
        
        vm.stopPrank();
        
        assertEq(registry.getExpiration(keccak256(bytes(LABEL))), expectedNewExpiration);
    }
    
    function test_011____renew_______________________RevertsIfExpired() public {
         // Register first
        uint256 registerPrice = registrar.rentPrice(LABEL, DURATION);
        bytes32 secret = bytes32(uint256(1));
        
        vm.startPrank(user1);
        bytes32 commitment = registrar.createCommitment(LABEL, user1, resolver, DURATION, secret);
        registrar.commit(commitment);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 60);
        
        vm.prank(user1);
        registrar.register{value: registerPrice}(LABEL, user1, resolver, DURATION, secret);
        
        uint256 expiration = registry.getExpiration(keccak256(bytes(LABEL)));
        vm.warp(expiration + 1);
        
        uint256 renewPrice = registrar.rentPrice(LABEL, DURATION);
        
        vm.startPrank(user1);
        vm.expectRevert("Name is expired");
        registrar.renew{value: renewPrice}(LABEL, DURATION);
        vm.stopPrank();
    }

    /* --- Withdrawal Tests --- */
    
    function test_012____withdraw____________________AdminCanWithdraw() public {
        uint256 price = registrar.rentPrice(LABEL, DURATION);
        bytes32 secret = bytes32(uint256(1));
        
        vm.startPrank(user1);
        bytes32 commitment = registrar.createCommitment(LABEL, user1, resolver, DURATION, secret);
        registrar.commit(commitment);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 60);
        
        vm.prank(user1);
        registrar.register{value: price}(LABEL, user1, resolver, DURATION, secret);
        
        uint256 balanceBefore = admin.balance;
        
        vm.startPrank(admin);
        registrar.withdrawAll();
        vm.stopPrank();
        
        uint256 balanceAfter = admin.balance;
        assertEq(balanceAfter - balanceBefore, price);
        assertEq(address(registrar).balance, 0);
    }
}

