const { expect } = require('chai');
const { ethers, upgrades } = require('hardhat');

describe('KnowledgeRegistry', function () {
  let KnowledgeRegistry;
  let knowledgeRegistry;
  let AgentFactory;
  let agentFactory;
  let BAP578;
  let bap578;
  let CircuitBreaker;
  let circuitBreaker;
  let Treasury;
  let treasury;
  let owner;
  let governance;
  let emergencyMultiSig;
  let addr1;
  let addr2;
  let addrs;

  // Mock logic contract address for testing
  const mockLogicAddress = '0x1234567890123456789012345678901234567890';
  const DEFAULT_MAX_SOURCES = 10;
  const AGENT_CREATION_FEE = ethers.utils.parseEther("0.01");

  // We'll store created agent addresses here
  let agent1Address;
  let agent2Address;

  // Knowledge types enum
  const KnowledgeType = {
    BASE: 0,
    CONTEXT: 1,
    MEMORY: 2,
    INSTRUCTION: 3,
    REFERENCE: 4,
    DYNAMIC: 5
  };

  beforeEach(async function () {
    [owner, governance, emergencyMultiSig, addr1, addr2, ...addrs] = await ethers.getSigners();

    // Deploy CircuitBreaker first
    CircuitBreaker = await ethers.getContractFactory('CircuitBreaker');
    circuitBreaker = await upgrades.deployProxy(
      CircuitBreaker,
      [governance.address, emergencyMultiSig.address],
      { initializer: 'initialize' }
    );
    await circuitBreaker.deployed();

    // Deploy BAP578 Implementation
    BAP578 = await ethers.getContractFactory('BAP578');
    const bap578Implementation = await BAP578.deploy();
    await bap578Implementation.deployed();

    // Deploy Treasury
    Treasury = await ethers.getContractFactory('BAP578Treasury');
    treasury = await upgrades.deployProxy(
      Treasury,
      [
        circuitBreaker.address,  // circuitBreaker address
        owner.address,           // foundation address
        addr1.address,           // community treasury
        addr2.address,           // staking rewards
        owner.address            // initial admin/owner
      ],
      { initializer: 'initialize' }
    );
    await treasury.deployed();

    // Deploy AgentFactory
    AgentFactory = await ethers.getContractFactory('AgentFactory');
    agentFactory = await upgrades.deployProxy(
      AgentFactory,
      [
        bap578Implementation.address,
        owner.address,
        mockLogicAddress,
        treasury.address,
        circuitBreaker.address
      ],
      { initializer: 'initialize', kind: 'uups' }
    );
    await agentFactory.deployed();

    // Deploy KnowledgeRegistry with AgentFactory address
    KnowledgeRegistry = await ethers.getContractFactory('KnowledgeRegistry');
    knowledgeRegistry = await upgrades.deployProxy(
      KnowledgeRegistry,
      [agentFactory.address, DEFAULT_MAX_SOURCES],
      { initializer: 'initialize', kind: 'uups' }
    );
    await knowledgeRegistry.deployed();

    // Create agents for testing using AgentFactory
    // Agent 1 for addr1
    let tx = await agentFactory.connect(addr1).createAgent(
      'Agent1',
      'AG1',
      mockLogicAddress,
      'ipfs://QmAgent1',
      { value: AGENT_CREATION_FEE }
    );
    let receipt = await tx.wait();
    let agentCreatedEvent = receipt.events?.find(e => e.event === 'AgentCreated');
    agent1Address = agentCreatedEvent?.args?.agent;

    // Agent 2 for addr2  
    tx = await agentFactory.connect(addr2).createAgent(
      'Agent2',
      'AG2',
      mockLogicAddress,
      'ipfs://QmAgent2',
      { value: AGENT_CREATION_FEE }
    );
    receipt = await tx.wait();
    agentCreatedEvent = receipt.events?.find(e => e.event === 'AgentCreated');
    agent2Address = agentCreatedEvent?.args?.agent;
  });

  describe('Deployment', function () {
    it('Should set the right agent factory', async function () {
      expect(await knowledgeRegistry.agentFactory()).to.equal(agentFactory.address);
    });

    it('Should set the right default max sources', async function () {
      expect(await knowledgeRegistry.defaultMaxSources()).to.equal(DEFAULT_MAX_SOURCES);
    });

    it('Should set the right owner', async function () {
      expect(await knowledgeRegistry.owner()).to.equal(owner.address);
    });

    it('Should not allow initialization with zero AgentFactory address', async function () {
      const KnowledgeRegistryFactory = await ethers.getContractFactory('KnowledgeRegistry');
      await expect(
        upgrades.deployProxy(
          KnowledgeRegistryFactory,
          [ethers.constants.AddressZero, DEFAULT_MAX_SOURCES],
          { initializer: 'initialize', kind: 'uups' }
        )
      ).to.be.revertedWith('KnowledgeRegistry: invalid AgentFactory address');
    });

    it('Should not allow initialization with zero max sources', async function () {
      const KnowledgeRegistryFactory = await ethers.getContractFactory('KnowledgeRegistry');
      await expect(
        upgrades.deployProxy(
          KnowledgeRegistryFactory,
          [agentFactory.address, 0],
          { initializer: 'initialize', kind: 'uups' }
        )
      ).to.be.revertedWith('KnowledgeRegistry: invalid max sources');
    });
  });

  describe('Knowledge Source Management', function () {
    const tokenId = 1; // All agents have token ID 1
    const uri = 'ipfs://QmKnowledgeSource1';
    const description = 'Test knowledge source';
    const contentHash = ethers.utils.formatBytes32String('content-hash');

    describe('Adding Knowledge Sources', function () {
      it('Should allow token owner to add knowledge source', async function () {
        await expect(
          knowledgeRegistry.connect(addr1).addKnowledgeSource(
            agent1Address,
            tokenId,
            uri,
            KnowledgeType.BASE,
            100, // priority
            description,
            contentHash
          )
        ).to.emit(knowledgeRegistry, 'KnowledgeSourceAdded')
          .withArgs(agent1Address, tokenId, 1, uri, KnowledgeType.BASE, 100);

        const sources = await knowledgeRegistry.getKnowledgeSources(agent1Address, tokenId);
        expect(sources.length).to.equal(1);
        expect(sources[0].uri).to.equal(uri);
        expect(sources[0].sourceType).to.equal(KnowledgeType.BASE);
        expect(sources[0].priority).to.equal(100);
        expect(sources[0].active).to.equal(true);
        expect(sources[0].description).to.equal(description);
        expect(sources[0].contentHash).to.equal(contentHash);
      });

      it('Should not allow non-owner to add knowledge source', async function () {
        await expect(
          knowledgeRegistry.connect(addr2).addKnowledgeSource(
            agent1Address,
            tokenId,
            uri,
            KnowledgeType.BASE,
            100,
            description,
            contentHash
          )
        ).to.be.revertedWith('KnowledgeRegistry: caller is not token owner');
      });

      it('Should not allow empty URI', async function () {
        await expect(
          knowledgeRegistry.connect(addr1).addKnowledgeSource(
            agent1Address,
            tokenId,
            '',
            KnowledgeType.BASE,
            100,
            description,
            contentHash
          )
        ).to.be.revertedWith('KnowledgeRegistry: empty URI');
      });

      it('Should enforce max sources limit', async function () {
        // Add maximum sources
        for (let i = 0; i < DEFAULT_MAX_SOURCES; i++) {
          await knowledgeRegistry.connect(addr1).addKnowledgeSource(
            agent1Address,
            tokenId,
            `ipfs://QmKnowledgeSource${i}`,
            KnowledgeType.BASE,
            100,
            `Description ${i}`,
            contentHash
          );
        }

        // Try to add one more
        await expect(
          knowledgeRegistry.connect(addr1).addKnowledgeSource(
            agent1Address,
            tokenId,
            'ipfs://QmExtraSource',
            KnowledgeType.BASE,
            100,
            'Extra source',
            contentHash
          )
        ).to.be.revertedWith('KnowledgeRegistry: max sources reached');
      });

      it('Should track URI usage across agents', async function () {
        // Add same URI to both agents
        await knowledgeRegistry.connect(addr1).addKnowledgeSource(
          agent1Address,
          tokenId,
          uri,
          KnowledgeType.BASE,
          100,
          description,
          contentHash
        );

        await knowledgeRegistry.connect(addr2).addKnowledgeSource(
          agent2Address,
          tokenId,
          uri,
          KnowledgeType.BASE,
          100,
          description,
          contentHash
        );

        const agentsUsingUri = await knowledgeRegistry.getAgentsUsingUri(uri);
        // Now returns packed agent identifiers (bytes32)
        expect(agentsUsingUri.length).to.equal(2);
      });

      it('Should handle dynamic sources correctly', async function () {
        // Enable dynamic sources (default)
        await knowledgeRegistry.connect(addr1).addKnowledgeSource(
          agent1Address,
          tokenId,
          'http://api.example.com/data',
          KnowledgeType.DYNAMIC,
          50,
          'Dynamic API source',
          contentHash
        );

        const sources = await knowledgeRegistry.getKnowledgeSources(agent1Address, tokenId);
        expect(sources[0].sourceType).to.equal(KnowledgeType.DYNAMIC);

        // Disable dynamic sources
        await knowledgeRegistry.connect(addr1).updateKnowledgeConfig(
          agent1Address,
          tokenId,
          DEFAULT_MAX_SOURCES,
          false // disallow dynamic sources
        );

        // Try to add another dynamic source
        await expect(
          knowledgeRegistry.connect(addr1).addKnowledgeSource(
            agent1Address,
            tokenId,
            'http://another-api.com/data',
            KnowledgeType.DYNAMIC,
            50,
            'Another dynamic source',
            contentHash
          )
        ).to.be.revertedWith('KnowledgeRegistry: dynamic sources not allowed');
      });
    });

    describe('Updating Knowledge Sources', function () {
      let sourceId;

      beforeEach(async function () {
        const tx = await knowledgeRegistry.connect(addr1).addKnowledgeSource(
          agent1Address,
          tokenId,
          uri,
          KnowledgeType.BASE,
          100,
          description,
          contentHash
        );
        sourceId = 1; // First source ID
      });

      it('Should allow token owner to update knowledge source', async function () {
        const newUri = 'ipfs://QmUpdatedSource';
        const newContentHash = ethers.utils.formatBytes32String('new-hash');

        await expect(
          knowledgeRegistry.connect(addr1).updateKnowledgeSource(
            agent1Address,
            tokenId,
            sourceId,
            newUri,
            newContentHash
          )
        ).to.emit(knowledgeRegistry, 'KnowledgeSourceUpdated')
          .withArgs(agent1Address, tokenId, sourceId, uri, newUri);

        const sources = await knowledgeRegistry.getKnowledgeSources(agent1Address, tokenId);
        expect(sources[0].uri).to.equal(newUri);
        expect(sources[0].contentHash).to.equal(newContentHash);
        expect(sources[0].version).to.equal(2); // Version incremented
      });

      it('Should not allow non-owner to update knowledge source', async function () {
        await expect(
          knowledgeRegistry.connect(addr2).updateKnowledgeSource(
            agent1Address,
            tokenId,
            sourceId,
            'ipfs://QmHacker',
            contentHash
          )
        ).to.be.revertedWith('KnowledgeRegistry: caller is not token owner');
      });

      it('Should not allow updating non-existent source', async function () {
        await expect(
          knowledgeRegistry.connect(addr1).updateKnowledgeSource(
            agent1Address,
            tokenId,
            999,
            'ipfs://QmNonExistent',
            contentHash
          )
        ).to.be.revertedWith('KnowledgeRegistry: source does not exist');
      });
    });

    describe('Toggling Knowledge Sources', function () {
      let sourceId;

      beforeEach(async function () {
        await knowledgeRegistry.connect(addr1).addKnowledgeSource(
          agent1Address,
          tokenId,
          uri,
          KnowledgeType.BASE,
          100,
          description,
          contentHash
        );
        sourceId = 1;
      });

      it('Should allow token owner to toggle knowledge source', async function () {
        // Initially active
        let sources = await knowledgeRegistry.getKnowledgeSources(agent1Address, tokenId);
        expect(sources[0].active).to.equal(true);

        // Toggle to inactive
        await expect(
          knowledgeRegistry.connect(addr1).toggleKnowledgeSource(agent1Address, tokenId, sourceId)
        ).to.emit(knowledgeRegistry, 'KnowledgeSourceToggled')
          .withArgs(agent1Address, tokenId, sourceId, false);

        sources = await knowledgeRegistry.getKnowledgeSources(agent1Address, tokenId);
        expect(sources[0].active).to.equal(false);

        // Toggle back to active
        await knowledgeRegistry.connect(addr1).toggleKnowledgeSource(agent1Address, tokenId, sourceId);
        sources = await knowledgeRegistry.getKnowledgeSources(agent1Address, tokenId);
        expect(sources[0].active).to.equal(true);
      });

      it('Should update active source count correctly', async function () {
        const config = await knowledgeRegistry.getKnowledgeConfig(agent1Address, tokenId);
        const initialActive = config.activeSources;

        await knowledgeRegistry.connect(addr1).toggleKnowledgeSource(agent1Address, tokenId, sourceId);
        
        const configAfterToggle = await knowledgeRegistry.getKnowledgeConfig(agent1Address, tokenId);
        expect(configAfterToggle.activeSources).to.equal(initialActive - 1);
      });
    });

    describe('Priority Management', function () {
      let sourceId;

      beforeEach(async function () {
        await knowledgeRegistry.connect(addr1).addKnowledgeSource(
          agent1Address,
          tokenId,
          uri,
          KnowledgeType.BASE,
          100,
          description,
          contentHash
        );
        sourceId = 1;
      });

      it('Should allow changing knowledge priority', async function () {
        const newPriority = 200;

        await expect(
          knowledgeRegistry.connect(addr1).changeKnowledgePriority(
            agent1Address,
            tokenId,
            sourceId,
            newPriority
          )
        ).to.emit(knowledgeRegistry, 'KnowledgePriorityChanged')
          .withArgs(agent1Address, tokenId, sourceId, 100, newPriority);

        const sources = await knowledgeRegistry.getKnowledgeSources(agent1Address, tokenId);
        expect(sources[0].priority).to.equal(newPriority);
      });

      it('Should return sources sorted by priority', async function () {
        // Add more sources with different priorities
        await knowledgeRegistry.connect(addr1).addKnowledgeSource(
          agent1Address,
          tokenId,
          'ipfs://QmLowPriority',
          KnowledgeType.CONTEXT,
          50,
          'Low priority',
          contentHash
        );

        await knowledgeRegistry.connect(addr1).addKnowledgeSource(
          agent1Address,
          tokenId,
          'ipfs://QmHighPriority',
          KnowledgeType.INSTRUCTION,
          150,
          'High priority',
          contentHash
        );

        const sortedSources = await knowledgeRegistry.getKnowledgeSourcesByPriority(agent1Address, tokenId);
        
        // Check that sources are sorted by priority (descending)
        expect(sortedSources[0].priority).to.equal(150);
        expect(sortedSources[1].priority).to.equal(100);
        expect(sortedSources[2].priority).to.equal(50);
      });
    });

    describe('Removing Knowledge Sources', function () {
      let sourceId;

      beforeEach(async function () {
        await knowledgeRegistry.connect(addr1).addKnowledgeSource(
          agent1Address,
          tokenId,
          uri,
          KnowledgeType.BASE,
          100,
          description,
          contentHash
        );
        sourceId = 1;
      });

      it('Should allow token owner to remove knowledge source', async function () {
        await expect(
          knowledgeRegistry.connect(addr1).removeKnowledgeSource(agent1Address, tokenId, sourceId)
        ).to.emit(knowledgeRegistry, 'KnowledgeSourceRemoved')
          .withArgs(agent1Address, tokenId, sourceId);

        const sources = await knowledgeRegistry.getKnowledgeSources(agent1Address, tokenId);
        expect(sources.length).to.equal(0);
      });

      it('Should update config counts correctly', async function () {
        const configBefore = await knowledgeRegistry.getKnowledgeConfig(agent1Address, tokenId);
        
        await knowledgeRegistry.connect(addr1).removeKnowledgeSource(agent1Address, tokenId, sourceId);
        
        const configAfter = await knowledgeRegistry.getKnowledgeConfig(agent1Address, tokenId);
        expect(configAfter.totalSources).to.equal(configBefore.totalSources - 1);
        expect(configAfter.activeSources).to.equal(configBefore.activeSources - 1);
      });
    });
  });

  describe('Knowledge Configuration', function () {
    const tokenId = 1;

    it('Should initialize with default configuration', async function () {
      const config = await knowledgeRegistry.getKnowledgeConfig(agent1Address, tokenId);
      
      expect(config.maxSources).to.equal(DEFAULT_MAX_SOURCES);
      expect(config.allowDynamicSources).to.equal(true);
      expect(config.totalSources).to.equal(0);
      expect(config.activeSources).to.equal(0);
    });

    it('Should allow token owner to update configuration', async function () {
      const newMaxSources = 20;
      const allowDynamic = false;

      await expect(
        knowledgeRegistry.connect(addr1).updateKnowledgeConfig(
          agent1Address,
          tokenId,
          newMaxSources,
          allowDynamic
        )
      ).to.emit(knowledgeRegistry, 'KnowledgeConfigUpdated')
        .withArgs(agent1Address, tokenId, newMaxSources, allowDynamic);

      const config = await knowledgeRegistry.getKnowledgeConfig(agent1Address, tokenId);
      expect(config.maxSources).to.equal(newMaxSources);
      expect(config.allowDynamicSources).to.equal(allowDynamic);
    });

    it('Should not allow non-owner to update configuration', async function () {
      await expect(
        knowledgeRegistry.connect(addr2).updateKnowledgeConfig(agent1Address, tokenId, 20, true)
      ).to.be.revertedWith('KnowledgeRegistry: caller is not token owner');
    });

    it('Should not allow max sources less than current total', async function () {
      // Add 5 sources
      for (let i = 0; i < 5; i++) {
        await knowledgeRegistry.connect(addr1).addKnowledgeSource(
          agent1Address,
          tokenId,
          `ipfs://QmSource${i}`,
          KnowledgeType.BASE,
          100,
          `Description ${i}`,
          ethers.utils.formatBytes32String(`hash${i}`)
        );
      }

      // Try to set max sources to 3 (less than current 5)
      await expect(
        knowledgeRegistry.connect(addr1).updateKnowledgeConfig(agent1Address, tokenId, 3, true)
      ).to.be.revertedWith('KnowledgeRegistry: max sources less than current total');
    });
  });

  describe('View Functions', function () {
    const tokenId = 1;

    beforeEach(async function () {
      // Add various knowledge sources
      await knowledgeRegistry.connect(addr1).addKnowledgeSource(
        agent1Address,
        tokenId,
        'ipfs://QmBase',
        KnowledgeType.BASE,
        100,
        'Base knowledge',
        ethers.utils.formatBytes32String('base')
      );

      await knowledgeRegistry.connect(addr1).addKnowledgeSource(
        agent1Address,
        tokenId,
        'ipfs://QmContext',
        KnowledgeType.CONTEXT,
        80,
        'Context knowledge',
        ethers.utils.formatBytes32String('context')
      );

      await knowledgeRegistry.connect(addr1).addKnowledgeSource(
        agent1Address,
        tokenId,
        'ipfs://QmMemory',
        KnowledgeType.MEMORY,
        60,
        'Memory knowledge',
        ethers.utils.formatBytes32String('memory')
      );

      // Toggle one source to inactive
      await knowledgeRegistry.connect(addr1).toggleKnowledgeSource(agent1Address, tokenId, 3);
    });

    it('Should return all knowledge sources', async function () {
      const sources = await knowledgeRegistry.getKnowledgeSources(agent1Address, tokenId);
      expect(sources.length).to.equal(3);
    });

    it('Should return only active knowledge sources', async function () {
      const activeSources = await knowledgeRegistry.getActiveKnowledgeSources(agent1Address, tokenId);
      expect(activeSources.length).to.equal(2); // One is toggled inactive
    });

    it('Should return sources by type', async function () {
      const baseSources = await knowledgeRegistry.getKnowledgeSourcesByType(
        agent1Address,
        tokenId,
        KnowledgeType.BASE
      );
      expect(baseSources.length).to.equal(1);
      expect(baseSources[0].sourceType).to.equal(KnowledgeType.BASE);

      const contextSources = await knowledgeRegistry.getKnowledgeSourcesByType(
        agent1Address,
        tokenId,
        KnowledgeType.CONTEXT
      );
      expect(contextSources.length).to.equal(1);
      expect(contextSources[0].sourceType).to.equal(KnowledgeType.CONTEXT);
    });

    it('Should return sources sorted by priority', async function () {
      const sortedSources = await knowledgeRegistry.getKnowledgeSourcesByPriority(agent1Address, tokenId);
      
      // Only active sources should be returned, sorted by priority
      expect(sortedSources.length).to.equal(2);
      expect(sortedSources[0].priority).to.be.gte(sortedSources[1].priority);
    });
  });

  describe('Admin Functions', function () {
    it('Should allow owner to update default max sources', async function () {
      const newDefault = 15;
      
      await knowledgeRegistry.connect(owner).setDefaultMaxSources(newDefault);
      expect(await knowledgeRegistry.defaultMaxSources()).to.equal(newDefault);
    });

    it('Should not allow non-owner to update default max sources', async function () {
      await expect(
        knowledgeRegistry.connect(addr1).setDefaultMaxSources(15)
      ).to.be.revertedWith('Ownable: caller is not the owner');
    });

    it('Should allow owner to update AgentFactory address', async function () {
      const newAddress = addr2.address; // Using any address for testing
      
      await knowledgeRegistry.connect(owner).updateAgentFactory(newAddress);
      expect(await knowledgeRegistry.agentFactory()).to.equal(newAddress);
    });

    it('Should not allow setting zero address for AgentFactory', async function () {
      await expect(
        knowledgeRegistry.connect(owner).updateAgentFactory(ethers.constants.AddressZero)
      ).to.be.revertedWith('KnowledgeRegistry: invalid AgentFactory address');
    });
  });

  describe('Cross-Agent Isolation', function () {
    const tokenId = 1;

    it('Should isolate knowledge between different agents', async function () {
      // Add knowledge to agent1
      await knowledgeRegistry.connect(addr1).addKnowledgeSource(
        agent1Address,
        tokenId,
        'ipfs://QmAgent1Knowledge',
        KnowledgeType.BASE,
        100,
        'Agent 1 knowledge',
        ethers.utils.formatBytes32String('agent1')
      );

      // Add knowledge to agent2
      await knowledgeRegistry.connect(addr2).addKnowledgeSource(
        agent2Address,
        tokenId,
        'ipfs://QmAgent2Knowledge',
        KnowledgeType.BASE,
        100,
        'Agent 2 knowledge',
        ethers.utils.formatBytes32String('agent2')
      );

      // Verify agent1's knowledge
      const agent1Sources = await knowledgeRegistry.getKnowledgeSources(agent1Address, tokenId);
      expect(agent1Sources.length).to.equal(1);
      expect(agent1Sources[0].uri).to.equal('ipfs://QmAgent1Knowledge');

      // Verify agent2's knowledge
      const agent2Sources = await knowledgeRegistry.getKnowledgeSources(agent2Address, tokenId);
      expect(agent2Sources.length).to.equal(1);
      expect(agent2Sources[0].uri).to.equal('ipfs://QmAgent2Knowledge');
    });

    it('Should not allow cross-agent knowledge manipulation', async function () {
      // Add knowledge to agent1
      await knowledgeRegistry.connect(addr1).addKnowledgeSource(
        agent1Address,
        tokenId,
        'ipfs://QmAgent1Knowledge',
        KnowledgeType.BASE,
        100,
        'Agent 1 knowledge',
        ethers.utils.formatBytes32String('agent1')
      );

      // addr2 should not be able to modify agent1's knowledge
      await expect(
        knowledgeRegistry.connect(addr2).updateKnowledgeSource(
          agent1Address,
          tokenId,
          1,
          'ipfs://QmHackedKnowledge',
          ethers.utils.formatBytes32String('hacked')
        )
      ).to.be.revertedWith('KnowledgeRegistry: caller is not token owner');
    });
  });
});
