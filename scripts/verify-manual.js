const hre = require("hardhat");
const fs = require("fs");

async function main() {
  console.log("\n📝 Manual Verification Instructions for BSCScan\n");

  // Load deployment info
  const network = hre.network.name;
  const deploymentPath = `./deployments/${network}_deployment.json`;
  
  if (!fs.existsSync(deploymentPath)) {
    console.log("❌ No deployment found for network:", network);
    process.exit(1);
  }

  const deployment = JSON.parse(fs.readFileSync(deploymentPath, "utf8"));
  
  console.log("============================================");
  console.log("DEPLOYED CONTRACT ADDRESSES");
  console.log("============================================");
  console.log("Proxy Address:", deployment.proxy);
  console.log("Implementation Address:", deployment.implementation);
  console.log("Treasury Address:", deployment.treasury);
  console.log("");

  const isTestnet = network === "testnet" || network === "bscTestnet";
  const explorerUrl = isTestnet ? "https://testnet.bscscan.com" : "https://bscscan.com";

  console.log("============================================");
  console.log("STEP 1: VERIFY IMPLEMENTATION CONTRACT");
  console.log("============================================");
  console.log(`1. Go to: ${explorerUrl}/address/${deployment.implementation}#code`);
  console.log("2. Click 'Verify and Publish'");
  console.log("3. Use these settings:");
  console.log("   - Compiler Type: Solidity (Single file)");
  console.log("   - Compiler Version: v0.8.20+commit.a1b79de6");
  console.log("   - Open Source License Type: MIT");
  console.log("");

  // Try to verify implementation automatically
  try {
    console.log("Attempting automatic verification of implementation...");
    await hre.run("verify:verify", {
      address: deployment.implementation,
      constructorArguments: [],
    });
    console.log("✅ Implementation verified automatically!");
  } catch (error) {
    if (error.message.includes("Already Verified")) {
      console.log("✅ Implementation already verified!");
    } else {
      console.log("⚠️  Auto-verification failed. Please verify manually using the link above.");
    }
  }

  console.log("");
  console.log("============================================");
  console.log("STEP 2: MARK PROXY AS PROXY CONTRACT");
  console.log("============================================");
  console.log(`1. Go to: ${explorerUrl}/proxycontractchecker`);
  console.log(`2. Enter Proxy Address: ${deployment.proxy}`);
  console.log("3. Click 'Verify'");
  console.log("");
  console.log("OR");
  console.log("");
  console.log(`1. Go to: ${explorerUrl}/address/${deployment.proxy}#code`);
  console.log("2. Click 'Is this a proxy?' link");
  console.log("3. Click 'Verify' on the proxy verification page");
  console.log("");

  console.log("============================================");
  console.log("STEP 3: LINK PROXY TO IMPLEMENTATION");
  console.log("============================================");
  console.log("After marking as proxy, BSCScan should automatically detect:");
  console.log(`- Implementation: ${deployment.implementation}`);
  console.log("- Proxy Type: EIP-1967");
  console.log("");
  console.log("If not detected automatically:");
  console.log(`1. Enter Implementation Address: ${deployment.implementation}`);
  console.log("2. Select 'EIP-1967' as proxy type");
  console.log("3. Click 'Save'");
  console.log("");

  console.log("============================================");
  console.log("VERIFICATION COMPLETE!");
  console.log("============================================");
  console.log("Once verified, you'll see:");
  console.log("- 'Read as Proxy' tab");
  console.log("- 'Write as Proxy' tab");
  console.log("");
  console.log(`Contract Page: ${explorerUrl}/address/${deployment.proxy}`);
  console.log("");
  
  console.log("============================================");
  console.log("IMPORTANT ADDRESSES");
  console.log("============================================");
  console.log(`Main Contract (for users): ${deployment.proxy}`);
  console.log(`Implementation (logic): ${deployment.implementation}`);
  console.log("");
  
  // Generate ABI for manual interaction
  const contractArtifact = await hre.artifacts.readArtifact("NonFungibleAgents");
  const abiPath = `./deployments/${network}_abi.json`;
  fs.writeFileSync(abiPath, JSON.stringify(contractArtifact.abi, null, 2));
  console.log(`ABI saved to: ${abiPath}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
