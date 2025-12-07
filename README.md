# Ethereum Credential Service (ECS) V2

**Version:** 0.2.1-beta  
**Status:** Beta - Deployed on Sepolia

**ECS V2** is a simplified, decentralized registry for "known" credential resolvers. Entities can register a unique namespace (e.g., `my-service.ecs.eth`) and point it to a standard ENS resolver that serves credential data.

ECS V2 is built to be fully compatible with the [ENS Hooks standard](https://github.com/nxt3d/ensips/blob/hooks/ensips/hooks.md), enabling ENS names to "jump" to these known resolvers to securely resolve onchain or offchain records.

## Installation

```bash
npm install @nxt3d/ecsjs@0.2.2-beta
```

> **Version:** 0.2.2-beta - [View on NPM](https://www.npmjs.com/package/@nxt3d/ecsjs)  
> **Important:** ECS V1 is deprecated and incompatible with V2.  
> **Note:** This package includes viem as a dependency, so you don't need to install it separately.

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
3.  **Client** calls `getResolverInfo(<ECS_RESOLVER_ADDRESS>)` on the ECS Registry to:
    - Find its registered label (e.g., `my-service`)
    - Check the `resolverUpdated` timestamp to verify resolver stability
    - Read the `review` field for admin-assigned ratings or certifications
    - **Make a trust decision** based on resolver age and review status
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
  getResolverInfo, 
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

// Or get resolver info
const { label, resolverUpdated, review } = await getResolverInfo(client, resolverAddress)
// Returns: { label: "name-stars", resolverUpdated: 1234567890n, review: "" }

// You can also use viem's ENS functions directly
const ensName = `${label}.ecs.eth`
const textValue = await client.getEnsText({
  name: ensName,
  key: credentialKey
})
// Returns: "100"
```

## Resolver Trust and Freshness

**ECS strictly enforces a one-to-one relationship between labels and resolvers.** While label owners can change resolvers (necessary for upgrades), this introduces a security concern. The registry tracks `resolverUpdated` timestamps, allowing clients to enforce security policies based on resolver age.

**Security-conscious clients can require resolvers to be established (e.g., 90+ days old) before trusting them.** Recent resolver changes may indicate compromise, untested deployments, or migrations requiring review.

```javascript
const { label, resolverUpdated, review } = await getResolverInfo(client, resolverAddress)
const resolverAge = Math.floor(Date.now() / 1000) - Number(resolverUpdated)

if (resolverAge < 90 * 24 * 60 * 60) { // 90 days for high security
  console.warn(`⚠️ Resolver for "${label}" changed ${Math.floor(resolverAge / 86400)} days ago`)
  // Reject or require security review
}

// Check admin review status
if (review && review !== "verified") {
  console.warn(`⚠️ Resolver "${label}" review status: ${review}`)
}
```

### Resolver Review System

**ECS registry administrators can assign review strings to credential resolvers** to indicate trust levels, certification status, or security assessments. For example:

```
Status: Verified, Audit Score: 85/100, Date: 2025-04-21
```

This enables the ECS protocol to curate and communicate the quality or trustworthiness of credential resolvers, helping clients make informed trust decisions beyond just resolver age.

**Planned Upgrades:** Resolvers can announce upcoming upgrades via the [`resolver-info` text record](https://github.com/nxt3d/ensips/blob/resolver-info-metadata/ensips/resolver-info-text-record.md), including the bytecode hash of the new implementation. Clients can whitelist this hash to maintain continuous resolution even when the resolver upgrades, verifying the upgrade follows the expected path.

## Deployments

### Sepolia Testnet

**Version:** 0.2.1-beta  
**Date:** December 6, 2025  
**Network:** Sepolia (Chain ID: 11155111)  
**Status:** ✅ Live and operational (Deployment 03 - Minimal Clone Factory)

#### Deployed Contracts

| Contract | Address | Verified |
|----------|---------|----------|
| ECS Registry | `0x4f2F0e7b61d9Bd0e30F186D6530Efc92429Fcc77` | [✅ View](https://sepolia.etherscan.io/address/0x4f2F0e7b61d9Bd0e30F186D6530Efc92429Fcc77) |
| ECS Registrar | `0x3f971176d86f223bB8A664F7ce006B818d1D5649` | [✅ View](https://sepolia.etherscan.io/address/0x3f971176d86f223bB8A664F7ce006B818d1D5649) |
| Credential Resolver (Implementation) | `0x04c55c4CCAf0b7bb2e00bc3ea72a92585FE35683` | [✅ View](https://sepolia.etherscan.io/address/0x04c55c4CCAf0b7bb2e00bc3ea72a92585FE35683) |
| Credential Resolver Factory | `0x3d9BFC750F1eb7EDaDA2DB0e5dE0F763c30446c1` | [✅ View](https://sepolia.etherscan.io/address/0x3d9bfc750f1eb7edada2db0e5de0f763c30446c1) |
| Credential Resolver (Clone - name-stars) | `0x9773397bd9366D80dAE708CA4C4413Abf88B3DAa` | [View](https://sepolia.etherscan.io/address/0x9773397bd9366D80dAE708CA4C4413Abf88B3DAa) |

> **New:** Resolver deployments now use EIP-1167 minimal clones, providing **91% gas savings** (1.98M gas → 169K gas per resolver)

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
- **Resolver:** `0x9773397bd9366D80dAE708CA4C4413Abf88B3DAa` (minimal clone)
- **Expires:** December 5, 2026

**Credential Records:**
- **Key:** `eth.ecs.name-stars.starts:vitalik.eth`
- **Text Value:** `"100"`
- **Data Value:** `100` (uint256)

#### Query Examples

**Using Cast:**

```bash
# Get label from resolver address (for Hooks)
cast call 0x4f2F0e7b61d9Bd0e30F186D6530Efc92429Fcc77 \
  "getResolverInfo(address)(string,uint128,string)" \
  0x9773397bd9366D80dAE708CA4C4413Abf88B3DAa \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
# Returns: "name-stars", <timestamp>, ""
```

**Using @nxt3d/ecsjs:**

```javascript
import { 
  createECSClient, 
  sepolia,
  getResolverInfo, 
  resolveCredential 
} from '@nxt3d/ecsjs'

const client = createECSClient({
  chain: sepolia,
  rpcUrl: 'https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY'
})

// Get resolver info from resolver address
const { label, resolverUpdated, review } = await getResolverInfo(
  client,
  '0x9773397bd9366D80dAE708CA4C4413Abf88B3DAa'
)
// Returns: { label: "name-stars", resolverUpdated: <timestamp>n, review: "" }

// Or resolve credential directly
const credential = await resolveCredential(
  client,
  '0x9773397bd9366D80dAE708CA4C4413Abf88B3DAa',
  'eth.ecs.name-stars.starts:vitalik.eth'
)
// Returns: "100"
```

**Run the demo:**

```bash
npm run hook  # Full Hooks resolution flow
npm run resolve  # Direct text record resolution
```

For full deployment details, see `deployments/sepolia-2025-12-05-02.md`

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

For full deployment details, see `deployments/sepolia-2025-12-05-02.md`
