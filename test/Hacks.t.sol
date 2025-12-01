// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/ECSRegistry.sol";
import "../src/ECSRegistrar.sol";

contract HacksTest is Test {
    /* --- Test Accounts --- */
    
    address admin = address(0x1001);
    address honestUser = address(0x1002);
    address attacker = address(0x1003);
    address resolver = address(0x1004);
    
    /* --- Contract Variables --- */
    
    ECSRegistry public registry;
    ECSRegistrar public registrar;
    
    /* --- Setup --- */
    
    function setUp() public {
        vm.startPrank(admin);
        registry = new ECSRegistry();
        registrar = new ECSRegistrar(registry);
        
        registry.grantRole(registry.REGISTRAR_ROLE(), address(registrar));
        
        // Setup generic pricing settings
        registrar.setParams(60, type(uint64).max, 3, 64);
        uint256[] memory prices = new uint256[](1);
        prices[0] = 1000 wei; // Reasonable price per second
        registrar.setPricingForAllLengths(prices);
        
        vm.stopPrank();
        
        // Fund users
        vm.deal(honestUser, 10 ether);
        vm.deal(attacker, 10 ether);
    }
    
    /* --- Test Dividers --- */
    
    function test1000________________________________________________________________________________() public pure {}
    function test1100____________________HACKS_TESTS________________________________________() public pure {}
    function test1200________________________________________________________________________________() public pure {}
    
    /**
     * @notice Demonstrates Front-Running Protection.
     * The commit-reveal scheme prevents an attacker from stealing the name
     * even if they see the reveal transaction.
     */
    function test_001____Hack____FrontRunningRegistration_Protected() public {
        string memory targetName = "valuable-name";
        uint256 duration = 365 days;
        uint256 price = registrar.rentPrice(targetName, duration);
        bytes32 secret = bytes32(uint256(123));
        
        // 1. Honest user commits
        vm.startPrank(honestUser);
        bytes32 commitment = registrar.createCommitment(targetName, honestUser, resolver, duration, secret);
        registrar.commit(commitment);
        vm.stopPrank();
        
        // Time passes
        vm.warp(block.timestamp + 60);
        
        // 2. Honest user reveals (broadcasts transaction)
        // Attacker sees the parameters in the mempool: targetName, honestUser, resolver, duration, secret.
        
        // 3. Attacker tries to front-run by registering the same name for THEMSELVES
        // using the exposed secret.
        vm.startPrank(attacker);
        
        // Attacker attempts to register. The contract checks for a commitment 
        // matching (targetName, attacker, resolver, duration, secret).
        // This specific commitment does NOT exist.
        
        vm.expectRevert(
            abi.encodeWithSelector(
                ECSRegistrar.CommitmentNotFound.selector,
                keccak256(abi.encodePacked(targetName, attacker, resolver, duration, secret))
            )
        );
        
        registrar.register{value: price}(
            targetName,
            attacker, // Attacker tries to claim ownership
            resolver,
            duration,
            secret
        );
        
        vm.stopPrank();
        
        // 4. Honest user transaction succeeds
        vm.startPrank(honestUser);
        registrar.register{value: price}(
            targetName,
            honestUser,
            resolver,
            duration,
            secret
        );
        vm.stopPrank();
        
        // 5. Verify Honest User owns the name
        bytes32 labelhash = keccak256(bytes(targetName));
        assertEq(registry.owner(labelhash), honestUser);
        
        console.log("Protection Confirmed: Attacker could not front-run registration.");
    }
}

