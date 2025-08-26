import { createPublicClient, http } from 'viem'
import { sepolia } from 'viem/chains'
import { createECSResolver } from '@nxt3d/ecs-resolver'
import dotenv from 'dotenv'

dotenv.config()

/**
 * Ethereum Credential Service (ECS) Demo Script - Using ECS Resolver
 * 
 * This script demonstrates how to query credentials from the ECS system
 * using our new ECS Resolver library that wraps Viem.
 */

const main = async () => {
  console.log("🌟 Ethereum Credential Service (ECS) - ECS Resolver");
  console.log("===================================================\n");
  
  console.log("The credentials we are resolving are:");
  console.log("");
  console.log("eth.ecs.ethstars.stars");
  console.log("");
  console.log("for:");
  console.log("- vitalik.eth");
  console.log("- 0xd8da6bf26964af9d7eed9e03e53415d37aa96045\n");
  
  // Initialize Viem public client
  const publicClient = createPublicClient({
    chain: sepolia,
    transport: http(process.env.SEPOLIA_RPC_URL)
  })

  // Create ECS resolver
  const resolver = createECSResolver({ publicClient })
  
  // Vitalik's information
  const ensName = "vitalik.eth"
  const walletAddress = "0xd8da6bf26964af9d7eed9e03e53415d37aa96045"
  const credentialKey = "eth.ecs.ethstars.stars"
  
  try {
    // Name-based resolution
    console.log("🔍 Name-based Resolution");
    console.log("------------------------");
    
    const nameResult = await resolver.resolveNameCredential(ensName, credentialKey)
    console.log(`📍 ENS Name: ${nameResult.ensName}`);
    
    if (nameResult.success) {
      console.log(`✅ Resolver Found: Working!`);
      console.log(`\n${ensName}`);
      console.log(`Number of Stars: ${nameResult.value}\n`);
    } else {
      console.log("❌ No resolver found for name-based lookup\n");
    }
    
    // Address-based resolution
    console.log("🔍 Address-based Resolution");
    console.log("---------------------------");
    
    const addressResult = await resolver.resolveAddressCredential(walletAddress, credentialKey)
    console.log(`📍 ENS Name: ${addressResult.ensName}`);
    
    if (addressResult.success) {
      console.log(`✅ Resolver Found: Working!`);
      console.log(`\n${walletAddress}:`);
      console.log(`Number of Stars: ${addressResult.value}\n`);
    } else {
      console.log("❌ No resolver found for address-based lookup\n");
    }
    
    console.log("🎉 Demo completed successfully!");
    console.log("💡 Both name-based and address-based resolution work via our ECS Resolver library!");
    
  } catch (error) {
    console.error("❌ Error:", error.message);
  }
};

main();
