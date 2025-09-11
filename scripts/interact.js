const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("🤖 BEP007 Contract Interaction Tool\n");

  const [deployer] = await ethers.getSigners();
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
    const bep007 = await ethers.getContractAt("BEP007", contracts.BEP007);
    const circuitBreaker = await ethers.getContractAt("CircuitBreaker", contracts.CircuitBreaker);

    // Display current state
    console.log("📊 Current Contract State:");
    console.log("----------------------------------------------------");
    
    // Check CircuitBreaker status
    const globalPause = await circuitBreaker.globalPause();
    console.log("🔒 Global Pause Status:", globalPause ? "PAUSED" : "ACTIVE");
    
    // Check BEP007 total supply
    const totalSupply = await bep007.totalSupply();
    console.log("🎯 Total Agents Created:", totalSupply.toString());
    
    // Check AgentFactory stats
    const globalStats = await agentFactory.getGlobalLearningStats();
    console.log("📈 Total Agents from Factory:", globalStats.totalAgentsCreated.toString());
    console.log("🧠 Learning Enabled Agents:", globalStats.totalLearningEnabledAgents.toString());
    console.log("📚 Total Learning Modules:", globalStats.totalLearningModules.toString());
    
    console.log("----------------------------------------------------\n");

    // Interactive menu
    console.log("🎮 Available Actions:");
    console.log("1. Create a new agent");
    console.log("2. Check agent details");
    console.log("3. Fund an agent");
    console.log("4. Pause/Unpause an agent");
    console.log("5. Check learning module status");
    console.log("6. Emergency pause (CircuitBreaker)");
    console.log("7. Exit");

    // For demo purposes, let's create a sample agent
    console.log("\n🚀 Demo: Creating a sample agent...");
    
    try {
      const tx = await agentFactory.createAgent(
        "Sample Agent",
        "SAMPLE",
        contracts.CreatorAgent,
        "ipfs://QmSampleHash"
      );
      
      const receipt = await tx.wait();
      console.log("✅ Agent created! Transaction hash:", receipt.transactionHash);
      
      // Find the AgentCreated event
      const agentCreatedEvent = receipt.events?.find(e => e.event === 'AgentCreated');
      if (agentCreatedEvent) {
        console.log("🎯 New Agent Address:", agentCreatedEvent.args.agent);
        console.log("🆔 Token ID:", agentCreatedEvent.args.tokenId.toString());
      }
      
    } catch (error) {
      console.log("⚠️ Agent creation failed (this is normal if already exists):", error.message);
    }

    // Show some useful commands
    console.log("\n💡 Useful Commands for Manual Interaction:");
    console.log("----------------------------------------------------");
    console.log("# Connect to Hardhat console:");
    console.log(`npx hardhat console --network ${deployment.network}`);
    console.log("");
    console.log("# Get contract instances:");
    console.log(`const factory = await ethers.getContractAt('AgentFactory', '${contracts.AgentFactory}')`);
    console.log(`const bep007 = await ethers.getContractAt('BEP007', '${contracts.BEP007}')`);
    console.log(`const circuitBreaker = await ethers.getContractAt('CircuitBreaker', '${contracts.CircuitBreaker}')`);
    console.log("");
    console.log("# Create an agent:");
    console.log("await factory.createAgent('MyAgent', 'MA', '" + contracts.CreatorAgent + "', 'ipfs://metadata')");
    console.log("");
    console.log("# Check total supply:");
    console.log("await bep007.totalSupply()");
    console.log("");
    console.log("# Get agent state:");
    console.log("await bep007.getState(1) // tokenId 1");
    console.log("----------------------------------------------------");

  } catch (error) {
    console.error("❌ Interaction failed:", error);
    throw error;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
