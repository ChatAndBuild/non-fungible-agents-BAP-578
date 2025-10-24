const { ethers, upgrades } = require('hardhat');

async function main() {
  console.log('Starting KnowledgeRegistry deployment...\n');

  // Get signers
  const [deployer] = await ethers.getSigners();
  console.log('Deployer address:', deployer.address);
  console.log('Deployer balance:', ethers.utils.formatEther(await deployer.getBalance()), 'ETH\n');

  // Configuration
  const DEFAULT_MAX_SOURCES = 10; // Default maximum knowledge sources per agent

  // Get contract addresses from environment or use defaults
  const AGENT_FACTORY_ADDRESS = process.env.AGENT_FACTORY_ADDRESS;
  
  if (!AGENT_FACTORY_ADDRESS) {
    console.error('ERROR: AGENT_FACTORY_ADDRESS not set in environment variables');
    console.log('Please set AGENT_FACTORY_ADDRESS in your .env file');
    console.log('Example: AGENT_FACTORY_ADDRESS=0x1234567890123456789012345678901234567890');
    console.log('\nNote: The KnowledgeRegistry now requires the AgentFactory address, not BAP578 address');
    process.exit(1);
  }

  console.log('Configuration:');
  console.log('- AgentFactory Address:', AGENT_FACTORY_ADDRESS);
  console.log('- Default Max Sources:', DEFAULT_MAX_SOURCES);
  console.log('');

  try {
    // Verify AgentFactory contract exists
    console.log('Verifying AgentFactory contract...');
    const agentFactoryCode = await ethers.provider.getCode(AGENT_FACTORY_ADDRESS);
    if (agentFactoryCode === '0x') {
      throw new Error(`No contract found at AgentFactory address: ${AGENT_FACTORY_ADDRESS}`);
    }
    console.log('✓ AgentFactory contract verified\n');

    // Deploy KnowledgeRegistry
    console.log('Deploying KnowledgeRegistry...');
    const KnowledgeRegistry = await ethers.getContractFactory('KnowledgeRegistry');
    
    const knowledgeRegistry = await upgrades.deployProxy(
      KnowledgeRegistry,
      [AGENT_FACTORY_ADDRESS, DEFAULT_MAX_SOURCES],
      { 
        initializer: 'initialize',
        kind: 'uups'
      }
    );

    await knowledgeRegistry.deployed();
    console.log('✓ KnowledgeRegistry deployed to:', knowledgeRegistry.address);

    // Wait for confirmations
    console.log('\nWaiting for block confirmations...');
    await knowledgeRegistry.deployTransaction.wait(5);
    console.log('✓ Deployment confirmed\n');

    // Verify deployment
    console.log('Verifying deployment...');
    const agentFactory = await knowledgeRegistry.agentFactory();
    const defaultMaxSources = await knowledgeRegistry.defaultMaxSources();
    const owner = await knowledgeRegistry.owner();

    console.log('✓ Deployment verified:');
    console.log('  - AgentFactory:', agentFactory);
    console.log('  - Default Max Sources:', defaultMaxSources.toString());
    console.log('  - Owner:', owner);
    console.log('');

    // Get implementation address
    const implementationAddress = await upgrades.erc1967.getImplementationAddress(knowledgeRegistry.address);
    console.log('Implementation address:', implementationAddress);
    console.log('');

    // Save deployment info
    const deploymentInfo = {
      network: network.name,
      deployedAt: new Date().toISOString(),
      addresses: {
        proxy: knowledgeRegistry.address,
        implementation: implementationAddress
      },
      configuration: {
        agentFactoryAddress: AGENT_FACTORY_ADDRESS,
        defaultMaxSources: DEFAULT_MAX_SOURCES,
        owner: owner
      },
      deployer: deployer.address,
      transactionHash: knowledgeRegistry.deployTransaction.hash
    };

    const fs = require('fs');
    const path = require('path');
    
    // Create deployments directory if it doesn't exist
    const deploymentsDir = path.join(__dirname, '..', 'deployments');
    if (!fs.existsSync(deploymentsDir)) {
      fs.mkdirSync(deploymentsDir, { recursive: true });
    }

    // Save deployment info to file
    const deploymentFile = path.join(deploymentsDir, `knowledge-registry-${network.name}.json`);
    fs.writeFileSync(deploymentFile, JSON.stringify(deploymentInfo, null, 2));
    console.log('Deployment info saved to:', deploymentFile);
    console.log('');

    // Display summary
    console.log('='.repeat(50));
    console.log('DEPLOYMENT SUMMARY');
    console.log('='.repeat(50));
    console.log('KnowledgeRegistry Proxy:', knowledgeRegistry.address);
    console.log('Implementation:', implementationAddress);
    console.log('');
    console.log('Configuration:');
    console.log('  AgentFactory:', AGENT_FACTORY_ADDRESS);
    console.log('  Default Max Sources:', DEFAULT_MAX_SOURCES);
    console.log('  Owner:', owner);
    console.log('');
    console.log('Transaction Hash:', knowledgeRegistry.deployTransaction.hash);
    console.log('='.repeat(50));
    console.log('');

    // Instructions for next steps
    console.log('NEXT STEPS:');
    console.log('1. Update .env file with KnowledgeRegistry address:');
    console.log(`   KNOWLEDGE_REGISTRY_ADDRESS=${knowledgeRegistry.address}`);
    console.log('');
    console.log('2. Verify contract on block explorer:');
    console.log(`   npx hardhat verify --network ${network.name} ${implementationAddress}`);
    console.log('');
    console.log('3. Test the deployment:');
    console.log('   - Add knowledge sources to agents');
    console.log('   - Update knowledge configurations');
    console.log('   - Test priority sorting and filtering');
    console.log('');

    // Optional: Automated test transaction
    if (process.env.RUN_TEST_TRANSACTION === 'true') {
      console.log('Running test transaction...');
      
      try {
        // Test by reading the default max sources
        const testMaxSources = await knowledgeRegistry.defaultMaxSources();
        console.log(`✓ Test transaction successful. Default max sources: ${testMaxSources}`);
      } catch (error) {
        console.error('✗ Test transaction failed:', error.message);
      }
    }

    console.log('\n✓ KnowledgeRegistry deployment completed successfully!');

  } catch (error) {
    console.error('\n✗ Deployment failed:');
    console.error(error);
    process.exit(1);
  }
}

// Execute deployment
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Unexpected error:');
    console.error(error);
    process.exit(1);
  });

/* 
USAGE INSTRUCTIONS:
==================

1. Set environment variables in .env:
   AGENT_FACTORY_ADDRESS=<your-agent-factory-contract-address>
   RUN_TEST_TRANSACTION=true  # Optional: to run a test transaction

2. Deploy to local network:
   npx hardhat run scripts/deploy-knowledge-registry.js --network localhost

3. Deploy to testnet:
   npx hardhat run scripts/deploy-knowledge-registry.js --network testnet

4. Deploy to mainnet:
   npx hardhat run scripts/deploy-knowledge-registry.js --network mainnet

FEATURES:
=========
- Upgradeable deployment using UUPS pattern
- Automatic verification of AgentFactory contract existence
- Saves deployment information to file
- Comprehensive deployment summary
- Error handling and validation
- Support for multiple networks

CONFIGURATION:
=============
The script uses the following configuration:
- DEFAULT_MAX_SOURCES: Maximum knowledge sources per agent (default: 10)
- AGENT_FACTORY_ADDRESS: Address of the deployed AgentFactory contract (required)

IMPORTANT CHANGES:
=================
The KnowledgeRegistry has been updated to support multiple agent contracts:
- Now requires AgentFactory address instead of a single BAP578 address
- Each agent is a separate contract with token ID 1
- Knowledge functions now require (agentContract, tokenId) instead of just tokenId

OUTPUTS:
========
The script creates a deployment file in the deployments/ directory containing:
- Proxy and implementation addresses
- Configuration parameters
- Deployment timestamp and transaction hash
- Network information
*/
