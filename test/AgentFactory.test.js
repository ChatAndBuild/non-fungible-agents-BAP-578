const { expect } = require('chai');
const { ethers, upgrades } = require('hardhat');

describe('AgentFactory', function () {
  let AgentFactory;
  let agentFactory;
  let BAP700;
  let bap700Implementation;
  let CircuitBreaker;
  let circuitBreaker;
  let MerkleTreeLearning;
  let merkleTreeLearning;
  let owner;
  let governance;
  let emergencyMultiSig;
  let addr1;
  let addr2;
  let addr3;
  let addrs;

  // Mock addresses for testing
  const mockLogicAddress = "0x1234567890123456789012345678901234567890";
  const mockTemplateAddress = "0x2345678901234567890123456789012345678901";
  const mockLearningModuleAddress = "0x3456789012345678901234567890123456789012";

  beforeEach(async function () {
    [owner, governance, emergencyMultiSig, addr1, addr2, addr3, ...addrs] = await ethers.getSigners();

    // Deploy CircuitBreaker first
    CircuitBreaker = await ethers.getContractFactory('CircuitBreaker');
    circuitBreaker = await upgrades.deployProxy(
      CircuitBreaker,
      [governance.address, emergencyMultiSig.address],
      { initializer: "initialize" }
    );
    await circuitBreaker.deployed();

    // Deploy BAP700 implementation
    BAP700 = await ethers.getContractFactory('BAP700');
    bap700Implementation = await BAP700.deploy();
    await bap700Implementation.deployed();

    // Deploy MerkleTreeLearning as default learning module
    MerkleTreeLearning = await ethers.getContractFactory('MerkleTreeLearning');
    merkleTreeLearning = await MerkleTreeLearning.deploy();
    await merkleTreeLearning.deployed();

    // Deploy AgentFactory
    AgentFactory = await ethers.getContractFactory('AgentFactory');
    agentFactory = await upgrades.deployProxy(
      AgentFactory,
      [bap700Implementation.address, owner.address, merkleTreeLearning.address],
      { initializer: "initialize", kind: "uups" }
    );
    await agentFactory.deployed();
  });

  describe('Deployment', function () {
    it('Should set the correct implementation address', async function () {
      expect(await agentFactory.implementation()).to.equal(bap700Implementation.address);
    });

    it('Should set the correct default learning module', async function () {
      expect(await agentFactory.defaultLearningModule()).to.equal(merkleTreeLearning.address);
    });

    it('Should initialize global learning stats correctly', async function () {
      const stats = await agentFactory.getGlobalLearningStats();
      expect(stats.totalAgentsCreated).to.equal(0);
      expect(stats.totalLearningEnabledAgents).to.equal(0);
      expect(stats.totalLearningInteractions).to.equal(0);
      expect(stats.totalLearningModules).to.equal(0);
      expect(stats.averageGlobalConfidence).to.equal(0);
      expect(stats.lastStatsUpdate).to.be.gt(0);
    });

    it('Should not allow initialization with zero implementation address', async function () {
      const AgentFactoryFactory = await ethers.getContractFactory('AgentFactory');
      await expect(
        upgrades.deployProxy(
          AgentFactoryFactory,
          [ethers.constants.AddressZero, circuitBreaker.address, merkleTreeLearning.address],
          { initializer: "initialize", kind: "uups" }
        )
      ).to.be.revertedWith("AgentFactory: implementation is zero address");
    });

    it('Should not allow initialization with zero governance address', async function () {
      const AgentFactoryFactory = await ethers.getContractFactory('AgentFactory');
      await expect(
        upgrades.deployProxy(
          AgentFactoryFactory,
          [bap700Implementation.address, ethers.constants.AddressZero, merkleTreeLearning.address],
          { initializer: "initialize", kind: "uups" }
        )
      ).to.be.revertedWith("AgentFactory: owner is zero address");
    });
  });

  describe('Agent Creation', function () {
    it('Should create an agent with basic metadata', async function () {
      const name = "Test Agent";
      const symbol = "TA";
      const metadataURI = "ipfs://QmTestAgent";

      const tx = await agentFactory.connect(addr1).createAgent(
        name,
        symbol,
        mockLogicAddress,
        metadataURI
      );

      const receipt = await tx.wait();
      const agentCreatedEvent = receipt.events?.find(e => e.event === 'AgentCreated');
      
      expect(agentCreatedEvent).to.not.be.undefined;
      expect(agentCreatedEvent.args.owner).to.equal(addr1.address);
      expect(agentCreatedEvent.args.tokenId).to.equal(1);
      expect(agentCreatedEvent.args.logic).to.equal(mockLogicAddress);

      // Verify the agent contract was created
      const agentAddress = agentCreatedEvent.args.agent;
      expect(agentAddress).to.not.equal(ethers.constants.AddressZero);

      // Verify the agent contract is properly initialized
      const agentContract = await ethers.getContractAt('BAP700', agentAddress);
      expect(await agentContract.name()).to.equal(name);
      expect(await agentContract.symbol()).to.equal(symbol);
      expect(await agentContract.ownerOf(1)).to.equal(addr1.address);
      expect(await agentContract.tokenURI(1)).to.equal(metadataURI);
    });

    it('Should create multiple agents with different owners', async function () {
      // Create first agent
      await agentFactory.connect(addr1).createAgent(
        "Agent 1",
        "A1",
        mockLogicAddress,
        "ipfs://QmAgent1"
      );

      // Create second agent
      await agentFactory.connect(addr2).createAgent(
        "Agent 2",
        "A2",
        mockLogicAddress,
        "ipfs://QmAgent2"
      );

      // Both should succeed and emit events
      // The actual verification would depend on how you want to track multiple agents
    });

    it('Should create agent with extended metadata', async function () {
      const name = "Extended Agent";
      const symbol = "EA";
      const metadataURI = "ipfs://QmExtendedAgent";

      const tx = await agentFactory.connect(addr1).createAgent(
        name,
        symbol,
        mockLogicAddress,
        metadataURI
      );

      const receipt = await tx.wait();
      const agentCreatedEvent = receipt.events?.find(e => e.event === 'AgentCreated');
      
      expect(agentCreatedEvent).to.not.be.undefined;
      
      // Verify the agent has empty extended metadata (since we're using the basic createAgent function)
      const agentAddress = agentCreatedEvent.args.agent;
      const agentContract = await ethers.getContractAt('BAP700', agentAddress);
      const metadata = await agentContract.getAgentMetadata(1);
      
      expect(metadata.persona).to.equal("");
      expect(metadata.experience).to.equal("");
      expect(metadata.voiceHash).to.equal("");
      expect(metadata.animationURI).to.equal("");
      expect(metadata.vaultURI).to.equal("");
      expect(metadata.vaultHash).to.equal(ethers.constants.HashZero);
    });

    it('Should not allow creating agent with zero logic address', async function () {
      await expect(
        agentFactory.connect(addr1).createAgent(
          "Test Agent",
          "TA",
          ethers.constants.AddressZero,
          "ipfs://QmTest"
        )
      ).to.be.reverted; // The revert will happen in the BAP700 contract
    });
  });

  describe('Template Management', function () {
    it('Should allow owner to approve templates', async function () {
      const category = "creator";
      const version = "v1.0.0";

      await expect(
        agentFactory.approveTemplate(
          mockTemplateAddress,
          category,
          version
        )
      ).to.emit(agentFactory, 'TemplateApproved')
      .withArgs(mockTemplateAddress, category, version);

      expect(await agentFactory.approvedTemplates(mockTemplateAddress)).to.be.true;
      expect(await agentFactory.templateVersions(category, version)).to.equal(mockTemplateAddress);
    });


it('Should not allow non-owner to approve templates', async function () {
      await expect(
        agentFactory.connect(addr1).approveTemplate(
          mockTemplateAddress,
          "creator",
          "v1.0.0"
        )
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it('Should not allow approving template with zero address', async function () {
      await expect(
        agentFactory.approveTemplate(
          ethers.constants.AddressZero,
          "creator",
          "v1.0.0"
        )
      ).to.be.revertedWith("AgentFactory: template is zero address");
    });

    it('Should allow owner to revoke templates', async function () {
      // First approve a template
      await agentFactory.approveTemplate(
        mockTemplateAddress,
        "creator",
        "v1.0.0"
      );

      // Then revoke it
      await agentFactory.revokeTemplate(mockTemplateAddress);

      expect(await agentFactory.approvedTemplates(mockTemplateAddress)).to.be.false;
    });

    it('Should not allow revoking non-approved template', async function () {
      await expect(
        agentFactory.revokeTemplate(mockTemplateAddress)
      ).to.be.revertedWith("AgentFactory: template not approved");
    });

    it('Should get template version correctly', async function () {
      const category = "creator";
      const version = "v1.0.0";

      await agentFactory.approveTemplate(
        mockTemplateAddress,
        category,
        version
      );

      expect(await agentFactory.getTemplateVersion(category, version)).to.equal(mockTemplateAddress);
    });

    it('Should revert when getting non-existent template version', async function () {
      await expect(
        agentFactory.getTemplateVersion("nonexistent", "v1.0.0")
      ).to.be.revertedWith("AgentFactory: no template for category");
    });
  });

  describe('Learning Module Management', function () {
    it('Should allow owner to approve learning modules', async function () {
      const category = "merkle-tree";
      const version = "v1.0.0";

      await expect(
        agentFactory.approveLearningModule(
          mockLearningModuleAddress,
          category,
          version
        )
      ).to.emit(agentFactory, 'LearningModuleApproved')
      .withArgs(mockLearningModuleAddress, category, version);

      expect(await agentFactory.approvedLearningModules(mockLearningModuleAddress)).to.be.true;
      expect(await agentFactory.learningModuleVersions(category)).to.equal(mockLearningModuleAddress);

      // Check that global stats were updated
      const stats = await agentFactory.getGlobalLearningStats();
      expect(stats.totalLearningModules).to.equal(1);
    });

    it('Should not allow non-owner to approve learning modules', async function () {
      await expect(
        agentFactory.connect(addr1).approveLearningModule(
          mockLearningModuleAddress,
          "merkle-tree",
          "v1.0.0"
        )
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it('Should not allow approving learning module with zero address', async function () {
      await expect(
        agentFactory.approveLearningModule(
          ethers.constants.AddressZero,
          "merkle-tree",
          "v1.0.0"
        )
      ).to.be.revertedWith("AgentFactory: learning module is zero address");
    });

    it('Should allow owner to revoke learning modules', async function () {
      // First approve a learning module
      await agentFactory.approveLearningModule(
        mockLearningModuleAddress,
        "merkle-tree",
        "v1.0.0"
      );

      // Then revoke it
      await agentFactory.revokeLearningModule(mockLearningModuleAddress);

      expect(await agentFactory.approvedLearningModules(mockLearningModuleAddress)).to.be.false;

      // Check that global stats were updated
      const stats = await agentFactory.getGlobalLearningStats();
      expect(stats.totalLearningModules).to.equal(0);
    });


it('Should not allow revoking non-approved learning module', async function () {
      await expect(
        agentFactory.revokeLearningModule(mockLearningModuleAddress)
      ).to.be.revertedWith("AgentFactory: learning module not approved");
    });

    it('Should get latest learning module correctly', async function () {
      const category = "merkle-tree";

      await agentFactory.approveLearningModule(
        mockLearningModuleAddress,
        category,
        "v1.0.0"
      );

      expect(await agentFactory.getLatestLearningModule(category)).to.equal(mockLearningModuleAddress);
    });

    it('Should revert when getting non-existent learning module', async function () {
      await expect(
        agentFactory.getLatestLearningModule("nonexistent")
      ).to.be.revertedWith("AgentFactory: no learning module for category");
    });

    it('Should check if learning module is approved', async function () {
      expect(await agentFactory.isLearningModuleApproved(mockLearningModuleAddress)).to.be.false;

      await agentFactory.approveLearningModule(
        mockLearningModuleAddress,
        "merkle-tree",
        "v1.0.0"
      );

      expect(await agentFactory.isLearningModuleApproved(mockLearningModuleAddress)).to.be.true;
    });
  });

  describe('Configuration Management', function () {
    it('Should allow owner to set default learning module', async function () {
      // First approve the learning module
      await agentFactory.approveLearningModule(
        mockLearningModuleAddress,
        "merkle-tree",
        "v1.0.0"
      );

      // Then set it as default
      await agentFactory.setDefaultLearningModule(mockLearningModuleAddress);

      expect(await agentFactory.defaultLearningModule()).to.equal(mockLearningModuleAddress);
    });

    it('Should not allow setting non-approved module as default', async function () {
      await expect(
        agentFactory.setDefaultLearningModule(mockLearningModuleAddress)
      ).to.be.revertedWith("AgentFactory: module not approved");
    });

    it('Should not allow setting zero address as default learning module', async function () {
      await expect(
        agentFactory.setDefaultLearningModule(ethers.constants.AddressZero)
      ).to.be.revertedWith("AgentFactory: module is zero address");
    });

    it('Should allow owner to set implementation', async function () {
      const newImplementation = addr3.address; // Using a different address for testing

      await agentFactory.setImplementation(newImplementation);

      expect(await agentFactory.implementation()).to.equal(newImplementation);
    });

    it('Should not allow setting zero address as implementation', async function () {
      await expect(
        agentFactory.setImplementation(ethers.constants.AddressZero)
      ).to.be.revertedWith("AgentFactory: implementation is zero address");
    });

    
  });

  describe('Global Learning Statistics', function () {
    it('Should return correct initial global learning stats', async function () {
      const stats = await agentFactory.getGlobalLearningStats();
      
      expect(stats.totalAgentsCreated).to.equal(0);
      expect(stats.totalLearningEnabledAgents).to.equal(0);
      expect(stats.totalLearningInteractions).to.equal(0);
      expect(stats.totalLearningModules).to.equal(0);
      expect(stats.averageGlobalConfidence).to.equal(0);
      expect(stats.lastStatsUpdate).to.be.gt(0);
    });

    it('Should update learning module count when approving modules', async function () {
      await agentFactory.approveLearningModule(
        mockLearningModuleAddress,
        "merkle-tree",
        "v1.0.0"
      );

      const stats = await agentFactory.getGlobalLearningStats();
      expect(stats.totalLearningModules).to.equal(1);
    });

    it('Should decrease learning module count when revoking modules', async function () {
      // Approve first
      await agentFactory.approveLearningModule(
        mockLearningModuleAddress,
        "merkle-tree",
        "v1.0.0"
      );


// Then revoke
      await agentFactory.revokeLearningModule(mockLearningModuleAddress);

      const stats = await agentFactory.getGlobalLearningStats();
      expect(stats.totalLearningModules).to.equal(0);
    });
  });

  describe('Access Control', function () {
    it('Should only allow owner to call governance functions', async function () {
      const functions = [
        'approveTemplate',
        'approveLearningModule',
        'revokeTemplate',
        'revokeLearningModule',
        'setDefaultLearningModule',
        'setImplementation',
      ];

      // Test that non-governance addresses cannot call these functions
      for (const func of functions) {
        if (func === 'approveTemplate') {
          await expect(
            agentFactory.connect(addr1)[func](mockTemplateAddress, "test", "v1.0.0")
          ).to.be.revertedWith("Ownable: caller is not the owner");
        } else if (func === 'approveLearningModule') {
          await expect(
            agentFactory.connect(addr1)[func](mockLearningModuleAddress, "test", "v1.0.0")
          ).to.be.revertedWith("Ownable: caller is not the owner");
        } else if (func === 'revokeTemplate') {
          await expect(
            agentFactory.connect(addr1)[func](mockTemplateAddress)
          ).to.be.revertedWith("Ownable: caller is not the owner");
        } else if (func === 'revokeLearningModule') {
          await expect(
            agentFactory.connect(addr1)[func](mockLearningModuleAddress)
          ).to.be.revertedWith("Ownable: caller is not the owner");
        } else if (func === 'setDefaultLearningModule') {
          await expect(
            agentFactory.connect(addr1)[func](mockLearningModuleAddress)
          ).to.be.revertedWith("Ownable: caller is not the owner");
        } else if (func === 'setImplementation') {
          await expect(
            agentFactory.connect(addr1)[func](addr3.address)
          ).to.be.revertedWith("Ownable: caller is not the owner");
        } else if (func === 'setGovernance') {
          await expect(
            agentFactory.connect(addr1)[func](addr3.address)
          ).to.be.revertedWith("Ownable: caller is not the owner");
        }
      }
    });
  });

  describe('Contract Upgrade', function () {
    it('Should only allow owner to upgrade contract', async function () {
      await expect(
        agentFactory.connect(addr1).upgradeTo(addr2.address)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it('Should only allow owner to upgrade and call', async function () {
      await expect(
        agentFactory.connect(addr1).upgradeToAndCall(addr2.address, "0x")
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe('Edge Cases and Error Handling', function () {
    it('Should handle multiple template versions for same category', async function () {
      const category = "creator";
      const version1 = "v1.0.0";
      const version2 = "v2.0.0";
      const template1 = mockTemplateAddress;
      const template2 = addr3.address;

      await agentFactory.approveTemplate(template1, category, version1);
      await agentFactory.approveTemplate(template2, category, version2);

      expect(await agentFactory.getTemplateVersion(category, version1)).to.equal(template1);
      expect(await agentFactory.getTemplateVersion(category, version2)).to.equal(template2);
    });

    it('Should handle multiple learning module categories', async function () {
      const category1 = "merkle-tree";
      const category2 = "neural-network";
      const module1 = mockLearningModuleAddress;
      const module2 = addr3.address;

      await agentFactory.approveLearningModule(module1, category1, "v1.0.0");
      await agentFactory.approveLearningModule(module2, category2, "v1.0.0");

      expect(await agentFactory.getLatestLearningModule(category1)).to.equal(module1);
      expect(await agentFactory.getLatestLearningModule(category2)).to.equal(module2);


const stats = await agentFactory.getGlobalLearningStats();
      expect(stats.totalLearningModules).to.equal(2);
    });

    it('Should handle agent creation with same parameters multiple times', async function () {
      const name = "Test Agent";
      const symbol = "TA";
      const metadataURI = "ipfs://QmTest";

      // Create first agent
      const tx1 = await agentFactory.connect(addr1).createAgent(
        name,
        symbol,
        mockLogicAddress,
        metadataURI
      );

      // Create second agent with same parameters
      const tx2 = await agentFactory.connect(addr1).createAgent(
        name,
        symbol,
        mockLogicAddress,
        metadataURI
      );

      // Both should succeed and create different contracts
      const receipt1 = await tx1.wait();
      const receipt2 = await tx2.wait();

      const event1 = receipt1.events?.find(e => e.event === 'AgentCreated');
      const event2 = receipt2.events?.find(e => e.event === 'AgentCreated');

      expect(event1.args.agent).to.not.equal(event2.args.agent);
    });
  });

  describe('Events', function () {
    it('Should emit AgentCreated event with correct parameters', async function () {
      const tx = await agentFactory.connect(addr1).createAgent(
        "Test Agent",
        "TA",
        mockLogicAddress,
        "ipfs://QmTest"
      );

      const receipt = await tx.wait();
      const event = receipt.events?.find(e => e.event === 'AgentCreated');

      expect(event).to.not.be.undefined;
      expect(event.args.owner).to.equal(addr1.address);
      expect(event.args.tokenId).to.equal(1);
      expect(event.args.logic).to.equal(mockLogicAddress);
      expect(event.args.agent).to.not.equal(ethers.constants.AddressZero);
    });

    it('Should emit TemplateApproved event', async function () {
      await expect(
        agentFactory.approveTemplate(
          mockTemplateAddress,
          "creator",
          "v1.0.0"
        )
      ).to.emit(agentFactory, 'TemplateApproved')
      .withArgs(mockTemplateAddress, "creator", "v1.0.0");
    });

    it('Should emit LearningModuleApproved event', async function () {
      await expect(
        agentFactory.approveLearningModule(
          mockLearningModuleAddress,
          "merkle-tree",
          "v1.0.0"
        )
      ).to.emit(agentFactory, 'LearningModuleApproved')
      .withArgs(mockLearningModuleAddress, "merkle-tree", "v1.0.0");
    });
  });
});