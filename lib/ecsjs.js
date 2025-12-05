/**
 * ecsjs - Ethereum Credential Service JavaScript Library
 * A simple library for interacting with ECS V2
 */

import { createPublicClient, http } from 'viem'
import { mainnet, sepolia } from 'viem/chains'

// Re-export viem utilities
export { http, mainnet, sepolia }

// Known ECS Registry addresses by chain
const ECS_REGISTRY_ADDRESSES = {
  1: '0x0000000000000000000000000000000000000000', // Mainnet (not deployed yet)
  11155111: '0x016BfbF42131004401ABdfe208F17A1620faB742' // Sepolia
}

/**
 * Create a client for interacting with ECS
 * @param {Object} config - Client configuration
 * @param {Object} config.chain - Chain to connect to (e.g., sepolia, mainnet)
 * @param {string} config.rpcUrl - RPC URL for the chain
 * @returns {Object} Viem public client
 */
export function createECSClient({ chain, rpcUrl }) {
  return createPublicClient({
    chain,
    transport: http(rpcUrl)
  })
}

// ECS Registry ABI
const ECS_REGISTRY_ABI = [
  {
    name: 'getResolverInfo',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'resolver_', type: 'address' }],
    outputs: [
      { name: 'label', type: 'string' },
      { name: 'resolverUpdated', type: 'uint128' }
    ]
  }
]

/**
 * Get the resolver info associated with a resolver address
 * @param {Object} client - Viem public client
 * @param {string} resolverAddress - The resolver address
 * @returns {Promise<Object>} The resolver info { label, resolverUpdated }
 */
export async function getResolverInfo(client, resolverAddress) {
  const chainId = client.chain.id
  const registryAddress = ECS_REGISTRY_ADDRESSES[chainId]
  
  if (!registryAddress || registryAddress === '0x0000000000000000000000000000000000000000') {
    throw new Error(`ECS Registry not deployed on chain ${chainId}`)
  }
  
  const [label, resolverUpdated] = await client.readContract({
    address: registryAddress,
    abi: ECS_REGISTRY_ABI,
    functionName: 'getResolverInfo',
    args: [resolverAddress]
  })
  
  return { label, resolverUpdated }
}

/**
 * Resolve a credential from a resolver address
 * @param {Object} client - Viem public client
 * @param {string} resolverAddress - The resolver address
 * @param {string} credentialKey - The credential key (e.g., "eth.ecs.name-stars.starts:vitalik.eth")
 * @returns {Promise<string>} The credential value
 */
export async function resolveCredential(client, resolverAddress, credentialKey) {
  // Get the label for this resolver
  const { label } = await getResolverInfo(client, resolverAddress)
  
  // Construct the ENS name
  const ensName = `${label}.ecs.eth`
  
  // Resolve the credential using ENS
  const value = await client.getEnsText({
    name: ensName,
    key: credentialKey
  })
  
  return value
}

/**
 * Get the ECS Registry address for a given chain
 * @param {number} chainId - The chain ID
 * @returns {string} The registry address
 */
export function getRegistryAddress(chainId) {
  return ECS_REGISTRY_ADDRESSES[chainId] || '0x0000000000000000000000000000000000000000'
}

