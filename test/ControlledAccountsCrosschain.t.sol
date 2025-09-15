// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/credentials/controlled-accounts/ControlledAccountsCrosschain.sol";

/**
 * @title ControlledAccountsCrosschainTest
 * @dev Test cross-chain functionality in ControlledAccountsCrosschain contract
 * 
 * This test verifies that the cross-chain functionality works correctly,
 * including chain-specific groups, cross-chain controller verification,
 * credential resolution with chain IDs, and proper event emission.
 */
contract ControlledAccountsCrosschainTest is Test {
    
    /* --- State Variables --- */
    
    ControlledAccountsCrosschain public controlledAccounts;
    
    /* --- Test Addresses --- */
    
    address constant CONTROLLER1 = address(0x1111111111111111111111111111111111111111);
    address constant CONTROLLER2 = address(0x2222222222222222222222222222222222222222);
    address constant CONTROLLED1 = address(0x3333333333333333333333333333333333333333);
    address constant CONTROLLED2 = address(0x4444444444444444444444444444444444444444);
    address constant CONTROLLED3 = address(0x5555555555555555555555555555555555555555);
    address constant CONTROLLED4 = address(0x6666666666666666666666666666666666666666);
    
    /* --- Test Chain IDs --- */
    
    uint256 constant SEPOLIA = 11155111;
    uint256 constant BASE_SEPOLIA = 84532;
    uint256 constant POLYGON_MUMBAI = 80001;
    uint256 constant ARBITRUM_SEPOLIA = 421614;
    
    /* --- Test Group IDs --- */
    
    bytes32 constant FAMILY_GROUP = keccak256(bytes("family"));
    bytes32 constant WORK_GROUP = keccak256(bytes("work"));
    bytes32 constant FRIENDS_GROUP = keccak256(bytes("friends"));
    bytes32 constant PROJECT_GROUP = keccak256(bytes("project"));
    
    /* --- Setup --- */
    
    function setUp() public {
        controlledAccounts = new ControlledAccountsCrosschain();
        _setupTestData();
    }
    
    /* --- Test Data Setup --- */
    
    function _setupTestData() internal {
        // Controller1 sets up accounts in different groups on different chains
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(SEPOLIA, FAMILY_GROUP, CONTROLLED1);
        
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(SEPOLIA, FAMILY_GROUP, CONTROLLED2);
        
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(BASE_SEPOLIA, WORK_GROUP, CONTROLLED2);
        
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(BASE_SEPOLIA, WORK_GROUP, CONTROLLED3);
        
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(POLYGON_MUMBAI, FRIENDS_GROUP, CONTROLLED1);
        
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(POLYGON_MUMBAI, FRIENDS_GROUP, CONTROLLED3);
        
        // Controller1 also has some accounts in default group on current chain
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(CONTROLLED4);
        
        // Controller2 sets up different groups on different chains
        vm.prank(CONTROLLER2);
        controlledAccounts.declareControlledAccount(ARBITRUM_SEPOLIA, PROJECT_GROUP, CONTROLLED1);
        
        vm.prank(CONTROLLER2);
        controlledAccounts.declareControlledAccount(ARBITRUM_SEPOLIA, PROJECT_GROUP, CONTROLLED4);
        
        // Some controlled accounts verify their controllers on different chains
        vm.prank(CONTROLLED1);
        controlledAccounts.setController(SEPOLIA, CONTROLLER1);
        
        vm.prank(CONTROLLED1);
        controlledAccounts.setController(BASE_SEPOLIA, CONTROLLER1);
        
        vm.prank(CONTROLLED2);
        controlledAccounts.setController(SEPOLIA, CONTROLLER1);
        
        vm.prank(CONTROLLED3);
        controlledAccounts.setController(BASE_SEPOLIA, CONTROLLER1);
        
        vm.prank(CONTROLLED4);
        controlledAccounts.setController(block.chainid, CONTROLLER1);
    }
    
    /* --- Cross-Chain Group Management Tests --- */
    
    function test_001____crossChainGroupManagement____AddAccountsToGroupsOnDifferentChains() public {
        // Verify family group on Sepolia
        address[] memory familyAccounts = controlledAccounts.getControlledAccounts(CONTROLLER1, SEPOLIA, FAMILY_GROUP);
        assertEq(familyAccounts.length, 2);
        assertEq(familyAccounts[0], CONTROLLED1);
        assertEq(familyAccounts[1], CONTROLLED2);
        
        // Verify work group on Base Sepolia
        address[] memory workAccounts = controlledAccounts.getControlledAccounts(CONTROLLER1, BASE_SEPOLIA, WORK_GROUP);
        assertEq(workAccounts.length, 2);
        assertEq(workAccounts[0], CONTROLLED2);
        assertEq(workAccounts[1], CONTROLLED3);
        
        // Verify friends group on Polygon Mumbai
        address[] memory friendsAccounts = controlledAccounts.getControlledAccounts(CONTROLLER1, POLYGON_MUMBAI, FRIENDS_GROUP);
        assertEq(friendsAccounts.length, 2);
        assertEq(friendsAccounts[0], CONTROLLED1);
        assertEq(friendsAccounts[1], CONTROLLED3);
        
        // Verify default group on current chain
        address[] memory defaultAccounts = controlledAccounts.getControlledAccounts(CONTROLLER1);
        assertEq(defaultAccounts.length, 1);
        assertEq(defaultAccounts[0], CONTROLLED4);
    }
    
    function test_002____crossChainGroupManagement____ChainIsolation() public {
        // Add same account to same group on different chains
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(SEPOLIA, FAMILY_GROUP, CONTROLLED4);
        
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(BASE_SEPOLIA, FAMILY_GROUP, CONTROLLED4);
        
        // Verify account exists in family group on both chains
        address[] memory ethereumFamily = controlledAccounts.getControlledAccounts(CONTROLLER1, SEPOLIA, FAMILY_GROUP);
        address[] memory baseFamily = controlledAccounts.getControlledAccounts(CONTROLLER1, BASE_SEPOLIA, FAMILY_GROUP);
        
        assertEq(ethereumFamily.length, 3); // CONTROLLED1, CONTROLLED2, CONTROLLED4
        assertEq(baseFamily.length, 1);     // CONTROLLED4
        
        // Remove from one chain only
        vm.prank(CONTROLLER1);
        controlledAccounts.removeControlledAccount(SEPOLIA, FAMILY_GROUP, CONTROLLED4);
        
        // Verify account removed from Ethereum but still on Base
        address[] memory ethereumFamilyAfter = controlledAccounts.getControlledAccounts(CONTROLLER1, SEPOLIA, FAMILY_GROUP);
        address[] memory baseFamilyAfter = controlledAccounts.getControlledAccounts(CONTROLLER1, BASE_SEPOLIA, FAMILY_GROUP);
        
        assertEq(ethereumFamilyAfter.length, 2); // Back to CONTROLLED1, CONTROLLED2
        assertEq(baseFamilyAfter.length, 1);     // Still CONTROLLED4
    }
    
    function test_003____crossChainGroupManagement____MultipleControllersWithCrossChainGroups() public {
        // Verify Controller2's project group on Arbitrum
        address[] memory projectAccounts = controlledAccounts.getControlledAccounts(CONTROLLER2, ARBITRUM_SEPOLIA, PROJECT_GROUP);
        assertEq(projectAccounts.length, 2);
        assertEq(projectAccounts[0], CONTROLLED1);
        assertEq(projectAccounts[1], CONTROLLED4);
        
        // Verify Controller2 has no default group accounts on current chain
        address[] memory defaultAccounts = controlledAccounts.getControlledAccounts(CONTROLLER2);
        assertEq(defaultAccounts.length, 0);
    }
    
    function test_004____crossChainGroupManagement____AddMultipleAccountsToCrossChainGroup() public {
        address[] memory newAccounts = new address[](2);
        newAccounts[0] = address(0x7777777777777777777777777777777777777777);
        newAccounts[1] = address(0x8888888888888888888888888888888888888888);
        
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccounts(SEPOLIA, FAMILY_GROUP, newAccounts);
        
        // Verify accounts were added to Ethereum family group
        address[] memory familyAccounts = controlledAccounts.getControlledAccounts(CONTROLLER1, SEPOLIA, FAMILY_GROUP);
        assertEq(familyAccounts.length, 4); // Original 2 + new 2
        assertEq(familyAccounts[2], address(0x7777777777777777777777777777777777777777));
        assertEq(familyAccounts[3], address(0x8888888888888888888888888888888888888888));
    }
    
    function test_005____crossChainGroupManagement____RemoveFromCrossChainGroup() public {
        // Remove CONTROLLED2 from family group on Ethereum
        vm.prank(CONTROLLER1);
        controlledAccounts.removeControlledAccount(SEPOLIA, FAMILY_GROUP, CONTROLLED2);
        
        // Verify removal from Ethereum
        address[] memory ethereumFamily = controlledAccounts.getControlledAccounts(CONTROLLER1, SEPOLIA, FAMILY_GROUP);
        assertEq(ethereumFamily.length, 1);
        assertEq(ethereumFamily[0], CONTROLLED1);
        
        // Verify CONTROLLED2 still exists in work group on Base
        address[] memory baseWork = controlledAccounts.getControlledAccounts(CONTROLLER1, BASE_SEPOLIA, WORK_GROUP);
        assertEq(baseWork.length, 2);
        assertEq(baseWork[0], CONTROLLED2);
        assertEq(baseWork[1], CONTROLLED3);
    }
    
    /* --- Cross-Chain Controller Verification Tests --- */
    
    function test_006____crossChainControllerVerification____SetControllerOnDifferentChains() public {
        // Set different controllers for same account on different chains
        vm.prank(CONTROLLED1);
        controlledAccounts.setController(SEPOLIA, CONTROLLER1);
        
        vm.prank(CONTROLLED1);
        controlledAccounts.setController(BASE_SEPOLIA, CONTROLLER2);
        
        // Verify different controllers on different chains
        bool ethereumController = controlledAccounts.isController(CONTROLLED1, SEPOLIA, CONTROLLER1);
        bool baseController = controlledAccounts.isController(CONTROLLED1, BASE_SEPOLIA, CONTROLLER2);
        
        assertTrue(ethereumController);
        assertTrue(baseController);
    }
    
    function test_007____crossChainControllerVerification____RemoveControllerFromSpecificChain() public {
        // Remove controller from specific chain
        vm.prank(CONTROLLED1);
        controlledAccounts.removeController(SEPOLIA, CONTROLLER1);
        
        // Verify controller removed from Ethereum but still exists on other chains
        bool ethereumController = controlledAccounts.isController(CONTROLLED1, SEPOLIA, CONTROLLER1);
        bool baseController = controlledAccounts.isController(CONTROLLED1, BASE_SEPOLIA, CONTROLLER1);
        
        assertFalse(ethereumController);
        assertTrue(baseController); // Still set from setup
    }
    
    /* --- Cross-Chain Credential Resolution Tests --- */
    
    function test_008____crossChainCredentialResolution____SepoliaFamilyGroupCredential() public {
        bytes memory identifier = _createAddressIdentifier(CONTROLLER1);
        
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts:11155111:family");
        
        string memory expected = string(abi.encodePacked(
            "0x3333333333333333333333333333333333333333\n",
            "0x4444444444444444444444444444444444444444"
        ));
        
        assertEq(result, expected);
    }
    
    function test_009____crossChainCredentialResolution____BaseSepoliaWorkGroupCredential() public {
        bytes memory identifier = _createAddressIdentifier(CONTROLLER1);
        
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts:84532:work");
        
        string memory expected = string(abi.encodePacked(
            "0x4444444444444444444444444444444444444444\n",
            "0x5555555555555555555555555555555555555555"
        ));
        
        assertEq(result, expected);
    }
    
    function test_010____crossChainCredentialResolution____PolygonMumbaiFriendsGroupCredential() public {
        bytes memory identifier = _createAddressIdentifier(CONTROLLER1);
        
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts:80001:friends");
        
        string memory expected = string(abi.encodePacked(
            "0x3333333333333333333333333333333333333333\n",
            "0x5555555555555555555555555555555555555555"
        ));
        
        assertEq(result, expected);
    }
    
    function test_011____crossChainCredentialResolution____ArbitrumSepoliaProjectGroupCredential() public {
        bytes memory identifier = _createAddressIdentifier(CONTROLLER2);
        
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts:421614:project");
        
        string memory expected = string(abi.encodePacked(
            "0x3333333333333333333333333333333333333333\n",
            "0x6666666666666666666666666666666666666666"
        ));
        
        assertEq(result, expected);
    }
    
    function test_012____crossChainCredentialResolution____CurrentChainDefaultGroupCredential() public {
        bytes memory identifier = _createAddressIdentifier(CONTROLLER1);
        
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts");
        
        string memory expected = "0x6666666666666666666666666666666666666666";
        
        assertEq(result, expected);
    }
    
    function test_013____crossChainCredentialResolution____ChainIdOnlyCredential() public {
        bytes memory identifier = _createAddressIdentifier(CONTROLLER1);
        
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts:11155111");
        
        // Chain ID 1 (Ethereum) has no accounts in default group, only in family group
        string memory expected = "";
        
        assertEq(result, expected);
    }
    
    function test_014____crossChainCredentialResolution____EmptyChainGroupReturnsEmpty() public {
        bytes memory identifier = _createAddressIdentifier(CONTROLLER1);
        
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts:9999:empty");
        
        assertEq(result, "");
    }
    
    function test_015____crossChainCredentialResolution____UnknownChainReturnsEmpty() public {
        bytes memory identifier = _createAddressIdentifier(CONTROLLER1);
        
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts:9999:family");
        
        assertEq(result, "");
    }
    
    /* --- Cross-Chain Event Tests --- */
    
    function test_016____crossChainEvents____DeclareControlledAccountInCrossChainGroup() public {
        vm.startPrank(CONTROLLER1);
        
        vm.expectEmit(true, true, true, true);
        address[] memory expectedAccounts = new address[](1);
        expectedAccounts[0] = address(0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa);
        emit ControlledAccountsCrosschain.ControlledAccountsDeclaredInGroup(CONTROLLER1, SEPOLIA, FAMILY_GROUP, expectedAccounts);
        
        controlledAccounts.declareControlledAccount(SEPOLIA, FAMILY_GROUP, address(0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa));
        
        vm.stopPrank();
    }
    
    function test_017____crossChainEvents____DeclareControlledAccountsInCrossChainGroup() public {
        address[] memory accounts = new address[](2);
        accounts[0] = address(0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB);
        accounts[1] = address(0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC);
        
        vm.startPrank(CONTROLLER1);
        
        vm.expectEmit(true, true, true, true);
        emit ControlledAccountsCrosschain.ControlledAccountsDeclaredInGroup(CONTROLLER1, BASE_SEPOLIA, WORK_GROUP, accounts);
        
        controlledAccounts.declareControlledAccounts(BASE_SEPOLIA, WORK_GROUP, accounts);
        
        vm.stopPrank();
    }
    
    function test_018____crossChainEvents____RemoveControlledAccountFromCrossChainGroup() public {
        // First add an account to remove
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(SEPOLIA, FAMILY_GROUP, address(0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd));
        
        // Then remove it
        vm.startPrank(CONTROLLER1);
        
        vm.expectEmit(true, true, true, false);
        emit ControlledAccountsCrosschain.ControlledAccountRemovedFromGroup(CONTROLLER1, SEPOLIA, FAMILY_GROUP, address(0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd));
        
        controlledAccounts.removeControlledAccount(SEPOLIA, FAMILY_GROUP, address(0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd));
        
        vm.stopPrank();
    }
    
    function test_019____crossChainEvents____SetCrossChainController() public {
        vm.startPrank(CONTROLLED1);
        
        vm.expectEmit(true, true, true, false);
        emit ControlledAccountsCrosschain.ControllerSet(CONTROLLED1, ARBITRUM_SEPOLIA, CONTROLLER2);
        
        controlledAccounts.setController(ARBITRUM_SEPOLIA, CONTROLLER2);
        
        vm.stopPrank();
    }
    
    /* --- Edge Cases --- */
    
    function test_020____edgeCases____EmptyChainIdInCredential() public {
        bytes memory identifier = _createAddressIdentifier(CONTROLLER1);
        
        // Test with empty chain ID after colon
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts::family");
        
        // Should treat as current chain since empty chain ID
        string memory expected = "";
        assertEq(result, expected);
    }
    
    function test_021____edgeCases____SameAccountInMultipleChains() public {
        // Add same account to same group on multiple chains
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(SEPOLIA, FAMILY_GROUP, CONTROLLED4);
        
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(BASE_SEPOLIA, FAMILY_GROUP, CONTROLLED4);
        
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(POLYGON_MUMBAI, FRIENDS_GROUP, CONTROLLED4);
        
        // Verify account exists in family group on all chains
        address[] memory ethereumFamily = controlledAccounts.getControlledAccounts(CONTROLLER1, SEPOLIA, FAMILY_GROUP);
        address[] memory baseFamily = controlledAccounts.getControlledAccounts(CONTROLLER1, BASE_SEPOLIA, FAMILY_GROUP);
        address[] memory polygonFriends = controlledAccounts.getControlledAccounts(CONTROLLER1, POLYGON_MUMBAI, FRIENDS_GROUP);
        
        assertEq(ethereumFamily.length, 3);   // CONTROLLED1, CONTROLLED2, CONTROLLED4
        assertEq(baseFamily.length, 1);       // CONTROLLED4
        assertEq(polygonFriends.length, 3);   // CONTROLLED1, CONTROLLED3, CONTROLLED4
        
        // Verify CONTROLLED4 is in family group on all three chains
        bool foundInEthereum = false;
        bool foundInBase = false;
        bool foundInPolygon = false;
        
        for (uint256 i = 0; i < ethereumFamily.length; i++) {
            if (ethereumFamily[i] == CONTROLLED4) foundInEthereum = true;
        }
        for (uint256 i = 0; i < baseFamily.length; i++) {
            if (baseFamily[i] == CONTROLLED4) foundInBase = true;
        }
        for (uint256 i = 0; i < polygonFriends.length; i++) {
            if (polygonFriends[i] == CONTROLLED4) foundInPolygon = true;
        }
        
        assertTrue(foundInEthereum);
        assertTrue(foundInBase);
        assertTrue(foundInPolygon);
    }
    
    function test_022____edgeCases____ZeroAddressInCrossChainGroups() public {
        // Add zero address to a group on different chain
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(SEPOLIA, FAMILY_GROUP, address(0));
        
        // Verify zero address was added
        address[] memory familyAccounts = controlledAccounts.getControlledAccounts(CONTROLLER1, SEPOLIA, FAMILY_GROUP);
        assertEq(familyAccounts.length, 3); // CONTROLLED1, CONTROLLED2, address(0)
        assertEq(familyAccounts[2], address(0));
    }
    
    function test_023____edgeCases____SelfControlInCrossChainGroups() public {
        // Add controller to its own group on different chain
        vm.prank(CONTROLLER1);
        controlledAccounts.declareControlledAccount(SEPOLIA, FAMILY_GROUP, CONTROLLER1);
        
        // Verify self-control was added
        address[] memory familyAccounts = controlledAccounts.getControlledAccounts(CONTROLLER1, SEPOLIA, FAMILY_GROUP);
        assertEq(familyAccounts.length, 3); // CONTROLLED1, CONTROLLED2, CONTROLLER1
        assertEq(familyAccounts[2], CONTROLLER1);
    }
    
    function test_024____edgeCases____InvalidChainIdInCredential() public {
        bytes memory identifier = _createAddressIdentifier(CONTROLLER1);
        
        // Test with invalid chain ID (non-numeric)
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts:invalid:family");
        
        // Should treat "invalid" as group ID and use current chain
        assertEq(result, "");
    }
    
    function test_025____edgeCases____BackwardCompatibilityWithOriginalFormat() public {
        bytes memory identifier = _createAddressIdentifier(CONTROLLER1);
        
        // Test original format without chain ID (should use current chain)
        string memory result = controlledAccounts.credential(identifier, "eth.ecs.controlled-accounts.accounts:family");
        
        // Should work with current chain and treat "family" as group ID
        assertEq(result, "");
    }
    
    /* --- Helper Functions --- */
    
    function _createAddressIdentifier(address addr) internal pure returns (bytes memory) {
        return abi.encodePacked(addr);
    }
}
