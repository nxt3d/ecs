# Ethereum Credential Service (ECS)

[![Version](https://img.shields.io/badge/version-0.1.0--beta-blue.svg)](https://github.com/your-repo/ecs)
[![Status](https://img.shields.io/badge/status-beta-orange.svg)](https://github.com/your-repo/ecs)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**Version:** 0.1.0-beta  
**Status:** Beta Release  
**Last Updated:** August 25, 2025  
**Deployment:** Ethereum Sepolia Testnet

ECS is a decentralized protocol built on Ethereum for storing, retrieving, and verifying digital credentials. It enables any application or service to create custom credentials with guaranteed namespace ownership and flexible onchain/offchain data storage. Credentials are core primitives for idenitty, and can be understood broadly to be any record or attestation made by a third party about an idenitty vs records made by the owner of the idenitty. A simple example is a reputation system where third parties attest to the "realness" of the identity, i.e. "vitalik.eth" is the real Vitalik Buterin's ENS name.

> **⚠️ Beta Notice:** This is a beta release deployed to Ethereum Sepolia testnet. The protocol is functional and tested, but may undergo changes before mainnet release. Use at your own risk in production environments.

---

## ECS Testnet Deployment

ECS is currently deployed on the Sepolia testnet. The contracts allow for credential providers to register a namespace, such as `ethstars.ecs.eth`, and then set a credential resolver for that namespace. The credential resolver is a contract that implements the `ICredentialResolver` interface, and is responsible for resolving the credential for a given identifier.

> **Example Credential Resolution**
>
> - **Credential:** `eth.ecs.ethstars.stars`
> - **Identifier:** `vitalik.eth`
> - **Result:** `"12728"`

Credentials are resolved via ENS using the ecs.eth domain. For example, a credetnial called `eth.ecs.ethstars.stars` can be resolved for "vitalik.eth" by querying the special ENS name `vitalik.eth.name.ecs.eth` for the credential (text record) `eth.ecs.ethstars.stars`. The result will be the credential value such as "12728". It is also possibele to resolve credentials for DNS names like `ethereum.org` or wallet addresses using `addr.ecs.eth`. 


### Key Contracts (Sepolia)
| Contract            | Address                                    | Etherscan |
|---------------------|--------------------------------------------|----------|
| ECSRegistry         | 0x360728b13Dfc832333beF3E4171dd42BdfCedC92 | [View](https://sepolia.etherscan.io/address/0x360728b13Dfc832333beF3E4171dd42BdfCedC92) |
| RootController      | 0x9b1e7Ae60cd8230F84FcDfD2c3aAB4851E783ddF | [View](https://sepolia.etherscan.io/address/0x9b1e7Ae60cd8230F84FcDfD2c3aAB4851E783ddF) |
| ECSRegistrarController | 0xd351637f9544A51979BFD0ae4D809C56b6acDe9F | [View](https://sepolia.etherscan.io/address/0xd351637f9544A51979BFD0ae4D809C56b6acDe9F) |
| ECSAddressResolver  | 0x2ffdf34ed40171cce860020ea37c9f1854e0995e | [View](https://sepolia.etherscan.io/address/0x2ffdf34ed40171cce860020ea37c9f1854e0995e) |
| ECSNameResolver     | 0xa8e8443f3bbaf7c903764cbc9602134a6bfec2b2 | [View](https://sepolia.etherscan.io/address/0xa8e8443f3bbaf7c903764cbc9602134a6bfec2b2) |
| OffchainStarAddrResolver | 0x9d89df9b49f21411be65af54a68f58ad9a05757d | [View](https://sepolia.etherscan.io/address/0x9d89df9b49f21411be65af54a68f58ad9a05757d) |
| OffchainStarNameResolver | 0x38ae0879afff64ab521610d5f812cb225308df02 | [View](https://sepolia.etherscan.io/address/0x38ae0879afff64ab521610d5f812cb225308df02) |

---

## Example Credential: EthStars

**EthStars** - An example implementation of the ECS protocol that demonstrates how to create a credential system for "starring" Ethereum addresses and domain names (.eth, .org, .com, etc.). Stars are stored onchain and cost 0.000001 Sepolia ETH.

**Credential:** `eth.ecs.ethstars.stars`

Features:

- **Star Addresses**: Any Ethereum mainnet address 
- **Star Domains**: Any domain name (ENS, traditional domains, etc.)
- **Query Stars**: Check star counts via ENS resolution
- **Onchain Storage**: All stars are permanently recorded on Ethereum Sepolia

**How the Example EthStars Works:**
- Users can star any address or domain via the example implementation
- Stars are written onchain to the ECS OffchainStarResolver/OffchainStarNameResolver contracts
- Anyone can query star counts via ENS resolution

> **Live App:** The production [EthStars App](https://ethstars.info/) runs on Base mainnet, while this Sepolia deployment serves as a working example of the ECS protocol.

### EthStars Testnet Credential Resolvers

- **OffchainStarAddrResolver (Address-based):** `0x9d89df9b49f21411be65af54a68f58ad9a05757d` [View](https://sepolia.etherscan.io/address/0x9d89df9b49f21411be65af54a68f58ad9a05757d)
- **OffchainStarNameResolver (Name-based):** `0x38ae0879afff64ab521610d5f812cb225308df02` [View](https://sepolia.etherscan.io/address/0x38ae0879afff64ab521610d5f812cb225308df02)

## ECS Protocol Overview

ECS unifies blockchain based credentials into a single service:

- **Namespace Ownership**: Register and own credential namespaces (e.g., `myservice.ecs.eth`)
- **Custom Credential Logic**: Deploy smart contracts that define how credentials are resolved and validated.
- **Flexible Data Storage**: Store credential data onchain, including L2s, for transparency or offchain to reduce cost. Offchain data can be and verified using CCIP-Read.
- **Universal Resolution**: Query any credential using a standard interface regardless of the underlying implementation.
- **Cross-Chain Interoperability**: Credentials can resolve and combine data from multiple chains, such as L2s, into a single cross-chain credential

ECS is built on L1 Ethereum (Currently deployed to Sepolia testnet), with credential resolvers that can access and aggregate data from one or more L2s or offchain sources. This architecture enables cost-effective data storage while maintaining the security and decentralization of Ethereum mainnet for namespace ownership and core protocol logic. Crucially, L1 Ethereum's unique position as the settlement layer allows it to access the state of all L2s, making it the ideal foundation for cross-chain credential resolution that can verify and combine data from multiple L2s.

## Resolving Credentials

ECS uses ENS (Ethereum Name Service) to resolve credentials, leveraging the existing domain name infrastructure and tooling including popular libraries like Ethers.js and Viem. When a credential is requested, the system automatically routes the query to the appropriate credential resolver. This allows credentials to be resolved using familiar domain-style names while maintaining the flexibility to implement custom credential logic behind each namespace.

## How Credential Resolution Works with ENS

ECS leverages the Ethereum Name Service (ENS) to make credentials universally accessible using familiar ENS name lookups and text record queries. This means any wallet, dapp, or script that supports ENS can also resolve ECS credentials—no new tooling required.

### 1. Credential Namespaces and Registration

- **Namespace Registration:**  
  Credentials are registered in the ECS Registry as namespaces. Each namespace is equivalent to a credential name (e.g., `ethstars`) and is registered in the normal domain order (e.g., `ethstars.ecs.eth`), not reversed.

- **Mono-Resolvers:**  
  Credentials are resolved through dedicated mono-resolvers, which are set on ENS subdomains that act as endpoints for specific credential types.  
  - **Current Mono-Resolvers:**  
    - `name.ecs.eth` for name-based credentials  
    - `addr.ecs.eth` for address-based credentials  
  - **Extensibility:** More mono-resolvers can be added in the future to support new credential types.

### 2. Credential Naming Patterns

ECS credentials are resolved as ENS sub-subdomains, following these patterns:

- **Name-based Credentials:**  
  ```
  <domain-or-ens-name>.name.ecs.eth
  ```
  _Example:_  
  `vitalik.eth.name.ecs.eth`  
  - This resolves to the credential for the ENS name or DNS domain `vitalik.eth`.

- **Address-based Credentials:**  
  ```
  <address>.<coinType>.addr.ecs.eth
  ```
  - `<address>`: Lowercase hex Ethereum address (no 0x prefix)
  - `<coinType>`: ENSIP-11 coin type in lowercase hex (Ethereum is `3c` i.e. 60)
  
  _Example:_  
  `d8da6bf26964af9d7eed9e03e53415d37aa96045.3c.addr.ecs.eth`  
  - This resolves to the credential for the Ethereum address `0xd8da6bf26964af9d7eed9e03e53415d37aa96045`, with the coin type `60`.

### 3. Example: Querying a Credential

Suppose you want to check how many "stars" Vitalik's address has in the EthStars credential:

1. **Construct the ENS name:**  
   `d8da6bf26964af9d7eed9e03e53415d37aa96045.3c.addr.ecs.eth`

2. **Query the text record:**  
   `eth.ecs.ethstars.stars`

3. **Sample Ethers.js Code:**
   ```js
   const name = "d8da6bf26964af9d7eed9e03e53415d37aa96045.3c.addr.ecs.eth";
   const resolver = await provider.getResolver(name);
   const stars = await resolver.getText("eth.ecs.ethstars.stars");
   ```

Or, for a name-based credential:

   ```js
   const name = "vitalik.eth.name.ecs.eth";
   const resolver = await provider.getResolver(name);
   const stars = await resolver.getText("eth.ecs.ethstars.stars");
   ```

## Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Git
- Node.js (for JavaScript examples)

### Installation

```bash
git clone <repository-url>
cd ecs
git submodule update --init --recursive
forge install
npm install
```

### Demo: Resolve vitalik.eth Stars

Try the live demo script to see ECS in action:

```bash
# Set up environment variables
cp .env.example .env
# Edit .env and add your SEPOLIA_RPC_URL

# Run the demo script
node ens-tools/resolve-vitalik-eth.js
```

This script demonstrates:
- **Name-based resolution**: `vitalik.eth.name.ecs.eth`
- **Address-based resolution**: `d8da6bf26964af9d7eed9e03e53415d37aa96045.3c.addr.ecs.eth`
- **Credential query**: `eth.ecs.ethstars.stars`

The script shows how to query star counts for both Vitalik's ENS name and his Ethereum address using the ECS protocol (currently on Sepolia testnet).

### Run Tests

```bash
# Run all tests (329 tests across 11 suites)
forge test

# Run specific test suites
forge test --match-contract "StarResolverIntegrationTest"
forge test --match-contract "StarNameResolverIntegrationTest"

# Run with detailed output
forge test -vvv
```

### Deploy to Testnet

```bash
# Copy environment variables
cp .env.example .env
# Edit .env with your keys

# Deploy to Sepolia (with environment variables sourced)
source .env && forge script script/DeployECS.s.sol:DeployECS --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY

## Creating Custom Credential Resolvers

### 1. Implement the ICredentialResolver Interface

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./ICredentialResolver.sol";

contract MyCustomResolver is ICredentialResolver {
    function credential(bytes memory identifier, string memory _credential) 
        external view override returns (string memory) {
        
        // The DNS-encoded identifier, such as either address.cointype or vitalik.eth
        // Implement your credential logic
        // Return the credential value or empty string
        
        return "your-credential-data";
    }
}
```

### 2. Register Your Namespace

```solidity
// Register namespace
uint256 fee = controller.calculateFee(365 days);
bytes32 namespace = controller.registerNamespace{value: fee}("myservice", 365 days);

// Deploy your credential resolver
MyCustomResolver resolver = new MyCustomResolver();

// Register the credential resolver for your namespace
addressResolver.setCredentialResolver(namespace, address(resolver));
```

### 3. Test Your Integration (Simple L1 Example)

Use the test framework pattern:

```solidity
contract MyResolverIntegrationTest is Test {
    ECSRegistry public registry;
    ECSRegistrarController public controller;
    ECSAddressResolver public addressResolver;
    ECSNameResolver public nameResolver;
    MyCustomResolver public myResolver;
    
    function setUp() public {
        // Deploy ECS infrastructure (copy from existing tests)
        // Deploy your resolver
        // Register namespace and credential resolver
    }
    
    function testMyCredentialResolution() public {
        // For address-based credentials: hexaddress.hexcointype.addr.ecs.eth  
        bytes memory dnsName = NameCoder.encode("0x34d79fFE0A82636ef12De45408bDF8B20c0f01e1.3c.addr.ecs.eth");
        
        bytes memory calldata = abi.encodeWithSelector(
            bytes4(0x59d1d43c), // text(bytes32,string)
            bytes32(0),
            "eth.ecs.myservice.balance" // Use reverse-domain credential key
        );
        
        bytes memory result = addressResolver.resolve(dnsName, calldata);
        string memory credential = abi.decode(result, (string));
        
        assertEq(credential, "expected-value");
    }
}
```
