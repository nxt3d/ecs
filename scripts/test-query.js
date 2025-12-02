import { createPublicClient, http } from 'viem'
import { sepolia } from 'viem/chains'

const client = createPublicClient({
  chain: sepolia,
  transport: http('https://eth-sepolia.g.alchemy.com/v2/0rXVfxycbHEigHX96u1p-G02VKeV2AS5')
})

console.log('🔍 Testing ECS Query Examples')
console.log('='.repeat(50))

try {
  // Get label from resolver address (for Hooks)
  console.log('\n1. Get label from resolver address...')
  const label = await client.readContract({
    address: '0x016BfbF42131004401ABdfe208F17A1620faB742',
    abi: [{
      name: 'getLabelByResolver',
      type: 'function',
      inputs: [{ name: 'resolver_', type: 'address' }],
      outputs: [{ name: '', type: 'string' }]
    }],
    functionName: 'getLabelByResolver',
    args: ['0x03eb9Bf23c828E3891A8fE3cB484A7ca769B985e']
  })
  console.log(`   ✅ Label: "${label}"`)

  // Query credential using ENS methods
  console.log('\n2. Query credential using ENS method...')
  const ensName = `${label}.ecs.eth`
  const credentialKey = 'eth.ecs.name-stars.starts:vitalik.eth'

  console.log(`   ENS Name: ${ensName}`)
  console.log(`   Key: ${credentialKey}`)

  const credential = await client.getEnsText({
    name: ensName,
    key: credentialKey
  })
  console.log(`   ✅ Value: "${credential}"`)

  console.log('\n' + '='.repeat(50))
  console.log('✅ All queries successful!')
  process.exit(0)
} catch (error) {
  console.error('\n❌ Error:', error.message)
  process.exit(1)
}

