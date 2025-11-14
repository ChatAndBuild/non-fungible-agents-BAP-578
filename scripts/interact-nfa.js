const hre = require("hardhat");
const readline = require("readline");
const fs = require("fs");

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

const question = (query) => new Promise((resolve) => rl.question(query, resolve));

// Helper function to create agent metadata
async function promptForMetadata() {
  console.log("\n📝 Enter Agent Metadata:");
  
  const persona = await question("Persona (JSON for traits/style, or press enter for default): ");
  const experience = await question("Experience/Role (e.g., 'Financial advisor'): ");
  const voiceHash = await question("Voice Hash (or press enter for 'voice_default'): ");
  const animationURI = await question("Animation URI (or press enter for none): ");
  const vaultURI = await question("Vault URI (or press enter for none): ");
  const vaultHashInput = await question("Vault Hash (or press enter for default): ");
  
  return {
    persona: persona || JSON.stringify({
      traits: ["helpful", "professional"],
      style: "friendly",
      tone: "conversational"
    }),
    experience: experience || "General AI Assistant",
    voiceHash: voiceHash || "voice_default",
    animationURI: animationURI || "",
    vaultURI: vaultURI || "",
    vaultHash: vaultHashInput 
      ? hre.ethers.utils.formatBytes32String(vaultHashInput)
      : hre.ethers.utils.formatBytes32String("default")
  };
}

async function main() {
  console.log("\n🤖 BAP578 - Interactive CLI\n");

  // Load deployment info
  const network = hre.network.name;
  const deploymentPath = `./deployments/${network}_deployment.json`;
  
  if (!fs.existsSync(deploymentPath)) {
    console.log("❌ No deployment found for network:", network);
    console.log("Please run the deployment script first: npx hardhat run scripts/deploy.js --network", network);
    process.exit(1);
  }

  const deployment = JSON.parse(fs.readFileSync(deploymentPath, "utf8"));
  console.log("📍 Using contract at:", deployment.proxy);

  const BAP578 = await hre.ethers.getContractFactory("BAP578");
  const nfa = BAP578.attach(deployment.proxy);
  const [signer] = await hre.ethers.getSigners();

  console.log("👤 Connected as:", signer.address);
  console.log("💰 Balance:", hre.ethers.utils.formatEther(await signer.getBalance()), "BNB");

  while (true) {
    console.log("\n📋 Choose an action:");
    console.log("1. Create new agent");
    console.log("2. View my agents");
    console.log("3. View agent details");
    console.log("4. Fund an agent");
    console.log("5. Withdraw from agent");
    console.log("6. Update agent status");
    console.log("7. Update agent logic address");
    console.log("8. Update agent metadata");
    console.log("9. View contract info");
    console.log("10. Admin functions");
    console.log("0. Exit");

    const choice = await question("\n> ");

    try {
      switch (choice) {
        case "1": // Create new agent
          const recipient = await question("Recipient address (or press enter for self): ");
          const logicAddress = await question("Logic address (or press enter for zero address): ");
          const newAgentMetadataURI = await question("Metadata URI (e.g., ipfs://...): ");
          
          const newAgentMetadata = await promptForMetadata();
          
          const mintFee = await nfa.MINT_FEE();
          const freeMintsRemaining = await nfa.getFreeMints(signer.address);
          
          if (freeMintsRemaining > 0) {
            console.log(`\n🎁 You have ${freeMintsRemaining} free mints remaining!`);
            console.log("🆓 Creating agent with free mint...");
            
            const tx = await nfa.createAgent(
              recipient || signer.address,
              logicAddress || hre.ethers.constants.AddressZero,
              newAgentMetadataURI,
              newAgentMetadata
            );
            const receipt = await tx.wait();
            console.log("✅ Agent created! Transaction:", receipt.transactionHash);
            
            const event = receipt.events.find(e => e.event === "AgentCreated");
            if (event) {
              console.log("🎯 Token ID:", event.args.tokenId.toString());
            }
            
            const remainingNow = await nfa.getFreeMints(signer.address);
            if (remainingNow > 0) {
              console.log(`�� You have ${remainingNow} free mints left`);
            } else {
              console.log("⚠️ You've used all your free mints. Future mints will cost", hre.ethers.utils.formatEther(mintFee), "BNB");
            }
            break;
          }
          
          console.log(`\n💎 Minting fee: ${hre.ethers.utils.formatEther(mintFee)} BNB`);
          console.log("💸 No free mints remaining, paying mint fee...");
          const tx = await nfa.createAgent(
            recipient || signer.address,
            logicAddress || hre.ethers.constants.AddressZero,
            newAgentMetadataURI,
            newAgentMetadata,
            { value: mintFee }
          );
          const receipt = await tx.wait();
          console.log("✅ Agent created! Transaction:", receipt.transactionHash);
          
          const event = receipt.events.find(e => e.event === "AgentCreated");
          if (event) {
            console.log("🎯 Token ID:", event.args.tokenId.toString());
          }
          break;

        case "2": // View my agents
          const myTokens = await nfa.tokensOfOwner(signer.address);
          console.log(`\n📦 You own ${myTokens.length} agents:`);
          for (const tokenId of myTokens) {
            const state = await nfa.getAgentState(tokenId);
            console.log(`- Token #${tokenId}: ${state.active ? "✅ Active" : "⏸️ Inactive"}, Balance: ${hre.ethers.utils.formatEther(state.balance)} BNB`);
          }
          break;

        case "3": // View agent details
          const viewTokenId = await question("Enter token ID: ");
          const state = await nfa.getAgentState(viewTokenId);
          const [metadata, metadataURI] = await nfa.getAgentMetadata(viewTokenId);
          
          console.log(`\n🔍 Agent #${viewTokenId}:`);
          console.log("📊 State:");
          console.log("  - Owner:", state.owner);
          console.log("  - Active:", state.active);
          console.log("  - Balance:", hre.ethers.utils.formatEther(state.balance), "BNB");
          console.log("  - Logic Address:", state.logicAddress);
          console.log("  - Created At:", new Date(state.createdAt * 1000).toLocaleString());
          
          console.log("\n📝 Metadata:");
          console.log("  - URI:", metadataURI);
          console.log("  - Persona:", metadata.persona);
          console.log("  - Experience:", metadata.experience);
          console.log("  - Voice Hash:", metadata.voiceHash);
          console.log("  - Animation URI:", metadata.animationURI);
          console.log("  - Vault URI:", metadata.vaultURI);
          break;

        case "4": // Fund an agent
          const fundTokenId = await question("Enter token ID to fund: ");
          const fundAmount = await question("Amount to fund (BNB): ");
          
          const fundTx = await nfa.fundAgent(fundTokenId, {
            value: hre.ethers.utils.parseEther(fundAmount)
          });
          await fundTx.wait();
          console.log(`✅ Funded agent #${fundTokenId} with ${fundAmount} BNB`);
          break;

        case "5": // Withdraw from agent
          const withdrawTokenId = await question("Enter your token ID: ");
          const withdrawAmount = await question("Amount to withdraw (BNB): ");
          
          const withdrawTx = await nfa.withdrawFromAgent(
            withdrawTokenId,
            hre.ethers.utils.parseEther(withdrawAmount)
          );
          await withdrawTx.wait();
          console.log(`✅ Withdrew ${withdrawAmount} BNB from agent #${withdrawTokenId}`);
          break;

        case "6": // Update agent status
          const statusTokenId = await question("Enter your token ID: ");
          const newStatus = await question("Set active? (y/n): ");
          
          const statusTx = await nfa.setAgentStatus(
            statusTokenId,
            newStatus.toLowerCase() === 'y'
          );
          await statusTx.wait();
          console.log(`✅ Updated agent #${statusTokenId} status`);
          break;

        case "7": // Update logic address
          const logicTokenId = await question("Enter your token ID: ");
          const newLogicAddress = await question("New logic address: ");
          
          const logicTx = await nfa.setLogicAddress(logicTokenId, newLogicAddress);
          await logicTx.wait();
          console.log(`✅ Updated logic address for agent #${logicTokenId}`);
          break;

        case "8": // Update agent metadata
          const metaTokenId = await question("Enter your token ID: ");
          const newMetadataURI = await question("New metadata URI: ");
          
          console.log("\nEnter new metadata:");
          const newMetadata = await promptForMetadata();
          
          const metaTx = await nfa.updateAgentMetadata(metaTokenId, newMetadataURI, newMetadata);
          await metaTx.wait();
          console.log(`✅ Updated metadata for agent #${metaTokenId}`);
          break;

        case "9": // View contract info
          console.log("\n📊 Contract Information:");
          console.log("- Name:", await nfa.name());
          console.log("- Symbol:", await nfa.symbol());
          console.log("- Total Supply:", (await nfa.getTotalSupply()).toString());
          console.log("- Owner:", await nfa.owner());
          console.log("- Treasury:", await nfa.treasuryAddress());
          console.log("- Paused:", await nfa.paused());
          console.log("- Mint Fee:", hre.ethers.utils.formatEther(await nfa.MINT_FEE()), "BNB");
          break;

        case "10": // Admin functions
          const owner = await nfa.owner();
          if (signer.address !== owner) {
            console.log("❌ You are not the contract owner");
            break;
          }

          console.log("\n🔑 Admin Functions:");
          console.log("1. Set free mints");
          console.log("2. Update treasury");
          console.log("3. Pause/unpause");
          console.log("4. Emergency withdraw");
          console.log("5. Back");

          const adminChoice = await question("\n> ");
          
          switch (adminChoice) {
            case "1":
              const freeUser = await question("User address: ");
              const freeAmount = await question("Number of free mints: ");
              const freeTx = await nfa.setFreeMints(freeUser, freeAmount);
              await freeTx.wait();
              console.log("✅ Free mints set");
              break;

            case "2":
              const newTreasury = await question("New treasury address: ");
              const treasuryTx = await nfa.setTreasury(newTreasury);
              await treasuryTx.wait();
              console.log("✅ Treasury updated");
              break;

            case "3":
              const currentPaused = await nfa.paused();
              console.log(`Contract is currently ${currentPaused ? "paused" : "active"}`);
              const setPause = await question(`${currentPaused ? "Unpause" : "Pause"}? (y/n): `);
              if (setPause.toLowerCase() === 'y') {
                const pauseTx = await nfa.setPaused(!currentPaused);
                await pauseTx.wait();
                console.log(`✅ Contract ${!currentPaused ? "paused" : "unpaused"}`);
              }
              break;

            case "4":
              const contractBalance = await hre.ethers.provider.getBalance(nfa.address);
              console.log(`Contract balance: ${hre.ethers.utils.formatEther(contractBalance)} BNB`);
              if (contractBalance.gt(0)) {
                const confirm = await question("Withdraw all? (y/n): ");
                if (confirm.toLowerCase() === 'y') {
                  const emergencyTx = await nfa.emergencyWithdraw();
                  await emergencyTx.wait();
                  console.log("✅ Emergency withdrawal complete");
                }
              } else {
                console.log("No balance to withdraw");
              }
              break;
          }
          break;

        case "0":
          console.log("\n👋 Goodbye!");
          process.exit(0);

        default:
          console.log("❌ Invalid choice");
      }
    } catch (error) {
      console.error("❌ Error:", error.message);
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
