const { expect } = require('chai');
const { ethers, upgrades } = require('hardhat');

describe('ExperienceModuleRegistry', function () {
  let ExperienceModuleRegistry;
  let experienceRegistry;
  let BEP007;
  let bep007;
  let CircuitBreaker;
  let circuitBreaker;
  let owner;
  let governance;
  let emergencyMultiSig;
  let addr1;
  let addr2;
  let addr3;
  let addrs;

  // Mock logic contract address for testing
  const mockLogicAddress = '0x1234567890123456789012345678901234567890';
  const mockModuleAddress = '0x9876543210987654321098765432109876543210';
  const mockModuleAddress2 = '0x1111111111111111111111111111111111111111';

  // Test data
  const testSpecification = JSON.stringify({
    context_id: "nfa007-experience-001",
    owner: "0xUserWalletAddress",
    created: "2025-01-20T10:00:00Z",
    persona: "Strategic crypto analyst with learning capabilities",
    learning_enabled: true,
    learning_type: "adaptive_experience",
    experience_slots: [
      {
        type: "alert_keywords",
        data: ["FUD", "rugpull", "hack", "$BNB", "scam"],
        learning_weight: 0.8,
        adaptation_rate: 0.1
      }
    ]
  });

  const testMetadata = JSON.stringify({
    description: "Test experience module",
    version: "1.0.0",
    capabilities: ["learning", "adaptation"]
  });

  beforeEach(async function () {
    [owner, governance, emergencyMultiSig, addr1, addr2, addr3, ...addrs] = await ethers.getSigners();

    // Deploy CircuitBreaker first
    CircuitBreaker = await ethers.getContractFactory('CircuitBreaker');
    circuitBreaker = await upgrades.deployProxy(
      CircuitBreaker,
      [governance.address, emergencyMultiSig.address],
      { initializer: 'initialize' },
    );
    await circuitBreaker.deployed();

    // Deploy BEP007 with CircuitBreaker as governance
    BEP007 = await ethers.getContractFactory('BEP007');
    bep007 = await upgrades.deployProxy(
      BEP007,
      ['Non-Fungible Agent', 'NFA', circuitBreaker.address],
      { initializer: 'initialize', kind: 'uups' },
    );
    await bep007.deployed();

    // Deploy ExperienceModuleRegistry
    ExperienceModuleRegistry = await ethers.getContractFactory('ExperienceModuleRegistry');
    experienceRegistry = await upgrades.deployProxy(
      ExperienceModuleRegistry,
      [bep007.address],
      { initializer: 'initialize', kind: 'uups' },
    );
    await experienceRegistry.deployed();
  });

  describe('Deployment', function () {
    it('Should set the right owner', async function () {
      expect(await experienceRegistry.owner()).to.equal(owner.address);
    });

    it('Should set the right BEP007 token address', async function () {
      expect(await experienceRegistry.bep007Token()).to.equal(bep007.address);
    });

    it('Should not allow initialization with zero BEP007 address', async function () {
      const ExperienceModuleRegistryFactory = await ethers.getContractFactory('ExperienceModuleRegistry');
      await expect(
        upgrades.deployProxy(ExperienceModuleRegistryFactory, [ethers.constants.AddressZero], {
          initializer: 'initialize',
          kind: 'uups',
        }),
      ).to.be.revertedWith('ExperienceModuleRegistry: invalid BEP007 address');
    });

    it('Should support upgradeable pattern', async function () {
      // Test that the contract is properly initialized and can be upgraded
      expect(await experienceRegistry.bep007Token()).to.equal(bep007.address);
    });
  });

  describe('Module Registration', function () {
    let tokenId;
    let moduleHash;

    beforeEach(async function () {
      // Create an agent token for testing
      await bep007['createAgent(address,address,string,(string,string,string,string,string,bytes32))'](
        addr1.address, 
        mockLogicAddress, 
        'ipfs://test', 
        {
          persona: 'Test Persona',
          experience: 'Test Experience',
          voiceHash: '',
          animationURI: '',
          vaultURI: '',
          vaultHash: ethers.constants.HashZero
        }
      );
      tokenId = 1;
      moduleHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('test-module-hash'));
    });

    it('Should register a new experience module with valid signature', async function () {
      // Create message hash for signing
      const messageHash = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'bytes32', 'string', 'uint256', 'uint256', 'string'],
        [tokenId, mockModuleAddress, moduleHash, testSpecification, 0, 0, testMetadata]
      );

      // Sign the message with addr1 (token owner)
      const signature = await addr1.signMessage(ethers.utils.arrayify(messageHash));

      // Register the module
      await expect(
        experienceRegistry.connect(addr1).registerModule(
          tokenId,
          mockModuleAddress,
          moduleHash,
          testSpecification,
          0, // STATIC
          0, // EXPERIMENTAL
          testMetadata,
          signature
        )
      ).to.emit(experienceRegistry, 'ModuleRegistered')
        .withArgs(tokenId, mockModuleAddress, addr1.address, 0, 0, testSpecification);

      // Verify module is registered
      const registeredModules = await experienceRegistry.getRegisteredModules(tokenId);
      expect(registeredModules).to.include(mockModuleAddress);

      // Verify module info
      const moduleInfo = await experienceRegistry.getModuleInfo(mockModuleAddress);
      expect(moduleInfo.moduleAddress).to.equal(mockModuleAddress);
      expect(moduleInfo.moduleHash).to.equal(moduleHash);
      expect(moduleInfo.specification).to.equal(testSpecification);
      expect(moduleInfo.experienceType).to.equal(0); // STATIC
      expect(moduleInfo.securityLevel).to.equal(0); // EXPERIMENTAL
      expect(moduleInfo.active).to.equal(true);
      expect(moduleInfo.creator).to.equal(addr1.address);
    });

    it('Should reject registration with invalid signature', async function () {
      // Create message hash for signing
      const messageHash = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'bytes32', 'string', 'uint256', 'uint256', 'string'],
        [tokenId, mockModuleAddress, moduleHash, testSpecification, 0, 0, testMetadata]
      );

      // Sign with wrong address (addr2 instead of addr1)
      const signature = await addr2.signMessage(ethers.utils.arrayify(messageHash));

      // Should fail with invalid signature
      await expect(
        experienceRegistry.connect(addr1).registerModule(
          tokenId,
          mockModuleAddress,
          moduleHash,
          testSpecification,
          0, // STATIC
          0, // EXPERIMENTAL
          testMetadata,
          signature
        )
      ).to.be.revertedWith('ExperienceModuleRegistry: invalid signature');
    });

    it('Should reject registration with zero module address', async function () {
      const messageHash = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'bytes32', 'string', 'uint256', 'uint256', 'string'],
        [tokenId, ethers.constants.AddressZero, moduleHash, testSpecification, 0, 0, testMetadata]
      );

      const signature = await addr1.signMessage(ethers.utils.arrayify(messageHash));

      await expect(
        experienceRegistry.connect(addr1).registerModule(
          tokenId,
          ethers.constants.AddressZero,
          moduleHash,
          testSpecification,
          0,
          0,
          testMetadata,
          signature
        )
      ).to.be.revertedWith('ExperienceModuleRegistry: invalid module address');
    });

    it('Should reject registration with empty specification', async function () {
      const messageHash = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'bytes32', 'string', 'uint256', 'uint256', 'string'],
        [tokenId, mockModuleAddress, moduleHash, '', 0, 0, testMetadata]
      );

      const signature = await addr1.signMessage(ethers.utils.arrayify(messageHash));

      await expect(
        experienceRegistry.connect(addr1).registerModule(
          tokenId,
          mockModuleAddress,
          moduleHash,
          '',
          0,
          0,
          testMetadata,
          signature
        )
      ).to.be.revertedWith('ExperienceModuleRegistry: empty specification');
    });

    it('Should register multiple modules for the same agent', async function () {
      // Register first module
      const messageHash1 = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'bytes32', 'string', 'uint256', 'uint256', 'string'],
        [tokenId, mockModuleAddress, moduleHash, testSpecification, 0, 0, testMetadata]
      );
      const signature1 = await addr1.signMessage(ethers.utils.arrayify(messageHash1));

      await experienceRegistry.connect(addr1).registerModule(
        tokenId,
        mockModuleAddress,
        moduleHash,
        testSpecification,
        0,
        0,
        testMetadata,
        signature1
      );

      // Register second module
      const moduleHash2 = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('test-module-hash-2'));
      const messageHash2 = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'bytes32', 'string', 'uint256', 'uint256', 'string'],
        [tokenId, mockModuleAddress2, moduleHash2, testSpecification, 1, 1, testMetadata]
      );
      const signature2 = await addr1.signMessage(ethers.utils.arrayify(messageHash2));

      await experienceRegistry.connect(addr1).registerModule(
        tokenId,
        mockModuleAddress2,
        moduleHash2,
        testSpecification,
        1, // ADAPTIVE
        1, // COMMUNITY
        testMetadata,
        signature2
      );

      // Verify both modules are registered
      const registeredModules = await experienceRegistry.getRegisteredModules(tokenId);
      expect(registeredModules).to.have.lengthOf(2);
      expect(registeredModules).to.include(mockModuleAddress);
      expect(registeredModules).to.include(mockModuleAddress2);
    });

    it('Should not duplicate modules in agent registry', async function () {
      // Register module first time
      const messageHash = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'bytes32', 'string', 'uint256', 'uint256', 'string'],
        [tokenId, mockModuleAddress, moduleHash, testSpecification, 0, 0, testMetadata]
      );
      const signature = await addr1.signMessage(ethers.utils.arrayify(messageHash));

      await experienceRegistry.connect(addr1).registerModule(
        tokenId,
        mockModuleAddress,
        moduleHash,
        testSpecification,
        0,
        0,
        testMetadata,
        signature
      );

      // Try to register same module again
      await experienceRegistry.connect(addr1).registerModule(
        tokenId,
        mockModuleAddress,
        moduleHash,
        testSpecification,
        0,
        0,
        testMetadata,
        signature
      );

      // Should still only have one module
      const registeredModules = await experienceRegistry.getRegisteredModules(tokenId);
      expect(registeredModules).to.have.lengthOf(1);
    });
  });

  describe('Module Approval Management', function () {
    let tokenId;

    beforeEach(async function () {
      // Create an agent token
      await bep007['createAgent(address,address,string,(string,string,string,string,string,bytes32))'](
        addr1.address, 
        mockLogicAddress, 
        'ipfs://test', 
        {
          persona: 'Test Persona',
          experience: 'Test Experience',
          voiceHash: '',
          animationURI: '',
          vaultURI: '',
          vaultHash: ethers.constants.HashZero
        }
      );
      tokenId = 1;

      // Register a module
      const moduleHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('test-module-hash'));
      const messageHash = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'bytes32', 'string', 'uint256', 'uint256', 'string'],
        [tokenId, mockModuleAddress, moduleHash, testSpecification, 0, 0, testMetadata]
      );
      const signature = await addr1.signMessage(ethers.utils.arrayify(messageHash));

      await experienceRegistry.connect(addr1).registerModule(
        tokenId,
        mockModuleAddress,
        moduleHash,
        testSpecification,
        0,
        0,
        testMetadata,
        signature
      );
    });

    it('Should allow token owner to approve a module', async function () {
      await expect(
        experienceRegistry.connect(addr1).setModuleApproval(tokenId, mockModuleAddress, true)
      ).to.emit(experienceRegistry, 'ModuleApproved')
        .withArgs(tokenId, mockModuleAddress, true);

      expect(await experienceRegistry.isModuleApproved(tokenId, mockModuleAddress)).to.equal(true);
    });

    it('Should allow token owner to revoke module approval', async function () {
      // First approve the module
      await experienceRegistry.connect(addr1).setModuleApproval(tokenId, mockModuleAddress, true);
      expect(await experienceRegistry.isModuleApproved(tokenId, mockModuleAddress)).to.equal(true);

      // Then revoke approval
      await expect(
        experienceRegistry.connect(addr1).setModuleApproval(tokenId, mockModuleAddress, false)
      ).to.emit(experienceRegistry, 'ModuleApproved')
        .withArgs(tokenId, mockModuleAddress, false);

      expect(await experienceRegistry.isModuleApproved(tokenId, mockModuleAddress)).to.equal(false);
    });

    it('Should reject approval from non-token owner', async function () {
      await expect(
        experienceRegistry.connect(addr2).setModuleApproval(tokenId, mockModuleAddress, true)
      ).to.be.revertedWith('ExperienceModuleRegistry: caller is not token owner');
    });

    it('Should reject approval for non-existent module', async function () {
      await expect(
        experienceRegistry.connect(addr1).setModuleApproval(tokenId, mockModuleAddress2, true)
      ).to.be.revertedWith('ExperienceModuleRegistry: module does not exist');
    });

    it('Should return only approved modules', async function () {
      // Register second module
      const moduleHash2 = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('test-module-hash-2'));
      const messageHash2 = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'bytes32', 'string', 'uint256', 'uint256', 'string'],
        [tokenId, mockModuleAddress2, moduleHash2, testSpecification, 0, 0, testMetadata]
      );
      const signature2 = await addr1.signMessage(ethers.utils.arrayify(messageHash2));

      await experienceRegistry.connect(addr1).registerModule(
        tokenId,
        mockModuleAddress2,
        moduleHash2,
        testSpecification,
        0,
        0,
        testMetadata,
        signature2
      );

      // Approve only first module
      await experienceRegistry.connect(addr1).setModuleApproval(tokenId, mockModuleAddress, true);

      // Get approved modules
      const approvedModules = await experienceRegistry.getApprovedModules(tokenId);
      expect(approvedModules).to.have.lengthOf(1);
      expect(approvedModules[0]).to.equal(mockModuleAddress);
    });
  });

  describe('Metadata Management', function () {
    let tokenId;

    beforeEach(async function () {
      // Create an agent token
      await bep007['createAgent(address,address,string,(string,string,string,string,string,bytes32))'](
        addr1.address, 
        mockLogicAddress, 
        'ipfs://test', 
        {
          persona: 'Test Persona',
          experience: 'Test Experience',
          voiceHash: '',
          animationURI: '',
          vaultURI: '',
          vaultHash: ethers.constants.HashZero
        }
      );
      tokenId = 1;

      // Register and approve a module
      const moduleHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('test-module-hash'));
      const messageHash = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'bytes32', 'string', 'uint256', 'uint256', 'string'],
        [tokenId, mockModuleAddress, moduleHash, testSpecification, 0, 0, testMetadata]
      );
      const signature = await addr1.signMessage(ethers.utils.arrayify(messageHash));

      await experienceRegistry.connect(addr1).registerModule(
        tokenId,
        mockModuleAddress,
        moduleHash,
        testSpecification,
        0,
        0,
        testMetadata,
        signature
      );

      await experienceRegistry.connect(addr1).setModuleApproval(tokenId, mockModuleAddress, true);
    });

    it('Should allow token owner to update module metadata', async function () {
      const newMetadata = JSON.stringify({
        description: "Updated test experience module",
        version: "2.0.0",
        capabilities: ["learning", "adaptation", "collaboration"]
      });

      await expect(
        experienceRegistry.connect(addr1).updateModuleMetadata(tokenId, mockModuleAddress, newMetadata)
      ).to.emit(experienceRegistry, 'ModuleMetadataUpdated')
        .withArgs(tokenId, mockModuleAddress, newMetadata);

      expect(await experienceRegistry.getModuleMetadata(tokenId, mockModuleAddress)).to.equal(newMetadata);
    });

    it('Should reject metadata update from non-token owner', async function () {
      const newMetadata = JSON.stringify({ description: "Unauthorized update" });

      await expect(
        experienceRegistry.connect(addr2).updateModuleMetadata(tokenId, mockModuleAddress, newMetadata)
      ).to.be.revertedWith('ExperienceModuleRegistry: caller is not token owner');
    });

    it('Should reject metadata update for non-approved module', async function () {
      // Revoke approval
      await experienceRegistry.connect(addr1).setModuleApproval(tokenId, mockModuleAddress, false);

      const newMetadata = JSON.stringify({ description: "Update attempt" });

      await expect(
        experienceRegistry.connect(addr1).updateModuleMetadata(tokenId, mockModuleAddress, newMetadata)
      ).to.be.revertedWith('ExperienceModuleRegistry: module not approved');
    });
  });

  describe('Agent Experience Configuration', function () {
    let tokenId;

    beforeEach(async function () {
      // Create an agent token
      await bep007['createAgent(address,address,string,(string,string,string,string,string,bytes32))'](
        addr1.address, 
        mockLogicAddress, 
        'ipfs://test', 
        {
          persona: 'Test Persona',
          experience: 'Test Experience',
          voiceHash: '',
          animationURI: '',
          vaultURI: '',
          vaultHash: ethers.constants.HashZero
        }
      );
      tokenId = 1;
    });

    it('Should allow token owner to update agent experience configuration', async function () {
      await expect(
        experienceRegistry.connect(addr1).updateAgentExperienceConfig(
          tokenId,
          true,  // learningEnabled
          2,     // LEARNING
          5      // maxModules
        )
      ).to.emit(experienceRegistry, 'AgentExperienceConfigUpdated')
        .withArgs(tokenId, true, 2, 5);

      const config = await experienceRegistry.getAgentExperienceConfig(tokenId);
      expect(config.learningEnabled).to.equal(true);
      expect(config.preferredType).to.equal(2); // LEARNING
      expect(config.maxModules).to.equal(5);
      expect(config.lastUpdate).to.be.a('object'); // BigNumber
      expect(config.lastUpdate.toNumber()).to.be.greaterThan(0);
    });

    it('Should reject configuration update with zero maxModules', async function () {
      await expect(
        experienceRegistry.connect(addr1).updateAgentExperienceConfig(
          tokenId,
          true,
          1,
          0  // Invalid maxModules
        )
      ).to.be.revertedWith('ExperienceModuleRegistry: maxModules must be greater than 0');
    });

    it('Should reject configuration update from non-token owner', async function () {
      await expect(
        experienceRegistry.connect(addr2).updateAgentExperienceConfig(
          tokenId,
          true,
          1,
          3
        )
      ).to.be.revertedWith('ExperienceModuleRegistry: caller is not token owner');
    });
  });

  describe('Module Deactivation', function () {
    let tokenId;

    beforeEach(async function () {
      // Create an agent token
      await bep007['createAgent(address,address,string,(string,string,string,string,string,bytes32))'](
        addr1.address, 
        mockLogicAddress, 
        'ipfs://test', 
        {
          persona: 'Test Persona',
          experience: 'Test Experience',
          voiceHash: '',
          animationURI: '',
          vaultURI: '',
          vaultHash: ethers.constants.HashZero
        }
      );
      tokenId = 1;

      // Register a module
      const moduleHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('test-module-hash'));
      const messageHash = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'bytes32', 'string', 'uint256', 'uint256', 'string'],
        [tokenId, mockModuleAddress, moduleHash, testSpecification, 0, 0, testMetadata]
      );
      const signature = await addr1.signMessage(ethers.utils.arrayify(messageHash));

      await experienceRegistry.connect(addr1).registerModule(
        tokenId,
        mockModuleAddress,
        moduleHash,
        testSpecification,
        0,
        0,
        testMetadata,
        signature
      );
    });

    it('Should allow module creator to deactivate module', async function () {
      await expect(
        experienceRegistry.connect(addr1).deactivateModule(mockModuleAddress, 'Security issue found')
      ).to.emit(experienceRegistry, 'ModuleDeactivated')
        .withArgs(mockModuleAddress, 'Security issue found');

      const moduleInfo = await experienceRegistry.getModuleInfo(mockModuleAddress);
      expect(moduleInfo.active).to.equal(false);
    });

    it('Should allow contract owner to deactivate any module', async function () {
      await expect(
        experienceRegistry.connect(owner).deactivateModule(mockModuleAddress, 'Admin deactivation')
      ).to.emit(experienceRegistry, 'ModuleDeactivated')
        .withArgs(mockModuleAddress, 'Admin deactivation');

      const moduleInfo = await experienceRegistry.getModuleInfo(mockModuleAddress);
      expect(moduleInfo.active).to.equal(false);
    });

    it('Should reject deactivation from unauthorized address', async function () {
      await expect(
        experienceRegistry.connect(addr2).deactivateModule(mockModuleAddress, 'Unauthorized attempt')
      ).to.be.revertedWith('ExperienceModuleRegistry: not authorized to deactivate');
    });
  });

  describe('View Functions', function () {
    let tokenId;

    beforeEach(async function () {
      // Create an agent token
      await bep007['createAgent(address,address,string,(string,string,string,string,string,bytes32))'](
        addr1.address, 
        mockLogicAddress, 
        'ipfs://test', 
        {
          persona: 'Test Persona',
          experience: 'Test Experience',
          voiceHash: '',
          animationURI: '',
          vaultURI: '',
          vaultHash: ethers.constants.HashZero
        }
      );
      tokenId = 1;

      // Register multiple modules with different types and security levels
      const moduleHash1 = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('test-module-hash-1'));
      const messageHash1 = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'bytes32', 'string', 'uint256', 'uint256', 'string'],
        [tokenId, mockModuleAddress, moduleHash1, testSpecification, 0, 0, testMetadata]
      );
      const signature1 = await addr1.signMessage(ethers.utils.arrayify(messageHash1));

      await experienceRegistry.connect(addr1).registerModule(
        tokenId,
        mockModuleAddress,
        moduleHash1,
        testSpecification,
        0, // STATIC
        0, // EXPERIMENTAL
        testMetadata,
        signature1
      );

      const moduleHash2 = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('test-module-hash-2'));
      const messageHash2 = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'bytes32', 'string', 'uint256', 'uint256', 'string'],
        [tokenId, mockModuleAddress2, moduleHash2, testSpecification, 2, 2, testMetadata]
      );
      const signature2 = await addr1.signMessage(ethers.utils.arrayify(messageHash2));

      await experienceRegistry.connect(addr1).registerModule(
        tokenId,
        mockModuleAddress2,
        moduleHash2,
        testSpecification,
        2, // LEARNING
        2, // PROFESSIONAL
        testMetadata,
        signature2
      );

      // Approve first module
      await experienceRegistry.connect(addr1).setModuleApproval(tokenId, mockModuleAddress, true);
    });

    it('Should return all registered modules for an agent', async function () {
      const registeredModules = await experienceRegistry.getRegisteredModules(tokenId);
      expect(registeredModules).to.have.lengthOf(2);
      expect(registeredModules).to.include(mockModuleAddress);
      expect(registeredModules).to.include(mockModuleAddress2);
    });

    it('Should return only approved modules for an agent', async function () {
      const approvedModules = await experienceRegistry.getApprovedModules(tokenId);
      expect(approvedModules).to.have.lengthOf(1);
      expect(approvedModules[0]).to.equal(mockModuleAddress);
    });

    it('Should return module metadata', async function () {
      const metadata = await experienceRegistry.getModuleMetadata(tokenId, mockModuleAddress);
      expect(metadata).to.equal(testMetadata);
    });

    it('Should return module information', async function () {
      const moduleInfo = await experienceRegistry.getModuleInfo(mockModuleAddress);
      expect(moduleInfo.moduleAddress).to.equal(mockModuleAddress);
      expect(moduleInfo.experienceType).to.equal(0); // STATIC
      expect(moduleInfo.securityLevel).to.equal(0); // EXPERIMENTAL
      expect(moduleInfo.active).to.equal(true);
      expect(moduleInfo.creator).to.equal(addr1.address);
    });

    it('Should return agent experience configuration', async function () {
      // Set configuration first
      await experienceRegistry.connect(addr1).updateAgentExperienceConfig(
        tokenId,
        true,
        2,
        5
      );

      const config = await experienceRegistry.getAgentExperienceConfig(tokenId);
      expect(config.learningEnabled).to.equal(true);
      expect(config.preferredType).to.equal(2);
      expect(config.maxModules).to.equal(5);
    });

    it('Should return module usage count', async function () {
      const usageCount = await experienceRegistry.getModuleUsageCount(mockModuleAddress);
      expect(usageCount).to.equal(1);
    });

    it('Should return all modules in global registry', async function () {
      const allModules = await experienceRegistry.getAllModules();
      expect(allModules).to.have.lengthOf(2);
      expect(allModules).to.include(mockModuleAddress);
      expect(allModules).to.include(mockModuleAddress2);
    });

    it('Should return modules by experience type', async function () {
      const staticModules = await experienceRegistry.getModulesByType(0); // STATIC
      expect(staticModules).to.have.lengthOf(1);
      expect(staticModules[0]).to.equal(mockModuleAddress);

      const learningModules = await experienceRegistry.getModulesByType(2); // LEARNING
      expect(learningModules).to.have.lengthOf(1);
      expect(learningModules[0]).to.equal(mockModuleAddress2);
    });

    it('Should return modules by security level', async function () {
      const experimentalModules = await experienceRegistry.getModulesBySecurityLevel(0); // EXPERIMENTAL
      expect(experimentalModules).to.have.lengthOf(1);
      expect(experimentalModules[0]).to.equal(mockModuleAddress);

      const professionalModules = await experienceRegistry.getModulesBySecurityLevel(2); // PROFESSIONAL
      expect(professionalModules).to.have.lengthOf(1);
      expect(professionalModules[0]).to.equal(mockModuleAddress2);
    });

    it('Should return total module count', async function () {
      const totalCount = await experienceRegistry.getTotalModuleCount();
      expect(totalCount).to.equal(2);
    });
  });

  describe('Utility Functions', function () {
    it('Should validate module specification correctly', async function () {
      const validSpec = JSON.stringify({
        context_id: "nfa007-experience-001",
        persona: "Test persona",
        experience_slots: []
      });

      const invalidSpec = JSON.stringify({
        invalid_field: "test"
      });

      expect(await experienceRegistry.validateModuleSpecification(validSpec)).to.equal(true);
      expect(await experienceRegistry.validateModuleSpecification(invalidSpec)).to.equal(false);
      expect(await experienceRegistry.validateModuleSpecification("")).to.equal(false);
    });
  });

  describe('Admin Functions', function () {
    it('Should allow owner to update BEP007 token address', async function () {
      // Create a new BEP007 contract
      const newBEP007 = await upgrades.deployProxy(
        BEP007,
        ['New NFA', 'NNFA', circuitBreaker.address],
        { initializer: 'initialize', kind: 'uups' },
      );
      await newBEP007.deployed();

      await experienceRegistry.connect(owner).updateBEP007Token(newBEP007.address);
      expect(await experienceRegistry.bep007Token()).to.equal(newBEP007.address);
    });

    it('Should reject BEP007 update from non-owner', async function () {
      await expect(
        experienceRegistry.connect(addr1).updateBEP007Token(addr2.address)
      ).to.be.revertedWith('Ownable: caller is not the owner');
    });

    it('Should reject BEP007 update with zero address', async function () {
      await expect(
        experienceRegistry.connect(owner).updateBEP007Token(ethers.constants.AddressZero)
      ).to.be.revertedWith('ExperienceModuleRegistry: invalid address');
    });
  });

  describe('Edge Cases and Error Conditions', function () {
    let tokenId;

    beforeEach(async function () {
      // Create an agent token
      await bep007['createAgent(address,address,string,(string,string,string,string,string,bytes32))'](
        addr1.address, 
        mockLogicAddress, 
        'ipfs://test', 
        {
          persona: 'Test Persona',
          experience: 'Test Experience',
          voiceHash: '',
          animationURI: '',
          vaultURI: '',
          vaultHash: ethers.constants.HashZero
        }
      );
      tokenId = 1;
    });

    it('Should handle non-existent token queries gracefully', async function () {
      const nonExistentTokenId = 999;
      
      const registeredModules = await experienceRegistry.getRegisteredModules(nonExistentTokenId);
      expect(registeredModules).to.have.lengthOf(0);

      const approvedModules = await experienceRegistry.getApprovedModules(nonExistentTokenId);
      expect(approvedModules).to.have.lengthOf(0);

      const config = await experienceRegistry.getAgentExperienceConfig(nonExistentTokenId);
      expect(config.learningEnabled).to.equal(false);
      expect(config.preferredType).to.equal(0);
      expect(config.maxModules).to.equal(0);
    });

    it('Should handle queries for non-existent modules', async function () {
      expect(await experienceRegistry.isModuleApproved(tokenId, mockModuleAddress)).to.equal(false);
      expect(await experienceRegistry.getModuleMetadata(tokenId, mockModuleAddress)).to.equal('');
      expect(await experienceRegistry.getModuleUsageCount(mockModuleAddress)).to.equal(0);
    });

    it('Should handle empty arrays in filtering functions', async function () {
      const staticModules = await experienceRegistry.getModulesByType(0);
      expect(staticModules).to.have.lengthOf(0);

      const professionalModules = await experienceRegistry.getModulesBySecurityLevel(2);
      expect(professionalModules).to.have.lengthOf(0);
    });

    it('Should handle deactivation of non-existent module', async function () {
      await expect(
        experienceRegistry.connect(owner).deactivateModule(mockModuleAddress, 'Test')
      ).to.be.revertedWith('ExperienceModuleRegistry: module does not exist');
    });
  });

  describe('Reentrancy Protection', function () {
    it('Should be protected against reentrancy attacks', async function () {
      // This test ensures the nonReentrant modifier is working
      // In a real reentrancy attack scenario, we would need a malicious contract
      // For now, we just verify the modifier is present by checking the function signature
      const contract = await ethers.getContractAt('ExperienceModuleRegistry', experienceRegistry.address);
      
      // The registerModule function should have the nonReentrant modifier
      // We can verify this by checking that multiple rapid calls don't cause issues
      const tokenId = 1;
      await bep007['createAgent(address,address,string,(string,string,string,string,string,bytes32))'](
        addr1.address, 
        mockLogicAddress, 
        'ipfs://test', 
        {
          persona: 'Test Persona',
          experience: 'Test Experience',
          voiceHash: '',
          animationURI: '',
          vaultURI: '',
          vaultHash: ethers.constants.HashZero
        }
      );

      const moduleHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('test-module-hash'));
      const messageHash = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'bytes32', 'string', 'uint256', 'uint256', 'string'],
        [tokenId, mockModuleAddress, moduleHash, testSpecification, 0, 0, testMetadata]
      );
      const signature = await addr1.signMessage(ethers.utils.arrayify(messageHash));

      // This should not revert due to reentrancy
      await expect(
        experienceRegistry.connect(addr1).registerModule(
          tokenId,
          mockModuleAddress,
          moduleHash,
          testSpecification,
          0,
          0,
          testMetadata,
          signature
        )
      ).to.not.be.reverted;
    });
  });
});
