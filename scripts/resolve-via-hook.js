import { 
  createECSClient, 
  sepolia,
  getResolverInfo, 
  resolveCredential 
} from '../lib/ecsjs.js'

// Create a client for Sepolia
const client = createECSClient({
  chain: sepolia,
  rpcUrl: 'https://eth-sepolia.g.alchemy.com/v2/0rXVfxycbHEigHX96u1p-G02VKeV2AS5'
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
  
  // Step 3: Verify resolver in ENS Registry
  console.log(`\nStep 3: Verify resolver in ENS Registry...`)
  const ensResolver = await client.getEnsResolver({ name: fullName })
  const ensResolverAddress = ensResolver?.address || '0x0000000000000000000000000000000000000000'
  console.log(`   ✅ ENS Resolver: ${ensResolverAddress}`)
  
  if (ensResolverAddress.toLowerCase() !== resolverAddress.toLowerCase()) {
    console.log(`   ⚠️  Warning: Resolver mismatch!`)
    console.log(`      Expected: ${resolverAddress}`)
    console.log(`      Found: ${ensResolverAddress}`)
  }
  
  // Step 4: Query text record using ENS method
  console.log(`\nStep 4: Query credential using ecsjs...`)
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
// hook("text(bytes32,string)", 0xB5D67A9bEf2052cC600f391A3997D46854cabC22)
const resolverAddress = '0xB5D67A9bEf2052cC600f391A3997D46854cabC22'
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

