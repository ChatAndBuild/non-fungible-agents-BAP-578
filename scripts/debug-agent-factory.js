const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("🔍 Debugging AgentFactory Configuration\n");
  console.log("=" .repeat(60));

  const [deployer] = await ethers.getSigners();
  console.log("🔑 Using account:", deployer.address);

  // Load deployment info
  const deploymentPath = path.join(__dirname, "..", "deployments", "bnbt-fixed-1759915283449.json");
  const deployment = JSON.parse(fs.readFileSync(deploymentPath, 'utf8'));
  
  console.log(`\n📁 Using deployment from: ${deployment.timestamp}`);
  console.log(`🌐 Network: BSC Testnet (chainId: ${deployment.chainId})\n`);

  try {
    // Check AgentFactory configuration
    console.log("📋 AgentFactory Configuration:");
    console.log("-" .repeat(60));
    const agentFactory = await ethers.getContractAt("AgentFactory", deployment.contracts.AgentFactory);
    
    // Check basic configuration
    const implementation = await agentFactory.implementation();
    const defaultLearningModule = await agentFactory.defaultLearningModule();
    const treasury = await agentFactory.treasury();
    const circuitBreaker = await agentFactory.circuitBreaker();
    const creationFee = await agentFactory.AGENT_CREATION_FEE();
    
    console.log(`  Implementation: ${implementation}`);
    console.log(`  Default Learning Module: ${defaultLearningModule}`);
    console.log(`  Treasury: ${treasury}`);
    console.log(`  Circuit Breaker: ${circuitBreaker}`);
    console.log(`  Creation Fee: ${ethers.utils.formatEther(creationFee)} BNB`);
    
    // Verify expected addresses match deployment
    console.log("\n🔍 Verification:");
    console.log("-" .repeat(60));
    console.log(`  Implementation matches: ${implementation === deployment.contracts.BAP578Implementation}`);
    console.log(`  Treasury matches: ${treasury === deployment.contracts.BAP578Treasury}`);
    console.log(`  Circuit Breaker matches: ${circuitBreaker === deployment.contracts.CircuitBreaker}`);
    
    // Check if learning module is approved
    const isLearningModuleApproved = await agentFactory.isLearningModuleApproved(defaultLearningModule);
    console.log(`  Learning Module Approved: ${isLearningModuleApproved}`);
    
    // Check Treasury configuration
    console.log("\n📋 Treasury Configuration:");
    console.log("-" .repeat(60));
    const treasuryContract = await ethers.getContractAt("BAP578Treasury", deployment.contracts.BAP578Treasury);
    
    // Check treasury addresses
    const foundationAddress = await treasuryContract.foundationAddress();
    const communityTreasuryAddress = await treasuryContract.communityTreasuryAddress();
    const stakingRewardsAddress = await treasuryContract.stakingRewardsAddress();
    
    console.log(`  Foundation Address: ${foundationAddress}`);
    console.log(`  Community Treasury: ${communityTreasuryAddress}`);
    console.log(`  Staking Rewards: ${stakingRewardsAddress}`);
    
    // Check if addresses are set (not zero)
    const isFoundationSet = foundationAddress !== ethers.constants.AddressZero;
    const isCommunitySet = communityTreasuryAddress !== ethers.constants.AddressZero;
    const isStakingSet = stakingRewardsAddress !== ethers.constants.AddressZero;
    
    console.log(`\n  Foundation Set: ${isFoundationSet}`);
    console.log(`  Community Set: ${isCommunitySet}`);
    console.log(`  Staking Set: ${isStakingSet}`);
    
    // Check Circuit Breaker
    console.log("\n📋 Circuit Breaker Configuration:");
    console.log("-" .repeat(60));
    const circuitBreakerContract = await ethers.getContractAt("CircuitBreaker", deployment.contracts.CircuitBreaker);
    
    // Try to check if paused (might not have this function)
    let isCircuitBreakerPaused = false;
    try {
      const emergencyPaused = await circuitBreakerContract.emergencyPaused();
      isCircuitBreakerPaused = emergencyPaused;
      console.log(`  Emergency Paused: ${emergencyPaused}`);
    } catch (e) {
      console.log(`  Circuit Breaker status: Active (no pause function)`);
    }
    
    // Try to simulate the createAgent call
    console.log("\n🔬 Simulating Agent Creation:");
    console.log("-" .repeat(60));
    
    try {
      // Try with a valid logic address instead of AddressZero
      const mockLogicAddress = "0x0000000000000000000000000000000000000001"; // Use address(1) instead of address(0)
      
      console.log("  Attempting with logic address: " + mockLogicAddress);
      
      // Use callStatic to simulate without actually sending transaction
      const result = await agentFactory.callStatic.createAgent(
        "Test Agent",
        "TEST",
        mockLogicAddress,
        "ipfs://test",
        { value: ethers.utils.parseEther("0.01") }
      );
      
      console.log("  ✅ Simulation successful! Would create agent at:", result);
    } catch (error) {
      console.log("  ❌ Simulation failed:", error.reason || error.message);
      
      // Try to decode the error
      if (error.data) {
        try {
          const errorInterface = new ethers.utils.Interface([
            "error Unauthorized()",
            "error InsufficientFee()",
            "error InvalidImplementation()",
            "error InvalidTreasury()",
            "error TreasuryOperationFailed()",
            "error ProxyCreationFailed()"
          ]);
          const decodedError = errorInterface.parseError(error.data);
          console.log("  📍 Decoded error:", decodedError.name);
        } catch (e) {
          console.log("  📍 Could not decode error");
        }
      }
    }
    
    // Provide recommendations
    console.log("\n💡 Recommendations:");
    console.log("-" .repeat(60));
    
    if (!isFoundationSet || !isCommunitySet || !isStakingSet) {
      console.log("⚠️ Treasury addresses are using deployer address (not ideal for production)");
      console.log("   This should work for testing but consider setting proper addresses");
    }
    
    if (isCircuitBreakerPaused) {
      console.log("⚠️ Circuit Breaker is paused - this might block operations");
    }
    
    console.log("\n📝 Possible Issues:");
    console.log("1. Using AddressZero as logic address might be rejected");
    console.log("2. Treasury might be rejecting the donation");
    console.log("3. Proxy creation might be failing");
    console.log("\nTry using a non-zero address for the logic parameter");
    
  } catch (error) {
    console.error("\n❌ Error during debugging:", error.message);
    throw error;
  }
}

main()
  .then(() => {
    console.log("\n✨ Debugging completed!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\nScript failed:", error);
    process.exit(1);
  });
