import { 
  createECSClient, 
  sepolia,
  getResolverInfo, 
  resolveCredential 
} from '../lib/ecsjs.js'

const client = createECSClient({
  chain: sepolia,
  rpcUrl: 'https://eth-sepolia.g.alchemy.com/v2/0rXVfxycbHEigHX96u1p-G02VKeV2AS5'
})

console.log('🔍 Testing ECS Query Examples')
console.log('='.repeat(50))

try {
  const resolverAddress = '0x03eb9Bf23c828E3891A8fE3cB484A7ca769B985e'
  const credentialKey = 'eth.ecs.name-stars.starts:vitalik.eth'

  // Get label from resolver address (for Hooks)
  console.log('\n1. Get label from resolver address...')
  const { label, resolverUpdated } = await getResolverInfo(client, resolverAddress)
  console.log(`   ✅ Label: "${label}"`)
  console.log(`   ✅ Updated: ${resolverUpdated}`)

  // Query credential using ecsjs
  console.log('\n2. Query credential using ecsjs...')
  console.log(`   Resolver: ${resolverAddress}`)
  console.log(`   Key: ${credentialKey}`)

  const credential = await resolveCredential(client, resolverAddress, credentialKey)
  console.log(`   ✅ Value: "${credential}"`)

  console.log('\n' + '='.repeat(50))
  console.log('✅ All queries successful!')
  process.exit(0)
} catch (error) {
  console.error('\n❌ Error:', error.message)
  process.exit(1)
}

