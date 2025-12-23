// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import "../src/CredentialResolverFactory.sol";
import "../src/CredentialResolver.sol";

contract CredentialResolverFactoryTest is Test {
    using Clones for address;
    
    /* --- Test Accounts --- */
    
    address factory = address(0x1001);
    address user1 = address(0x1002);
    address user2 = address(0x1003);
    
    /* --- Contract Variables --- */
    
    CredentialResolverFactory public resolverFactory;
    CredentialResolver public implementation;
    
    /* --- Setup --- */
    
    function setUp() public {
        vm.startPrank(factory);
        
        // Deploy implementation
        implementation = new CredentialResolver();
        
        // Deploy factory
        resolverFactory = new CredentialResolverFactory(address(implementation));
        
        vm.stopPrank();
    }
    
    /* --- Test Dividers --- */
    
    function test1000________________________________________________________________________________() public pure {}
    function test1100____________________RESOLVER_FACTORY_TESTS______________________________() public pure {}
    function test1200________________________________________________________________________________() public pure {}
    
    /* --- Factory Tests --- */
    
    function test_001____createResolver______________CanDeployClone() public {
        vm.prank(user1);
        address clone = resolverFactory.createResolver(user1);
        
        // Verify clone was deployed
        assertTrue(clone != address(0));
        assertTrue(resolverFactory.isClone(clone));
        assertEq(resolverFactory.getCloneCount(), 1);
        assertEq(resolverFactory.getClone(0), clone);
        
        // Verify owner
        assertEq(CredentialResolver(clone).owner(), user1);
    }
    
    function test_002____createResolver______________ClonesAreIndependent() public {
        // Deploy two clones
        vm.prank(user1);
        address clone1 = resolverFactory.createResolver(user1);
        
        vm.prank(user2);
        address clone2 = resolverFactory.createResolver(user2);
        
        // Verify different addresses
        assertTrue(clone1 != clone2);
        
        // Verify different owners
        assertEq(CredentialResolver(clone1).owner(), user1);
        assertEq(CredentialResolver(clone2).owner(), user2);
        
        // Set different data
        vm.prank(user1);
        CredentialResolver(clone1).setText("key1", "value1");
        
        vm.prank(user2);
        CredentialResolver(clone2).setText("key1", "value2");
        
        // Verify independent storage
        assertEq(CredentialResolver(clone1).text(bytes32(0), "key1"), "value1");
        assertEq(CredentialResolver(clone2).text(bytes32(0), "key1"), "value2");
    }
    
    function test_003____createResolverDeterministic_PredictsCorrectAddress() public {
        bytes32 salt = keccak256("test-salt");
        
        // Predict address
        address predicted = resolverFactory.predictDeterministicAddress(salt);
        
        // Deploy with same salt
        vm.prank(user1);
        address clone = resolverFactory.createResolverDeterministic(user1, salt);
        
        // Verify prediction was correct
        assertEq(clone, predicted);
        assertEq(CredentialResolver(clone).owner(), user1);
    }
    
    function test_004____createResolver______________OnlyOwnerCanSetRecords() public {
        vm.prank(user1);
        address clone = resolverFactory.createResolver(user1);
        
        // user1 (owner) can set records
        vm.prank(user1);
        CredentialResolver(clone).setText("test", "value");
        assertEq(CredentialResolver(clone).text(bytes32(0), "test"), "value");
        
        // user2 (not owner) cannot set records
        vm.prank(user2);
        vm.expectRevert();
        CredentialResolver(clone).setText("test", "other");
    }
    
    function test_005____createResolver______________GasSavings() public {
        // Deploy a regular CredentialResolver (implementation already deployed in setUp)
        // Note: Implementation cannot be initialized, so we'll compare clone vs clone
        // but measure the cost of deploying a full contract vs clone
        
        // Measure clone deployment via factory
        uint256 gasBefore = gasleft();
        vm.prank(user1);
        address clone = resolverFactory.createResolver(user1);
        uint256 cloneGas = gasBefore - gasleft();
        
        // For comparison, measure deploying a new implementation (which is what regular deployment would be)
        gasBefore = gasleft();
        CredentialResolver newImpl = new CredentialResolver();
        uint256 implGas = gasBefore - gasleft();
        
        console.log("Implementation deployment gas:", implGas);
        console.log("Clone deployment gas:", cloneGas);
        console.log("Gas saved:", implGas - cloneGas);
        if (implGas > 0) {
            console.log("Savings percentage:", ((implGas - cloneGas) * 100) / implGas);
        }
        
        // Clone should be significantly cheaper than deploying a new implementation
        assertTrue(cloneGas < implGas);
    }
    
    function test_006____initialize_________________ImplementationCannotBeInitialized() public {
        // Implementation has initializers disabled in constructor, so it cannot be initialized
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        implementation.initialize(user1);
        
        // Implementation owner is set to deployer in constructor
        assertEq(implementation.owner(), factory);
    }
    
    function test_007____initialize_________________CloneCanOnlyBeInitializedOnce() public {
        // Create a clone using low-level clone
        address clone = address(implementation).clone();
        
        // First initialization should succeed
        CredentialResolver(clone).initialize(user1);
        assertEq(CredentialResolver(clone).owner(), user1);
        
        // Second initialization should fail
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        CredentialResolver(clone).initialize(user2);
    }
    
    function test_008____initialize_________________CannotInitializeCloneWithZeroAddress() public {
        // Create a clone manually (not through factory which checks this)
        address clone = address(implementation).clone();
        
        // Initialize clone with zero address should revert
        // Note: Factory already prevents this, but testing direct initialization
        vm.expectRevert(abi.encodeWithSignature("OwnableInvalidOwner(address)", address(0)));
        CredentialResolver(clone).initialize(address(0));
    }
    
    function test_009____initialize_________________FactoryCannotCreateResolverForZeroAddress() public {
        // Factory should not allow creating resolver with zero address owner
        vm.expectRevert(abi.encodeWithSignature("InvalidOwner()"));
        resolverFactory.createResolver(address(0));
    }
}

