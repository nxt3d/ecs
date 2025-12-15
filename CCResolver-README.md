# CCResolver Integration

CCResolver is an ENS Extended Resolver that provides Smart Credentials with verifiable on-chain proof of controlled accounts through cryptographic signatures using the ERC-8092 Associated Accounts standard.

## Deployment

**controlled-accounts.ecs.eth** is registered on Sepolia and points to CCResolver v0.1.0.

- **ECS Name**: `controlled-accounts.ecs.eth`
- **Owner**: `0xF8e03bd4436371E0e2F7C02E529b2172fe72b4EF`
- **Resolver**: `0xAE5A879A021982B65A691dFdcE83528e8e13dFd3` (CCResolver v0.1.0)
- **AssociationsStore**: `0x658CC576192a9e950DCd1BFb0F77F1D75a055D49`
- **Text Record Prefix**: `eth.ecs.controlled-accounts:`
- **Version**: v0.1.0 (Full ENS resolver support)
- **Features**: controlled-accounts, text records, data records, addr (multi-coin), contenthash, resolver-info

## Resolver Info

CCResolver implements the [resolver-info standard](https://github.com/nxt3d/ensips/blob/resolver-info-metadata/ensips/resolver-info-text-record.md) for metadata discovery:

```bash
cast call 0xAE5A879A021982B65A691dFdcE83528e8e13dFd3 \
  "text(bytes32,string)(string)" \
  0x0000000000000000000000000000000000000000000000000000000000000000 \
  "resolver-info" \
  --rpc-url $SEPOLIA_RPC_URL
```

Returns metadata including version, features, and standards compliance.

## Querying Controlled Accounts

Query controlled accounts using the text record format:

```javascript
const textRecord = await resolver.text(node, "eth.ecs.controlled-accounts:0");
```

Returns YAML with parent and child accounts in ERC-7930 format:

```yaml
id: 0
registeredAt: 1765302228
parent: "0x0001000003aa36a7144d45cd7472f2c46e81734c561a2d0b4b66c8fefe"
children:
  - "0x0001000003aa36a714f935f966a073746a9ee0f6a685a41da23a64e1d1"
  - "0x0001000003aa36a714cc8d7b159eafa8a2c4ca5c88c3f6b760761dbf28"
```

## Testing

Test the integration:

```bash
npm run test-cc
```

This verifies:
- CCResolver configuration
- Controlled accounts validation
- ENS text() interface
- YAML formatting
- Extended Resolver interface
- ERC-7930 address decoding

## Updating the Resolver

To update controlled-accounts.ecs.eth to point to a new resolver:

### Step 1: Commit Update

```bash
export NEW_CC_RESOLVER_ADDRESS=0x...

forge script script/CommitResolverUpdate.s.sol:CommitResolverUpdate \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vv

# Save the UPDATE_SECRET from output
```

### Step 2: Apply Update (after 60 seconds)

```bash
export UPDATE_SECRET=0x...

forge script script/UpdateResolverAddress.s.sol:UpdateResolverAddress \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vv
```

## Registering New Resolvers

To register a new resolver label under the ECS namespace:

### Step 1: Commit

```bash
export CC_RESOLVER_ADDRESS=0xAE5A879A021982B65A691dFdcE83528e8e13dFd3

forge script script/CommitControlledAccounts.s.sol:CommitControlledAccounts \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vv

# Save the REGISTRATION_SECRET from output
```

### Step 2: Register (after 60 seconds)

```bash
export REGISTRATION_SECRET=0x...

forge script script/RegisterControlledAccounts.s.sol:RegisterControlledAccounts \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vv
```

## Environment Variables

Required in `.env`:

```bash
# ECS Contracts
ECS_REGISTRY_ADDRESS=0xb09C149664773bFA88B72FA41437AdADcB8bF5B4
ECS_REGISTRAR_ADDRESS=0xD1399C6879EA5A92eB25ee8A0512c7a4fC0DDc6b

# CCResolver v0.1.0
CC_RESOLVER_ADDRESS=0xAE5A879A021982B65A691dFdcE83528e8e13dFd3
NEW_CC_RESOLVER_ADDRESS=0xAE5A879A021982B65A691dFdcE83528e8e13dFd3

# Deployer
DEPLOYER_PRIVATE_KEY=0x...
SEPOLIA_RPC_URL=https://...
```

## How It Works

1. **Associations**: Parent and child accounts create signed associations in AssociationsStore
2. **Registration**: Controlled accounts are registered in CCResolver with a unique ID
3. **Verification**: CCResolver validates signatures in real-time when queried
4. **ENS Resolution**: Query via ENS text records using the format `eth.ecs.controlled-accounts:<id>`

## Key Features

- ✅ Implements IExtendedResolver for ENS compatibility
- ✅ Returns YAML-formatted data
- ✅ Uses ERC-7930 Interoperable Address format
- ✅ Real-time signature verification via AssociationsStore
- ✅ Updatable text record prefix (owner-controlled)
- ✅ Supports K1 (secp256k1) and ERC-1271 signatures

## References

- [CCResolver v0.1.0 Documentation](https://github.com/nxt3d/AssociatedAccounts)
- [Resolver-Info Standard](https://github.com/nxt3d/ensips/blob/resolver-info-metadata/ensips/resolver-info-text-record.md)
- [ERC-8092: Associated Accounts](https://github.com/ethereum/ERCs/pull/1377)
- [ERC-7930: Interoperable Address Format](https://eips.ethereum.org/EIPS/eip-7930)
- [EIP-712: Typed Data Signing](https://eips.ethereum.org/EIPS/eip-712)
- [ENSIP-5: Text Records](https://docs.ens.domains/ensip/5)
- [ENSIP-10: Extended Resolver](https://docs.ens.domains/ensip/10)

