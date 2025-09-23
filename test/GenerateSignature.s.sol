// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";

contract GenerateSignature is Script {
    function run() public {
        address controlledAccount = address(0x2e988A386a799F506693793c6A5AF6B54dfAaBfB);
        uint256 coinType = 0x8000000000000000000000000000000000000000000000000000000000000001;
        address controller = address(0x1111111111111111111111111111111111111111);
        address contractAddress = address(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f);
        
        // Create the message hash that should be signed (same as contract)
        bytes32 messageHash = keccak256(abi.encodePacked(
            "ControlledAccounts: setControllerWithSignature",
            controlledAccount,
            coinType,
            controller,
            contractAddress
        ));
        
        console.log("Message hash:", vm.toString(messageHash));
        
        // Convert to Ethereum signed message hash
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            messageHash
        ));
        
        console.log("Eth signed message hash:", vm.toString(ethSignedMessageHash));
    }
}
