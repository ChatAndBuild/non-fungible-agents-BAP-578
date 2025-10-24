const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("📚 BAP-578 Agent Knowledge Upload\n");
  console.log("=" .repeat(60));

  const [deployer] = await ethers.getSigners();
  console.log("🔑 Using account:", deployer.address);

  // Get the latest deployment
  const deploymentsDir = path.join(__dirname, "..", "deployments");
  const deploymentFiles = fs.readdirSync(deploymentsDir)
    .filter(file => file.endsWith('.json'))
    .sort((a, b) => {
      const timestampA = parseInt(a.split('-')[1]?.replace('.json', '') || '0');
      const timestampB = parseInt(b.split('-')[1]?.replace('.json', '') || '0');
      return timestampB - timestampA;
    });

  const latestDeployment = deploymentFiles[0];
  const deploymentPath = path.join(deploymentsDir, latestDeployment);
  const deployment = JSON.parse(fs.readFileSync(deploymentPath, 'utf8'));

  console.log(`📁 Using deployment: ${latestDeployment}`);
  console.log(`🌐 Network: ${deployment.network}\n`);

  const contracts = deployment.contracts;

  try {
    // Get KnowledgeRegistry contract
    const knowledgeRegistry = await ethers.getContractAt(
      "KnowledgeRegistry", 
      contracts.KnowledgeRegistry
    );

    // Get the agent contract address and token ID of your agent
    // You'll need to get this from your agent creation transaction
    const AGENT_CONTRACT = "0xb9793c8F7fa0cA9c80061A6635005a1B21E0D5F1"; // Your newly created agent's contract address
    const tokenId = 1; // Token ID is always 1 for each agent
    
    console.log(`🤖 Adding knowledge to Agent:`);
    console.log(`   Contract: ${AGENT_CONTRACT}`);
    console.log(`   Token ID: ${tokenId}\n`);

    // Define different types of knowledge sources
    const knowledgeSources = [
      {
        uri: "ipfs://QmYourBaseKnowledgeHash",  // Replace with your IPFS hash
        type: 0, // BASE - Base training data
        priority: 100, // Highest priority
        description: "Core knowledge base with foundational AI training data",
        contentHash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("base_knowledge_v1"))
      },
      {
        uri: "https://api.example.com/agent-context.json", // Can use HTTP links
        type: 1, // CONTEXT - Contextual information
        priority: 90,
        description: "Contextual information about the agent's environment and purpose",
        contentHash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("context_v1"))
      },
      {
        uri: "ipfs://QmAgentMemoryStorage",
        type: 2, // MEMORY - Agent memories
        priority: 80,
        description: "Persistent memory storage for agent experiences",
        contentHash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("memory_v1"))
      },
      {
        uri: "ipfs://QmInstructionSet",
        type: 3, // INSTRUCTION - Instructions/prompts
        priority: 95,
        description: "System prompts and behavioral instructions",
        contentHash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("instructions_v1"))
      },
      {
        uri: "https://docs.example.com/reference",
        type: 4, // REFERENCE - Reference documentation
        priority: 70,
        description: "Reference documentation and external resources",
        contentHash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("reference_v1"))
      }
    ];

    // First, check the current knowledge configuration
    console.log("📊 Checking Knowledge Configuration...");
    const config = await knowledgeRegistry.getKnowledgeConfig(AGENT_CONTRACT, tokenId);
    console.log(`  Max Sources Allowed: ${config.maxSources}`);
    console.log(`  Dynamic Sources Allowed: ${config.allowDynamicSources}`);
    console.log(`  Current Total Sources: ${config.totalSources}`);
    console.log(`  Active Sources: ${config.activeSources}\n`);

    // Add each knowledge source
    console.log("📤 Adding Knowledge Sources...");
    console.log("-" .repeat(60));
    
    const addedSources = [];
    for (const source of knowledgeSources) {
      console.log(`\n🔸 Adding ${getKnowledgeTypeName(source.type)} knowledge:`);
      console.log(`  URI: ${source.uri}`);
      console.log(`  Priority: ${source.priority}`);
      console.log(`  Description: ${source.description.substring(0, 60)}...`);
      
        const tx = await knowledgeRegistry.addKnowledgeSource(
          AGENT_CONTRACT,
          tokenId,
          source.uri,
          source.type,
          source.priority,
          source.description,
          source.contentHash
        );
      
      console.log(`  ⏳ Transaction: ${tx.hash}`);
      const receipt = await tx.wait();
      
      // Get the source ID from the event
      const event = receipt.events?.find(e => e.event === 'KnowledgeSourceAdded');
      const sourceId = event?.args?.sourceId;
      
      console.log(`  ✅ Added with Source ID: ${sourceId}`);
      addedSources.push({ ...source, id: sourceId });
    }

    console.log("\n" + "=" .repeat(60));
    console.log("📚 Knowledge Sources Summary:");
    console.log("-" .repeat(60));
    
    // Get all knowledge sources for the agent
    const allSources = await knowledgeRegistry.getKnowledgeSources(AGENT_CONTRACT, tokenId);
    console.log(`Total Knowledge Sources: ${allSources.length}`);
    
    // Get sources by priority (sorted)
    const prioritizedSources = await knowledgeRegistry.getKnowledgeSourcesByPriority(AGENT_CONTRACT, tokenId);
    console.log("\n🎯 Sources by Priority (High to Low):");
    for (const source of prioritizedSources) {
      console.log(`  ${source.priority}: ${getKnowledgeTypeName(source.sourceType)} - ${source.uri}`);
    }

    // Display usage examples
    console.log("\n" + "=" .repeat(60));
    console.log("🔧 Knowledge Management Examples:");
    console.log("-" .repeat(60));
    console.log("\n1️⃣ Update a knowledge source:");
    console.log(`   await knowledgeRegistry.updateKnowledgeSource(`);
    console.log(`     "${AGENT_CONTRACT}", // agent contract`);
    console.log(`     ${tokenId}, // tokenId`);
    console.log(`     sourceId, // ID of the source to update`);
    console.log(`     "ipfs://QmNewKnowledgeHash", // new URI`);
    console.log(`     newContentHash // new content hash`);
    console.log(`   )`);
    
    console.log("\n2️⃣ Toggle knowledge source active/inactive:");
    console.log(`   await knowledgeRegistry.toggleKnowledgeSource("${AGENT_CONTRACT}", ${tokenId}, sourceId)`);
    
    console.log("\n3️⃣ Change priority of a source:");
    console.log(`   await knowledgeRegistry.changeKnowledgePriority("${AGENT_CONTRACT}", ${tokenId}, sourceId, newPriority)`);
    
    console.log("\n4️⃣ Remove a knowledge source:");
    console.log(`   await knowledgeRegistry.removeKnowledgeSource("${AGENT_CONTRACT}", ${tokenId}, sourceId)`);
    
    console.log("\n5️⃣ Get active knowledge sources:");
    console.log(`   const activeSources = await knowledgeRegistry.getActiveKnowledgeSources("${AGENT_CONTRACT}", ${tokenId})`);
    
    console.log("\n6️⃣ Get knowledge by type (e.g., INSTRUCTION):");
    console.log(`   const instructions = await knowledgeRegistry.getKnowledgeSourcesByType("${AGENT_CONTRACT}", ${tokenId}, 3)`);

    // Knowledge types reference
    console.log("\n" + "=" .repeat(60));
    console.log("📖 Knowledge Types Reference:");
    console.log("-" .repeat(60));
    console.log("  0 = BASE        : Base training data");
    console.log("  1 = CONTEXT     : Contextual information");
    console.log("  2 = MEMORY      : Agent memories");
    console.log("  3 = INSTRUCTION : Instructions/prompts");
    console.log("  4 = REFERENCE   : Reference documentation");
    console.log("  5 = DYNAMIC     : Dynamic/live data");

    // Best practices
    console.log("\n" + "=" .repeat(60));
    console.log("💡 Best Practices for Knowledge Management:");
    console.log("-" .repeat(60));
    console.log("1. Use IPFS for immutable, decentralized storage");
    console.log("2. Use higher priority (90-100) for core knowledge");
    console.log("3. Use content hashes to verify data integrity");
    console.log("4. Version your knowledge sources when updating");
    console.log("5. Use descriptive URIs and descriptions");
    console.log("6. Organize knowledge by type for better retrieval");
    console.log("7. Keep inactive outdated sources for history");
    
    // How to upload to IPFS
    console.log("\n" + "=" .repeat(60));
    console.log("🌐 How to Upload Knowledge to IPFS:");
    console.log("-" .repeat(60));
    console.log("1. Install IPFS CLI or use Pinata/Infura");
    console.log("2. Prepare your knowledge file (JSON, TXT, etc.)");
    console.log("3. Upload: ipfs add yourfile.json");
    console.log("4. Pin it: ipfs pin add <hash>");
    console.log("5. Use the hash: ipfs://Qm...");
    console.log("\nExample knowledge.json structure:");
    console.log(JSON.stringify({
      version: "1.0.0",
      agent_name: "Your Agent",
      knowledge: {
        base_knowledge: ["fact1", "fact2"],
        capabilities: ["capability1", "capability2"],
        personality: "Professional and helpful",
        goals: ["goal1", "goal2"]
      }
    }, null, 2));

    console.log("\n✅ Knowledge successfully added to your agent!");

  } catch (error) {
    console.error("\n❌ Error adding knowledge:", error.message);
    
    if (error.message.includes("caller is not token owner")) {
      console.log("\n💡 Hint: Make sure you own the token ID specified");
    } else if (error.message.includes("max sources reached")) {
      console.log("\n💡 Hint: The agent has reached its maximum knowledge sources limit");
      console.log("    You may need to remove some sources or increase the limit");
    }
    throw error;
  }
}

// Helper function to get knowledge type name
function getKnowledgeTypeName(type) {
  const types = ["BASE", "CONTEXT", "MEMORY", "INSTRUCTION", "REFERENCE", "DYNAMIC"];
  return types[type] || "UNKNOWN";
}

// Run the script
main()
  .then(() => {
    console.log("\n✨ Knowledge upload completed successfully!");
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
