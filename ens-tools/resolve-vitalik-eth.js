import { ethers } from "ethers";
import dotenv from "dotenv";

dotenv.config();

/**
 * Ethereum Credential Service (ECS) Demo Script
 * 
 * This script demonstrates how to query credentials from the ECS system
 * using ENS (Ethereum Name Service) resolution with CCIP-Read.
 * 
 * The ECS system allows querying credentials in two ways:
 * 1. Name-based: {name}.name.ecs.eth
 * 2. Address-based: {address}.{cointype}.addr.ecs.eth
 */

const main = async () => {
  console.log("🌟 Ethereum Credential Service (ECS)");
  console.log("====================================\n");
  
  console.log("The credentials we are resolving are:");
  console.log("");
  console.log("eth.ecs.ethstars.stars");
  console.log("");
  console.log("for:");
  console.log("- vitalik.eth");
  console.log("- 0xd8da6bf26964af9d7eed9e03e53415d37aa96045\n");
  
  // Initialize provider
  const provider = new ethers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);
  
  // Vitalik's information
  const ensName = "vitalik.eth";
  const walletAddress = "0xd8da6bf26964af9d7eed9e03e53415d37aa96045";
  const textRecordKey = "eth.ecs.ethstars.stars";
  

  
  try {
    // Name-based resolution
    console.log("🔍 Name-based Resolution");
    console.log("------------------------");
    
    const nameBasedENS = `${ensName}.name.ecs.eth`;
    console.log(`📍 ENS Name: ${nameBasedENS}`);
    
    const nameResolver = await provider.getResolver(nameBasedENS);
    if (nameResolver) {
      console.log(`✅ Resolver Found: ${nameResolver.address}`);
      const nameStars = await nameResolver.getText(textRecordKey);
      console.log(`\n${ensName}`);
      console.log(`Number of Stars: ${nameStars}\n`);
    } else {
      console.log("❌ No resolver found for name-based lookup\n");
    }
    
    // Address-based resolution
    console.log("🔍 Address-based Resolution");
    console.log("---------------------------");
    
    // Format: {address}.{cointype}.addr.ecs.eth
    // Coin type 3c = Ethereum (60 in decimal = 3c in hex)
    const addressBasedENS = `${walletAddress.slice(2).toLowerCase()}.3c.addr.ecs.eth`;
    console.log(`📍 ENS Name: ${addressBasedENS}`);
    
    const addressResolver = await provider.getResolver(addressBasedENS);
    if (addressResolver) {
      console.log(`✅ Resolver Found: ${addressResolver.address}`);
      const addressStars = await addressResolver.getText(textRecordKey);
      console.log(`\n${walletAddress}:`);
      console.log(`Number of Stars: ${addressStars}\n`);
    } else {
      console.log("❌ No resolver found for address-based lookup\n");
    }
    
    console.log("🎉 Demo completed successfully!");
    console.log("💡 Both name-based and address-based resolution work via CCIP-Read");
    
  } catch (error) {
    console.error("❌ Error:", error.message);
  }
};

main();
