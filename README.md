# Ethereum Credential Service (ECS) V2

**Version:** 0.2.2-beta  
**Status:** Beta - Deployed on Sepolia

**ECS V2** is a decentralized registry of Smart Credentials—verifiable onchain or offchain data about any identity. Smart Credentials are implemented as Extended Resolvers. ECS supports both public and privacy-preserving credentials using Zero Knowledge Proofs (ZKPs), enabling users to prove attributes without revealing underlying data.

Entities can register a unique namespace (e.g., `my-service.ecs.eth`) and point it to their Smart Credential (Extended Resolver). ECS is built to be fully compatible with the [ENS Hooks standard](https://github.com/nxt3d/ensips/blob/hooks/ensips/hooks.md), enabling ENS names to securely resolve Smart Credentials.

## Installation

```bash
npm install @nxt3d/ecsjs@0.2.4-beta
```

> **Version:** 0.2.4-beta - [View on NPM](https://www.npmjs.com/package/@nxt3d/ecsjs)  
> **Important:** ECS V1 is deprecated and incompatible with V2.  
> **Note:** This package includes viem as a dependency, so you don't need to install it separately.

## Goals of V2

*   **Simplicity:** The complex multi-level registry has been replaced with a flat, single-label registry. Labels (e.g., `optimism`) map directly to Smart Credentials.
*   **Standard Extended Resolvers:** Smart Credentials are implemented as standard [ENSIP-10 (Extended Resolver)](https://docs.ens.domains/ens-improvement-proposals/ensip-10-wildcard-resolution) contracts. This means any existing ENS tooling can interact with them.
*   **Flexible Data:** Smart Credential providers can define their own schema and keys. There's no forced structure for credential data.
*   **Hooks Integration:** ECS serves as the registry for [Hooks](https://github.com/nxt3d/ensips/blob/hooks/ensips/hooks.md). Hooks in ENS text records can reference registered Smart Credentials.
*   **`ecs.eth` Resolution:** Smart Credentials are resolved through service subdomains (e.g., `my-service.ecs.eth`). Queries use specific keys (e.g., `eth.ecs.my-service.credential:vitalik.eth`) to fetch data for a target identity.

## Architecture

### 1. ECS Registry (`ECSRegistry.sol`)
The core contract. It maintains a mapping of:
`LabelHash -> (Owner, Expiration)`

*   **ENS Integration:** When a label is registered, ECS automatically creates the corresponding subname (e.g., `my-service.ecs.eth`) in the official **ENS Registry**.
*   **Smart Credential Management:** The Smart Credential address is stored directly on the ENS Registry record for that subname.
*   **Ownership:** ECS retains ownership of the ENS subnode to ensure protocol rules, while the logical owner manages the record via the ECS Registry.
*   **Commit/Reveal:** Secure updates using a commitment pattern to prevent front-running.

### 2. CredentialResolverFactory (`CredentialResolverFactory.sol`)
A factory contract for deploying gas-efficient CredentialResolver clones:

*   **Minimal Proxy Pattern:** Uses EIP-1167 for ultra-low-cost deployments (~160k gas vs ~2.1M gas for full deployment)
*   **Clone Management:** Tracks all deployed clones and provides query functions
*   **Deterministic Deployment:** Supports deterministic address generation for predictable deployments
*   **Initialization:** Automatically initializes clones with owner address
*   **Validation:** Prevents deployment with zero address owners

### 3. Smart Credentials (`CredentialResolver.sol`)
Smart Credentials are Extended Resolver contracts that are built and registered. The default implementation includes:

*   **Standard ENS Extended Resolvers:** Implements standard ENS methods (`text`, `addr`, `contenthash`, `data`) and works with any ENS client
*   **ERC-8049 Integration:** Uses ERC-8049 for contract-level metadata storage via `setContractMetadata()` and `getContractMetadata()`
*   **ENS `data()` Support:** The `data()` ENS resolver function delegates to ERC-8049 storage for standardized metadata access
*   **Ownable Pattern:** Uses standard `Ownable` (not upgradeable) for minimal clones, with initialization guards
*   **Gas-Efficient Clones:** Deployed as minimal proxies (EIP-1167) with independent storage per clone
*   **Interface Support:** Implements `IERC165`, `IExtendedResolver`, and `IERC8049`

Smart Credentials can be:
*   **Onchain Smart Credentials:** Storing attestation data directly on Ethereum
*   **Offchain/L2 Smart Credentials:** Using CCIP-Read to fetch data from Optimism, Base, or a centralized server, verified by signatures or proofs
*   **Privacy-Preserving Smart Credentials:** Supporting Zero Knowledge Proofs (ZKPs) to prove attributes without revealing underlying data
*   **Specialized Smart Credentials:** Like [CCResolver](./CCResolver-README.md) for controlled accounts verification via ERC-8092, demonstrating the flexibility of the ECS system

## Usage Flow with Hooks

Hooks enable ENS names to redirect queries to registered Smart Credentials.

1.  **User** sets a text record on their ENS name (e.g., `maria.eth`) containing a **Hook**:
    ```
    hook("text(bytes32,string)", <SMART_CREDENTIAL_ADDRESS>)
    ```
2.  **Client** reads this record and extracts the `<SMART_CREDENTIAL_ADDRESS>`.
3.  **Client** calls `getResolverInfo(<SMART_CREDENTIAL_ADDRESS>)` on the ECS Registry to:
    - Find its registered label (e.g., `my-service`)
    - Check the `resolverUpdated` timestamp to verify Smart Credential stability
    - Read the `review` field for admin-assigned ratings or certifications
    - **Make a trust decision** based on Smart Credential age and review status
4.  **Client** constructs the service name `my-service.ecs.eth` (optional, for provenance).
5.  **Client** queries the Smart Credential directly: `text(node, "credential-key")`.
    - Note: Single-label Smart Credentials ignore the `node` parameter, so any value (including `0x0`) works.
6.  **Smart Credential** returns the verified credential data.

This creates a trusted link to the record, where `maria.eth` doesn't store the record herself; instead, the data is resolved from a trusted registered Smart Credential.

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

// User has hook pointing to Smart Credential
const smartCredentialAddress = '0x48A3D8Cec7807eDB1ba78878c356B3D051278891'
const credentialKey = 'eth.ecs.name-stars.starts:vitalik.eth'

// Get label and resolve credential in one call
const credential = await resolveCredential(client, smartCredentialAddress, credentialKey)
// Returns: "100"

// Or get Smart Credential info
const { label, resolverUpdated, review } = await getResolverInfo(client, smartCredentialAddress)
// Returns: { label: "name-stars", resolverUpdated: 1234567890n, review: "" }

// You can also use viem's ENS functions directly
const ensName = `${label}.ecs.eth`
const textValue = await client.getEnsText({
  name: ensName,
  key: credentialKey
})
// Returns: "100"
```

## Smart Credential Trust and Freshness

**ECS strictly enforces a one-to-one relationship between labels and Smart Credentials.** While label owners can change Smart Credentials (necessary for upgrades), this introduces a security concern. The registry tracks `resolverUpdated` timestamps, allowing clients to enforce security policies based on Smart Credential age.

**Security-conscious clients can require Smart Credentials to be established (e.g., 90+ days old) before trusting them.** Recent changes may indicate compromise, untested deployments, or migrations requiring review.

```javascript
const { label, resolverUpdated, review } = await getResolverInfo(client, resolverAddress)
const credentialAge = Math.floor(Date.now() / 1000) - Number(resolverUpdated)

if (credentialAge < 90 * 24 * 60 * 60) { // 90 days for high security
  console.warn(`⚠️ Smart Credential "${label}" changed ${Math.floor(credentialAge / 86400)} days ago`)
  // Reject or require security review
}

// Check admin review status
if (review && review !== "verified") {
  console.warn(`⚠️ Smart Credential "${label}" review status: ${review}`)
}
```

### Smart Credential Review System

**ECS registry administrators can assign review strings to Smart Credentials** to indicate trust levels, certification status, or security assessments. For example:

```
Status: Verified, Audit Score: 85/100, Date: 2025-04-21
```

This enables the ECS protocol to curate and communicate the quality or trustworthiness of Smart Credentials, helping clients make informed trust decisions beyond just age.

**Planned Upgrades:** Smart Credentials can announce upcoming upgrades via the [`resolver-info` text record](https://github.com/nxt3d/ensips/blob/resolver-info-metadata/ensips/resolver-info-text-record.md), including the bytecode hash of the new implementation. Clients can whitelist this hash to maintain continuous resolution even when the Smart Credential upgrades, verifying the upgrade follows the expected path.

## Deployments

### Sepolia Testnet

**Version:** 0.2.2-beta  
**Date:** December 23, 2025  
**Network:** Sepolia (Chain ID: 11155111)  
**Status:** ✅ Live and operational (Latest Deployment - Ownable + ERC-8049 Clone Pattern)

#### Deployed Contracts

| Contract | Address | Verified |
|----------|---------|----------|
| ECS Registry | `0x1Cc0E6c3B645D7751DE7Ff7ce7d17cD228e4a4F2` | [✅ View](https://sepolia.etherscan.io/address/0x1Cc0E6c3B645D7751DE7Ff7ce7d17cD228e4a4F2) |
| ECS Registrar | `0x86a67901820da1e3523Db67d02083C0a08170b37` | [✅ View](https://sepolia.etherscan.io/address/0x86a67901820da1e3523Db67d02083C0a08170b37) |
| Credential Resolver (Implementation) | `0x7F7e3EA29fd74cfA4672eD2F1995d7DD6988d06f` | [✅ View](https://sepolia.etherscan.io/address/0x7F7e3EA29fd74cfA4672eD2F1995d7DD6988d06f) |
| Credential Resolver Factory | `0xb5b31DEb61f6b9Dd61b222ad50084e11EF53B8E3` | [✅ View](https://sepolia.etherscan.io/address/0xb5b31DEb61f6b9Dd61b222ad50084e11EF53B8E3) |
| Credential Resolver (Clone - name-stars) | `0x48A3D8Cec7807eDB1ba78878c356B3D051278891` | [View](https://sepolia.etherscan.io/address/0x48A3D8Cec7807eDB1ba78878c356B3D051278891) |

> **New in v0.2.2:** Ownable pattern for minimal clones + ERC-8049 integration for contract metadata + Factory pattern for gas-efficient deployments

#### Configuration

- **Root Name:** `ecs.eth`
- **Root Node:** `0xe436ba58406c69a63a9611a11eb52314c5c17ba9eaaa7dab8506fe8849517286`
- **Deployer:** `0xF8e03bd4436371E0e2F7C02E529b2172fe72b4EF`
- **Registrar Pricing:** ~0.001 ETH/year (32000 wei/second)
- **Min Commitment Age:** 60 seconds

#### Registered Labels

##### name-stars.ecs.eth

- **Status:** ✅ Registered
- **Owner:** `0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38`
- **Smart Credential:** `0x48A3D8Cec7807eDB1ba78878c356B3D051278891` (minimal clone)
- **Expires:** January 7, 2027

**Credential Records:**
- **Key:** `eth.ecs.name-stars.starts:vitalik.eth`
- **Text Value:** `"100"` (via `setText()`)
- **Data Value:** `100` (uint256, via ERC-8049 `setContractMetadata()`)

**Features:**
- Uses ERC-8049 for contract-level metadata storage
- `data()` ENS resolver function delegates to ERC-8049 storage
- Supports both text records and ERC-8049 metadata
- Implements `IERC8049` interface for standardized metadata access
- Minimal proxy clone (EIP-1167) for gas-efficient deployment

**Onchain Verification:**
- ✅ `text()` function returns `"100"`
- ✅ `data()` function returns `100` (uint256) via ERC-8049
- ✅ `getContractMetadata()` returns ERC-8049 metadata
- ✅ `supportsInterface(IERC8049)` returns `true`
- ✅ Registry correctly maps resolver to label `"name-stars"`

##### controlled-accounts.ecs.eth

- **Status:** ✅ Registered
- **Owner:** `0xF8e03bd4436371E0e2F7C02E529b2172fe72b4EF`
- **Smart Credential:** `0xAE5A879A021982B65A691dFdcE83528e8e13dFd3` (CCResolver v0.1.0)
- **Expires:** 2035 (10 years)

**Features:**
- Full ENS Extended Resolver implementation (Smart Credential)
- Controlled accounts verification via ERC-8092 Associated Accounts
- Real-time signature verification through AssociationsStore
- Returns YAML-formatted data with parent/child accounts in ERC-7930 format
- Implements `resolver-info` standard for metadata discovery

**Text Record Keys:**
- **Controlled Accounts:** `eth.ecs.controlled-accounts:<id>` - Returns YAML with verified parent and child accounts
- **Resolver Info:** `resolver-info` - Returns metadata about the resolver (version, features, standards)

**Query Example:**

```javascript
import { createPublicClient, http } from 'viem'
import { sepolia } from 'viem/chains'

const client = createPublicClient({
  chain: sepolia,
  transport: http('https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY')
})

// Query controlled accounts using ENS text record
const yaml = await client.getEnsText({
  name: 'controlled-accounts.ecs.eth',
  key: 'eth.ecs.controlled-accounts:0'
})

// Returns YAML like:
// id: 0
// registeredAt: 1765302228
// parent: "0x0001000003aa36a7144d45cd7472f2c46e81734c561a2d0b4b66c8fefe"
// children:
//   - "0x0001000003aa36a714f935f966a073746a9ee0f6a685a41da23a64e1d1"
//   - "0x0001000003aa36a714cc8d7b159eafa8a2c4ca5c88c3f6b760761dbf28"
```

**Test the integration:**

```bash
npm run test-cc  # Run full CCResolver integration tests
```

For complete documentation, see [CCResolver-README.md](./CCResolver-README.md)

#### Query Examples

**Using Cast:**

```bash
# Get label from Smart Credential address (for Hooks)
cast call 0x1Cc0E6c3B645D7751DE7Ff7ce7d17cD228e4a4F2 \
  "getResolverInfo(address)(string,uint128,string)" \
  0x48A3D8Cec7807eDB1ba78878c356B3D051278891 \
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

// Get Smart Credential info from address
const { label, resolverUpdated, review } = await getResolverInfo(
  client,
  '0x48A3D8Cec7807eDB1ba78878c356B3D051278891'
)
// Returns: { label: "name-stars", resolverUpdated: <timestamp>n, review: "" }

// Or resolve credential directly
const credential = await resolveCredential(
  client,
  '0x48A3D8Cec7807eDB1ba78878c356B3D051278891',
  'eth.ecs.name-stars.starts:vitalik.eth'
)
// Returns: "100"
```

**Run the demos:**

```bash
npm run hook     # Full Hooks resolution flow
npm run resolve  # Direct text record resolution
npm run test-cc  # CCResolver controlled accounts integration
npm test         # Test ecsjs library with latest deployment
```

**Onchain Testing:**

All contracts have been verified onchain and tested:

```bash
# Test resolver functions directly
cast call 0x48A3D8Cec7807eDB1ba78878c356B3D051278891 \
  "text(bytes32,string)(string)" \
  0x0 "eth.ecs.name-stars.starts:vitalik.eth" \
  --rpc-url $SEPOLIA_RPC_URL
# Returns: "100"

cast call 0x48A3D8Cec7807eDB1ba78878c356B3D051278891 \
  "data(bytes32,string)(bytes)" \
  0x0 "eth.ecs.name-stars.starts:vitalik.eth" \
  --rpc-url $SEPOLIA_RPC_URL
# Returns: 0x0000000000000000000000000000000000000000000000000000000000000064 (100)

cast call 0x48A3D8Cec7807eDB1ba78878c356B3D051278891 \
  "getContractMetadata(string)(bytes)" \
  "eth.ecs.name-stars.starts:vitalik.eth" \
  --rpc-url $SEPOLIA_RPC_URL
# Returns: 0x0000000000000000000000000000000000000000000000000000000000000064

cast call 0x1Cc0E6c3B645D7751DE7Ff7ce7d17cD228e4a4F2 \
  "getResolverInfo(address)(string,uint128,string)" \
  0x48A3D8Cec7807eDB1ba78878c356B3D051278891 \
  --rpc-url $SEPOLIA_RPC_URL
# Returns: "name-stars", <timestamp>, ""
```

For full deployment details, see `deployments/sepolia-2025-12-23-1429.md`

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

For full deployment details, see `deployments/sepolia-2025-12-23-1429.md`
