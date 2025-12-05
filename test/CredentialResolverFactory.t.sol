// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/CredentialResolverFactory.sol";
import "../src/CredentialResolver.sol";

contract CredentialResolverFactoryTest is Test {
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
        
        // Deploy implementation (factory will be the initial owner)
        implementation = new CredentialResolver(factory);
        
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
        // Deploy a regular CredentialResolver
        uint256 gasBefore = gasleft();
        new CredentialResolver(user1);
        uint256 regularGas = gasBefore - gasleft();
        
        // Deploy a clone
        gasBefore = gasleft();
        vm.prank(user1);
        resolverFactory.createResolver(user1);
        uint256 cloneGas = gasBefore - gasleft();
        
        console.log("Regular deployment gas:", regularGas);
        console.log("Clone deployment gas:", cloneGas);
        console.log("Gas saved:", regularGas - cloneGas);
        console.log("Savings percentage:", ((regularGas - cloneGas) * 100) / regularGas);
        
        // Clone should be significantly cheaper
        assertTrue(cloneGas < regularGas);
    }
}

