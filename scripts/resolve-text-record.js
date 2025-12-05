import { createECSClient, sepolia } from '@nxt3d/ecsjs'

// Create a client for Sepolia
const client = createECSClient({
  chain: sepolia,
  rpcUrl: 'https://eth-sepolia.g.alchemy.com/v2/0rXVfxycbHEigHX96u1p-G02VKeV2AS5'
})

async function resolveTextRecord(name, key) {
  console.log(`\nResolving text record for: ${name}`)
  console.log(`Key: ${key}`)
  console.log('---')
  
  // Get resolver address using ENS method
  const resolverAddress = await client.getEnsResolver({ name })
  console.log(`Resolver: ${resolverAddress?.address || 'None'}`)
  
  if (!resolverAddress || resolverAddress.address === '0x0000000000000000000000000000000000000000') {
    console.log('❌ No resolver set for this name')
    return null
  }
  
  // Query text record using ENS method
  const textValue = await client.getEnsText({ name, key })
  
  console.log(`\n✅ Text Record Value: "${textValue}"`)
  return textValue
}

// Resolve the credential record
const name = 'name-stars.ecs.eth'
const key = 'eth.ecs.name-stars.starts:vitalik.eth'

resolveTextRecord(name, key)
  .then(() => {
    console.log('\n✅ Resolution complete!')
    process.exit(0)
  })
  .catch((error) => {
    console.error('\n❌ Error:', error)
    process.exit(1)
  })

