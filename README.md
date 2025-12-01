# Ethereum Credential Service (ECS) V2

**ECS V2** is a simplified, decentralized registry for "known" credential resolvers. It allows any entity to register a unique namespace (e.g., `my-service.ecs.eth`) and point it to a standard ENS resolver that can serve credential data.

ECS V2 is built to be fully compatible with the [ENS Hooks standard](https://github.com/nxt3d/ensips/blob/hooks/ensips/hooks.md), enabling ENS names to "jump" to these known resolvers to securely resolve onchain or offchain records.

## Goals of V2

*   **Simplicity:** We've replaced the complex multi-level registry with a flat, single-label registry. You register a label (e.g., `optimism`), and it maps directly to a resolver.
*   **Standard Standards:** Credential resolvers are now just standard [ENSIP-10 (Extended Resolver)](https://docs.ens.domains/ens-improvement-proposals/ensip-10-wildcard-resolution) contracts. This means any existing ENS tooling can interact with them.
*   **Flexible Data:** Credential providers can define their own schema and keys. There's no forced structure for credential data.
*   **Hooks Integration:** ECS serves as the "Phone Book" for [Hooks](https://github.com/nxt3d/ensips/blob/hooks/ensips/hooks.md). A hook in an ENS text record can point to an ECS resolver to fetch trusted data.
*   **`ecs.eth` Resolution:** ECS allows you to resolve credentials through service subdomains (e.g., `my-service.ecs.eth`). Queries are made using specific keys (e.g., `eth.ecs.my-service.credential:vitalik.eth`) to fetch data for a target identity.

## Architecture

### 1. ECS Registry (`ECSRegistry.sol`)
The core contract. It maintains a mapping of:
`LabelHash -> (Owner, Resolver Address, Expiration)`

*   **Flat Structure:** No subnames. Just `label` -> `resolver`.
*   **Ownership:** Owners can update the resolver address.
*   **Commit/Reveal:** Secure updates using a commitment pattern to prevent front-running.

### 2. ECS Resolver (`ECSResolver.sol`)
The main entry point for resolving credentials via ECS.
*   It implements `IExtendedResolver`.
*   When you query it (e.g., via `resolve(name, data)`), it looks up the specific credential resolver for that name in the **ECS Registry**.
*   It then forwards the request to that resolver using `CCIP-Read`, enabling seamless offchain data resolution (e.g., from L2s or gateways).

### 3. Known Resolvers
These are the contracts you build and register. They can be:
*   **Onchain Resolvers:** Storing attestation data directly on Ethereum.
*   **Offchain/L2 Resolvers:** Using CCIP-Read to fetch data from Optimism, Base, or a centralized server, verified by signatures or proofs.
*   **Standard ENS Resolvers:** Since they implement `IExtendedResolver`, they work just like any other ENS resolver.

## Usage Flow with Hooks

Hooks allow an ENS name to "redirect" a query to a known resolver.

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
