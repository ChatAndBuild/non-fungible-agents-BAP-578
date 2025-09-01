const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying donation system with account:", deployer.address);

    // Deploy CircuitBreaker first (if not already deployed)
    const CircuitBreaker = await ethers.getContractFactory("CircuitBreaker");
    const circuitBreaker = await CircuitBreaker.deploy();
    await circuitBreaker.deployed();
    console.log("CircuitBreaker deployed to:", circuitBreaker.address);

    // Deploy BEP007 implementation
    const BEP007 = await ethers.getContractFactory("BEP007");
    const bep007Implementation = await BEP007.deploy();
    await bep007Implementation.deployed();
    console.log("BEP007 implementation deployed to:", bep007Implementation.address);

    // Deploy BEP007Treasury
    const BEP007Treasury = await ethers.getContractFactory("BEP007Treasury");
    const treasury = await BEP007Treasury.deploy();
    await treasury.deployed();
    console.log("BEP007Treasury deployed to:", treasury.address);

    // Deploy BEP007StakingRewards
    const BEP007StakingRewards = await ethers.getContractFactory("BEP007StakingRewards");
    const stakingRewards = await BEP007StakingRewards.deploy();
    await stakingRewards.deployed();
    console.log("BEP007StakingRewards deployed to:", stakingRewards.address);

    // Deploy AgentFactory
    const AgentFactory = await ethers.getContractFactory("AgentFactory");
    const agentFactory = await AgentFactory.deploy();
    await agentFactory.deployed();
    console.log("AgentFactory deployed to:", agentFactory.address);

    // Deploy BEP007Governance
    const BEP007Governance = await ethers.getContractFactory("BEP007Governance");
    const governance = await BEP007Governance.deploy();
    await governance.deployed();
    console.log("BEP007Governance deployed to:", governance.address);

    // Initialize contracts
    console.log("Initializing contracts...");

    // Initialize CircuitBreaker
    await circuitBreaker.initialize(deployer.address);
    console.log("CircuitBreaker initialized");

    // Initialize Treasury with placeholder addresses (update these with actual addresses)
    const foundationAddress = deployer.address; // Replace with actual foundation address
    const communityTreasuryAddress = deployer.address; // Replace with actual community treasury address
    
    await treasury.initialize(
        circuitBreaker.address,
        foundationAddress,
        communityTreasuryAddress,
        stakingRewards.address,
        deployer.address
    );
    console.log("BEP007Treasury initialized");

    // Initialize StakingRewards
    const minimumStakeAmount = 1; // Minimum 1 token to stake
    const stakingPeriod = 30; // 30 days minimum staking period
    const rewardMultiplier = 100; // 1% daily reward rate (100 basis points)

    await stakingRewards.initialize(
        circuitBreaker.address,
        bep007Implementation.address,
        minimumStakeAmount,
        stakingPeriod,
        rewardMultiplier,
        deployer.address
    );
    console.log("BEP007StakingRewards initialized");

    // Initialize AgentFactory
    await agentFactory.initialize(
        bep007Implementation.address,
        deployer.address,
        ethers.constants.AddressZero, // No default learning module for now
        treasury.address
    );
    console.log("AgentFactory initialized");

    // Initialize Governance
    const votingPeriod = 7; // 7 days voting period
    const quorumPercentage = 10; // 10% quorum
    const executionDelay = 2; // 2 days execution delay

    await governance.initialize(
        bep007Implementation.address,
        deployer.address,
        votingPeriod,
        quorumPercentage,
        executionDelay
    );
    console.log("BEP007Governance initialized");

    // Set up governance relationships
    await governance.setAgentFactory(agentFactory.address);
    await governance.setTreasury(treasury.address);
    console.log("Governance relationships configured");

    // Transfer ownership of CircuitBreaker to governance
    await circuitBreaker.transferOwnership(governance.address);
    console.log("CircuitBreaker ownership transferred to governance");

    // Transfer ownership of BEP007 implementation to governance
    await bep007Implementation.transferOwnership(governance.address);
    console.log("BEP007 implementation ownership transferred to governance");

    console.log("\n=== Donation System Deployment Complete ===");
    console.log("CircuitBreaker:", circuitBreaker.address);
    console.log("BEP007 Implementation:", bep007Implementation.address);
    console.log("BEP007Treasury:", treasury.address);
    console.log("BEP007StakingRewards:", stakingRewards.address);
    console.log("AgentFactory:", agentFactory.address);
    console.log("BEP007Governance:", governance.address);
    console.log("\n=== Important Notes ===");
    console.log("1. Update foundation and community treasury addresses in treasury contract");
    console.log("2. Configure staking parameters as needed");
    console.log("3. Set up proper governance timelock and multi-sig controls");
    console.log("4. Test the donation system thoroughly before mainnet deployment");

    // Save deployment addresses
    const deploymentInfo = {
        circuitBreaker: circuitBreaker.address,
        bep007Implementation: bep007Implementation.address,
        treasury: treasury.address,
        stakingRewards: stakingRewards.address,
        agentFactory: agentFactory.address,
        governance: governance.address,
        foundationAddress: foundationAddress,
        communityTreasuryAddress: communityTreasuryAddress,
        deployer: deployer.address
    };

    console.log("\nDeployment info:", JSON.stringify(deploymentInfo, null, 2));
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
