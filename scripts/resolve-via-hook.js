import { 
  createECSClient, 
  sepolia,
  getResolverInfo, 
  resolveCredential 
} from '@nxt3d/ecsjs'

// Create a client for Sepolia
const client = createECSClient({
  chain: sepolia,
  rpcUrl: process.env.SEPOLIA_RPC_URL || 'https://ethereum-sepolia-rpc.publicnode.com'
})

async function resolveViaHook(resolverAddress, credentialKey) {
  console.log('\n🔗 ENS Hooks Resolution Flow')
  console.log('=' .repeat(50))
  console.log(`\n📍 Starting with resolver address: ${resolverAddress}`)
  console.log(`🔑 Credential key: ${credentialKey}\n`)
  
  // Step 1: Get label from ECS Registry using ecsjs
  console.log('Step 1: Query ECS Registry for label...')
  const { label, resolverUpdated } = await getResolverInfo(client, resolverAddress)
  console.log(`   ✅ Label: "${label}"`)
  console.log(`   ✅ Updated: ${resolverUpdated}`)
  
  // Step 2: Construct full ENS name
  const fullName = `${label}.ecs.eth`
  console.log(`\nStep 2: Construct full ENS name...`)
  console.log(`   ✅ Full name: ${fullName}`)
  
  console.log(`\nStep 3: Query credential using ecsjs...`)
  const textValue = await resolveCredential(client, resolverAddress, credentialKey)
  console.log(`   ✅ Text Record Value: "${textValue}"`)
  
  console.log('\n' + '='.repeat(50))
  console.log('🎉 Resolution Complete!')
  console.log(`\n📊 Summary:`)
  console.log(`   Resolver: ${resolverAddress}`)
  console.log(`   Label: ${label}`)
  console.log(`   Full Name: ${fullName}`)
  console.log(`   Key: ${credentialKey}`)
  console.log(`   Value: "${textValue}"`)
  console.log('=' .repeat(50) + '\n')
  
  return {
    resolver: resolverAddress,
    label,
    fullName,
    key: credentialKey,
    value: textValue
  }
}

// Example: User has a Hook pointing to this resolver
// hook("text(bytes32,string)", 0x9773397bd9366D80dAE708CA4C4413Abf88B3DAa)
const resolverAddress = '0x9773397bd9366D80dAE708CA4C4413Abf88B3DAa'
const credentialKey = 'eth.ecs.name-stars.starts:vitalik.eth'

resolveViaHook(resolverAddress, credentialKey)
  .then(() => {
    console.log('✅ Hook resolution flow complete!')
    process.exit(0)
  })
  .catch((error) => {
    console.error('\n❌ Error:', error)
    process.exit(1)
  })

