const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("📚 Simple Knowledge Upload for BAP-578 Agent\n");
  console.log("=" .repeat(60));

  const [deployer] = await ethers.getSigners();
  console.log("🔑 Using account:", deployer.address);

  // Configuration - MODIFY THESE
  const AGENT_CONTRACT = "0x5c945E46D1f61284677840b368277abC67e68fd0"; // Your agent's contract address
  const TOKEN_ID = 1; // Token ID (always 1 for each agent)
  const KNOWLEDGE_URI = "ipfs://QmYourKnowledgeHash"; // Your IPFS hash or HTTP URL
  
  // Example: You can use a public IPFS gateway URL instead:
  // const KNOWLEDGE_URI = "https://ipfs.io/ipfs/QmYourHash";
  
  // Example: You can use a GitHub raw file:
  // const KNOWLEDGE_URI = "https://raw.githubusercontent.com/user/repo/main/knowledge.json";

  // Get deployment
  const deploymentsDir = path.join(__dirname, "..", "deployments");
  const deploymentFiles = fs.readdirSync(deploymentsDir)
    .filter(file => file.endsWith('.json'))
    .sort((a, b) => {
      const timestampA = parseInt(a.split('-')[1]?.replace('.json', '') || '0');
      const timestampB = parseInt(b.split('-')[1]?.replace('.json', '') || '0');
      return timestampB - timestampA;
    });

  const latestDeployment = deploymentFiles[0];
  const deployment = JSON.parse(
    fs.readFileSync(path.join(deploymentsDir, latestDeployment), 'utf8')
  );

  console.log(`📁 Using deployment: ${latestDeployment}\n`);

  try {
    // Get KnowledgeRegistry contract
    const knowledgeRegistry = await ethers.getContractAt(
      "KnowledgeRegistry", 
      deployment.contracts.KnowledgeRegistry
    );

  console.log(`🤖 Adding knowledge to Agent:`);
  console.log(`  📍 Contract: ${AGENT_CONTRACT}`);
  console.log(`  🆔 Token ID: ${TOKEN_ID}`);
  console.log(`  📎 Knowledge URI: ${KNOWLEDGE_URI}\n`);

    // Add the knowledge source
    console.log("📤 Uploading knowledge...");
    
    const tx = await knowledgeRegistry.addKnowledgeSource(
      AGENT_CONTRACT,
      TOKEN_ID,
      KNOWLEDGE_URI,
      0, // Type: BASE (0) - Change as needed
      100, // Priority: 100 (highest)
      "Primary knowledge base for the agent", // Description
      ethers.utils.keccak256(ethers.utils.toUtf8Bytes(KNOWLEDGE_URI)) // Content hash
    );
    
    console.log(`⏳ Transaction sent: ${tx.hash}`);
    console.log("   Waiting for confirmation...");
    
    const receipt = await tx.wait();
    const event = receipt.events?.find(e => e.event === 'KnowledgeSourceAdded');
    const sourceId = event?.args?.sourceId;
    
    console.log(`\n✅ Knowledge added successfully!`);
    console.log(`   Source ID: ${sourceId}`);
    console.log(`   Gas used: ${receipt.gasUsed.toString()}`);

    // Verify the upload
    const sources = await knowledgeRegistry.getKnowledgeSources(AGENT_CONTRACT, TOKEN_ID);
    console.log(`\n📊 Total knowledge sources for this agent: ${sources.length}`);
    
    const latestSource = sources[sources.length - 1];
    console.log("\n📚 Latest knowledge source details:");
    console.log(`   URI: ${latestSource.uri}`);
    console.log(`   Type: ${getTypeName(latestSource.sourceType)}`);
    console.log(`   Priority: ${latestSource.priority}`);
    console.log(`   Active: ${latestSource.active}`);
    console.log(`   Description: ${latestSource.description}`);

    console.log("\n" + "=" .repeat(60));
    console.log("🎉 Success! Your knowledge has been uploaded.");
    console.log("\nNext steps:");
    console.log("1. Upload more knowledge sources if needed");
    console.log("2. Update existing sources with new versions");
    console.log("3. Manage priorities to control importance");
    console.log("4. Toggle sources on/off as needed");

  } catch (error) {
    console.error("\n❌ Error:", error.message);
    
    if (error.message.includes("caller is not token owner")) {
      console.log("\n💡 You need to be the owner of token ID", TOKEN_ID);
      console.log("   Make sure you're using the correct token ID");
    }
  }
}

function getTypeName(type) {
  const types = ["BASE", "CONTEXT", "MEMORY", "INSTRUCTION", "REFERENCE", "DYNAMIC"];
  return types[type] || "UNKNOWN";
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
