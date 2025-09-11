const { ethers } = require('hardhat');

async function main() {
  console.log('🚀 Deploying BAP-578 Non-Fungible Agent contracts...\n');

  const [deployer] = await ethers.getSigners();
  console.log("deployer", deployer);
  console.log('Deploying contracts with account:', deployer.address);
  console.log('Account balance:', ethers.utils.formatEther(await deployer.getBalance()));

  const network = await ethers.provider.getNetwork();
  console.log('Network:', network.name, 'Chain ID:', network.chainId);

  try {
    // Deploy CircuitBreaker first
    console.log('\n📋 1. Deploying CircuitBreaker...');
    const CircuitBreaker = await ethers.getContractFactory('CircuitBreaker');
    const circuitBreaker = await CircuitBreaker.deploy();
    await circuitBreaker.deployed();
    
    // Initialize CircuitBreaker
    await circuitBreaker.initialize(deployer.address, deployer.address);
    console.log('✅ CircuitBreaker deployed to:', circuitBreaker.address);

    // Deploy BAP578
    console.log('\n📋 2. Deploying BAP578...');
    const BAP578 = await ethers.getContractFactory('BAP578');
    const bap578 = await BAP578.deploy();
    await bap578.deployed();
    
    // Initialize BAP578
    await bap578.initialize('BAP578 Non-Fungible Agents', 'NFA', circuitBreaker.address);
    console.log('✅ BAP578 deployed to:', bap578.address);

    // Deploy MerkleTreeLearning
    console.log('\n📋 3. Deploying MerkleTreeLearning...');
    const MerkleTreeLearning = await ethers.getContractFactory('MerkleTreeLearning');
    const merkleLearning = await MerkleTreeLearning.deploy();
    await merkleLearning.deployed();
    
    // Initialize MerkleTreeLearning
    await merkleLearning.initialize();
    console.log('✅ MerkleTreeLearning deployed to:', merkleLearning.address);

    // Deploy AgentFactory
    console.log('\n📋 4. Deploying AgentFactory...');
    const AgentFactory = await ethers.getContractFactory('AgentFactory');
    const agentFactory = await AgentFactory.deploy();
    await agentFactory.deployed();
    
    // Initialize AgentFactory
    await agentFactory.initialize(bap578.address, deployer.address, merkleLearning.address);
    console.log('✅ AgentFactory deployed to:', agentFactory.address);

    // Deploy BAP578Governance
    console.log('\n📋 5. Deploying BAP578Governance...');
    const BAP578Governance = await ethers.getContractFactory('BAP578Governance');
    const governance = await BAP578Governance.deploy();
    await governance.deployed();
    
    // Initialize BAP578Governance
    await governance.initialize(
      bap578.address,
      deployer.address,
      7, // 7 days voting period
      10, // 10% quorum
      2  // 2 days execution delay
    );
    console.log('✅ BAP578Governance deployed to:', governance.address);

    // Deploy CreatorAgent template
    console.log('\n📋 6. Deploying CreatorAgent template...');
    const CreatorAgent = await ethers.getContractFactory('CreatorAgent');
    const creatorAgent = await CreatorAgent.deploy(
      bap578.address,
      'Template Creator',
      'Template creator agent',
      'General'
    );
    await creatorAgent.deployed();
    console.log('✅ CreatorAgent template deployed to:', creatorAgent.address);

    // Setup configurations
    console.log('\n📋 7. Setting up configurations...');
    
    // Set governance in CircuitBreaker
    await circuitBreaker.setGovernance(governance.address);
    console.log('✅ Governance set in CircuitBreaker');

    // Set AgentFactory in Governance
    await governance.setAgentFactory(agentFactory.address);
    console.log('✅ AgentFactory set in Governance');

    // Approve learning module
    await agentFactory.approveLearningModule(merkleLearning.address, 'MerkleTree', '1.0.0');
    console.log('✅ Learning module approved');

    // Register agent template
    await agentFactory.approveTemplate(creatorAgent.address, 'Creator', '1.0.0');
    console.log('✅ Agent template registered');

    console.log('\n🎉 Deployment complete!');
    console.log('----------------------------------------------------');
    console.log('📋 Contract Addresses:');
    console.log('CircuitBreaker:', circuitBreaker.address);
    console.log('BAP578:', bap578.address);
    console.log('MerkleTreeLearning:', merkleLearning.address);
    console.log('AgentFactory:', agentFactory.address);
    console.log('BAP578Governance:', governance.address);
    console.log('CreatorAgent Template:', creatorAgent.address);
    console.log('----------------------------------------------------');
    console.log('💡 Update your .env file with these addresses');
    console.log('💡 Run verification: npx hardhat run scripts/verify-contracts.js --network <network>');
    console.log('💡 Test interaction: npx hardhat run scripts/interact.js --network <network>');

  } catch (error) {
    console.error('❌ Deployment failed:', error);
    throw error;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
