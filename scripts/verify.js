const hre = require("hardhat");
const fs = require("fs");

async function main() {
  console.log("\n🔍 Starting contract verification on BSCScan...\n");

  // Load deployment info
  const network = hre.network.name;
  const deploymentPath = `./deployments/${network}_deployment.json`;
  
  if (!fs.existsSync(deploymentPath)) {
    console.log("❌ No deployment found for network:", network);
    console.log("Please deploy first: npm run deploy:", network);
    process.exit(1);
  }

  const deployment = JSON.parse(fs.readFileSync(deploymentPath, "utf8"));
  console.log("📄 Deployment loaded from:", deploymentPath);
  console.log("🔗 Proxy address:", deployment.proxy);
  console.log("📝 Implementation address:", deployment.implementation);
  console.log("🏦 Treasury address:", deployment.treasury);

  try {
    // Verify implementation contract using new hardhat-verify
    console.log("\n1️⃣ Verifying implementation contract...");
    try {
      await hre.run("verify:verify", {
        address: deployment.implementation,
        constructorArguments: [],
        contract: "contracts/NonFungibleAgents.sol:NonFungibleAgents"
      });
      console.log("✅ Implementation verified!");
    } catch (error) {
      if (error.message.includes("Already Verified") || error.message.includes("already verified")) {
        console.log("✅ Implementation already verified!");
      } else {
        console.log("⚠️ Implementation verification failed:", error.message);
      }
    }

    // Note: Proxy verification usually needs manual steps on BSCScan
    console.log("\n2️⃣ Proxy contract verification:");
    console.log("⚠️ Proxy contracts often require manual verification on BSCScan");
    console.log("Please follow these steps:");
    console.log(`1. Go to: https://testnet.bscscan.com/proxycontractchecker`);
    console.log(`2. Enter proxy address: ${deployment.proxy}`);
    console.log(`3. BSCScan should auto-detect implementation: ${deployment.implementation}`);

    console.log("\n✨ Verification process complete!");
    console.log("\n📋 Contract Information:");
    console.log("- Main Contract (Proxy):", deployment.proxy);
    console.log("- Implementation:", deployment.implementation);
    console.log("- Network:", network);
    console.log("- Explorer URL:");
    
    if (network === "testnet" || network === "bscTestnet") {
      console.log(`  https://testnet.bscscan.com/address/${deployment.proxy}`);
      console.log("\n💡 You can also manually verify at:");
      console.log(`  https://testnet.bscscan.com/proxycontractchecker?a=${deployment.proxy}`);
    } else if (network === "mainnet" || network === "bscMainnet") {
      console.log(`  https://bscscan.com/address/${deployment.proxy}`);
      console.log("\n💡 You can also manually verify at:");
      console.log(`  https://bscscan.com/proxycontractchecker?a=${deployment.proxy}`);
    }

    console.log("\n📝 Notes:");
    console.log("- Users should interact with the PROXY address:", deployment.proxy);
    console.log("- The proxy automatically delegates calls to the implementation");
    console.log("- BSCScan should auto-detect the proxy pattern and show 'Read/Write as Proxy'");

  } catch (error) {
    console.error("\n❌ Verification failed:", error);
    console.log("\n💡 Tips:");
    console.log("1. Make sure BSCSCAN_API_KEY is set in your .env file");
    console.log("2. Wait a few minutes after deployment before verifying");
    console.log("3. Check if the contract is already verified on BSCScan");
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
