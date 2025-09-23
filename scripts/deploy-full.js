const { ethers, upgrades } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("🚀 Starting full BAP-578 NFA deployment...\n");

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

    // 2. Deploy BAP578 implementation
    console.log("\n📋 2. Deploying BAP578 implementation...");
    const BAP578 = await ethers.getContractFactory("BAP578");
    const bap578Implementation = await upgrades.deployProxy(
      BAP578,
      ["BAP578 Non-Fungible Agents", "NFA", circuitBreaker.address],
      { initializer: "initialize" }
    );
    await bap578Implementation.deployed();
    deployments.BAP578 = bap578Implementation.address;
    console.log("✅ BAP578 deployed to:", bap578Implementation.address);

    // 3. Deploy BAP578Treasury
    console.log("\n📋 3. Deploying BAP578Treasury...");
    const BAP578Treasury = await ethers.getContractFactory("BAP578Treasury");
    const treasury = await upgrades.deployProxy(
      BAP578Treasury,
      [
        circuitBreaker.address,
        deployer.address, // foundation address (update in production)
        deployer.address, // community treasury (update in production)
        deployer.address, // staking rewards (update in production)
        deployer.address  // initial admin
      ],
      { initializer: "initialize" }
    );
    await treasury.deployed();
    deployments.BAP578Treasury = treasury.address;
    console.log("✅ BAP578Treasury deployed to:", treasury.address);

    // 4. Deploy VaultPermissionManager
    console.log("\n📋 4. Deploying VaultPermissionManager...");
    const VaultPermissionManager = await ethers.getContractFactory("VaultPermissionManager");
    const vaultManager = await upgrades.deployProxy(
      VaultPermissionManager,
      [circuitBreaker.address],
      { initializer: "initialize" }
    );
    await vaultManager.deployed();
    deployments.VaultPermissionManager = vaultManager.address;
    console.log("✅ VaultPermissionManager deployed to:", vaultManager.address);

    // 5. Deploy ExperienceModuleRegistry
    console.log("\n📋 5. Deploying ExperienceModuleRegistry...");
    const ExperienceModuleRegistry = await ethers.getContractFactory("ExperienceModuleRegistry");
    const experienceRegistry = await upgrades.deployProxy(
      ExperienceModuleRegistry,
      [circuitBreaker.address],
      { initializer: "initialize" }
    );
    await experienceRegistry.deployed();
    deployments.ExperienceModuleRegistry = experienceRegistry.address;
    console.log("✅ ExperienceModuleRegistry deployed to:", experienceRegistry.address);

    // 6. Deploy Learning Modules
    console.log("\n📋 6. Deploying Learning Modules...");
    
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

    // 7. Deploy AgentFactory
    console.log("\n📋 7. Deploying AgentFactory...");
    const AgentFactory = await ethers.getContractFactory("AgentFactory");
    const agentFactory = await upgrades.deployProxy(
      AgentFactory,
      [
        bap578Implementation.address,
        deployer.address,
        merkleLearning.address,
        treasury.address
      ],
      { initializer: "initialize" }
    );
    await agentFactory.deployed();
    deployments.AgentFactory = agentFactory.address;
    console.log("✅ AgentFactory deployed to:", agentFactory.address);

    // 8. Deploy BAP578Governance
    console.log("\n📋 8. Deploying BAP578Governance...");
    const BAP578Governance = await ethers.getContractFactory("BAP578Governance");
    const governance = await upgrades.deployProxy(
      BAP578Governance,
      [
        bap578Implementation.address,
        deployer.address,
        7, // 7 days voting period
        10, // 10% quorum
        2  // 2 days execution delay
      ],
      { initializer: "initialize" }
    );
    await governance.deployed();
    deployments.BAP578Governance = governance.address;
    console.log("✅ BAP578Governance deployed to:", governance.address);

    // 9. Deploy CreatorAgent template (optional)
    console.log("\n📋 9. Deploying CreatorAgent template...");
    const CreatorAgent = await ethers.getContractFactory("CreatorAgent");
    const creatorAgent = await CreatorAgent.deploy(
      bap578Implementation.address,
      "Template Creator",
      "Template creator agent",
      "General"
    );
    await creatorAgent.deployed();
    deployments.CreatorAgent = creatorAgent.address;
    console.log("✅ CreatorAgent template deployed to:", creatorAgent.address);

    // 10. Setup initial configurations
    console.log("\n📋 10. Setting up initial configurations...");
    
    // Set governance in CircuitBreaker
    console.log("Setting governance in CircuitBreaker...");
    await circuitBreaker.setGovernance(governance.address);
    console.log("✅ Governance set in CircuitBreaker");

    // Set governance in Treasury
    console.log("Setting governance in Treasury...");
    await treasury.setGovernance(governance.address);
    console.log("✅ Governance set in Treasury");

    // Set governance in VaultPermissionManager
    console.log("Setting governance in VaultPermissionManager...");
    await vaultManager.setGovernance(governance.address);
    console.log("✅ Governance set in VaultPermissionManager");

    // Set governance in ExperienceModuleRegistry
    console.log("Setting governance in ExperienceModuleRegistry...");
    await experienceRegistry.setGovernance(governance.address);
    console.log("✅ Governance set in ExperienceModuleRegistry");

    // Set AgentFactory in Governance
    console.log("Setting AgentFactory in Governance...");
    await governance.setAgentFactory(agentFactory.address);
    console.log("✅ AgentFactory set in Governance");

    // Set Treasury in Governance
    console.log("Setting Treasury in Governance...");
    await governance.setTreasury(treasury.address);
    console.log("✅ Treasury set in Governance");

    // Approve learning module in factory
    console.log("Approving learning module...");
    await agentFactory.approveLearningModule(merkleLearning.address, "MerkleTree", "1.0.0");
    console.log("✅ Learning module approved");

    // Register experience module
    console.log("Registering experience module...");
    await experienceRegistry.registerModule(
      merkleLearning.address,
      "MerkleTreeLearning",
      "1.0.0",
      "Merkle tree based learning module for agents"
    );
    console.log("✅ Experience module registered");

    // Register agent template in factory
    console.log("Registering agent template...");
    await agentFactory.approveTemplate(creatorAgent.address, "Creator", "1.0.0");
    console.log("✅ Agent template registered");

    // 11. Save deployment addresses
    const deploymentData = {
      network: network.name,
      chainId: network.chainId,
      deployer: deployer.address,
      timestamp: new Date().toISOString(),
      contracts: deployments,
      gasUsed: {
        // Gas tracking would be added here in production
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
    console.log("4. Configure proper multisig wallets for production");
    console.log("5. Run integration tests");

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
