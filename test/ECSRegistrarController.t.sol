// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/ECSRegistry.sol";
import "../src/ECSRegistrarController.sol";
import "../src/RootController.sol";
import "../src/utils/NameCoder.sol";

contract ECSRegistrarControllerTest is Test {
    ECSRegistry public registry;
    ECSRegistrarController public controller;
    RootController public rootController;
    
    /* --- Constants --- */
    
    bytes32 private constant ROOT_NAMESPACE = bytes32(0);
    uint256 private constant REGISTRATION_DURATION = 365 days;
    uint256 private constant SHORT_DURATION = 31 days;
    uint256 private constant LONG_DURATION = 3 * 365 days;
    uint256 private constant TEST_EXPIRATION = 365 days;
    
    /* --- Test Accounts --- */
    
    address admin = address(0x1001);
    address user1 = address(0x1002);
    address user2 = address(0x1003);
    address operator1 = address(0x1004);
    
    /* --- Domain Variables --- */
    
    bytes32 public ethNode;
    bytes32 public baseNode;
    
    /* --- Setup --- */
    
    function setUp() public {
        // create a block timestamp of 1000000000
        vm.warp(1000000000);
        
        // Calculate node hashes using NameCoder for consistency
        ethNode = NameCoder.namehash(NameCoder.encode("eth"), 0);
        baseNode = NameCoder.namehash(NameCoder.encode("ecs.eth"), 0);
        
        // Deploy contracts
        vm.startPrank(admin);
        registry = new ECSRegistry();
        rootController = new RootController(registry);
        
        // Set up domain structure using NameCoder consistently
        registry.setApprovalForNamespace(ROOT_NAMESPACE, address(rootController), true);
        rootController.setSubnameOwner("eth", admin);
        registry.setSubnameOwner("ecs", "eth", admin, block.timestamp + REGISTRATION_DURATION, false);

        registry.grantRole(registry.CONTROLLER_ROLE(), admin);

        // Set the expiration for both the eth node and the ecs node
        registry.setExpiration(ethNode, block.timestamp + REGISTRATION_DURATION);
        registry.setExpiration(baseNode, block.timestamp + REGISTRATION_DURATION);
        
        // Deploy controller
        string memory baseDomain = "ecs.eth";
        controller = new ECSRegistrarController(registry, baseDomain);
        
        // Set up roles
        registry.grantRole(registry.CONTROLLER_ROLE(), address(controller));
        
        // Approve controller to create subnamespaces under ecs.eth
        registry.setApprovalForNamespace(baseNode, address(controller), true);
        
        vm.stopPrank();
        
        // Fund test accounts
        vm.deal(admin, 10 ether);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }
    
    /* --- Test Dividers --- */
    
    function test1000________________________________________________________________________________() public pure {}
    function test1100_________________ECS_REGISTRAR_CONTROLLER_TESTS_____________________________() public pure {}
    function test1200________________________________________________________________________________() public pure {}
    
    /* --- Constructor Tests --- */
    
    function test_001____constructor_________________InitializesCorrectly() public view {
        assertEq(address(controller.registry()), address(registry));
        assertEq(controller.baseDomain(), "ecs.eth");
        assertTrue(controller.hasRole(controller.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(controller.hasRole(controller.ADMIN_ROLE(), admin));
    }
    
    function test_002____constructor_________________SetsDefaultValues() public view {
        assertEq(controller.feePerSecond(), 1 wei);
        assertEq(controller.MINIMUM_REGISTRATION_DURATION(), 30 days);
        assertEq(controller.MAXIMUM_REGISTRATION_DURATION(), 10 * 365 days);
        assertEq(controller.minLabelLength(), 3);
        assertEq(controller.maxLabelLength(), 63);
    }
    
    /* --- registerNamespace Tests --- */
    
    function test_003____registerNamespace___________RegistersNamespaceSuccessfully() public {
        uint256 expectedFee = controller.calculateFee(REGISTRATION_DURATION);
        
        // Calculate the expected namespace hash
        bytes memory fullDomain = NameCoder.encode("myapp.ecs.eth");
        bytes32 expectedNamespace = NameCoder.namehash(fullDomain, 0);
        
        vm.startPrank(user1);
        
        vm.expectEmit(true, true, true, true);
        emit ECSRegistrarController.NamespaceRegistered("myapp", expectedNamespace, user1, REGISTRATION_DURATION);
        
        // Register namespace
        bytes32 namespace = controller.registerNamespace{value: expectedFee}("myapp", REGISTRATION_DURATION);
        
        vm.stopPrank();
        
        // Verify namespace was registered
        assertEq(namespace, expectedNamespace);
        assertEq(registry.owner(namespace), user1);
        assertFalse(registry.isExpired(namespace));
        
        // Check expiration time
        uint256 expirationTime = registry.getExpiration(namespace);
        assertEq(expirationTime, block.timestamp + REGISTRATION_DURATION);
    }
    
    function test_004____registerNamespace___________ChargesCorrectFee() public {
        uint256 expectedFee = controller.calculateFee(REGISTRATION_DURATION);
        uint256 initialBalance = user1.balance;
        
        vm.startPrank(user1);
        controller.registerNamespace{value: expectedFee}("myapp", REGISTRATION_DURATION);
        vm.stopPrank();
        
        // Check fee was charged
        assertEq(user1.balance, initialBalance - expectedFee);
        assertEq(address(controller).balance, expectedFee);
    }
    
    function test_005____registerNamespace___________AcceptsExcessPayment() public {
        uint256 expectedFee = controller.calculateFee(REGISTRATION_DURATION);
        uint256 overpayment = 0.1 ether;
        uint256 totalSent = expectedFee + overpayment;
        uint256 initialBalance = user1.balance;
        
        vm.startPrank(user1);
        controller.registerNamespace{value: totalSent}("myapp", REGISTRATION_DURATION);
        vm.stopPrank();
        
        // Check full amount was charged (no refund in current implementation)
        assertEq(user1.balance, initialBalance - totalSent);
        assertEq(address(controller).balance, totalSent);
    }
    
    function test_006____registerNamespace___________RevertsOnInsufficientPayment() public {
        uint256 expectedFee = controller.calculateFee(REGISTRATION_DURATION);
        uint256 insufficientPayment = expectedFee - 1;
        
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ECSRegistrarController.InsufficientFee.selector,
                expectedFee,
                insufficientPayment
            )
        );
        controller.registerNamespace{value: insufficientPayment}("myapp", REGISTRATION_DURATION);
        vm.stopPrank();
    }
    
    function test_007____registerNamespace___________RevertsOnInvalidDuration() public {
        uint256 tooShort = 1 days;
        uint256 tooLong = 20 * 365 days;
        
        vm.startPrank(user1);
        
        // Too short
        vm.expectRevert(
            abi.encodeWithSelector(
                ECSRegistrarController.InvalidDuration.selector,
                tooShort
            )
        );
        controller.registerNamespace{value: 1 ether}("myapp", tooShort);
        
        // Too long
        vm.expectRevert(
            abi.encodeWithSelector(
                ECSRegistrarController.InvalidDuration.selector,
                tooLong
            )
        );
        controller.registerNamespace{value: 1 ether}("myapp", tooLong);
        
        vm.stopPrank();
    }
    
    function test_008____registerNamespace___________RevertsOnInvalidName() public {
        uint256 fee = controller.calculateFee(REGISTRATION_DURATION);
        
        vm.startPrank(user1);
        
        // Empty name
        vm.expectRevert(
            abi.encodeWithSelector(
                ECSRegistrarController.InvalidName.selector,
                ""
            )
        );
        controller.registerNamespace{value: fee}("", REGISTRATION_DURATION);
        
        // Name with invalid characters
        vm.expectRevert(
            abi.encodeWithSelector(
                ECSRegistrarController.InvalidName.selector,
                "invalid!"
            )
        );
        controller.registerNamespace{value: fee}("invalid!", REGISTRATION_DURATION);
        
        vm.stopPrank();
    }
    
    function test_009____registerNamespace___________AllowsRegistrationAfterExpiration() public {
        uint256 fee = controller.calculateFee(SHORT_DURATION);
        
        // Register namespace with short duration
        vm.startPrank(user1);
        bytes32 namespace = controller.registerNamespace{value: fee}("myapp", SHORT_DURATION);
        vm.stopPrank();
        
        // Fast forward past expiration
        vm.warp(block.timestamp + SHORT_DURATION + 1);
        
        // Register same namespace with different user
        vm.startPrank(user2);
        bytes32 namespace2 = controller.registerNamespace{value: fee}("myapp", SHORT_DURATION);
        vm.stopPrank();
        
        // Should be the same namespace hash
        assertEq(namespace, namespace2);
        assertEq(registry.owner(namespace), user2);
    }
    
    function test_010____registerNamespace___________HandlesMultipleNamespaces() public {
        uint256 fee = controller.calculateFee(REGISTRATION_DURATION);
        
        vm.startPrank(user1);
        
        // Register multiple namespaces
        bytes32 namespace1 = controller.registerNamespace{value: fee}("myapp", REGISTRATION_DURATION);
        bytes32 namespace2 = controller.registerNamespace{value: fee}("webapp", REGISTRATION_DURATION);
        bytes32 namespace3 = controller.registerNamespace{value: fee}("api", REGISTRATION_DURATION);
        
        vm.stopPrank();
        
        // Verify all namespaces are registered
        assertEq(registry.owner(namespace1), user1);
        assertEq(registry.owner(namespace2), user1);
        assertEq(registry.owner(namespace3), user1);
        
        assertFalse(registry.isExpired(namespace1));
        assertFalse(registry.isExpired(namespace2));
        assertFalse(registry.isExpired(namespace3));
    }
    
    /* --- renewNamespace Tests --- */
    
    function test_011____renewNamespace______________RenewsNamespaceSuccessfully() public {
        uint256 initialFee = controller.calculateFee(REGISTRATION_DURATION);
        uint256 renewalFee = controller.calculateFee(REGISTRATION_DURATION);
        
        // Register namespace
        vm.startPrank(user1);
        bytes32 namespace = controller.registerNamespace{value: initialFee}("myapp", REGISTRATION_DURATION);
        vm.stopPrank();
        
        uint256 initialExpiration = registry.getExpiration(namespace);
        
        // Renew namespace
        vm.startPrank(user1);
        
        vm.expectEmit(true, true, true, true);
        emit ECSRegistrarController.NamespaceRenewed(namespace, user1, REGISTRATION_DURATION);
        
        controller.renewNamespace{value: renewalFee}(namespace, REGISTRATION_DURATION);
        vm.stopPrank();
        
        // Check expiration was extended
        uint256 newExpiration = registry.getExpiration(namespace);
        assertEq(newExpiration, initialExpiration + REGISTRATION_DURATION);
        
        // Verify still owned by same user
        assertEq(registry.owner(namespace), user1);
    }
    
    function test_012____renewNamespace______________ChargesCorrectFee() public {
        uint256 initialFee = controller.calculateFee(REGISTRATION_DURATION);
        uint256 renewalFee = controller.calculateFee(LONG_DURATION);
        
        // Register namespace
        vm.startPrank(user1);
        bytes32 namespace = controller.registerNamespace{value: initialFee}("myapp", REGISTRATION_DURATION);
        vm.stopPrank();
        
        uint256 balanceBeforeRenewal = user1.balance;
        
        // Renew namespace with different duration
        vm.startPrank(user1);
        controller.renewNamespace{value: renewalFee}(namespace, LONG_DURATION);
        vm.stopPrank();
        
        // Check renewal fee was charged
        assertEq(user1.balance, balanceBeforeRenewal - renewalFee);
        assertEq(address(controller).balance, initialFee + renewalFee);
    }
    
    function test_013____renewNamespace______________RenewsBeforeExpirationSuccessfully() public {
        uint256 fee = controller.calculateFee(SHORT_DURATION);
        
        // Register namespace with short duration
        vm.startPrank(user1);
        bytes32 namespace = controller.registerNamespace{value: fee}("myapp", SHORT_DURATION);
        vm.stopPrank();
        
        uint256 initialExpiration = registry.getExpiration(namespace);
        
        // Fast forward to near expiration but not expired yet (1 day before expiration)
        vm.warp(block.timestamp + SHORT_DURATION - 1 days);
        
        // Verify namespace is not yet expired
        assertFalse(registry.isExpired(namespace));
        
        // Renew namespace before expiration should succeed
        uint256 renewalFee = controller.calculateFee(REGISTRATION_DURATION);
        vm.startPrank(user1);
        
        vm.expectEmit(true, true, true, true);
        emit ECSRegistrarController.NamespaceRenewed(namespace, user1, REGISTRATION_DURATION);
        
        controller.renewNamespace{value: renewalFee}(namespace, REGISTRATION_DURATION);
        vm.stopPrank();
        
        // Verify renewal worked - expiration should be extended from the original expiration time
        uint256 newExpiration = registry.getExpiration(namespace);
        assertEq(newExpiration, initialExpiration + REGISTRATION_DURATION);
        assertEq(registry.owner(namespace), user1);
        assertFalse(registry.isExpired(namespace));
    }
    
    function test_014____renewNamespace______________RevertsOnExpiredNamespace() public {
        uint256 fee = controller.calculateFee(SHORT_DURATION);
        
        // Register namespace with short duration
        vm.startPrank(user1);
        bytes32 namespace = controller.registerNamespace{value: fee}("myapp", SHORT_DURATION);
        vm.stopPrank();
        
        // Fast forward past expiration
        vm.warp(block.timestamp + SHORT_DURATION + 1);
        
        // Verify namespace is expired
        assertTrue(registry.isExpired(namespace));
        
        // Try to renew expired namespace - should fail
        uint256 renewalFee = controller.calculateFee(REGISTRATION_DURATION);
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ECSRegistrarController.NamespaceExpired.selector,
                namespace
            )
        );
        controller.renewNamespace{value: renewalFee}(namespace, REGISTRATION_DURATION);
        vm.stopPrank();
    }
    
    function test_015____renewNamespace______________RevertsOnUnauthorizedRenewal() public {
        uint256 fee = controller.calculateFee(REGISTRATION_DURATION);
        
        // Register namespace with user1
        vm.startPrank(user1);
        bytes32 namespace = controller.registerNamespace{value: fee}("myapp", REGISTRATION_DURATION);
        vm.stopPrank();
        
        // Try to renew with different user
        vm.startPrank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                ECSRegistrarController.UnauthorizedAccess.selector,
                user2,
                namespace
            )
        );
        controller.renewNamespace{value: fee}(namespace, REGISTRATION_DURATION);
        vm.stopPrank();
    }
    
    /* --- calculateFee Tests --- */
    
    function test_018____calculateFee________________ReturnsCorrectFeeForVariousDurations() public view {
        uint256 feePerSecond = controller.feePerSecond();
        
        // Test various durations
        assertEq(controller.calculateFee(365 days), feePerSecond * 365 days);
        assertEq(controller.calculateFee(30 days), feePerSecond * 30 days);
        assertEq(controller.calculateFee(1 days), feePerSecond * 1 days);
        assertEq(controller.calculateFee(3600), feePerSecond * 3600); // 1 hour
    }
    
    function test_018____calculateFee________________HandlesEdgeCases() public view {
        uint256 feePerSecond = controller.feePerSecond();
        
        // Test edge cases
        assertEq(controller.calculateFee(1), feePerSecond);
        assertEq(controller.calculateFee(0), 0);
        assertEq(controller.calculateFee(10 * 365 days), feePerSecond * 10 * 365 days);
    }
    
    function test_018____calculateFee________________HandlesFreeRegistrations() public {
        // Update fee to zero
        vm.startPrank(admin);
        controller.updateFeePerSecond(0);
        vm.stopPrank();
        
        // All durations should be free
        assertEq(controller.calculateFee(1 days), 0);
        assertEq(controller.calculateFee(365 days), 0);
        assertEq(controller.calculateFee(10 * 365 days), 0);
        
        // Test registration works with zero fee
        vm.startPrank(user1);
        bytes32 namespace = controller.registerNamespace{value: 0}("myapp", REGISTRATION_DURATION);
        vm.stopPrank();
        
        assertEq(registry.owner(namespace), user1);
    }
    
    /* --- isNamespaceAvailable Tests --- */
    
    function test_021____isNamespaceAvailable________ReturnsTrueForAvailableNamespace() public view {
        assertTrue(controller.isNamespaceAvailable("available"));
        assertTrue(controller.isNamespaceAvailable("another"));
    }
    
    function test_021____isNamespaceAvailable________ReturnsFalseForRegisteredNamespace() public {
        uint256 fee = controller.calculateFee(REGISTRATION_DURATION);
        
        // Register namespace
        vm.startPrank(user1);
        controller.registerNamespace{value: fee}("myapp", REGISTRATION_DURATION);
        vm.stopPrank();
        
        // Should not be available
        assertFalse(controller.isNamespaceAvailable("myapp"));
    }
    
    function test_021____isNamespaceAvailable________ReturnsTrueForExpiredNamespace() public {
        uint256 fee = controller.calculateFee(SHORT_DURATION);
        
        // Register namespace with short duration
        vm.startPrank(user1);
        controller.registerNamespace{value: fee}("myapp", SHORT_DURATION);
        vm.stopPrank();
        
        // Fast forward past expiration
        vm.warp(block.timestamp + SHORT_DURATION + 1);
        
        // Should be available again
        assertTrue(controller.isNamespaceAvailable("myapp"));
    }
    
    /* --- Admin Function Tests --- */
    
    function test_023____updateFeePerSecond__________UpdatesFeeSuccessfully() public {
        uint256 newFee = 10 wei;
        
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit ECSRegistrarController.FeePerSecondUpdated(1 wei, newFee);
        controller.updateFeePerSecond(newFee);
        vm.stopPrank();
        
        assertEq(controller.feePerSecond(), newFee);
    }
    
    function test_023____updateFeePerSecond__________RevertsForNonAdmin() public {
        vm.startPrank(user1);
        vm.expectRevert();
        controller.updateFeePerSecond(10 wei);
        vm.stopPrank();
    }
    
    function test_024____updateMinLabelLength________UpdatesSuccessfully() public {
        uint256 newMinLength = 2;
        
        vm.startPrank(admin);
        controller.updateMinLabelLength(newMinLength);
        vm.stopPrank();
        
        assertEq(controller.minLabelLength(), newMinLength);
    }
    
    function test_025____updateMaxLabelLength________UpdatesSuccessfully() public {
        uint256 newMaxLength = 100;
        
        vm.startPrank(admin);
        controller.updateMaxLabelLength(newMaxLength);
        vm.stopPrank();
        
        assertEq(controller.maxLabelLength(), newMaxLength);
    }
    
    function test_026____updateLabelLength___________RevertsForNonAdmin() public {
        vm.startPrank(user1);
        vm.expectRevert();
        controller.updateMinLabelLength(2);
        vm.stopPrank();
        
        vm.startPrank(user1);
        vm.expectRevert();
        controller.updateMaxLabelLength(100);
        vm.stopPrank();
    }
    
    function test_028____withdrawFees________________WithdrawsFeesSuccessfully() public {
        uint256 fee = controller.calculateFee(REGISTRATION_DURATION);
        
        // Register namespace to generate fees
        vm.startPrank(user1);
        controller.registerNamespace{value: fee}("myapp", REGISTRATION_DURATION);
        vm.stopPrank();
        
        uint256 initialBalance = admin.balance;
        
        // Withdraw fees
        vm.startPrank(admin);
        controller.withdrawFees();
        vm.stopPrank();
        
        assertEq(admin.balance, initialBalance + fee);
        assertEq(address(controller).balance, 0);
    }
    
    function test_028____withdrawFees________________RevertsForNonAdmin() public {
        vm.startPrank(user1);
        vm.expectRevert();
        controller.withdrawFees();
        vm.stopPrank();
    }
    
    /* --- Protected Namespace Tests --- */
    
    function test_039____protectedNamespace__________RegistersProtectedNamespaceSuccessfully() public {
        uint256 fee = controller.calculateFee(REGISTRATION_DURATION);
        
        vm.startPrank(user1);
        bytes32 namespace = controller.registerNamespace{value: fee}("protected-app", REGISTRATION_DURATION);
        vm.stopPrank();
        
        // Verify namespace was registered and is protected
        assertEq(registry.owner(namespace), user1);
        assertFalse(registry.isExpired(namespace));
        assertTrue(registry.isProtected(namespace));
    }
    
    function test_039____protectedNamespace__________PreventsReregistrationWhenActive() public {
        uint256 fee = controller.calculateFee(REGISTRATION_DURATION);
        
        // Register protected namespace with user1
        vm.startPrank(user1);
        bytes32 namespace = controller.registerNamespace{value: fee}("protected-app", REGISTRATION_DURATION);
        vm.stopPrank();
        
        // Try to register same namespace with user2 - should fail
        vm.startPrank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                ECSRegistry.ProtectedNamespace.selector,
                namespace
            )
        );
        controller.registerNamespace{value: fee}("protected-app", REGISTRATION_DURATION);
        vm.stopPrank();
        
        // Verify original owner unchanged
        assertEq(registry.owner(namespace), user1);
    }
    
    function test_039____protectedNamespace__________PreventsReregistrationByOriginalOwner() public {
        uint256 fee = controller.calculateFee(REGISTRATION_DURATION);
        
        // Register protected namespace
        vm.startPrank(user1);
        bytes32 namespace = controller.registerNamespace{value: fee}("protected-app", REGISTRATION_DURATION);
        vm.stopPrank();
        
        // Try to register same namespace again with same user - should still fail
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ECSRegistry.ProtectedNamespace.selector,
                namespace
            )
        );
        controller.registerNamespace{value: fee}("protected-app", REGISTRATION_DURATION);
        vm.stopPrank();
    }
    
    function test_039____protectedNamespace__________AllowsReregistrationAfterExpiration() public {
        uint256 fee = controller.calculateFee(SHORT_DURATION);
        
        // Register protected namespace with short duration
        vm.startPrank(user1);
        bytes32 namespace = controller.registerNamespace{value: fee}("protected-app", SHORT_DURATION);
        vm.stopPrank();
        
        // Fast forward past expiration
        vm.warp(block.timestamp + SHORT_DURATION + 1);
        
        // Verify namespace is expired but still protected
        assertTrue(registry.isExpired(namespace));
        assertTrue(registry.isProtected(namespace));
        
        // Register same namespace after expiration - should succeed because it's expired
        vm.startPrank(user2);
        bytes32 newNamespace = controller.registerNamespace{value: fee}("protected-app", SHORT_DURATION);
        vm.stopPrank();
        
        // Verify new registration succeeded and owner changed
        assertEq(namespace, newNamespace); // Same namespace hash
        assertEq(registry.owner(namespace), user2); // New owner
        assertTrue(registry.isProtected(namespace)); // Still protected
        assertFalse(registry.isExpired(namespace)); // No longer expired
    }
    
    function test_039____protectedNamespace__________AllowsRenewalOfProtectedNamespace() public {
        uint256 registrationFee = controller.calculateFee(REGISTRATION_DURATION);
        uint256 renewalFee = controller.calculateFee(REGISTRATION_DURATION);
        
        // Register protected namespace
        vm.startPrank(user1);
        bytes32 namespace = controller.registerNamespace{value: registrationFee}("protected-app", REGISTRATION_DURATION);
        vm.stopPrank();
        
        uint256 initialExpiration = registry.getExpiration(namespace);
        
        // Renew protected namespace should work
        vm.startPrank(user1);
        vm.expectEmit(true, true, true, true);
        emit ECSRegistrarController.NamespaceRenewed(namespace, user1, REGISTRATION_DURATION);
        
        controller.renewNamespace{value: renewalFee}(namespace, REGISTRATION_DURATION);
        vm.stopPrank();
        
        // Verify renewal worked and namespace is still protected
        uint256 newExpiration = registry.getExpiration(namespace);
        assertEq(newExpiration, initialExpiration + REGISTRATION_DURATION);
        assertEq(registry.owner(namespace), user1);
        assertTrue(registry.isProtected(namespace));
        assertFalse(registry.isExpired(namespace));
    }
    
    function test_039____protectedNamespace__________RevertsRenewalWhenExpired() public {
        uint256 registrationFee = controller.calculateFee(SHORT_DURATION);
        uint256 renewalFee = controller.calculateFee(REGISTRATION_DURATION);
        
        // Register protected namespace with short duration
        vm.startPrank(user1);
        bytes32 namespace = controller.registerNamespace{value: registrationFee}("protected-app", SHORT_DURATION);
        vm.stopPrank();
        
        // Fast forward past expiration
        vm.warp(block.timestamp + SHORT_DURATION + 1);
        
        // Verify namespace is expired but still protected
        assertTrue(registry.isExpired(namespace));
        assertTrue(registry.isProtected(namespace));
        
        // Try to renew expired protected namespace - should fail
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ECSRegistrarController.NamespaceExpired.selector,
                namespace
            )
        );
        controller.renewNamespace{value: renewalFee}(namespace, REGISTRATION_DURATION);
        vm.stopPrank();
        
        // Verify namespace is still expired and protected
        assertTrue(registry.isExpired(namespace));
        assertTrue(registry.isProtected(namespace));
        assertEq(registry.owner(namespace), user1);
    }
    
    function test_040____protectedNamespace__________MultipleProtectedNamespacesWork() public {
        uint256 fee = controller.calculateFee(REGISTRATION_DURATION);
        
        // Register multiple protected namespaces
        vm.startPrank(user1);
        bytes32 namespace1 = controller.registerNamespace{value: fee}("protected-app1", REGISTRATION_DURATION);
        bytes32 namespace2 = controller.registerNamespace{value: fee}("protected-app2", REGISTRATION_DURATION);
        vm.stopPrank();
        
        vm.startPrank(user2);
        bytes32 namespace3 = controller.registerNamespace{value: fee}("protected-app3", REGISTRATION_DURATION);
        vm.stopPrank();
        
        // Verify all are protected and owned correctly
        assertTrue(registry.isProtected(namespace1));
        assertTrue(registry.isProtected(namespace2));
        assertTrue(registry.isProtected(namespace3));
        
        assertEq(registry.owner(namespace1), user1);
        assertEq(registry.owner(namespace2), user1);
        assertEq(registry.owner(namespace3), user2);
        
        // Try to reregister any of them - should all fail
        vm.startPrank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                ECSRegistry.ProtectedNamespace.selector,
                namespace1
            )
        );
        controller.registerNamespace{value: fee}("protected-app1", REGISTRATION_DURATION);
        vm.stopPrank();
        
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ECSRegistry.ProtectedNamespace.selector,
                namespace3
            )
        );
        controller.registerNamespace{value: fee}("protected-app3", REGISTRATION_DURATION);
        vm.stopPrank();
    }
    
    function test_041____protectedNamespace__________IsNamespaceAvailableReturnsFalseWhenActiveButTrueWhenExpired() public {
        uint256 fee = controller.calculateFee(SHORT_DURATION);
        
        // Register protected namespace
        vm.startPrank(user1);
        controller.registerNamespace{value: fee}("protected-app", SHORT_DURATION);
        vm.stopPrank();
        
        // Should not be available when active (even though it's protected)
        assertFalse(controller.isNamespaceAvailable("protected-app"));
        
        // Fast forward past expiration
        vm.warp(block.timestamp + SHORT_DURATION + 1);
        
        // Should be available when expired (even though it's protected)
        assertTrue(controller.isNamespaceAvailable("protected-app"));
    }

    /* --- Complex Integration Tests --- */
    
    function test_029____fullNamespaceLifecycle_____RegisterRenewAndExpire() public {
        uint256 initialFee = controller.calculateFee(SHORT_DURATION);
        uint256 renewalFee = controller.calculateFee(SHORT_DURATION);
        
        // Register namespace
        vm.startPrank(user1);
        bytes32 namespace = controller.registerNamespace{value: initialFee}("myapp", SHORT_DURATION);
        vm.stopPrank();
        
        // Verify active
        assertFalse(registry.isExpired(namespace));
        assertEq(registry.owner(namespace), user1);
        
        // Renew before expiration
        vm.startPrank(user1);
        controller.renewNamespace{value: renewalFee}(namespace, SHORT_DURATION);
        vm.stopPrank();
        
        // Verify still active
        assertFalse(registry.isExpired(namespace));
        
        // Fast forward past expiration
        vm.warp(block.timestamp + SHORT_DURATION * 2 + 1);
        
        // Verify expired
        assertTrue(registry.isExpired(namespace));
        
        // Register same namespace with different user
        vm.startPrank(user2);
        bytes32 namespace2 = controller.registerNamespace{value: initialFee}("myapp", SHORT_DURATION);
        vm.stopPrank();
        
        // Verify new owner
        assertEq(namespace, namespace2);
        assertEq(registry.owner(namespace), user2);
    }
    
    function test_030____feeManagement_______________UpdateFeesAndTestCalculations() public {
        uint256 newFee = 100 wei;
        
        // Update fee
        vm.startPrank(admin);
        controller.updateFeePerSecond(newFee);
        vm.stopPrank();
        
        // Test fee calculation with new fee
        uint256 calculatedFee = controller.calculateFee(REGISTRATION_DURATION);
        assertEq(calculatedFee, newFee * REGISTRATION_DURATION);
        
        // Register namespace with new fee
        vm.startPrank(user1);
        controller.registerNamespace{value: calculatedFee}("myapp", REGISTRATION_DURATION);
        vm.stopPrank();
        
        // Verify correct fee was charged
        assertEq(address(controller).balance, calculatedFee);
    }
    
    function test_031____multipleUsersAndNamespaces_ManagesComplexScenarios() public {
        uint256 fee = controller.calculateFee(REGISTRATION_DURATION);
        
        // Multiple users register different namespaces
        vm.startPrank(user1);
        bytes32 namespace1 = controller.registerNamespace{value: fee}("myapp", REGISTRATION_DURATION);
        bytes32 namespace2 = controller.registerNamespace{value: fee}("webapp", REGISTRATION_DURATION);
        vm.stopPrank();
        
        vm.startPrank(user2);
        bytes32 namespace3 = controller.registerNamespace{value: fee}("api", REGISTRATION_DURATION);
        vm.stopPrank();
        
        // Verify ownership
        assertEq(registry.owner(namespace1), user1);
        assertEq(registry.owner(namespace2), user1);
        assertEq(registry.owner(namespace3), user2);
        
        // Renew one namespace
        vm.startPrank(user1);
        controller.renewNamespace{value: fee}(namespace1, REGISTRATION_DURATION);
        vm.stopPrank();
        
        // Verify all still active
        assertFalse(registry.isExpired(namespace1));
        assertFalse(registry.isExpired(namespace2));
        assertFalse(registry.isExpired(namespace3));
        
        // Verify total fees collected
        assertEq(address(controller).balance, fee * 4); // 3 registrations + 1 renewal
    }
} 