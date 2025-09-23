// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";

/**
 * @title SignatureTest
 * @dev Simple contract to test signature verification
 */
contract SignatureTest is Test {
    
    function testSignatureVerification() public {
        // Test address and private key
        address testAddress = address(0x2e988A386a799F506693793c6A5AF6B54dfAaBfB);
        uint256 privateKey = 0x1234567890123456789012345678901234567890123456789012345678901234;
        
        // Test data
        uint256 coinType = 0;
        address controller = address(0x1111111111111111111111111111111111111111);
        
        // Create the message hash (same format as ControlledAccountsCrosschain)
        bytes32 messageHash = keccak256(abi.encodePacked(
            "ControlledAccounts: setControllerWithSignature",
            testAddress,
            coinType,
            controller,
            address(this)
        ));
        
        // Convert to Ethereum signed message hash
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            messageHash
        ));
        
        console.log("Message hash:", vm.toString(messageHash));
        console.log("Eth signed message hash:", vm.toString(ethSignedMessageHash));
        
        // Sign the message
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        console.log("Signature:", vm.toString(signature));
        
        // Verify the signature
        address recovered = ecrecover(ethSignedMessageHash, v, r, s);
        console.log("Recovered address:", recovered);
        console.log("Expected address:", testAddress);
        
        assertEq(recovered, testAddress, "Signature verification should work");
    }
}



