const { ethers, upgrades } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
    console.log("🚀 Starting BAP-578 donation system deployment...\n");

    const [deployer] = await ethers.getSigners();
    console.log("Deploying donation system with account:", deployer.address);
    console.log("Account balance:", ethers.utils.formatEther(await deployer.getBalance()));

    const network = await ethers.provider.getNetwork();
    console.log("Network:", network.name, "Chain ID:", network.chainId);

    const deployments = {};

    try {
        // 1. Deploy CircuitBreaker first (if not already deployed)
        console.log("\n📋 1. Deploying CircuitBreaker...");
        const CircuitBreaker = await ethers.getContractFactory("CircuitBreaker");
        const circuitBreaker = await upgrades.deployProxy(
            CircuitBreaker,
            [deployer.address, deployer.address], // governance and emergency multisig
            { initializer: "initialize" }
        );
        await circuitBreaker.deployed();
        deployments.CircuitBreaker = circuitBreaker.address;
        console.log("✅ CircuitBreaker deployed to:", circuitBreaker.address);

        // 2. Deploy BAP578 implementation
        console.log("\n📋 2. Deploying BAP578 implementation...");
        const BAP578 = await ethers.getContractFactory("BAP578");
        const bap578Implementation = await upgrades.deployProxy(
            BAP578,
            ["BAP578 Non-Fungible Agents", "NFA", circuitBreaker.address],
            { initializer: "initialize" }
        );
        await bap578Implementation.deployed();
        deployments.BAP578 = bap578Implementation.address;
        console.log("✅ BAP578 implementation deployed to:", bap578Implementation.address);

        // 3. Deploy BAP578Treasury
        console.log("\n📋 3. Deploying BAP578Treasury...");
        const BAP578Treasury = await ethers.getContractFactory("BAP578Treasury");
        const treasury = await upgrades.deployProxy(
            BAP578Treasury,
            [
                circuitBreaker.address,
                deployer.address, // foundation address (replace with actual in production)
                deployer.address, // community treasury address (replace with actual in production)
                deployer.address, // staking rewards address (replace with actual in production)
                deployer.address  // initial admin
            ],
            { initializer: "initialize" }
        );
        await treasury.deployed();
        deployments.BAP578Treasury = treasury.address;
        console.log("✅ BAP578Treasury deployed to:", treasury.address);

        // 4. Deploy VaultPermissionManager
        console.log("\n📋 4. Deploying VaultPermissionManager...");
        const VaultPermissionManager = await ethers.getContractFactory("VaultPermissionManager");
        const vaultManager = await upgrades.deployProxy(
            VaultPermissionManager,
            [circuitBreaker.address],
            { initializer: "initialize" }
        );
        await vaultManager.deployed();
        deployments.VaultPermissionManager = vaultManager.address;
        console.log("✅ VaultPermissionManager deployed to:", vaultManager.address);

        // 5. Deploy ExperienceModuleRegistry
        console.log("\n📋 5. Deploying ExperienceModuleRegistry...");
        const ExperienceModuleRegistry = await ethers.getContractFactory("ExperienceModuleRegistry");
        const experienceRegistry = await upgrades.deployProxy(
            ExperienceModuleRegistry,
            [circuitBreaker.address],
            { initializer: "initialize" }
        );
        await experienceRegistry.deployed();
        deployments.ExperienceModuleRegistry = experienceRegistry.address;
        console.log("✅ ExperienceModuleRegistry deployed to:", experienceRegistry.address);

        // 6. Deploy AgentFactory
        console.log("\n📋 6. Deploying AgentFactory...");
        const AgentFactory = await ethers.getContractFactory("AgentFactory");
        const agentFactory = await upgrades.deployProxy(
            AgentFactory,
            [
                bap578Implementation.address,
                deployer.address,
                ethers.constants.AddressZero, // No default learning module for now
                treasury.address
            ],
            { initializer: "initialize" }
        );
        await agentFactory.deployed();
        deployments.AgentFactory = agentFactory.address;
        console.log("✅ AgentFactory deployed to:", agentFactory.address);

        // 7. Deploy BAP578Governance
        console.log("\n📋 7. Deploying BAP578Governance...");
        const BAP578Governance = await ethers.getContractFactory("BAP578Governance");
        const governance = await upgrades.deployProxy(
            BAP578Governance,
            [
                bap578Implementation.address,
                deployer.address,
                7, // 7 days voting period
                10, // 10% quorum
                2  // 2 days execution delay
            ],
            { initializer: "initialize" }
        );
        await governance.deployed();
        deployments.BAP578Governance = governance.address;
        console.log("✅ BAP578Governance deployed to:", governance.address);

        // 8. Setup governance relationships
        console.log("\n📋 8. Setting up governance relationships...");

        // Set governance in CircuitBreaker
        await circuitBreaker.setGovernance(governance.address);
        console.log("✅ Governance set in CircuitBreaker");

        // Set governance in Treasury
        await treasury.setGovernance(governance.address);
        console.log("✅ Governance set in Treasury");

        // Set governance in VaultPermissionManager
        await vaultManager.setGovernance(governance.address);
        console.log("✅ Governance set in VaultPermissionManager");

        // Set governance in ExperienceModuleRegistry
        await experienceRegistry.setGovernance(governance.address);
        console.log("✅ Governance set in ExperienceModuleRegistry");

        // Set AgentFactory in Governance
        await governance.setAgentFactory(agentFactory.address);
        console.log("✅ AgentFactory set in Governance");

        // Set Treasury in Governance
        await governance.setTreasury(treasury.address);
        console.log("✅ Treasury set in Governance");

        // 9. Save deployment addresses
        const deploymentData = {
            network: network.name,
            chainId: network.chainId,
            deployer: deployer.address,
            timestamp: new Date().toISOString(),
            contracts: deployments,
            configuration: {
                foundationAddress: deployer.address,
                communityTreasuryAddress: deployer.address,
                stakingRewardsAddress: deployer.address,
                votingPeriod: 7,
                quorumPercentage: 10,
                executionDelay: 2
            }
        };

        const deploymentsDir = path.join(__dirname, "..", "deployments");
        if (!fs.existsSync(deploymentsDir)) {
            fs.mkdirSync(deploymentsDir, { recursive: true });
        }

        const filename = `donation-system-${network.name}-${Date.now()}.json`;
        const filepath = path.join(deploymentsDir, filename);
        fs.writeFileSync(filepath, JSON.stringify(deploymentData, null, 2));

        console.log("\n=== Donation System Deployment Complete ===");
        console.log("----------------------------------------------------");
        console.log("📋 Contract Addresses:");
        Object.entries(deployments).forEach(([name, address]) => {
            console.log(`${name}: ${address}`);
        });
        console.log("----------------------------------------------------");
        console.log(`📁 Deployment data saved to: ${filepath}`);
        
        console.log("\n=== Important Notes ===");
        console.log("1. Update foundation and community treasury addresses in production");
        console.log("2. Configure staking parameters as needed");
        console.log("3. Set up proper governance timelock and multi-sig controls");
        console.log("4. Test the donation system thoroughly before mainnet deployment");
        console.log("5. Consider adding additional learning modules");
        console.log("6. Set up monitoring and alerts for treasury activities");

        console.log("\n💡 Testing donation functionality:");
        console.log("const treasury = await ethers.getContractAt('BAP578Treasury', '" + treasury.address + "')");
        console.log("await treasury.donate({ value: ethers.utils.parseEther('1') })");
        console.log("const balance = await treasury.getTotalDonations()");
        console.log("console.log('Total donations:', ethers.utils.formatEther(balance))");

    } catch (error) {
        console.error("❌ Deployment failed:", error);
        throw error;
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
