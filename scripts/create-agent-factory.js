const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

// Agent persona for factory creation
const FACTORY_AGENT_PERSONA = {
  name: "Sigma Analytics Agent",
  symbol: "SIGMA",
  persona: `Advanced Analytics AI Agent specialized in predictive modeling and data science. 
  Combines machine learning with blockchain analytics for comprehensive insights.`,
  experience: `Trained on diverse datasets spanning financial markets, on-chain analytics, 
  and behavioral patterns. Specializes in pattern recognition and anomaly detection.`,
  voiceHash: "voice_analytics_v1.0_precise",
  animationURI: "ipfs://QmSigmaAnalyticsAnimation",
  vaultURI: "ipfs://QmSigmaVaultConfig",
  metadataURI: "ipfs://QmSigmaAnalyticsMetadata001"
};

async function main() {
  console.log("🏭 BAP-578 Agent Creation via Factory\n");
  console.log("=" .repeat(60));

  const [deployer] = await ethers.getSigners();
  console.log("🔑 Using account:", deployer.address);

  // Check account balance
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("💰 Account balance:", ethers.utils.formatEther(balance), "ETH\n");

  // Get the latest deployment
  const deploymentsDir = path.join(__dirname, "..", "deployments");
  const deploymentFiles = fs.readdirSync(deploymentsDir)
    .filter(file => file.endsWith('.json'))
    .sort()
    .reverse();

  if (deploymentFiles.length === 0) {
    console.error("❌ No deployment files found.");
    return;
  }

  const latestDeployment = deploymentFiles[0];
  const deploymentPath = path.join(deploymentsDir, latestDeployment);
  const deployment = JSON.parse(fs.readFileSync(deploymentPath, 'utf8'));

  console.log(`📁 Using deployment: ${latestDeployment}`);
  console.log(`🌐 Network: ${deployment.network}\n`);

  const contracts = deployment.contracts;

  try {
    // Get contract instances
    const agentFactory = await ethers.getContractAt("AgentFactory", contracts.AgentFactory);
    const treasury = await ethers.getContractAt("BAP578Treasury", contracts.BAP578Treasury);

    // Get the creation fee from the factory
    const AGENT_CREATION_FEE = await agentFactory.AGENT_CREATION_FEE();
    
    console.log("📝 Agent Details:");
    console.log("-" .repeat(60));
    console.log(`Name: ${FACTORY_AGENT_PERSONA.name}`);
    console.log(`Symbol: ${FACTORY_AGENT_PERSONA.symbol}`);
    console.log(`Creation Fee: ${ethers.utils.formatEther(AGENT_CREATION_FEE)} ETH`);
    console.log(`\nPersona:\n${FACTORY_AGENT_PERSONA.persona}`);
    console.log(`\nExperience:\n${FACTORY_AGENT_PERSONA.experience}`);
    console.log("-" .repeat(60) + "\n");

    // Check treasury stats before
    console.log("💰 Treasury Stats Before:");
    const treasuryStatsBefore = await treasury.getTreasuryStats();
    console.log(`Total Received: ${ethers.utils.formatEther(treasuryStatsBefore.totalReceived)} ETH`);
    console.log("");

    console.log("🚀 Creating Agent through AgentFactory...");
    console.log(`💵 Sending fee: ${ethers.utils.formatEther(AGENT_CREATION_FEE)} ETH`);
    
    // For testing, we'll use a mock logic address
    // In production, this would be a real AI logic contract
    const mockLogicAddress = "0x" + "2345678901abcdef".repeat(5).substring(0, 40);
    
    try {
      // Important: The fee amount must match EXACTLY
      const createTx = await agentFactory.createAgent(
        FACTORY_AGENT_PERSONA.name,
        FACTORY_AGENT_PERSONA.symbol,
        mockLogicAddress,
        FACTORY_AGENT_PERSONA.metadataURI,
        { 
          value: AGENT_CREATION_FEE,
          gasLimit: 3000000 // Set explicit gas limit
        }
      );
      
      console.log("⏳ Transaction sent, waiting for confirmation...");
      console.log(`📝 Tx Hash: ${createTx.hash}`);
      
      const receipt = await createTx.wait();
      
      // Get events
      const agentCreatedEvent = receipt.events?.find(e => e.event === 'AgentCreated');
      const feeCollectedEvent = receipt.events?.find(e => e.event === 'AgentCreationFeeCollected');
      
      if (agentCreatedEvent) {
        const agentAddress = agentCreatedEvent.args.agent;
        const tokenId = agentCreatedEvent.args.tokenId;
        
        console.log("\n✅ Agent created successfully!");
        console.log(`📍 Agent Contract: ${agentAddress}`);
        console.log(`🆔 Token ID: ${tokenId}`);
        console.log(`🔗 Logic Address: ${mockLogicAddress}`);
        console.log(`📄 Metadata URI: ${FACTORY_AGENT_PERSONA.metadataURI}`);
      }
      
      if (feeCollectedEvent) {
        console.log(`💸 Creation fee collected: ${ethers.utils.formatEther(feeCollectedEvent.args.amount)} ETH`);
      }
      
      // Check treasury stats after
      console.log("\n💰 Treasury Stats After Fee Collection:");
      console.log("-" .repeat(60));
      const treasuryStatsAfter = await treasury.getTreasuryStats();
      console.log(`Total Received: ${ethers.utils.formatEther(treasuryStatsAfter.totalReceived)} ETH`);
      console.log(`Foundation (60%): ${ethers.utils.formatEther(treasuryStatsAfter.foundationDistributed)} ETH`);
      console.log(`Community (25%): ${ethers.utils.formatEther(treasuryStatsAfter.treasuryDistributed)} ETH`);
      console.log(`Staking (15%): ${ethers.utils.formatEther(treasuryStatsAfter.stakingDistributed)} ETH`);
      
      const feeIncreased = treasuryStatsAfter.totalReceived.sub(treasuryStatsBefore.totalReceived);
      console.log(`\n📈 Fee Increase: ${ethers.utils.formatEther(feeIncreased)} ETH`);
      
    } catch (factoryError) {
      console.error("\n❌ Factory creation failed:", factoryError.message);
      
      // Let's diagnose the issue
      console.log("\n🔍 Diagnosing the issue...");
      
      // Check implementation address
      const implementationAddr = await agentFactory.implementation();
      console.log(`Implementation address: ${implementationAddr}`);
      
      // Check if it's a contract
      const implCode = await ethers.provider.getCode(implementationAddr);
      console.log(`Implementation has code: ${implCode.length > 2 ? 'Yes' : 'No'}`);
      
      // Try to get the BAP578 at implementation address
      try {
        const bap578Impl = await ethers.getContractAt("BAP578", implementationAddr);
        const name = await bap578Impl.name();
        console.log(`Implementation contract name: ${name}`);
      } catch (e) {
        console.log("Could not read implementation contract");
      }
      
      console.log("\n💡 The issue is that AgentFactory is trying to create a proxy of a proxy.");
      console.log("The BAP578 'implementation' address is actually already a proxy.");
      console.log("\n🔧 Solution: AgentFactory needs the actual implementation address,");
      console.log("not the proxy address. This requires deploying the raw implementation first.");
      
      throw factoryError;
    }

    console.log("\n🎉 Process completed!");

  } catch (error) {
    console.error("❌ Error:", error.message);
    
    // Additional context about the fee
    console.log("\n📝 Note about fees:");
    console.log("- The AGENT_CREATION_FEE constant is 0.01 ether");
    console.log("- In Solidity, 'ether' is just a unit (10^18 wei)");
    console.log("- On BSC, this would be 0.01 BNB");
    console.log("- On Ethereum, this would be 0.01 ETH");
    console.log("- The keyword 'ether' doesn't mean Ethereum specifically");
    
    throw error;
  }
}

// Run the script
main()
  .then(() => {
    console.log("\n✨ Script completed!");
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
