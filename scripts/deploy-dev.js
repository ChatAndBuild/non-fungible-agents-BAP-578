const { ethers } = require("hardhat");

async function main() {
  console.log("🚀 Starting development deployment...\n");

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", ethers.utils.formatEther(await deployer.getBalance()));

  const network = await ethers.provider.getNetwork();
  console.log("Network:", network.name, "Chain ID:", network.chainId);

  const deployments = {};

  try {
    // 1. Deploy CircuitBreaker (simple deployment for dev)
    console.log("\n📋 1. Deploying CircuitBreaker...");
    const CircuitBreaker = await ethers.getContractFactory("CircuitBreaker");
    const circuitBreaker = await CircuitBreaker.deploy();
    await circuitBreaker.deployed();
    
    // Initialize CircuitBreaker
    await circuitBreaker.initialize(deployer.address, deployer.address);
    deployments.CircuitBreaker = circuitBreaker.address;
    console.log("✅ CircuitBreaker deployed to:", circuitBreaker.address);

    // 2. Deploy BAP578 (simple deployment for dev)
    console.log("\n📋 2. Deploying BAP578...");
    const BAP578 = await ethers.getContractFactory("BAP578");
    const bap578 = await BAP578.deploy();
    await bap578.deployed();
    
    // Initialize BAP578
    await bap578.initialize("BAP578 Dev NFAs", "DNFA", circuitBreaker.address);
    deployments.BAP578 = bap578.address;
    console.log("✅ BAP578 deployed to:", bap578.address);

    // 3. Deploy BAP578Treasury
    console.log("\n📋 3. Deploying BAP578Treasury...");
    const BAP578Treasury = await ethers.getContractFactory("BAP578Treasury");
    const treasury = await BAP578Treasury.deploy();
    await treasury.deployed();
    
    // Initialize Treasury with dev addresses
    await treasury.initialize(
      circuitBreaker.address,
      deployer.address, // foundation address
      deployer.address, // community treasury
      deployer.address, // staking rewards
      deployer.address  // initial admin
    );
    deployments.BAP578Treasury = treasury.address;
    console.log("✅ BAP578Treasury deployed to:", treasury.address);

    // 4. Deploy VaultPermissionManager
    console.log("\n📋 4. Deploying VaultPermissionManager...");
    const VaultPermissionManager = await ethers.getContractFactory("VaultPermissionManager");
    const vaultManager = await VaultPermissionManager.deploy();
    await vaultManager.deployed();
    
    // Initialize VaultPermissionManager with both required parameters
    await vaultManager.initialize(circuitBreaker.address, deployer.address);
    deployments.VaultPermissionManager = vaultManager.address;
    console.log("✅ VaultPermissionManager deployed to:", vaultManager.address);

    // 5. Deploy ExperienceModuleRegistry
    console.log("\n📋 5. Deploying ExperienceModuleRegistry...");
    const ExperienceModuleRegistry = await ethers.getContractFactory("ExperienceModuleRegistry");
    const experienceRegistry = await ExperienceModuleRegistry.deploy();
    await experienceRegistry.deployed();
    
    // Initialize ExperienceModuleRegistry with BAP578 address
    await experienceRegistry.initialize(bap578.address);
    deployments.ExperienceModuleRegistry = experienceRegistry.address;
    console.log("✅ ExperienceModuleRegistry deployed to:", experienceRegistry.address);

    // 6. Deploy MerkleTreeLearning
    console.log("\n📋 6. Deploying MerkleTreeLearning...");
    const MerkleTreeLearning = await ethers.getContractFactory("MerkleTreeLearning");
    const merkleLearning = await MerkleTreeLearning.deploy();
    await merkleLearning.deployed();
    
    // Initialize MerkleTreeLearning
    await merkleLearning.initialize();
    deployments.MerkleTreeLearning = merkleLearning.address;
    console.log("✅ MerkleTreeLearning deployed to:", merkleLearning.address);

    // 7. Deploy AgentFactory
    console.log("\n📋 7. Deploying AgentFactory...");
    const AgentFactory = await ethers.getContractFactory("AgentFactory");
    const agentFactory = await AgentFactory.deploy();
    await agentFactory.deployed();
    
    // Initialize AgentFactory with all 5 required parameters
    await agentFactory.initialize(
      bap578.address,
      deployer.address,
      merkleLearning.address,
      treasury.address,
      circuitBreaker.address  // Added missing circuitBreakerAddr parameter
    );
    deployments.AgentFactory = agentFactory.address;
    console.log("✅ AgentFactory deployed to:", agentFactory.address);

    // 8. Basic setup
    console.log("\n📋 8. Setting up basic configurations...");
    
    // Approve learning module
    await agentFactory.approveLearningModule(merkleLearning.address, "MerkleTree", "1.0.0");
    console.log("✅ Learning module approved");

    // Note: ExperienceModuleRegistry.registerModule requires 8 parameters including tokenId and signature
    // This should be done by agents after they are created, not during deployment
    console.log("ℹ️  Experience module registration skipped (requires agent tokenId)");

    console.log("\n🎉 Development deployment completed!");
    console.log("----------------------------------------------------");
    console.log("📋 Contract Addresses:");
    Object.entries(deployments).forEach(([name, address]) => {
      console.log(`${name}: ${address}`);
    });
    console.log("----------------------------------------------------");
    console.log("\n💡 Quick test commands:");
    console.log(`npx hardhat console --network ${network.name}`);
    console.log("const factory = await ethers.getContractAt('AgentFactory', '" + agentFactory.address + "')");
    console.log("// Create an agent (0.01 ETH fee required):");
    console.log("await factory.createAgent('TestAgent', 'TEST', ethers.constants.AddressZero, 'ipfs://test', { value: ethers.utils.parseEther('0.01') })");
    console.log("\n💡 To interact with the treasury:");
    console.log("const treasury = await ethers.getContractAt('BAP578Treasury', '" + treasury.address + "')");
    console.log("await treasury.donate('Test donation', { value: ethers.utils.parseEther('1') })");

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
