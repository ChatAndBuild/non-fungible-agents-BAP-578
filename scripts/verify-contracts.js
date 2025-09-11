const { run } = require("hardhat");
const { ethers, upgrades } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("🔍 Starting upgradable proxy contract verification...\n");

  // Get the latest deployment file
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

  console.log(`📁 Using deployment file: ${latestDeployment}`);
  console.log(`🌐 Network: ${deployment.network} (Chain ID: ${deployment.chainId})\n`);

  const contracts = deployment.contracts;
  const verificationResults = {};

  try {
    // Helper function to verify upgradable proxy contracts
    async function verifyUpgradableContract(contractName, proxyAddress) {
      console.log(`🔍 Verifying ${contractName} (Upgradable Proxy)...`);
      
      try {
        // Get implementation address from proxy
        const implementationAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);
        console.log(`📍 Proxy Address: ${proxyAddress}`);
        console.log(`📍 Implementation Address: ${implementationAddress}`);

        // Verify the implementation contract
        console.log(`🔍 Verifying ${contractName} implementation...`);
        await run("verify:verify", {
          address: implementationAddress,
          constructorArguments: []
        });
        console.log(`✅ ${contractName} implementation verified`);

        // Try to verify the proxy contract (this might fail if already verified)
        try {
          console.log(`🔍 Verifying ${contractName} proxy...`);
          await run("verify:verify", {
            address: proxyAddress,
            constructorArguments: []
          });
          console.log(`✅ ${contractName} proxy verified`);
        } catch (proxyError) {
          if (proxyError.message.includes("Already Verified")) {
            console.log(`✅ ${contractName} proxy already verified`);
          } else {
            console.log(`⚠️ ${contractName} proxy verification failed: ${proxyError.message}`);
          }
        }

        verificationResults[contractName] = {
          proxy: proxyAddress,
          implementation: implementationAddress,
          status: "verified"
        };

      } catch (error) {
        console.log(`⚠️ ${contractName} verification failed: ${error.message}`);
        verificationResults[contractName] = {
          proxy: proxyAddress,
          implementation: "unknown",
          status: "failed",
          error: error.message
        };
      }
    }

    // Helper function to verify regular contracts
    async function verifyRegularContract(contractName, contractAddress, constructorArgs = []) {
      console.log(`🔍 Verifying ${contractName} (Regular Contract)...`);
      
      try {
        await run("verify:verify", {
          address: contractAddress,
          constructorArguments: constructorArgs
        });
        console.log(`✅ ${contractName} verified`);
        
        verificationResults[contractName] = {
          address: contractAddress,
          status: "verified"
        };
      } catch (error) {
        if (error.message.includes("Already Verified")) {
          console.log(`✅ ${contractName} already verified`);
          verificationResults[contractName] = {
            address: contractAddress,
            status: "already verified"
          };
        } else {
          console.log(`⚠️ ${contractName} verification failed: ${error.message}`);
          verificationResults[contractName] = {
            address: contractAddress,
            status: "failed",
            error: error.message
          };
        }
      }
    }

    // Verify upgradable proxy contracts
    const upgradableContracts = [
      "CircuitBreaker",
      "BEP007", 
      "MerkleTreeLearning",
      "AgentFactory",
      "BEP007Governance"
    ];

    for (const contractName of upgradableContracts) {
      if (contracts[contractName]) {
        await verifyUpgradableContract(contractName, contracts[contractName]);
        console.log(""); // Add spacing
      }
    }

    // Verify regular contracts (non-upgradable)
    if (contracts.CreatorAgent) {
      await verifyRegularContract("CreatorAgent", contracts.CreatorAgent, [
        contracts.BEP007,
        "Template Creator",
        "Template creator agent",
        "General"
      ]);
    }

    console.log("\n🎉 Contract verification completed!");
    console.log("====================================================");
    console.log("📋 Verification Results:");
    console.log("====================================================");
    
    Object.entries(verificationResults).forEach(([name, result]) => {
      console.log(`\n${name}:`);
      if (result.proxy) {
        console.log(`  Proxy: ${result.proxy}`);
        console.log(`  Implementation: ${result.implementation}`);
      } else {
        console.log(`  Address: ${result.address}`);
      }
      console.log(`  Status: ${result.status}`);
      if (result.error) {
        console.log(`  Error: ${result.error}`);
      }
    });
    console.log("====================================================");

    // Save verification results
    const verificationData = {
      network: deployment.network,
      chainId: deployment.chainId,
      timestamp: new Date().toISOString(),
      verificationResults
    };

    const verificationFile = `verification-${deployment.network}-${Date.now()}.json`;
    const verificationPath = path.join(deploymentsDir, verificationFile);
    fs.writeFileSync(verificationPath, JSON.stringify(verificationData, null, 2));
    console.log(`\n📁 Verification results saved to: ${verificationFile}`);

  } catch (error) {
    console.error("❌ Verification failed:", error);
    throw error;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
