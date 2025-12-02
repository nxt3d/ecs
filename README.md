# Ethereum Credential Service (ECS) V2

**ECS V2** is a simplified, decentralized registry for "known" credential resolvers. Entities can register a unique namespace (e.g., `my-service.ecs.eth`) and point it to a standard ENS resolver that serves credential data.

ECS V2 is built to be fully compatible with the [ENS Hooks standard](https://github.com/nxt3d/ensips/blob/hooks/ensips/hooks.md), enabling ENS names to "jump" to these known resolvers to securely resolve onchain or offchain records.

## Installation

```bash
npm install @nxt3d/ecsjs@^2.0.0
```

> **Important:** Ensure you install version `^2.0.0` or higher. V1 is deprecated and incompatible with ECS V2.  
> **Note:** `@nxt3d/ecsjs` includes viem as a dependency, so you don't need to install it separately.

## Goals of V2

*   **Simplicity:** The complex multi-level registry has been replaced with a flat, single-label registry. Labels (e.g., `optimism`) map directly to resolvers.
*   **Standard Resolvers:** Credential resolvers are now just standard [ENSIP-10 (Extended Resolver)](https://docs.ens.domains/ens-improvement-proposals/ensip-10-wildcard-resolution) contracts. This means any existing ENS tooling can interact with them.
*   **Flexible Data:** Credential providers can define their own schema and keys. There's no forced structure for credential data.
*   **Hooks Integration:** ECS serves as the registry for [Hooks](https://github.com/nxt3d/ensips/blob/hooks/ensips/hooks.md). Hooks in ENS text records can reference ECS resolvers to fetch trusted data.
*   **`ecs.eth` Resolution:** Credentials are resolved through service subdomains (e.g., `my-service.ecs.eth`). Queries use specific keys (e.g., `eth.ecs.my-service.credential:vitalik.eth`) to fetch data for a target identity.

## Architecture

### 1. ECS Registry (`ECSRegistry.sol`)
The core contract. It maintains a mapping of:
`LabelHash -> (Owner, Expiration)`

*   **ENS Integration:** When a label is registered, ECS automatically creates the corresponding subname (e.g., `my-service.ecs.eth`) in the official **ENS Registry**.
*   **Resolver Management:** The resolver address is stored directly on the ENS Registry record for that subname.
*   **Ownership:** ECS retains ownership of the ENS subnode to ensure protocol rules, while the logical owner manages the record via the ECS Registry.
*   **Commit/Reveal:** Secure updates using a commitment pattern to prevent front-running.

### 2. Known Resolvers
These are contracts that are built and registered. They can be:
*   **Onchain Resolvers:** Storing attestation data directly on Ethereum.
*   **Offchain/L2 Resolvers:** Using CCIP-Read to fetch data from Optimism, Base, or a centralized server, verified by signatures or proofs.
*   **Standard ENS Resolvers:** Since they implement standard ENS methods (`text`, `addr`, etc.), they work with any ENS client.

## Usage Flow with Hooks

Hooks enable ENS names to redirect queries to known resolvers.

1.  **User** sets a text record on their ENS name (e.g., `maria.eth`) containing a **Hook**:
    ```
    hook("text(bytes32,string)", <ECS_RESOLVER_ADDRESS>)
    ```
2.  **Client** reads this record and extracts the `<ECS_RESOLVER_ADDRESS>`.
3.  **Client** calls `getLabelByResolver(<ECS_RESOLVER_ADDRESS>)` on the ECS Registry to find its registered label (e.g., `my-service`).
4.  **Client** constructs the service name `my-service.ecs.eth` (optional, for provenance).
5.  **Client** queries the resolver directly: `text(node, "credential-key")`.
    - Note: Single-label resolvers ignore the `node` parameter, so any value (including `0x0`) works.
6.  **Resolver** returns the verified credential data.

This creates a trusted link to the record, where `maria.eth` doesn't store the record herself; instead, the record can be resolved against a "known" trusted resolver.

### Example: Resolving a Hook

```javascript
import { 
  createECSClient, 
  sepolia,
  getLabelByResolver, 
  resolveCredential 
} from '@nxt3d/ecsjs'

const client = createECSClient({
  chain: sepolia,
  rpcUrl: 'https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY'
})

// User has hook pointing to resolver
const resolverAddress = '0x03eb9Bf23c828E3891A8fE3cB484A7ca769B985e'
const credentialKey = 'eth.ecs.name-stars.starts:vitalik.eth'

// Get label and resolve credential in one call
const credential = await resolveCredential(client, resolverAddress, credentialKey)
// Returns: "100"

// Or get just the label
const label = await getLabelByResolver(client, resolverAddress)
// Returns: "name-stars"

// You can also use viem's ENS functions directly
const ensName = `${label}.ecs.eth`
const textValue = await client.getEnsText({
  name: ensName,
  key: credentialKey
})
// Returns: "100"
```

## Deployments

### Sepolia Testnet

**Date:** December 2, 2025  
**Network:** Sepolia (Chain ID: 11155111)  
**Status:** ✅ Live and operational

#### Deployed Contracts

| Contract | Address |
|----------|---------|
| ECS Registry | `0x016BfbF42131004401ABdfe208F17A1620faB742` |
| ECS Registrar | `0x7aDf2626E846aC3a36ac72f25B8329C893b45e12` |
| Credential Resolver (name-stars) | `0x03eb9Bf23c828E3891A8fE3cB484A7ca769B985e` |

#### Configuration

- **Root Name:** `ecs.eth`
- **Root Node:** `0xe436ba58406c69a63a9611a11eb52314c5c17ba9eaaa7dab8506fe8849517286`
- **Deployer:** `0xF8e03bd4436371E0e2F7C02E529b2172fe72b4EF`
- **Registrar Pricing:** ~0.001 ETH/year (32000 wei/second)
- **Min Commitment Age:** 60 seconds

#### Registered Labels

##### name-stars.ecs.eth

- **Status:** ✅ Registered
- **Owner:** `0xF8e03bd4436371E0e2F7C02E529b2172fe72b4EF`
- **Resolver:** `0x03eb9Bf23c828E3891A8fE3cB484A7ca769B985e`
- **Expires:** December 2, 2026

**Credential Records:**
- **Key:** `eth.ecs.name-stars.starts:vitalik.eth`
- **Text Value:** `"100"`
- **Data Value:** `100` (uint256)

#### Query Examples

**Using Cast:**

```bash
# Get label from resolver address (for Hooks)
cast call 0x016BfbF42131004401ABdfe208F17A1620faB742 \
  "getLabelByResolver(address)(string)" \
  0x03eb9Bf23c828E3891A8fE3cB484A7ca769B985e \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
# Returns: "name-stars"
```

**Using @nxt3d/ecsjs:**

```javascript
import { 
  createECSClient, 
  sepolia,
  getLabelByResolver, 
  resolveCredential 
} from '@nxt3d/ecsjs'

const client = createECSClient({
  chain: sepolia,
  rpcUrl: 'https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY'
})

// Get label from resolver address
const label = await getLabelByResolver(
  client,
  '0x03eb9Bf23c828E3891A8fE3cB484A7ca769B985e'
)
// Returns: "name-stars"

// Or resolve credential directly
const credential = await resolveCredential(
  client,
  '0x03eb9Bf23c828E3891A8fE3cB484A7ca769B985e',
  'eth.ecs.name-stars.starts:vitalik.eth'
)
// Returns: "100"
```

**Run the demo:**

```bash
npm run hook  # Full Hooks resolution flow
npm run resolve  # Direct text record resolution
```

For full deployment details, see `deployments/sepolia-2025-12-02-03.md`

## Getting Started

### Build

```shell
forge build
```

### Test

```shell
forge test
```

### Deploy

See deployment scripts in `script/`:
- `DeployAndCommit.s.sol` - Deploy contracts and commit registration
- `RegisterAndSetup.s.sol` - Complete registration after 60s wait

For full deployment details, see `deployments/sepolia-2025-12-02-03.md`
