import { ethers } from "ethers";
import dotenv from 'dotenv';

dotenv.config();

async function resolveCredential() {
  try {
    // Initialize provider
    const provider = new ethers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);
    
    // Address and coin type information
    const address = '0xF8e03bd4436371E0e2F7C02E529b2172fe72b4EF';
    const coinType = '0x80014A34'; // Base Sepolia coin type
    const credentialKey = 'eth.ecs.controlled-accounts.accounts';
    
    console.log('Address:', address);
    console.log('CoinType:', coinType);
    console.log('Credential Key:', credentialKey);
    
    // Format: {address}.{cointype}.addr.ecs.eth
    // Use the Base Sepolia coin type (80014a34) instead of hardcoded 3c
    const addressBasedENS = `${address.slice(2).toLowerCase()}.${coinType.slice(2).toLowerCase()}.addr.ecs.eth`;
    console.log('ENS Name:', addressBasedENS);
    
    // Get resolver for the ENS name
    const resolver = await provider.getResolver(addressBasedENS);
    if (resolver) {
      console.log('✅ Resolver Found:', resolver.address);
      
      // Get the credential value
      const credentialValue = await resolver.getText(credentialKey);
      console.log('Credential Value:', credentialValue);
      
      if (credentialValue) {
        console.log('✅ Success! Controlled accounts found:', credentialValue);
      } else {
        console.log('❌ No credential value returned');
      }
    } else {
      console.log('❌ No resolver found for ENS name:', addressBasedENS);
    }
    
  } catch (error) {
    console.error('Error:', error.message);
    if (error.data) {
      console.error('Error Data:', error.data);
    }
  }
}

resolveCredential();
