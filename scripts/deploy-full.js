const { ethers, upgrades } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("🚀 Starting full BEP007 NFA deployment...\n");

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", ethers.utils.formatEther(await deployer.getBalance()));

  const deployments = {};
  const network = await ethers.provider.getNetwork();
  console.log("Network:", network.name, "Chain ID:", network.chainId);

  try {
    // 1. Deploy CircuitBreaker first (no dependencies)
    console.log("\n📋 1. Deploying CircuitBreaker...");
    const CircuitBreaker = await ethers.getContractFactory("CircuitBreaker");
    const circuitBreaker = await upgrades.deployProxy(
      CircuitBreaker,
      [deployer.address, deployer.address], // governance and emergency multisig
      { initializer: "initialize" }
    );
    await circuitBreaker.deployed();
    deployments.CircuitBreaker = circuitBreaker.address;
    console.log("✅ CircuitBreaker deployed to:", circuitBreaker.address);

    // 2. Deploy BEP007 implementation
    console.log("\n📋 2. Deploying BEP007 implementation...");
    const BEP007 = await ethers.getContractFactory("BEP007");
    const bep007Implementation = await upgrades.deployProxy(
      BEP007,
      ["BEP007 Non-Fungible Agents", "NFA", circuitBreaker.address],
      { initializer: "initialize" }
    );
    await bep007Implementation.deployed();
    deployments.BEP007 = bep007Implementation.address;
    console.log("✅ BEP007 deployed to:", bep007Implementation.address);

    // 3. Deploy Learning Modules
    console.log("\n📋 3. Deploying Learning Modules...");
    
    // Deploy MerkleTreeLearning
    const MerkleTreeLearning = await ethers.getContractFactory("MerkleTreeLearning");
    const merkleLearning = await upgrades.deployProxy(
      MerkleTreeLearning,
      [],
      { initializer: "initialize" }
    );
    await merkleLearning.deployed();
    deployments.MerkleTreeLearning = merkleLearning.address;
    console.log("✅ MerkleTreeLearning deployed to:", merkleLearning.address);

    // 4. Deploy AgentFactory
    console.log("\n📋 4. Deploying AgentFactory...");
    const AgentFactory = await ethers.getContractFactory("AgentFactory");
    const agentFactory = await upgrades.deployProxy(
      AgentFactory,
      [bep007Implementation.address, deployer.address, merkleLearning.address],
      { initializer: "initialize" }
    );
    await agentFactory.deployed();
    deployments.AgentFactory = agentFactory.address;
    console.log("✅ AgentFactory deployed to:", agentFactory.address);

    // 5. Deploy BEP007Governance
    console.log("\n📋 5. Deploying BEP007Governance...");
    const BEP007Governance = await ethers.getContractFactory("BEP007Governance");
    const governance = await upgrades.deployProxy(
      BEP007Governance,
      [
        bep007Implementation.address,
        deployer.address,
        7, // 7 days voting period
        10, // 10% quorum
        2  // 2 days execution delay
      ],
      { initializer: "initialize" }
    );
    await governance.deployed();
    deployments.BEP007Governance = governance.address;
    console.log("✅ BEP007Governance deployed to:", governance.address);

    // 6. Deploy CreatorAgent template
    console.log("\n📋 6. Deploying CreatorAgent template...");
    const CreatorAgent = await ethers.getContractFactory("CreatorAgent");
    const creatorAgent = await CreatorAgent.deploy(
      bep007Implementation.address,
      "Template Creator",
      "Template creator agent",
      "General"
    );
    await creatorAgent.deployed();
    deployments.CreatorAgent = creatorAgent.address;
    console.log("✅ CreatorAgent template deployed to:", creatorAgent.address);

    // 7. Setup initial configurations
    console.log("\n📋 7. Setting up initial configurations...");
    
    // Set governance in CircuitBreaker
    console.log("Setting governance in CircuitBreaker...");
    await circuitBreaker.setGovernance(governance.address);
    console.log("✅ Governance set in CircuitBreaker");

    // Set AgentFactory in Governance
    console.log("Setting AgentFactory in Governance...");
    await governance.setAgentFactory(agentFactory.address);
    console.log("✅ AgentFactory set in Governance");

    // Approve learning module in factory
    console.log("Approving learning module...");
    await agentFactory.approveLearningModule(merkleLearning.address, "MerkleTree", "1.0.0");
    console.log("✅ Learning module approved");

    // Register agent template in factory
    console.log("Registering agent template...");
    await agentFactory.approveTemplate(creatorAgent.address, "Creator", "1.0.0");
    console.log("✅ Agent template registered");

    // 8. Save deployment addresses
    const deploymentData = {
      network: network.name,
      chainId: network.chainId,
      deployer: deployer.address,
      timestamp: new Date().toISOString(),
      contracts: deployments,
      gasUsed: {
        // Gas tracking would be added here in a real deployment
      }
    };

    const deploymentsDir = path.join(__dirname, "..", "deployments");
    if (!fs.existsSync(deploymentsDir)) {
      fs.mkdirSync(deploymentsDir, { recursive: true });
    }

    const filename = `${network.name}-${Date.now()}.json`;
    const filepath = path.join(deploymentsDir, filename);
    fs.writeFileSync(filepath, JSON.stringify(deploymentData, null, 2));

    console.log("\n🎉 Deployment completed successfully!");
    console.log("----------------------------------------------------");
    console.log("📋 Contract Addresses:");
    Object.entries(deployments).forEach(([name, address]) => {
      console.log(`${name}: ${address}`);
    });
    console.log("----------------------------------------------------");
    console.log(`📁 Deployment data saved to: ${filepath}`);
    console.log("\n💡 Next steps:");
    console.log("1. Update your .env file with these addresses");
    console.log("2. Verify contracts on block explorer");
    console.log("3. Set up monitoring and alerts");

  } catch (error) {
    console.error("❌ Deployment failed:", error);
    throw error;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
