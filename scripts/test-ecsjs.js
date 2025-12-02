import { 
  createECSClient, 
  sepolia,
  getLabelByResolver, 
  resolveCredential 
} from '../lib/ecsjs.js'

const client = createECSClient({
  chain: sepolia,
  rpcUrl: 'https://eth-sepolia.g.alchemy.com/v2/0rXVfxycbHEigHX96u1p-G02VKeV2AS5'
})

console.log('🧪 Testing ecsjs library')
console.log('='.repeat(50))

try {
  // Example 1: Get label from resolver address
  console.log('\n1. Get label from resolver address...')
  const resolverAddress = '0x03eb9Bf23c828E3891A8fE3cB484A7ca769B985e'
  const label = await getLabelByResolver(client, resolverAddress)
  console.log(`   ✅ Label: "${label}"`)

  // Example 2: Resolve credential
  console.log('\n2. Resolve credential...')
  const credentialKey = 'eth.ecs.name-stars.starts:vitalik.eth'
  const value = await resolveCredential(client, resolverAddress, credentialKey)
  console.log(`   Key: ${credentialKey}`)
  console.log(`   ✅ Value: "${value}"`)

  console.log('\n' + '='.repeat(50))
  console.log('✅ All tests passed!')
  process.exit(0)
} catch (error) {
  console.error('\n❌ Error:', error.message)
  process.exit(1)
}

