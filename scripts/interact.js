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

      // Demo Section 2: Fund an Agent
      console.log("💰 Demo 2: Funding the agent...");
      
      const fundAmount = ethers.utils.parseEther("0.1");
      const fundTx = await bap578.fundAgent(tokenId, { value: fundAmount });
      await fundTx.wait();
      console.log("✅ Agent funded with 0.1 ETH!");
      
      const updatedState = await bap578.getState(tokenId);
      console.log("💵 New Balance:", ethers.utils.formatEther(updatedState.balance), "ETH");
      console.log("");

      // Demo Section 3: Treasury Donation
      console.log("🎁 Demo 3: Making a donation to treasury...");
      
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
    console.log(`const treasury = await ethers.getContractAt('BAP578Treasury', '${contracts.BAP578Treasury}')`);
    console.log("");
    console.log("# Create an agent:");
    console.log(`await bap578['createAgent(address,address,string)'](deployer.address, '0x1234...', 'ipfs://metadata')`);
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
