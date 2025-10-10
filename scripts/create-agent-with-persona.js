const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

// Mockup personas for different agent types
const AGENT_PERSONAS = {
  "research-analyst": {
    name: "Atlas Research Agent",
    symbol: "ATLAS",
    persona: `Research Analyst AI Agent specialized in market analysis and data interpretation. 
    Core competencies include: technical analysis, fundamental research, trend identification, 
    and automated report generation. Designed to provide data-driven insights with high accuracy.`,
    experience: `Trained on 5+ years of market data across multiple asset classes. 
    Successfully analyzed over 10,000 market events with 85% accuracy rate. 
    Specialized in DeFi protocols, NFT markets, and emerging blockchain technologies.`,
    voiceHash: "voice_research_v1.0_analytical_professional",
    animationURI: "ipfs://QmResearchAgentAnimation3D",
    vaultURI: "ipfs://QmResearchAgentVaultConfig",
    metadataURI: "ipfs://QmAtlasResearchAgentMetadata001",
    knowledgeSources: [
      {
        uri: "ipfs://QmMarketDataAnalysis2024",
        type: 0, // BASE
        priority: 100,
        description: "Core market analysis algorithms and patterns"
      },
      {
        uri: "ipfs://QmDeFiProtocolsKnowledge",
        type: 1, // CONTEXT
        priority: 90,
        description: "DeFi protocols and smart contract interaction patterns"
      },
      {
        uri: "ipfs://QmHistoricalMarketEvents",
        type: 2, // MEMORY
        priority: 80,
        description: "Historical market events and outcomes database"
      }
    ]
  },
  "creative-artist": {
    name: "Nova Creative Agent",
    symbol: "NOVA",
    persona: `Creative AI Agent focused on generative art and NFT creation. 
    Specializes in conceptual design, style transfer, and multimodal content generation. 
    Capable of creating unique digital artworks based on prompts and market trends.`,
    experience: `Generated over 50,000 unique artworks across various styles. 
    Collaborated with 100+ human artists. Expertise in surrealism, cyberpunk, 
    abstract expressionism, and emerging digital art movements.`,
    voiceHash: "voice_creative_v1.0_expressive_artistic",
    animationURI: "ipfs://QmNovaCreativeAnimation",
    vaultURI: "ipfs://QmNovaVaultConfiguration",
    metadataURI: "ipfs://QmNovaCreativeAgentMetadata001",
    knowledgeSources: [
      {
        uri: "ipfs://QmArtHistoryDatabase",
        type: 0, // BASE
        priority: 100,
        description: "Comprehensive art history and style database"
      },
      {
        uri: "ipfs://QmGenerativeAlgorithms",
        type: 3, // INSTRUCTION
        priority: 95,
        description: "Advanced generative art algorithms and techniques"
      },
      {
        uri: "ipfs://QmTrendAnalysisModule",
        type: 5, // DYNAMIC
        priority: 70,
        description: "Real-time art trend analysis and adaptation module"
      }
    ]
  },
  "defi-trader": {
    name: "Quantum DeFi Agent",
    symbol: "QUANTUM",
    persona: `Autonomous DeFi Trading Agent with advanced arbitrage detection and risk management. 
    Executes complex trading strategies across multiple protocols. Features MEV protection, 
    slippage optimization, and automated yield farming capabilities.`,
    experience: `Executed $10M+ in trading volume with consistent positive returns. 
    Specialized in cross-chain arbitrage, liquidity provision, and yield optimization. 
    Average APY: 45% with risk-adjusted Sharpe ratio of 2.3.`,
    voiceHash: "voice_trader_v1.0_precise_analytical",
    animationURI: "ipfs://QmQuantumTraderVisualization",
    vaultURI: "ipfs://QmQuantumSecureVault",
    metadataURI: "ipfs://QmQuantumDeFiAgentMetadata001",
    knowledgeSources: [
      {
        uri: "ipfs://QmTradingStrategiesCore",
        type: 0, // BASE
        priority: 100,
        description: "Core trading strategies and risk models"
      },
      {
        uri: "ipfs://QmProtocolIntegrations",
        type: 1, // CONTEXT
        priority: 95,
        description: "Multi-protocol integration and interaction patterns"
      },
      {
        uri: "ipfs://QmMarketMicrostructure",
        type: 4, // REFERENCE
        priority: 85,
        description: "Market microstructure and MEV analysis"
      },
      {
        uri: "ipfs://QmRealTimeMarketData",
        type: 5, // DYNAMIC
        priority: 90,
        description: "Real-time market data feed and analysis"
      }
    ]
  }
};

async function main() {
  console.log("🤖 BAP-578 Agent Creation with Persona Tool\n");
  console.log("=" .repeat(60));

  const [deployer] = await ethers.getSigners();
  console.log("🔑 Using account:", deployer.address);

  // Check account balance
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("💰 Account balance:", ethers.utils.formatEther(balance), "ETH\n");

  // Get the latest deployment
  const deploymentsDir = path.join(__dirname, "..", "deployments");
  if (!fs.existsSync(deploymentsDir)) {
    console.error("❌ No deployments directory found. Run deployment first.");
    return;
  }

  const deploymentFiles = fs.readdirSync(deploymentsDir)
    .filter(file => file.endsWith('.json'))
    .sort()
    .reverse();

  if (deploymentFiles.length === 0) {
    console.error("❌ No deployment files found. Run deployment first.");
    return;
  }

  const latestDeployment = deploymentFiles[0];
  const deploymentPath = path.join(deploymentsDir, latestDeployment);
  const deployment = JSON.parse(fs.readFileSync(deploymentPath, 'utf8'));

  console.log(`📁 Using deployment: ${latestDeployment}`);
  console.log(`🌐 Network: ${deployment.network}\n`);

  const contracts = deployment.contracts;

  // Select agent persona
  console.log("🎭 Available Agent Personas:");
  console.log("-" .repeat(60));
  Object.keys(AGENT_PERSONAS).forEach((key, index) => {
    const persona = AGENT_PERSONAS[key];
    console.log(`${index + 1}. ${persona.name} (${persona.symbol})`);
    console.log(`   Type: ${key}`);
    console.log(`   Specialty: ${persona.persona.split('.')[0]}`);
  });
  console.log("");

  // For this demo, we'll use the research analyst persona
  const selectedPersonaKey = "research-analyst";
  const selectedPersona = AGENT_PERSONAS[selectedPersonaKey];
  
  console.log(`✅ Selected: ${selectedPersona.name}`);
  console.log("-" .repeat(60));
  console.log("📝 Persona Details:");
  console.log(`Name: ${selectedPersona.name}`);
  console.log(`Symbol: ${selectedPersona.symbol}`);
  console.log(`\nPersona:\n${selectedPersona.persona}`);
  console.log(`\nExperience:\n${selectedPersona.experience}`);
  console.log("-" .repeat(60) + "\n");

  try {
    // Get contract instances
    const agentFactory = await ethers.getContractAt("AgentFactory", contracts.AgentFactory);
    const bap578 = await ethers.getContractAt("BAP578", contracts.BAP578);
    const knowledgeRegistry = contracts.KnowledgeRegistry 
      ? await ethers.getContractAt("KnowledgeRegistry", contracts.KnowledgeRegistry)
      : null;
    const treasury = await ethers.getContractAt("BAP578Treasury", contracts.BAP578Treasury);

    // Create agent directly through BAP578 contract (no fee required for direct creation)
    console.log("🚀 Creating Agent directly through BAP578 contract...");
    
    // Mock logic address (in production, this would be a real logic contract)
    const mockLogicAddress = "0x" + "1234567890abcdef".repeat(5).substring(0, 40);
    
    // Create extended metadata object
    const extendedMetadata = {
      persona: selectedPersona.persona,
      experience: selectedPersona.experience,
      voiceHash: selectedPersona.voiceHash,
      animationURI: selectedPersona.animationURI,
      vaultURI: selectedPersona.vaultURI,
      vaultHash: ethers.utils.formatBytes32String("vault-hash-" + Date.now())
    };
    
    // Create agent directly through BAP578
    const createTx = await bap578["createAgent(address,address,string,(string,string,string,string,string,bytes32))"](
      deployer.address,
      mockLogicAddress,
      selectedPersona.metadataURI,
      extendedMetadata
    );
    
    console.log("⏳ Transaction sent, waiting for confirmation...");
    const receipt = await createTx.wait();
    
    // Get the token ID from the Transfer event (standard ERC721 event)
    const transferEvent = receipt.events?.find(e => e.event === 'Transfer');
    const tokenId = transferEvent?.args?.tokenId || 1;
    
    console.log("✅ Agent created successfully!");
    console.log(`🆔 Token ID: ${tokenId}`);
    console.log(`🔗 Logic Address: ${mockLogicAddress}`);
    console.log(`📄 Metadata URI: ${selectedPersona.metadataURI}`);
    console.log("");

    // Get and display agent state
    const agentState = await bap578.getState(tokenId);
    console.log("📊 Agent State:");
    console.log(`  Owner: ${agentState.owner}`);
    console.log(`  Status: ${["Paused", "Active", "Terminated"][agentState.status]}`);
    console.log(`  Balance: ${ethers.utils.formatEther(agentState.balance)} ETH`);
    console.log(`  Last Action: ${new Date(agentState.lastActionTimestamp * 1000).toISOString()}`);
    console.log("");

    // Add knowledge sources if KnowledgeRegistry is deployed
    if (knowledgeRegistry && selectedPersona.knowledgeSources) {
      console.log("🧠 Adding Knowledge Sources...");
      console.log("-" .repeat(60));
      
      for (const source of selectedPersona.knowledgeSources) {
        try {
          console.log(`\n📚 Adding: ${source.description}`);
          console.log(`   URI: ${source.uri}`);
          console.log(`   Priority: ${source.priority}`);
          
          const addKnowledgeTx = await knowledgeRegistry.addKnowledgeSource(
            tokenId,
            source.uri,
            source.type,
            source.priority,
            source.description,
            ethers.utils.formatBytes32String(`hash-${Date.now()}`)
          );
          await addKnowledgeTx.wait();
          console.log("   ✅ Added successfully");
        } catch (error) {
          console.log(`   ⚠️ Failed to add: ${error.message.substring(0, 50)}`);
        }
      }
      
      // Display knowledge configuration
      const config = await knowledgeRegistry.getKnowledgeConfig(tokenId);
      console.log("\n⚙️ Knowledge Configuration:");
      console.log(`  Total Sources: ${config.totalSources}`);
      console.log(`  Active Sources: ${config.activeSources}`);
      console.log(`  Max Sources: ${config.maxSources}`);
      console.log("");
    }

    // Fund the agent with some ETH
    console.log("💰 Funding agent with initial ETH...");
    const fundAmount = ethers.utils.parseEther("0.05");
    const fundTx = await bap578.fundAgent(tokenId, { value: fundAmount });
    await fundTx.wait();
    console.log(`✅ Agent funded with ${ethers.utils.formatEther(fundAmount)} ETH`);
    
    // Get updated state
    const updatedState = await bap578.getState(tokenId);
    console.log(`💵 New Agent Balance: ${ethers.utils.formatEther(updatedState.balance)} ETH`);
    console.log("");

    // Display summary
    console.log("=" .repeat(60));
    console.log("🎉 Agent Creation Complete!");
    console.log("=" .repeat(60));
    console.log("\n📋 Agent Summary:");
    console.log(`  Name: ${selectedPersona.name}`);
    console.log(`  Symbol: ${selectedPersona.symbol}`);
    console.log(`  Contract: ${bap578.address}`);
    console.log(`  Token ID: ${tokenId}`);
    console.log(`  Owner: ${deployer.address}`);
    console.log(`  Balance: ${ethers.utils.formatEther(updatedState.balance)} ETH`);
    
    if (knowledgeRegistry && selectedPersona.knowledgeSources) {
      const sources = await knowledgeRegistry.getKnowledgeSources(tokenId);
      console.log(`  Knowledge Sources: ${sources.length}`);
    }
    
    console.log("\n🔧 Interaction Commands:");
    console.log("-" .repeat(60));
    console.log("# Get agent state:");
    console.log(`await bap578.getState(${tokenId})`);
    console.log("\n# Fund agent:");
    console.log(`await bap578.fundAgent(${tokenId}, { value: ethers.utils.parseEther('0.1') })`);
    console.log("\n# Pause/Unpause agent:");
    console.log(`await bap578.pause(${tokenId})`);
    console.log(`await bap578.unpause(${tokenId})`);
    
    if (knowledgeRegistry) {
      console.log("\n# Get knowledge sources:");
      console.log(`await knowledgeRegistry.getKnowledgeSources(${tokenId})`);
      console.log("\n# Get sources by priority:");
      console.log(`await knowledgeRegistry.getKnowledgeSourcesByPriority(${tokenId})`);
    }
    
    // Check treasury stats after fee collection
    console.log("\n💰 Treasury Stats After Fee Collection:");
    console.log("-" .repeat(60));
    const treasuryStats = await treasury.getTreasuryStats();
    console.log(`Total Received: ${ethers.utils.formatEther(treasuryStats.totalReceived)} ETH`);
    console.log(`Foundation (60%): ${ethers.utils.formatEther(treasuryStats.foundationDistributed)} ETH`);
    console.log(`Community (25%): ${ethers.utils.formatEther(treasuryStats.treasuryDistributed)} ETH`);
    console.log(`Staking (15%): ${ethers.utils.formatEther(treasuryStats.stakingDistributed)} ETH`);
    
    // Display other available personas
    console.log("\n🎭 Other Available Personas:");
    console.log("-" .repeat(60));
    Object.keys(AGENT_PERSONAS).forEach(key => {
      if (key !== selectedPersonaKey) {
        const persona = AGENT_PERSONAS[key];
        console.log(`- ${persona.name} (${key})`);
      }
    });
    console.log("\n💡 Tip: Modify the 'selectedPersonaKey' variable to create different agent types!");

  } catch (error) {
    console.error("❌ Error creating agent:", error.message);
    
    // Provide helpful error messages
    if (error.message.includes("insufficient funds")) {
      console.log("\n💡 Hint: Make sure your account has at least 0.01 ETH for the creation fee plus gas");
    } else if (error.message.includes("AgentFactory")) {
      console.log("\n💡 Hint: Make sure AgentFactory is properly deployed");
    }
    throw error;
  }
}

// Run the script
main()
  .then(() => {
    console.log("\n✨ Agent creation with persona completed successfully!");
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
