# Ethereum Credential Service (ECS) V2

**ECS V2** is a simplified, decentralized registry for "known" credential resolvers. Entities can register a unique namespace (e.g., `my-service.ecs.eth`) and point it to a standard ENS resolver that serves credential data.

ECS V2 is built to be fully compatible with the [ENS Hooks standard](https://github.com/nxt3d/ensips/blob/hooks/ensips/hooks.md), enabling ENS names to "jump" to these known resolvers to securely resolve onchain or offchain records.

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
4.  **Client** constructs the service name `my-service.ecs.eth`.
5.  **Client** resolves the original query (e.g., `text(node, "proof-of-person")`) against `my-service.ecs.eth`.
6.  **Resolver** returns the verified credential data.

This creates a trusted link to the record, where `maria.eth` doesn't store the record herself; instead, the record can be resolved against a "known" trusted resolver.

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

(Add deployment instructions here)
