const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * Script to update treasury addresses for the BAP578 ecosystem
 * 
 * IMPORTANT: Only the contract owner can execute this update
 * 
 * Usage:
 * 1. Update the NEW_ADDRESSES object below with your desired addresses
 * 2. Run: npx hardhat run scripts/update-treasury-addresses.js --network [network]
 */

// ========================================
// CONFIGURE YOUR NEW ADDRESSES HERE
// ========================================
const NEW_ADDRESSES = {
  foundation: "0xA815F37bE041DeC39eD3D2b028BbF02ac7923Aac",
  community: "0xA815F37bE041DeC39eD3D2b028BbF02ac7923Aac",
  staking: "0xA815F37bE041DeC39eD3D2b028BbF02ac7923Aac"
};

async function main() {
  console.log("🔧 BAP-578 Treasury Address Update Tool\n");
  console.log("=" .repeat(60));

  const [deployer] = await ethers.getSigners();
  console.log("🔑 Using account:", deployer.address);

  // Check account balance
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("💰 Account balance:", ethers.utils.formatEther(balance), "ETH\n");

  // Check if addresses are configured
  if (!NEW_ADDRESSES.foundation || !NEW_ADDRESSES.community || !NEW_ADDRESSES.staking) {
    console.error("❌ ERROR: You must configure the new addresses first!");
    return;
  }

  // Validate addresses
  if (!ethers.utils.isAddress(NEW_ADDRESSES.foundation) ||
      !ethers.utils.isAddress(NEW_ADDRESSES.community) ||
      !ethers.utils.isAddress(NEW_ADDRESSES.staking)) {
    console.error("❌ ERROR: Invalid address format detected!");
    return;
  }

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
    // Get treasury contract instance
    const treasury = await ethers.getContractAt("BAP578Treasury", contracts.BAP578Treasury);
    
    // Get current treasury addresses
    const currentFoundation = await treasury.foundationAddress();
    const currentCommunity = await treasury.communityTreasuryAddress();
    const currentStaking = await treasury.stakingRewardsAddress();
    
    console.log("📊 CURRENT TREASURY ADDRESSES");
    console.log("-" .repeat(60));
    console.log(`Foundation (60%):     ${currentFoundation}`);
    console.log(`Community (25%):      ${currentCommunity}`);
    console.log(`Staking (15%):        ${currentStaking}`);
    console.log("");
    
    // Check ownership
    const treasuryOwner = await treasury.owner();
    console.log("🔐 OWNERSHIP CHECK");
    console.log("-" .repeat(60));
    console.log(`Treasury Owner:       ${treasuryOwner}`);
    console.log(`Your Address:         ${deployer.address}`);
    console.log(`Are you the owner?    ${treasuryOwner.toLowerCase() === deployer.address.toLowerCase() ? "✅ YES" : "❌ NO"}`);
    console.log("");
    
    if (treasuryOwner.toLowerCase() !== deployer.address.toLowerCase()) {
      console.error("❌ ERROR: You are not the treasury owner!");
      console.error(`The current owner is: ${treasuryOwner}`);
      console.error("Only the owner can update treasury addresses.");
      console.error("\nPossible solutions:");
      console.error("1. Switch to the owner account");
      console.error("2. Contact the current owner to perform this update");
      console.error("3. If you're the governance contract, use governance proposals");
      return;
    }
    
    // Check if addresses are actually changing
    const noChanges = 
      currentFoundation.toLowerCase() === NEW_ADDRESSES.foundation.toLowerCase() &&
      currentCommunity.toLowerCase() === NEW_ADDRESSES.community.toLowerCase() &&
      currentStaking.toLowerCase() === NEW_ADDRESSES.staking.toLowerCase();
    
    if (noChanges) {
      console.log("⚠️  WARNING: New addresses are the same as current addresses!");
      console.log("No update needed.");
      return;
    }
    
    // Display proposed changes
    console.log("🔄 PROPOSED CHANGES");
    console.log("-" .repeat(60));
    
    if (currentFoundation.toLowerCase() !== NEW_ADDRESSES.foundation.toLowerCase()) {
      console.log("Foundation Address:");
      console.log(`  From: ${currentFoundation}`);
      console.log(`  To:   ${NEW_ADDRESSES.foundation}`);
    } else {
      console.log(`Foundation: No change (${currentFoundation})`);
    }
    
    if (currentCommunity.toLowerCase() !== NEW_ADDRESSES.community.toLowerCase()) {
      console.log("Community Treasury:");
      console.log(`  From: ${currentCommunity}`);
      console.log(`  To:   ${NEW_ADDRESSES.community}`);
    } else {
      console.log(`Community: No change (${currentCommunity})`);
    }
    
    if (currentStaking.toLowerCase() !== NEW_ADDRESSES.staking.toLowerCase()) {
      console.log("Staking Rewards:");
      console.log(`  From: ${currentStaking}`);
      console.log(`  To:   ${NEW_ADDRESSES.staking}`);
    } else {
      console.log(`Staking: No change (${currentStaking})`);
    }
    
    console.log("");
    
    // Add a 3-second delay for user to review
    console.log("🕐 Starting update in 3 seconds... (Press Ctrl+C to cancel)");
    await new Promise(resolve => setTimeout(resolve, 3000));
    
    // Execute the update
    console.log("\n🚀 Updating treasury addresses...");
    const updateTx = await treasury.updateTreasuryAddresses(
      NEW_ADDRESSES.foundation,
      NEW_ADDRESSES.community,
      NEW_ADDRESSES.staking
    );
    
    console.log("📝 Transaction submitted!");
    console.log(`   Hash: ${updateTx.hash}`);
    console.log("⏳ Waiting for confirmation...");
    
    const receipt = await updateTx.wait();
    console.log(`✅ Transaction confirmed in block ${receipt.blockNumber}`);
    console.log(`⛽ Gas used: ${receipt.gasUsed.toString()}`);
    
    // Verify the update
    console.log("\n🔍 VERIFYING UPDATE");
    console.log("-" .repeat(60));
    
    const newFoundation = await treasury.foundationAddress();
    const newCommunity = await treasury.communityTreasuryAddress();
    const newStaking = await treasury.stakingRewardsAddress();
    
    const updateSuccess = 
      newFoundation.toLowerCase() === NEW_ADDRESSES.foundation.toLowerCase() &&
      newCommunity.toLowerCase() === NEW_ADDRESSES.community.toLowerCase() &&
      newStaking.toLowerCase() === NEW_ADDRESSES.staking.toLowerCase();
    
    if (updateSuccess) {
      console.log("✅ SUCCESS! Treasury addresses have been updated:");
      console.log(`   Foundation: ${newFoundation}`);
      console.log(`   Community:  ${newCommunity}`);
      console.log(`   Staking:    ${newStaking}`);
      
      // Save update record
      const updateRecord = {
        timestamp: new Date().toISOString(),
        network: deployment.network,
        transactionHash: updateTx.hash,
        blockNumber: receipt.blockNumber,
        updatedBy: deployer.address,
        oldAddresses: {
          foundation: currentFoundation,
          community: currentCommunity,
          staking: currentStaking
        },
        newAddresses: {
          foundation: newFoundation,
          community: newCommunity,
          staking: newStaking
        },
        treasuryContract: contracts.BAP578Treasury
      };
      
      const updatesDir = path.join(__dirname, "..", "treasury-updates");
      if (!fs.existsSync(updatesDir)) {
        fs.mkdirSync(updatesDir);
      }
      
      const updateFilename = `treasury-update-${Date.now()}.json`;
      const updatePath = path.join(updatesDir, updateFilename);
      fs.writeFileSync(updatePath, JSON.stringify(updateRecord, null, 2));
      
      console.log(`\n💾 Update record saved to: treasury-updates/${updateFilename}`);
    } else {
      console.error("❌ ERROR: Address update verification failed!");
      console.error("The addresses may not have been updated correctly.");
      console.error("Please check the transaction and try again if necessary.");
    }
    
  } catch (error) {
    console.error("\n❌ Error updating treasury addresses:", error.message);
    
    if (error.message.includes("Ownable")) {
      console.error("\n💡 You are not the owner of the treasury contract.");
      console.error("   Only the owner can update treasury addresses.");
    } else if (error.message.includes("zero address")) {
      console.error("\n💡 One or more addresses are invalid (zero address).");
      console.error("   Please ensure all addresses are valid and non-zero.");
    } else if (error.message.includes("user rejected")) {
      console.error("\n💡 Transaction was rejected by the user.");
    } else {
      console.error("\n💡 An unexpected error occurred. Please check:");
      console.error("   - Network connection");
      console.error("   - Account has sufficient gas");
      console.error("   - Contract addresses are correct");
    }
    
    throw error;
  }
}

// Command-line argument parsing for addresses (optional)
if (process.argv.length === 5) {
  NEW_ADDRESSES.foundation = process.argv[2];
  NEW_ADDRESSES.community = process.argv[3];
  NEW_ADDRESSES.staking = process.argv[4];
  console.log("📝 Using command-line addresses:");
  console.log(`   Foundation: ${NEW_ADDRESSES.foundation}`);
  console.log(`   Community: ${NEW_ADDRESSES.community}`);
  console.log(`   Staking: ${NEW_ADDRESSES.staking}`);
}

// Run the script
main()
  .then(() => {
    console.log("\n✨ Treasury address update completed successfully!");
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
