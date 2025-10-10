const { ethers } = require("ethers");
const fs = require("fs");
const path = require("path");

// Example script for minting agents using deployed ABIs
// Fixes the "unconfigured name" error

async function mintAgent() {
  try {
    // 1. Configure your provider properly
    // For local network
    const provider = new ethers.JsonRpcProvider("http://localhost:8545");
    
    // For testnet/mainnet (example with BSC testnet)
    // const provider = new ethers.JsonRpcProvider("https://data-seed-prebsc-1-s1.binance.org:8545/");
    
    // 2. Set up signer (use private key or mnemonic)
    // IMPORTANT: Never hardcode private keys in production!
    const privateKey = process.env.PRIVATE_KEY || "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"; // Default hardhat account #0
    const signer = new ethers.Wallet(privateKey, provider);
    
    console.log("Minting with account:", signer.address);
    
    // 3. Load the contract ABI
    const contractPath = path.join(__dirname, "../artifacts/contracts/BAP578.sol/BAP578.json");
    const contractJson = JSON.parse(fs.readFileSync(contractPath, "utf8"));
    const abi = contractJson.abi;
    
    // 4. Get contract address from deployment
    const deploymentsDir = path.join(__dirname, "../deployments");
    const deploymentFiles = fs.readdirSync(deploymentsDir)
      .filter(file => file.endsWith('.json'))
      .sort()
      .reverse();
    
    if (deploymentFiles.length === 0) {
      throw new Error("No deployment files found");
    }
    
    const latestDeployment = deploymentFiles[0];
    const deployment = JSON.parse(fs.readFileSync(path.join(deploymentsDir, latestDeployment), 'utf8'));
    
    // Use the main BAP578 proxy address
    const contractAddress = deployment.contracts.BAP578;
    console.log("Using BAP578 contract at:", contractAddress);
    
    // 5. Create contract instance
    const bap578 = new ethers.Contract(contractAddress, abi, signer);
    
    // 6. Prepare agent metadata
    const agentMetadata = {
      persona: "Test Agent Persona",
      experience: "Test Experience",
      voiceHash: "voice_test_v1",
      animationURI: "ipfs://TestAnimation",
      vaultURI: "ipfs://TestVault",
      vaultHash: ethers.encodeBytes32String("test-vault-hash")
    };
    
    // 7. Call the createAgent function
    console.log("Minting agent...");
    
    // Method 1: Using the overloaded function with extended metadata
    const tx = await bap578["createAgent(address,address,string,(string,string,string,string,string,bytes32))"](
      signer.address, // owner
      "0x1234567890123456789012345678901234567890", // mock logic address
      "ipfs://TestAgentMetadata", // metadata URI
      agentMetadata // extended metadata struct
    );
    
    // Method 2: Using the simple function (no extended metadata)
    // const tx = await bap578["createAgent(address,address,string)"](
    //   signer.address, // owner
    //   "0x1234567890123456789012345678901234567890", // mock logic address
    //   "ipfs://TestAgentMetadata" // metadata URI
    // );
    
    console.log("Transaction sent:", tx.hash);
    const receipt = await tx.wait();
    console.log("Transaction confirmed!");
    
    // Get token ID from Transfer event
    const transferEvent = receipt.logs.find(
      log => log.topics[0] === ethers.id("Transfer(address,address,uint256)")
    );
    
    if (transferEvent) {
      const tokenId = ethers.toBigInt(transferEvent.topics[3]);
      console.log("✅ Agent minted successfully!");
      console.log("Token ID:", tokenId.toString());
      
      // Get agent state
      const state = await bap578.getState(tokenId);
      console.log("\nAgent State:");
      console.log("- Owner:", state.owner);
      console.log("- Status:", ["Paused", "Active", "Terminated"][state.status]);
      console.log("- Logic Address:", state.logicAddress);
      console.log("- Balance:", ethers.formatEther(state.balance), "ETH");
    }
    
  } catch (error) {
    console.error("Error minting agent:", error);
    
    // Specific error handling
    if (error.message.includes("UNCONFIGURED_NAME")) {
      console.log("\n❌ Network Configuration Error!");
      console.log("Solution: Make sure your provider is configured correctly.");
      console.log("Example fixes:");
      console.log('1. Use JsonRpcProvider: new ethers.JsonRpcProvider("http://localhost:8545")');
      console.log('2. For Hardhat: await ethers.provider.getNetwork()');
      console.log('3. Specify chainId explicitly: { chainId: 31337 }');
    } else if (error.message.includes("CALL_EXCEPTION")) {
      console.log("\n❌ Contract Call Error!");
      console.log("Possible causes:");
      console.log("1. Wrong contract address");
      console.log("2. Contract not deployed");
      console.log("3. Incorrect function parameters");
      console.log("4. Insufficient permissions");
    }
  }
}

// Alternative: Using Hardhat Runtime Environment
async function mintAgentWithHardhat() {
  const { ethers } = require("hardhat");
  
  try {
    // This automatically configures the network
    const [signer] = await ethers.getSigners();
    console.log("Minting with account:", signer.address);
    
    // Load deployment
    const deploymentsDir = path.join(__dirname, "../deployments");
    const deploymentFiles = fs.readdirSync(deploymentsDir)
      .filter(file => file.endsWith('.json'))
      .sort()
      .reverse();
    
    const latestDeployment = deploymentFiles[0];
    const deployment = JSON.parse(fs.readFileSync(path.join(deploymentsDir, latestDeployment), 'utf8'));
    
    // Get contract
    const bap578 = await ethers.getContractAt("BAP578", deployment.contracts.BAP578);
    
    // Mint agent
    const tx = await bap578["createAgent(address,address,string)"](
      signer.address,
      "0x1234567890123456789012345678901234567890",
      "ipfs://TestAgentMetadata"
    );
    
    const receipt = await tx.wait();
    console.log("✅ Agent minted successfully!");
    
  } catch (error) {
    console.error("Error:", error);
  }
}

// Check if running directly or through Hardhat
if (require.main === module) {
  // Check if hardhat is available
  try {
    require("hardhat");
    console.log("Using Hardhat environment...\n");
    mintAgentWithHardhat()
      .then(() => process.exit(0))
      .catch(error => {
        console.error(error);
        process.exit(1);
      });
  } catch {
    console.log("Using standalone ethers.js...\n");
    mintAgent()
      .then(() => process.exit(0))
      .catch(error => {
        console.error(error);
        process.exit(1);
      });
  }
}

module.exports = { mintAgent, mintAgentWithHardhat };
