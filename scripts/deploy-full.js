const { ethers, upgrades } = require("hardhat");
const fs = require("fs");
const path = require("path");

// Helper function to wait for a delay
const delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));

// Helper function to wait for transaction with retries
async function waitForTransaction(tx, name) {
  console.log(`⏳ Waiting for ${name} transaction...`);
  try {
    const receipt = await tx.wait();
    console.log(`✅ ${name} confirmed in block ${receipt.blockNumber}`);
    return receipt;
  } catch (error) {
    console.log(`⚠️ Error waiting for ${name}: ${error.message}`);
    throw error;
  }
}

// Helper function to execute transaction with retry logic
async function executeWithRetry(fn, name, maxRetries = 3, delayMs = 5000) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      console.log(`🔄 Executing ${name} (attempt ${i + 1}/${maxRetries})...`);
      const result = await fn();
      
      // Add delay after successful transaction to avoid in-flight limit
      await delay(delayMs);
      
      return result;
    } catch (error) {
      console.log(`⚠️ Attempt ${i + 1} failed for ${name}: ${error.message}`);
      
      if (error.message.includes("in-flight transaction limit")) {
        console.log(`⏳ Waiting ${delayMs * 2}ms before retry...`);
        await delay(delayMs * 2);
      } else if (i === maxRetries - 1) {
        throw error;
      } else {
        console.log(`⏳ Waiting ${delayMs}ms before retry...`);
        await delay(delayMs);
      }
    }
  }
}

async function main() {
  console.log("🚀 Starting full BAP-578 NFA deployment...\n");

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", ethers.utils.formatEther(await deployer.getBalance()));

  const deployments = {};
  const network = await ethers.provider.getNetwork();
  console.log("Network:", network.name, "Chain ID:", network.chainId);
  console.log("\n⚠️ Note: This deployment includes delays to avoid transaction limits");

  try {
    // 1. Deploy CircuitBreaker first (no dependencies)
    console.log("\n📋 1. Deploying CircuitBreaker...");
    const CircuitBreaker = await ethers.getContractFactory("CircuitBreaker");
    const circuitBreaker = await executeWithRetry(async () => {
      const contract = await upgrades.deployProxy(
        CircuitBreaker,
        [deployer.address, deployer.address], // governance and emergency multisig
        { initializer: "initialize" }
      );
      await contract.deployed();
      return contract;
    }, "CircuitBreaker deployment");
    deployments.CircuitBreaker = circuitBreaker.address;
    console.log("✅ CircuitBreaker deployed to:", circuitBreaker.address);

    // 2. Deploy BAP578 - BOTH raw implementation AND a main proxy
    console.log("\n📋 2. Deploying BAP578...");
    
    // 2a. First, deploy the raw implementation for AgentFactory to use
    console.log("   2a. Deploying raw BAP578 implementation for AgentFactory...");
    const BAP578Implementation = await ethers.getContractFactory("BAP578");
    const bap578RawImpl = await executeWithRetry(async () => {
      const impl = await BAP578Implementation.deploy();
      await impl.deployed();
      return impl;
    }, "BAP578 Implementation deployment");
    deployments.BAP578Implementation = bap578RawImpl.address;
    console.log("   ✅ Raw BAP578 implementation deployed to:", bap578RawImpl.address);
    
    // 2b. Deploy a main BAP578 proxy for direct agent creation (optional, but useful)
    console.log("   2b. Deploying main BAP578 proxy for direct creation...");
    const bap578Proxy = await executeWithRetry(async () => {
      const proxy = await upgrades.deployProxy(
        BAP578Implementation,
        ["BAP578 Non-Fungible Agents", "NFA", circuitBreaker.address],
        { initializer: "initialize" }
      );
      await proxy.deployed();
      return proxy;
    }, "BAP578 Proxy deployment");
    deployments.BAP578 = bap578Proxy.address;
    console.log("   ✅ Main BAP578 proxy deployed to:", bap578Proxy.address);

    // 3. Deploy BAP578Treasury
    console.log("\n📋 3. Deploying BAP578Treasury...");
    const BAP578Treasury = await ethers.getContractFactory("BAP578Treasury");
    const treasury = await executeWithRetry(async () => {
      const contract = await upgrades.deployProxy(
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
      await contract.deployed();
      return contract;
    }, "BAP578Treasury deployment");
    deployments.BAP578Treasury = treasury.address;
    console.log("✅ BAP578Treasury deployed to:", treasury.address);

    // 4. Deploy VaultPermissionManager
    console.log("\n📋 4. Deploying VaultPermissionManager...");
    const VaultPermissionManager = await ethers.getContractFactory("VaultPermissionManager");
    const vaultManager = await executeWithRetry(async () => {
      const contract = await upgrades.deployProxy(
        VaultPermissionManager,
        [circuitBreaker.address, deployer.address],  // Added deployer.address as ownerAddr
        { initializer: "initialize" }
      );
      await contract.deployed();
      return contract;
    }, "VaultPermissionManager deployment");
    deployments.VaultPermissionManager = vaultManager.address;
    console.log("✅ VaultPermissionManager deployed to:", vaultManager.address);

    // 5. Deploy ExperienceModuleRegistry
    console.log("\n📋 5. Deploying ExperienceModuleRegistry...");
    const ExperienceModuleRegistry = await ethers.getContractFactory("ExperienceModuleRegistry");
    const experienceRegistry = await executeWithRetry(async () => {
      const contract = await upgrades.deployProxy(
        ExperienceModuleRegistry,
        [circuitBreaker.address],
        { initializer: "initialize" }
      );
      await contract.deployed();
      return contract;
    }, "ExperienceModuleRegistry deployment");
    deployments.ExperienceModuleRegistry = experienceRegistry.address;
    console.log("✅ ExperienceModuleRegistry deployed to:", experienceRegistry.address);

    // 6. Deploy Learning Modules (moved before AgentFactory)
    console.log("\n📋 6. Deploying Learning Modules...");
    
    // Deploy MerkleTreeLearning
    const MerkleTreeLearning = await ethers.getContractFactory("MerkleTreeLearning");
    const merkleLearning = await executeWithRetry(async () => {
      const contract = await upgrades.deployProxy(
        MerkleTreeLearning,
        [],
        { initializer: "initialize" }
      );
      await contract.deployed();
      return contract;
    }, "MerkleTreeLearning deployment");
    deployments.MerkleTreeLearning = merkleLearning.address;
    console.log("✅ MerkleTreeLearning deployed to:", merkleLearning.address);

    // 7. Deploy AgentFactory with RAW IMPLEMENTATION
    console.log("\n📋 7. Deploying AgentFactory (with raw implementation)...");
    const AgentFactory = await ethers.getContractFactory("AgentFactory");
    const agentFactory = await executeWithRetry(async () => {
      const contract = await upgrades.deployProxy(
        AgentFactory,
        [
          bap578RawImpl.address,  // Use RAW implementation, NOT the proxy!
          deployer.address,
          merkleLearning.address,
          treasury.address,
          circuitBreaker.address
        ],
        { initializer: "initialize" }
      );
      await contract.deployed();
      return contract;
    }, "AgentFactory deployment");
    deployments.AgentFactory = agentFactory.address;
    console.log("✅ AgentFactory deployed to:", agentFactory.address);
    console.log("    Using BAP578 implementation:", bap578RawImpl.address);

    // 8. Deploy KnowledgeRegistry (AFTER AgentFactory, uses AgentFactory address)
    console.log("\n📋 8. Deploying KnowledgeRegistry...");
    const KnowledgeRegistry = await ethers.getContractFactory("KnowledgeRegistry");
    const knowledgeRegistry = await executeWithRetry(async () => {
      const contract = await upgrades.deployProxy(
        KnowledgeRegistry,
        [agentFactory.address, 10], // Now using AgentFactory address, 10 max sources per agent
        { initializer: "initialize", kind: "uups" }
      );
      await contract.deployed();
      return contract;
    }, "KnowledgeRegistry deployment");
    deployments.KnowledgeRegistry = knowledgeRegistry.address;
    console.log("✅ KnowledgeRegistry deployed to:", knowledgeRegistry.address);
    console.log("    Using AgentFactory:", agentFactory.address);

    // 9. Deploy BAP578Governance
    console.log("\n📋 9. Deploying BAP578Governance...");
    const BAP578Governance = await ethers.getContractFactory("BAP578Governance");
    const governance = await executeWithRetry(async () => {
      const contract = await upgrades.deployProxy(
        BAP578Governance,
        [
          bap578Proxy.address,  // Use main proxy for governance
          deployer.address,
          7, // 7 days voting period
          10, // 10% quorum
          2  // 2 days execution delay
        ],
        { initializer: "initialize" }
      );
      await contract.deployed();
      return contract;
    }, "BAP578Governance deployment");
    deployments.BAP578Governance = governance.address;
    console.log("✅ BAP578Governance deployed to:", governance.address);

    // 10. Setup initial configurations with proper delays
    console.log("\n📋 10. Setting up initial configurations...");
    console.log("⚠️ Adding delays between configuration transactions...");
    
    // Set governance in CircuitBreaker
    await executeWithRetry(async () => {
      console.log("Setting governance in CircuitBreaker...");
      const tx = await circuitBreaker.setGovernance(governance.address);
      await waitForTransaction(tx, "Set governance");
      console.log("✅ Governance set in CircuitBreaker");
    }, "Set governance", 3, 10000); // Longer delay for config transactions

    // Set AgentFactory in Governance
    await executeWithRetry(async () => {
      console.log("Setting AgentFactory in Governance...");
      const tx = await governance.setAgentFactory(agentFactory.address);
      await waitForTransaction(tx, "Set AgentFactory");
      console.log("✅ AgentFactory set in Governance");
    }, "Set AgentFactory", 3, 10000);

    // Set Treasury in Governance
    await executeWithRetry(async () => {
      console.log("Setting Treasury in Governance...");
      const tx = await governance.setTreasury(treasury.address);
      await waitForTransaction(tx, "Set Treasury");
      console.log("✅ Treasury set in Governance");
    }, "Set Treasury", 3, 10000);

    // Approve learning module in factory
    await executeWithRetry(async () => {
      console.log("Approving learning module...");
      const tx = await agentFactory.approveLearningModule(merkleLearning.address, "MerkleTree", "1.0.0");
      await waitForTransaction(tx, "Approve learning module");
      console.log("✅ Learning module approved");
    }, "Approve learning module", 3, 10000);

    // 11. Save deployment addresses
    const deploymentData = {
      network: network.name,
      chainId: network.chainId,
      deployer: deployer.address,
      timestamp: new Date().toISOString(),
      contracts: deployments,
      notes: {
        BAP578Implementation: "Raw implementation for AgentFactory to create proxies",
        BAP578: "Main proxy for direct agent creation (no fee)",
        AgentFactory: "Factory that creates agent proxies (0.01 ETH fee)",
        deployment: "Deployment with retry logic and delays to handle in-flight transaction limits"
      }
    };

    const deploymentsDir = path.join(__dirname, "..", "deployments");
    if (!fs.existsSync(deploymentsDir)) {
      fs.mkdirSync(deploymentsDir, { recursive: true });
    }

    const filename = `${network.name || 'unknown'}-${Date.now()}.json`;
    const filepath = path.join(deploymentsDir, filename);
    fs.writeFileSync(filepath, JSON.stringify(deploymentData, null, 2));

    console.log("\n🎉 Deployment completed successfully!");
    console.log("====================================================");
    console.log("📋 Contract Addresses:");
    console.log("----------------------------------------------------");
    Object.entries(deployments).forEach(([name, address]) => {
      console.log(`${name}: ${address}`);
    });
    console.log("----------------------------------------------------");
    console.log("\n📝 Important Notes:");
    console.log("- BAP578Implementation: Raw contract for AgentFactory");
    console.log("- BAP578: Main proxy for direct creation (no fee)");
    console.log("- AgentFactory: Creates proxies with 0.01 ETH fee");
    console.log("- All transactions executed with retry logic");
    console.log("----------------------------------------------------");
    console.log(`📁 Deployment data saved to: ${filepath}`);
    console.log("\n💡 Next steps:");
    console.log("1. Test AgentFactory with: npx hardhat run scripts/create-agent-factory.js --network testnet");
    console.log("2. Test direct creation with: npx hardhat run scripts/create-agent-with-persona.js --network testnet");
    console.log("3. Create agent on testnet: npx hardhat run scripts/create-agent-on-testnet.js --network testnet");

  } catch (error) {
    console.error("\n❌ Deployment failed:", error.message);
    console.error("\n💡 Troubleshooting tips:");
    console.error("1. If 'in-flight transaction limit' error persists:");
    console.error("   - Wait a few minutes and try again");
    console.error("   - The BSC testnet limits pending transactions");
    console.error("2. Check your account balance - you need BNB for gas");
    console.error("3. Verify your RPC endpoint is working properly");
    throw error;
  }
}

main()
  .then(() => {
    console.log("\n✨ Script completed successfully!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\n💥 Script failed with error:", error);
    process.exit(1);
  });
