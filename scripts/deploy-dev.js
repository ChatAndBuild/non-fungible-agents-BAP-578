const { ethers } = require("hardhat");

async function main() {
  console.log("🚀 Starting development deployment...\n");

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", ethers.utils.formatEther(await deployer.getBalance()));

  const network = await ethers.provider.getNetwork();
  console.log("Network:", network.name, "Chain ID:", network.chainId);

  try {
    // 1. Deploy CircuitBreaker (simple deployment for dev)
    console.log("\n📋 1. Deploying CircuitBreaker...");
    const CircuitBreaker = await ethers.getContractFactory("CircuitBreaker");
    const circuitBreaker = await CircuitBreaker.deploy();
    await circuitBreaker.deployed();
    
    // Initialize CircuitBreaker
    await circuitBreaker.initialize(deployer.address, deployer.address);
    console.log("✅ CircuitBreaker deployed to:", circuitBreaker.address);

    // 2. Deploy BEP007 (simple deployment for dev)
    console.log("\n📋 2. Deploying BEP007...");
    const BEP007 = await ethers.getContractFactory("BEP007");
    const bep007 = await BEP007.deploy();
    await bep007.deployed();
    
    // Initialize BEP007
    await bep007.initialize("BEP007 Dev NFAs", "DNFA", circuitBreaker.address);
    console.log("✅ BEP007 deployed to:", bep007.address);

    // 3. Deploy MerkleTreeLearning
    console.log("\n📋 3. Deploying MerkleTreeLearning...");
    const MerkleTreeLearning = await ethers.getContractFactory("MerkleTreeLearning");
    const merkleLearning = await MerkleTreeLearning.deploy();
    await merkleLearning.deployed();
    
    // Initialize MerkleTreeLearning
    await merkleLearning.initialize();
    console.log("✅ MerkleTreeLearning deployed to:", merkleLearning.address);

    // 4. Deploy AgentFactory
    console.log("\n📋 4. Deploying AgentFactory...");
    const AgentFactory = await ethers.getContractFactory("AgentFactory");
    const agentFactory = await AgentFactory.deploy();
    await agentFactory.deployed();
    
    // Initialize AgentFactory
    await agentFactory.initialize(bep007.address, deployer.address, merkleLearning.address);
    console.log("✅ AgentFactory deployed to:", agentFactory.address);

    // 5. Deploy CreatorAgent template
    console.log("\n📋 5. Deploying CreatorAgent template...");
    const CreatorAgent = await ethers.getContractFactory("CreatorAgent");
    const creatorAgent = await CreatorAgent.deploy(
      bep007.address,
      "Dev Creator",
      "Development creator agent",
      "Development"
    );
    await creatorAgent.deployed();
    console.log("✅ CreatorAgent template deployed to:", creatorAgent.address);

    // 6. Basic setup
    console.log("\n📋 6. Setting up basic configurations...");
    
    // Approve learning module
    await agentFactory.approveLearningModule(merkleLearning.address, "MerkleTree", "1.0.0");
    console.log("✅ Learning module approved");

    // Register agent template
    await agentFactory.approveTemplate(creatorAgent.address, "Creator", "1.0.0");
    console.log("✅ Agent template registered");

    console.log("\n🎉 Development deployment completed!");
    console.log("----------------------------------------------------");
    console.log("📋 Contract Addresses:");
    console.log("CircuitBreaker:", circuitBreaker.address);
    console.log("BEP007:", bep007.address);
    console.log("MerkleTreeLearning:", merkleLearning.address);
    console.log("AgentFactory:", agentFactory.address);
    console.log("CreatorAgent Template:", creatorAgent.address);
    console.log("----------------------------------------------------");
    console.log("\n💡 Quick test commands:");
    console.log(`npx hardhat console --network ${network.name}`);
    console.log("const factory = await ethers.getContractAt('AgentFactory', '" + agentFactory.address + "')");
    console.log("await factory.createAgent('TestAgent', 'TEST', '" + creatorAgent.address + "', 'ipfs://test')");

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
