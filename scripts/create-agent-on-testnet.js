const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("🤖 Creating Agent on BSC Testnet using AgentFactory\n");
  console.log("=" .repeat(60));

  // Get signer
  const [deployer] = await ethers.getSigners();
  console.log("🔑 Using account:", deployer.address);

  // Check account balance
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("💰 Account balance:", ethers.utils.formatEther(balance), "BNB");

  // Check if we have enough balance for creation fee + gas
  const AGENT_CREATION_FEE = ethers.utils.parseEther("0.01");
  const requiredBalance = AGENT_CREATION_FEE.add(ethers.utils.parseEther("0.005")); // Fee + gas estimate
  
  if (balance.lt(requiredBalance)) {
    console.error(`\n❌ Insufficient balance. Need at least ${ethers.utils.formatEther(requiredBalance)} BNB`);
    console.error(`   Current: ${ethers.utils.formatEther(balance)} BNB`);
    console.error(`   Required: 0.01 BNB (creation fee) + ~0.005 BNB (gas)`);
    console.log("\n💡 Get testnet BNB from: https://testnet.binance.org/faucet-smart");
    return;
  }

  // Load deployment info - use the latest deployment
  const deploymentPath = path.join(__dirname, "..", "deployments", "bnbt-fixed-1759915283449.json");
  const deployment = JSON.parse(fs.readFileSync(deploymentPath, 'utf8'));
  
  console.log(`\n📁 Using deployment from: ${deployment.timestamp}`);
  console.log(`🌐 Network: BSC Testnet (chainId: ${deployment.chainId})`);
  console.log(`📍 AgentFactory: ${deployment.contracts.AgentFactory}\n`);

  // Agent parameters
  const agentParams = {
    name: "Test Agent BSC",
    symbol: "TAGENT",
    logicAddress: "0x0000000000000000000000000000000000000001", // Use address(1) as placeholder instead of AddressZero
    metadataURI: "ipfs://QmTestAgentMetadata" + Date.now() // Unique metadata URI
  };

  console.log("📝 Agent Parameters:");
  console.log("-" .repeat(60));
  console.log(`  Name: ${agentParams.name}`);
  console.log(`  Symbol: ${agentParams.symbol}`);
  console.log(`  Logic Address: ${agentParams.logicAddress}`);
  console.log(`  Metadata URI: ${agentParams.metadataURI}`);
  console.log(`  Creation Fee: 0.01 BNB`);
  console.log("");

  try {
    // Get AgentFactory contract instance
    const agentFactory = await ethers.getContractAt("AgentFactory", deployment.contracts.AgentFactory);
    
    // Check current fee (should be 0.01 ETH/BNB)
    const creationFee = await agentFactory.AGENT_CREATION_FEE();
    console.log(`💵 Verified Creation Fee: ${ethers.utils.formatEther(creationFee)} BNB\n`);

    // Create the agent
    console.log("🚀 Creating agent through AgentFactory...");
    console.log("⏳ Sending transaction...\n");
    
    const createTx = await agentFactory.createAgent(
      agentParams.name,
      agentParams.symbol,
      agentParams.logicAddress,
      agentParams.metadataURI,
      { 
        value: AGENT_CREATION_FEE,
        gasLimit: 3000000 // Set explicit gas limit for safety
      }
    );
    
    console.log(`📤 Transaction sent!`);
    console.log(`   Hash: ${createTx.hash}`);
    console.log(`   Explorer: https://testnet.bscscan.com/tx/${createTx.hash}\n`);
    
    console.log("⏳ Waiting for confirmation...");
    const receipt = await createTx.wait();
    
    console.log(`✅ Transaction confirmed!`);
    console.log(`   Block: ${receipt.blockNumber}`);
    console.log(`   Gas Used: ${receipt.gasUsed.toString()}\n`);
    
    // Parse events to get the created agent address and token ID
    const agentCreatedEvent = receipt.events?.find(e => e.event === 'AgentCreated');
    
    if (agentCreatedEvent) {
      const { agent, owner, tokenId, logic } = agentCreatedEvent.args;
      
      console.log("🎉 Agent Created Successfully!");
      console.log("=" .repeat(60));
      console.log(`  Agent Contract: ${agent}`);
      console.log(`  Token ID: ${tokenId.toString()}`);
      console.log(`  Owner: ${owner}`);
      console.log(`  Logic: ${logic}`);
      console.log(`  Explorer: https://testnet.bscscan.com/address/${agent}`);
      
      // Get BAP578 instance to interact with the agent
      const bap578 = await ethers.getContractAt("BAP578", agent);
      
      // Get agent state
      console.log("\n📊 Agent State:");
      console.log("-" .repeat(60));
      try {
        const state = await bap578.getState(tokenId);
        console.log(`  Owner: ${state.owner}`);
        console.log(`  Status: ${["Paused", "Active", "Terminated"][state.status]}`);
        console.log(`  Balance: ${ethers.utils.formatEther(state.balance)} BNB`);
        console.log(`  Last Action: ${new Date(state.lastActionTimestamp * 1000).toISOString()}`);
      } catch (error) {
        console.log("  (Unable to fetch state - may need to wait for indexing)");
      }
      
      // Save agent info to file
      const agentInfo = {
        network: "BSC Testnet",
        chainId: 97,
        createdAt: new Date().toISOString(),
        transactionHash: createTx.hash,
        blockNumber: receipt.blockNumber,
        agent: {
          address: agent,
          tokenId: tokenId.toString(),
          name: agentParams.name,
          symbol: agentParams.symbol,
          owner: owner,
          logic: logic,
          metadataURI: agentParams.metadataURI
        },
        contracts: {
          agentFactory: deployment.contracts.AgentFactory,
          treasury: deployment.contracts.BAP578Treasury,
          governance: deployment.contracts.BAP578Governance
        }
      };
      
      const agentsDir = path.join(__dirname, "..", "created-agents");
      if (!fs.existsSync(agentsDir)) {
        fs.mkdirSync(agentsDir);
      }
      
      const filename = `agent-${Date.now()}.json`;
      const filepath = path.join(agentsDir, filename);
      fs.writeFileSync(filepath, JSON.stringify(agentInfo, null, 2));
      
      console.log(`\n💾 Agent info saved to: created-agents/${filename}`);
      
      // Display next steps
      console.log("\n🔧 Next Steps:");
      console.log("-" .repeat(60));
      console.log("1. Fund your agent:");
      console.log(`   await bap578.fundAgent(${tokenId}, { value: ethers.utils.parseEther('0.1') })`);
      console.log("\n2. Set agent metadata:");
      console.log(`   await bap578.setMetadataURI(${tokenId}, 'your-metadata-uri')`);
      console.log("\n3. Activate agent (if needed):");
      console.log(`   await bap578.unpause(${tokenId})`);
      console.log("\n4. Check agent state:");
      console.log(`   await bap578.getState(${tokenId})`);
      
      // Check treasury distribution
      console.log("\n💰 Treasury Fee Distribution:");
      console.log("-" .repeat(60));
      const treasury = await ethers.getContractAt("BAP578Treasury", deployment.contracts.BAP578Treasury);
      const treasuryStats = await treasury.getTreasuryStats();
      console.log(`  Total Received: ${ethers.utils.formatEther(treasuryStats.totalReceived)} BNB`);
      console.log(`  Foundation (60%): ${ethers.utils.formatEther(treasuryStats.foundationDistributed)} BNB`);
      console.log(`  Community (25%): ${ethers.utils.formatEther(treasuryStats.treasuryDistributed)} BNB`);
      console.log(`  Staking (15%): ${ethers.utils.formatEther(treasuryStats.stakingDistributed)} BNB`);
      
    } else {
      console.log("⚠️ AgentCreated event not found. Check transaction logs manually.");
      console.log(`   Explorer: https://testnet.bscscan.com/tx/${createTx.hash}`);
    }
    
  } catch (error) {
    console.error("\n❌ Error creating agent:", error.message);
    
    // Provide helpful error messages
    if (error.message.includes("insufficient funds")) {
      console.log("\n💡 Hint: Make sure you have at least 0.01 BNB for the creation fee plus gas");
      console.log("   Get testnet BNB from: https://testnet.binance.org/faucet-smart");
    } else if (error.message.includes("execution reverted")) {
      console.log("\n💡 Hint: Transaction reverted. Check:");
      console.log("   - AgentFactory contract is properly initialized");
      console.log("   - Treasury contract is set and operational");
      console.log("   - You're sending exactly 0.01 BNB as fee");
    }
    
    throw error;
  }
}

// Run the script
main()
  .then(() => {
    console.log("\n✨ Agent creation completed successfully!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\nScript failed:", error);
    process.exit(1);
  });
