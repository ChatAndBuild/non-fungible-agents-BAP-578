const hre = require("hardhat");

async function main() {
  console.log("\n🚀 Deploying BAP578 NFT Contract...\n");

  // Get deployer account
  const [deployer] = await hre.ethers.getSigners();
  console.log("📍 Deploying with account:", deployer.address);
  console.log("💰 Account balance:", (await deployer.getBalance()).toString());

  // Set treasury address (can be changed to a multisig or different address)
  const treasuryAddress = deployer.address;
  console.log("🏦 Treasury address:", treasuryAddress);

  // Deploy upgradeable contract using OpenZeppelin Upgrades plugin
  console.log("\n📝 Deploying upgradeable contract...");
  const BAP578 = await hre.ethers.getContractFactory("BAP578");
  
  const nfa = await hre.upgrades.deployProxy(
    BAP578,
    ["Non-Fungible Agents", "NFA", treasuryAddress],
    { initializer: "initialize", kind: "uups" }
  );
  
  await nfa.deployed();
  console.log("✅ Proxy deployed to:", nfa.address);
  
  // Get implementation address
  const implementationAddress = await hre.upgrades.erc1967.getImplementationAddress(nfa.address);
  console.log("✅ Implementation deployed to:", implementationAddress);

  // Verify initialization
  console.log("\n🔍 Verifying deployment...");
  console.log("- Name:", await nfa.name());
  console.log("- Symbol:", await nfa.symbol());
  console.log("- Owner:", await nfa.owner());
  console.log("- Treasury:", await nfa.treasuryAddress());
  console.log("- Mint Fee:", hre.ethers.utils.formatEther(await nfa.MINT_FEE()), "ETH");

  // Optionally create first agent as example
  const createFirstAgent = false; // Set to true if you want to mint an example agent
  
  if (createFirstAgent) {
    console.log("\n🎨 Creating example agent...");
    
    const exampleMetadata = {
      persona: JSON.stringify({
        traits: ["helpful", "friendly", "knowledgeable"],
        style: "professional yet approachable",
        tone: "warm and engaging"
      }),
      experience: "AI Assistant specialized in blockchain and smart contracts",
      voiceHash: "voice_default_001",
      animationURI: "ipfs://QmExampleAnimation",
      vaultURI: "ipfs://QmExampleVault",
      vaultHash: hre.ethers.utils.formatBytes32String("exampleVault")
    };
    
    const mintFee = await nfa.MINT_FEE();
    const tx = await nfa.createAgent(
      deployer.address,
      hre.ethers.constants.AddressZero, // No specific logic address
      "ipfs://QmExampleMetadata", // Example metadata URI
      exampleMetadata,
      { value: mintFee }
    );
    
    const receipt = await tx.wait();
    console.log("✅ Example agent created! Transaction:", receipt.transactionHash);
    
    // Get the token ID from event
    const event = receipt.events.find(e => e.event === "AgentCreated");
    if (event) {
      console.log("🎯 Token ID:", event.args.tokenId.toString());
    }
  }

  console.log("\n✨ Deployment complete!");
  console.log("\n📄 Contract Addresses:");
  console.log("- Implementation:", implementationAddress);
  console.log("- Proxy (Main Contract):", nfa.address);

  console.log("\n💡 You can interact with the contract at:", nfa.address);
  
  // Save deployment info
  const fs = require("fs");
  const deploymentInfo = {
    network: hre.network.name,
    implementation: implementationAddress,
    proxy: nfa.address,
    treasury: treasuryAddress,
    deployer: deployer.address,
    timestamp: new Date().toISOString()
  };
  
  const deploymentPath = `./deployments/${hre.network.name}_deployment.json`;
  if (!fs.existsSync("./deployments")) {
    fs.mkdirSync("./deployments");
  }
  fs.writeFileSync(deploymentPath, JSON.stringify(deploymentInfo, null, 2));
  console.log("\n💾 Deployment info saved to:", deploymentPath);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
