const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("🤖 BAP-578 Non-Fungible Agent Interaction Tool\n");

  const [deployer, addr1] = await ethers.getSigners();
  console.log("Using account:", deployer.address);

  // Get the latest deployment file
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

  try {
    // Get contract instances
    const agentFactory = await ethers.getContractAt("AgentFactory", contracts.AgentFactory);
    const bap578 = await ethers.getContractAt("BAP578", contracts.BAP578);
    const circuitBreaker = await ethers.getContractAt("CircuitBreaker", contracts.CircuitBreaker);
    const treasury = await ethers.getContractAt("BAP578Treasury", contracts.BAP578Treasury);
    const knowledgeRegistry = contracts.KnowledgeRegistry 
      ? await ethers.getContractAt("KnowledgeRegistry", contracts.KnowledgeRegistry)
      : null;
    const experienceRegistry = await ethers.getContractAt("ExperienceModuleRegistry", contracts.ExperienceModuleRegistry);

    // Display current state
    console.log("📊 Current Contract State:");
    console.log("----------------------------------------------------");
    
    // Check CircuitBreaker status
    const globalPause = await circuitBreaker.globalPause();
    console.log("🔒 Global Pause Status:", globalPause ? "PAUSED" : "ACTIVE");
    
    // Check BAP578 total supply
    const totalSupply = await bap578.totalSupply();
    console.log("🎯 Total Agents Created:", totalSupply.toString());
    
    // Check AgentFactory stats
    const globalStats = await agentFactory.getGlobalLearningStats();
    console.log("📈 Total Agents from Factory:", globalStats.totalAgentsCreated.toString());
    console.log("🧠 Learning Enabled Agents:", globalStats.totalLearningEnabledAgents.toString());
    console.log("📚 Total Learning Modules:", globalStats.totalLearningModules.toString());
    
    // Check Treasury stats
    const treasuryStats = await treasury.getTreasuryStats();
    console.log("💰 Total Donations Received:", ethers.utils.formatEther(treasuryStats.totalReceived), "ETH");
    
    console.log("----------------------------------------------------\n");

    // Demo Section 1: Create an Agent
    console.log("🚀 Demo 1: Creating a new agent...");
    
    try {
      // Mock logic address for testing
      const mockLogicAddress = "0x1234567890123456789012345678901234567890";
      
      // Create agent directly through BAP578 (no fee required)
      const createAgentTx = await bap578["createAgent(address,address,string)"](
        deployer.address,
        mockLogicAddress,
        "ipfs://QmTestAgent123"
      );
      
      const receipt = await createAgentTx.wait();
      console.log("✅ Agent created successfully!");
      
      // Get the token ID from the Transfer event
      const transferEvent = receipt.events?.find(e => e.event === 'Transfer');
      const tokenId = transferEvent?.args?.tokenId || 1;
      console.log("🆔 Token ID:", tokenId.toString());
      
      // Get agent state
      const agentState = await bap578.getState(tokenId);
      console.log("📋 Agent State:");
      console.log("  - Owner:", agentState.owner);
      console.log("  - Status:", ["Paused", "Active", "Terminated"][agentState.status]);
      console.log("  - Logic Address:", agentState.logicAddress);
      console.log("  - Balance:", ethers.utils.formatEther(agentState.balance), "ETH");
      console.log("");

      // Demo Section 2: KnowledgeRegistry Interactions
      if (knowledgeRegistry) {
        console.log("🧠 Demo 2: KnowledgeRegistry - Adding Knowledge Sources...");
        
        // Knowledge types enum
        const KnowledgeType = {
          BASE: 0,
          CONTEXT: 1,
          MEMORY: 2,
          INSTRUCTION: 3,
          REFERENCE: 4,
          DYNAMIC: 5
        };
        
        try {
          // Add a knowledge source
          const addKnowledgeTx = await knowledgeRegistry.addKnowledgeSource(
            tokenId,
            "ipfs://QmKnowledgeBase001",
            KnowledgeType.BASE,
            100, // priority
            "Primary training dataset for the agent",
            ethers.utils.formatBytes32String("kb001-hash")
          );
          await addKnowledgeTx.wait();
          console.log("✅ Knowledge source added!");
          
          // Add another knowledge source with different type
          const addContextTx = await knowledgeRegistry.addKnowledgeSource(
            tokenId,
            "ipfs://QmContextData001",
            KnowledgeType.CONTEXT,
            80, // lower priority
            "Contextual information for task processing",
            ethers.utils.formatBytes32String("ctx001-hash")
          );
          await addContextTx.wait();
          console.log("✅ Context source added!");
          
          // Get all knowledge sources for the agent
          const sources = await knowledgeRegistry.getKnowledgeSources(tokenId);
          console.log(`\n📚 Agent has ${sources.length} knowledge sources:`);
          
          for (const source of sources) {
            const typeNames = ["BASE", "CONTEXT", "MEMORY", "INSTRUCTION", "REFERENCE", "DYNAMIC"];
            console.log(`  - ${typeNames[source.sourceType]} | Priority: ${source.priority} | URI: ${source.uri}`);
            console.log(`    Description: ${source.description}`);
            console.log(`    Active: ${source.active}, Version: ${source.version}`);
          }
          
          // Get sources by priority
          const prioritizedSources = await knowledgeRegistry.getKnowledgeSourcesByPriority(tokenId);
          console.log("\n🏆 Knowledge sources by priority:");
          for (let i = 0; i < prioritizedSources.length; i++) {
            console.log(`  ${i + 1}. Priority ${prioritizedSources[i].priority}: ${prioritizedSources[i].uri}`);
          }
          
          // Get configuration
          const config = await knowledgeRegistry.getKnowledgeConfig(tokenId);
          console.log("\n⚙️  Knowledge Configuration:");
          console.log(`  - Max Sources: ${config.maxSources}`);
          console.log(`  - Total Sources: ${config.totalSources}`);
          console.log(`  - Active Sources: ${config.activeSources}`);
          console.log(`  - Dynamic Sources Allowed: ${config.allowDynamicSources}`);
          
        } catch (error) {
          console.log("⚠️ Knowledge source operations skipped (may already exist):", error.message.substring(0, 50));
        }
      } else {
        console.log("⚠️ KnowledgeRegistry not deployed in this environment");
      }
      console.log("");

      // Demo Section 3: Fund an Agent
      console.log("💰 Demo 3: Funding the agent...");
      
      const fundAmount = ethers.utils.parseEther("0.1");
      const fundTx = await bap578.fundAgent(tokenId, { value: fundAmount });
      await fundTx.wait();
      console.log("✅ Agent funded with 0.1 ETH!");
      
      const updatedState = await bap578.getState(tokenId);
      console.log("💵 New Balance:", ethers.utils.formatEther(updatedState.balance), "ETH");
      console.log("");

      // Demo Section 4: Treasury Donation
      console.log("🎁 Demo 4: Making a donation to treasury...");
      
      const donateTx = await treasury.donate("Supporting the ecosystem!", {
        value: ethers.utils.parseEther("0.01")
      });
      await donateTx.wait();
      console.log("✅ Donation sent to treasury!");
      
      const newTreasuryStats = await treasury.getTreasuryStats();
      console.log("📊 Treasury Distribution:");
      console.log("  - Foundation (60%):", ethers.utils.formatEther(newTreasuryStats.foundationDistributed), "ETH");
      console.log("  - Community (25%):", ethers.utils.formatEther(newTreasuryStats.treasuryDistributed), "ETH");
      console.log("  - Staking (15%):", ethers.utils.formatEther(newTreasuryStats.stakingDistributed), "ETH");
      
    } catch (error) {
      console.log("⚠️ Demo operations completed or skipped:", error.message.substring(0, 100));
    }

    // Show useful commands
    console.log("\n💡 Useful Commands for Manual Interaction:");
    console.log("----------------------------------------------------");
    console.log("# Connect to Hardhat console:");
    console.log(`npx hardhat console --network ${deployment.network}`);
    console.log("");
    console.log("# Get contract instances:");
    console.log(`const factory = await ethers.getContractAt('AgentFactory', '${contracts.AgentFactory}')`);
    console.log(`const bap578 = await ethers.getContractAt('BAP578', '${contracts.BAP578}')`);
    console.log(`const knowledgeRegistry = await ethers.getContractAt('KnowledgeRegistry', '${contracts.KnowledgeRegistry || 'DEPLOY_FIRST'}')`);
    console.log(`const treasury = await ethers.getContractAt('BAP578Treasury', '${contracts.BAP578Treasury}')`);
    console.log("");
    console.log("# Create an agent:");
    console.log(`await bap578['createAgent(address,address,string)'](deployer.address, '0x1234...', 'ipfs://metadata')`);
    console.log("");
    console.log("# Add knowledge source (if KnowledgeRegistry deployed):");
    console.log("await knowledgeRegistry.addKnowledgeSource(tokenId, 'ipfs://knowledge', 0, 100, 'description', ethers.utils.formatBytes32String('hash'))");
    console.log("");
    console.log("# Get knowledge sources:");
    console.log("await knowledgeRegistry.getKnowledgeSources(tokenId)");
    console.log("");
    console.log("# Fund an agent:");
    console.log("await bap578.fundAgent(tokenId, { value: ethers.utils.parseEther('0.1') })");
    console.log("");
    console.log("# Check agent state:");
    console.log("await bap578.getState(tokenId)");
    console.log("");
    console.log("# Make a donation:");
    console.log("await treasury.donate('message', { value: ethers.utils.parseEther('0.01') })");
    console.log("----------------------------------------------------");

    // Knowledge Registry specific commands
    if (knowledgeRegistry) {
      console.log("\n🧠 KnowledgeRegistry Specific Commands:");
      console.log("----------------------------------------------------");
      console.log("# Get sources by priority:");
      console.log("await knowledgeRegistry.getKnowledgeSourcesByPriority(tokenId)");
      console.log("");
      console.log("# Toggle knowledge source:");
      console.log("await knowledgeRegistry.toggleKnowledgeSource(tokenId, sourceId)");
      console.log("");
      console.log("# Update knowledge priority:");
      console.log("await knowledgeRegistry.changeKnowledgePriority(tokenId, sourceId, newPriority)");
      console.log("");
      console.log("# Update knowledge configuration:");
      console.log("await knowledgeRegistry.updateKnowledgeConfig(tokenId, maxSources, allowDynamic)");
      console.log("");
      console.log("# Get active sources only:");
      console.log("await knowledgeRegistry.getActiveKnowledgeSources(tokenId)");
      console.log("");
      console.log("# Get sources by type (0=BASE, 1=CONTEXT, 2=MEMORY, etc.):");
      console.log("await knowledgeRegistry.getKnowledgeSourcesByType(tokenId, 0)");
      console.log("----------------------------------------------------");
    }

  } catch (error) {
    console.error("❌ Interaction failed:", error);
    throw error;
  }
}

// Run the interaction script
main()
  .then(() => {
    console.log("\n✨ Interaction script completed successfully!");
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
