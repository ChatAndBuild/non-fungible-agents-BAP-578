const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("🤖 BAP-578 Agent Creation with Vault Support\n");
  console.log("=" .repeat(60));

  const [deployer] = await ethers.getSigners();
  console.log("🔑 Using account:", deployer.address);

  // Check account balance
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("💰 Account balance:", ethers.utils.formatEther(balance), "ETH\n");

  // Get the latest deployment
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
    // Get AgentFactory contract instance
    const agentFactory = await ethers.getContractAt("AgentFactory", contracts.AgentFactory);
    
    // Prepare agent parameters
    const agentParams = {
      name: "Vault-Enabled Agent",
      symbol: "VEA",
      logicAddress: "0x" + "1234567890abcdef".repeat(5).substring(0, 40), // Mock logic address
      metadataURI: "ipfs://QmAgentMetadata123",
      extendedMetadata: {
        persona: "Advanced AI agent with secure vault storage for sensitive data and learning experiences",
        experience: "Specialized in data management, secure storage patterns, and distributed systems",
        voiceHash: "voice_secure_v1.0",
        animationURI: "ipfs://QmAgentAnimation456",
        vaultURI: "ipfs://QmVaultData789",  // ✅ Vault URI included!
        vaultHash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("secure_vault_content_" + Date.now()))  // ✅ Vault hash for verification!
      }
    };
    
    console.log("🚀 Creating Agent with Extended Metadata and Vault Support...");
    console.log("-" .repeat(60));
    console.log("📋 Agent Details:");
    console.log(`  Name: ${agentParams.name}`);
    console.log(`  Symbol: ${agentParams.symbol}`);
    console.log(`  Logic Address: ${agentParams.logicAddress}`);
    console.log(`  Metadata URI: ${agentParams.metadataURI}`);
    console.log("\n📦 Extended Metadata:");
    console.log(`  Persona: ${agentParams.extendedMetadata.persona.substring(0, 80)}...`);
    console.log(`  Experience: ${agentParams.extendedMetadata.experience.substring(0, 80)}...`);
    console.log(`  Voice Hash: ${agentParams.extendedMetadata.voiceHash}`);
    console.log(`  Animation URI: ${agentParams.extendedMetadata.animationURI}`);
    console.log(`  Vault URI: ${agentParams.extendedMetadata.vaultURI}`);
    console.log(`  Vault Hash: ${agentParams.extendedMetadata.vaultHash}`);
    console.log("-" .repeat(60) + "\n");
    
    // Check if we have enough balance for the fee (0.01 ETH + gas)
    const requiredFee = ethers.utils.parseEther("0.01");
    if (balance.lt(requiredFee.mul(2))) { // Check for fee + gas buffer
      console.error("❌ Insufficient balance. Need at least 0.02 ETH (0.01 for fee + gas)");
      return;
    }
    
    // Create the agent using the new function
    console.log("💸 Sending transaction with 0.01 ETH fee...");
    const createTx = await agentFactory.createAgentWithExtendedMetadata(
      agentParams.name,
      agentParams.symbol,
      agentParams.logicAddress,
      agentParams.metadataURI,
      agentParams.extendedMetadata,
      { value: requiredFee }
    );
    
    console.log("⏳ Transaction sent, waiting for confirmation...");
    console.log(`📝 Transaction hash: ${createTx.hash}`);
    
    const receipt = await createTx.wait();
    
    // Get the agent address and token ID from events
    const agentCreatedEvent = receipt.events?.find(e => e.event === 'AgentCreated');
    const agentAddress = agentCreatedEvent?.args?.agent;
    const tokenId = agentCreatedEvent?.args?.tokenId;
    const owner = agentCreatedEvent?.args?.owner;
    
    console.log("\n✅ Agent created successfully!");
    console.log(`🏠 Agent Contract: ${agentAddress}`);
    console.log(`🆔 Token ID: ${tokenId}`);
    console.log(`👤 Owner: ${owner}`);
    console.log(`⛽ Gas used: ${receipt.gasUsed.toString()}`);
    
    // Get the BAP578 instance to verify the extended metadata
    const bap578 = await ethers.getContractAt("BAP578", agentAddress);
    
    // Get and display the agent's extended metadata
    console.log("\n🔍 Verifying Agent Metadata...");
    const metadata = await bap578.getAgentMetadata(tokenId);
    
    console.log("📊 Stored Extended Metadata:");
    console.log(`  Persona: ${metadata.persona ? "✅ Stored" : "❌ Empty"}`);
    console.log(`  Experience: ${metadata.experience ? "✅ Stored" : "❌ Empty"}`);
    console.log(`  Voice Hash: ${metadata.voiceHash ? "✅ " + metadata.voiceHash : "❌ Empty"}`);
    console.log(`  Animation URI: ${metadata.animationURI ? "✅ " + metadata.animationURI : "❌ Empty"}`);
    console.log(`  Vault URI: ${metadata.vaultURI ? "✅ " + metadata.vaultURI : "❌ Empty"}`);
    console.log(`  Vault Hash: ${metadata.vaultHash !== "0x0000000000000000000000000000000000000000000000000000000000000000" ? "✅ Set" : "❌ Empty"}`);
    
    // Get agent state
    const agentState = await bap578.getState(tokenId);
    console.log("\n📈 Agent State:");
    console.log(`  Status: ${["Paused", "Active", "Terminated"][agentState.status]}`);
    console.log(`  Balance: ${ethers.utils.formatEther(agentState.balance)} ETH`);
    console.log(`  Logic Address: ${agentState.logicAddress}`);
    
    // Display vault access information
    console.log("\n🔐 Vault Access Information:");
    console.log("-" .repeat(60));
    console.log("The agent's vault is now configured and can be accessed through:");
    console.log(`  Vault URI: ${metadata.vaultURI}`);
    console.log(`  Verification Hash: ${metadata.vaultHash}`);
    console.log("\nTo grant vault access permissions, use the VaultPermissionManager contract:");
    console.log("  1. Create a vault in VaultPermissionManager");
    console.log("  2. Grant permissions to delegates");
    console.log("  3. Delegates can access vault data with time-based permissions");
    
    // Display comparison with old method
    console.log("\n📊 Comparison: Old vs New Creation Method:");
    console.log("-" .repeat(60));
    console.log("Old Method (createAgent):");
    console.log("  ❌ No vault support");
    console.log("  ❌ No extended metadata");
    console.log("  ❌ Empty persona and experience");
    console.log("\nNew Method (createAgentWithExtendedMetadata):");
    console.log("  ✅ Full vault support (URI + Hash)");
    console.log("  ✅ Extended metadata included");
    console.log("  ✅ Persona and experience data");
    console.log("  ✅ Animation and voice support");
    console.log("  ✅ Same 0.01 ETH fee");
    
    // Display treasury stats
    const treasury = await ethers.getContractAt("BAP578Treasury", contracts.BAP578Treasury);
    const treasuryStats = await treasury.getTreasuryStats();
    
    console.log("\n💰 Treasury Stats After Creation Fee:");
    console.log("-" .repeat(60));
    console.log(`Total Received: ${ethers.utils.formatEther(treasuryStats.totalReceived)} ETH`);
    console.log(`Foundation (60%): ${ethers.utils.formatEther(treasuryStats.foundationDistributed)} ETH`);
    console.log(`Community (25%): ${ethers.utils.formatEther(treasuryStats.treasuryDistributed)} ETH`);
    console.log(`Staking (15%): ${ethers.utils.formatEther(treasuryStats.stakingDistributed)} ETH`);
    
    // Display usage instructions
    console.log("\n🎯 Next Steps:");
    console.log("-" .repeat(60));
    console.log("1. Create a vault in VaultPermissionManager:");
    console.log(`   await vaultManager.createVault("agent-${tokenId}-vault", "Agent vault description")`);
    console.log("\n2. Grant permissions to delegates:");
    console.log(`   await vaultManager.grantPermission(delegateAddress, "agent-${tokenId}-vault", 1, 3600, "metadata")`);
    console.log("\n3. Fund the agent:");
    console.log(`   await bap578.fundAgent(${tokenId}, { value: ethers.utils.parseEther("0.1") })`);
    console.log("\n4. Check agent metadata:");
    console.log(`   await bap578.getAgentMetadata(${tokenId})`);
    
    console.log("\n✨ Success! Your agent is created with full vault support!");

  } catch (error) {
    console.error("\n❌ Error creating agent:", error.message);
    
    // Provide helpful error messages
    if (error.message.includes("insufficient funds")) {
      console.log("\n💡 Hint: Make sure your account has at least 0.01 ETH for the creation fee plus gas");
    } else if (error.message.includes("AgentFactory")) {
      console.log("\n💡 Hint: Make sure AgentFactory is properly deployed and upgraded");
    } else if (error.message.includes("createAgentWithExtendedMetadata")) {
      console.log("\n💡 Hint: The AgentFactory contract needs to be upgraded to support the new function");
      console.log("      You may need to upgrade the contract using the proxy upgrade mechanism");
    }
    throw error;
  }
}

// Run the script
main()
  .then(() => {
    console.log("\n✨ Agent creation with vault support completed successfully!");
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
