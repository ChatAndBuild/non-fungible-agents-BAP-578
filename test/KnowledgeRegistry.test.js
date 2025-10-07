const { expect } = require('chai');
const { ethers, upgrades } = require('hardhat');

describe('KnowledgeRegistry', function () {
  let KnowledgeRegistry;
  let knowledgeRegistry;
  let BAP578;
  let bap578;
  let CircuitBreaker;
  let circuitBreaker;
  let owner;
  let governance;
  let emergencyMultiSig;
  let addr1;
  let addr2;
  let addrs;

  // Mock logic contract address for testing
  const mockLogicAddress = '0x1234567890123456789012345678901234567890';
  const DEFAULT_MAX_SOURCES = 10;

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

    // Deploy BAP578
    BAP578 = await ethers.getContractFactory('BAP578');
    bap578 = await upgrades.deployProxy(
      BAP578,
      ['Non-Fungible Agent', 'NFA', circuitBreaker.address],
      { initializer: 'initialize', kind: 'uups' }
    );
    await bap578.deployed();

    // Deploy KnowledgeRegistry
    KnowledgeRegistry = await ethers.getContractFactory('KnowledgeRegistry');
    knowledgeRegistry = await upgrades.deployProxy(
      KnowledgeRegistry,
      [bap578.address, DEFAULT_MAX_SOURCES],
      { initializer: 'initialize', kind: 'uups' }
    );
    await knowledgeRegistry.deployed();

    // Create an agent for testing
    await bap578['createAgent(address,address,string)'](
      addr1.address,
      mockLogicAddress,
      'ipfs://QmTest'
    );
  });

  describe('Deployment', function () {
    it('Should set the right BAP578 token', async function () {
      expect(await knowledgeRegistry.bap578Token()).to.equal(bap578.address);
    });

    it('Should set the right default max sources', async function () {
      expect(await knowledgeRegistry.defaultMaxSources()).to.equal(DEFAULT_MAX_SOURCES);
    });

    it('Should set the right owner', async function () {
      expect(await knowledgeRegistry.owner()).to.equal(owner.address);
    });

    it('Should not allow initialization with zero BAP578 address', async function () {
      const KnowledgeRegistryFactory = await ethers.getContractFactory('KnowledgeRegistry');
      await expect(
        upgrades.deployProxy(
          KnowledgeRegistryFactory,
          [ethers.constants.AddressZero, DEFAULT_MAX_SOURCES],
          { initializer: 'initialize', kind: 'uups' }
        )
      ).to.be.revertedWith('KnowledgeRegistry: invalid BAP578 address');
    });

    it('Should not allow initialization with zero max sources', async function () {
      const KnowledgeRegistryFactory = await ethers.getContractFactory('KnowledgeRegistry');
      await expect(
        upgrades.deployProxy(
          KnowledgeRegistryFactory,
          [bap578.address, 0],
          { initializer: 'initialize', kind: 'uups' }
        )
      ).to.be.revertedWith('KnowledgeRegistry: invalid max sources');
    });
  });

  describe('Knowledge Source Management', function () {
    const tokenId = 1;
    const uri = 'ipfs://QmKnowledgeSource1';
    const description = 'Test knowledge source';
    const contentHash = ethers.utils.formatBytes32String('content-hash');

    describe('Adding Knowledge Sources', function () {
      it('Should allow token owner to add knowledge source', async function () {
        await expect(
          knowledgeRegistry.connect(addr1).addKnowledgeSource(
            tokenId,
            uri,
            KnowledgeType.BASE,
            100, // priority
            description,
            contentHash
          )
        ).to.emit(knowledgeRegistry, 'KnowledgeSourceAdded')
          .withArgs(tokenId, 1, uri, KnowledgeType.BASE, 100);

        const sources = await knowledgeRegistry.getKnowledgeSources(tokenId);
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
        // Create another agent
        await bap578['createAgent(address,address,string)'](
          addr2.address,
          mockLogicAddress,
          'ipfs://QmTest2'
        );

        // Add same URI to both agents
        await knowledgeRegistry.connect(addr1).addKnowledgeSource(
          1,
          uri,
          KnowledgeType.BASE,
          100,
          description,
          contentHash
        );

        await knowledgeRegistry.connect(addr2).addKnowledgeSource(
          2,
          uri,
          KnowledgeType.BASE,
          100,
          description,
          contentHash
        );

        const agentsUsingUri = await knowledgeRegistry.getAgentsUsingUri(uri);
        expect(agentsUsingUri.length).to.equal(2);
        expect(agentsUsingUri[0].toNumber()).to.equal(1);
        expect(agentsUsingUri[1].toNumber()).to.equal(2);
      });

      it('Should handle dynamic sources correctly', async function () {
        // Enable dynamic sources (default)
        await knowledgeRegistry.connect(addr1).addKnowledgeSource(
          tokenId,
          'http://api.example.com/data',
          KnowledgeType.DYNAMIC,
          50,
          'Dynamic API source',
          contentHash
        );

        const sources = await knowledgeRegistry.getKnowledgeSources(tokenId);
        expect(sources[0].sourceType).to.equal(KnowledgeType.DYNAMIC);

        // Disable dynamic sources
        await knowledgeRegistry.connect(addr1).updateKnowledgeConfig(
          tokenId,
          DEFAULT_MAX_SOURCES,
          false // disallow dynamic sources
        );

        // Try to add another dynamic source
        await expect(
          knowledgeRegistry.connect(addr1).addKnowledgeSource(
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
            tokenId,
            sourceId,
            newUri,
            newContentHash
          )
        ).to.emit(knowledgeRegistry, 'KnowledgeSourceUpdated')
          .withArgs(tokenId, sourceId, uri, newUri);

        const sources = await knowledgeRegistry.getKnowledgeSources(tokenId);
        expect(sources[0].uri).to.equal(newUri);
        expect(sources[0].contentHash).to.equal(newContentHash);
        expect(sources[0].version).to.equal(2); // Version incremented
      });

      it('Should not allow non-owner to update knowledge source', async function () {
        await expect(
          knowledgeRegistry.connect(addr2).updateKnowledgeSource(
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
            tokenId,
            999,
            'ipfs://QmNonExistent',
            contentHash
          )
        ).to.be.revertedWith('KnowledgeRegistry: source does not exist');
      });

      it('Should update URI tracking when source URI changes', async function () {
        const newUri = 'ipfs://QmNewUri';
        
        await knowledgeRegistry.connect(addr1).updateKnowledgeSource(
          tokenId,
          sourceId,
          newUri,
          contentHash
        );

        const oldUriAgents = await knowledgeRegistry.getAgentsUsingUri(uri);
        const newUriAgents = await knowledgeRegistry.getAgentsUsingUri(newUri);

        // Check that old URI no longer includes this tokenId
        const oldUriAgentNumbers = oldUriAgents.map(id => id.toNumber());
        expect(oldUriAgentNumbers).to.not.include(tokenId);
        
        // Check that new URI includes this tokenId
        expect(newUriAgents.length).to.equal(1);
        expect(newUriAgents[0].toNumber()).to.equal(tokenId);
      });
    });

    describe('Toggling Knowledge Sources', function () {
      let sourceId;

      beforeEach(async function () {
        await knowledgeRegistry.connect(addr1).addKnowledgeSource(
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
        let sources = await knowledgeRegistry.getKnowledgeSources(tokenId);
        expect(sources[0].active).to.equal(true);

        // Toggle to inactive
        await expect(
          knowledgeRegistry.connect(addr1).toggleKnowledgeSource(tokenId, sourceId)
        ).to.emit(knowledgeRegistry, 'KnowledgeSourceToggled')
          .withArgs(tokenId, sourceId, false);

        sources = await knowledgeRegistry.getKnowledgeSources(tokenId);
        expect(sources[0].active).to.equal(false);

        // Toggle back to active
        await knowledgeRegistry.connect(addr1).toggleKnowledgeSource(tokenId, sourceId);
        sources = await knowledgeRegistry.getKnowledgeSources(tokenId);
        expect(sources[0].active).to.equal(true);
      });

      it('Should update active source count correctly', async function () {
        const config = await knowledgeRegistry.getKnowledgeConfig(tokenId);
        const initialActive = config.activeSources;

        await knowledgeRegistry.connect(addr1).toggleKnowledgeSource(tokenId, sourceId);
        
        const configAfterToggle = await knowledgeRegistry.getKnowledgeConfig(tokenId);
        expect(configAfterToggle.activeSources).to.equal(initialActive - 1);
      });
    });

    describe('Priority Management', function () {
      let sourceId;

      beforeEach(async function () {
        await knowledgeRegistry.connect(addr1).addKnowledgeSource(
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
            tokenId,
            sourceId,
            newPriority
          )
        ).to.emit(knowledgeRegistry, 'KnowledgePriorityChanged')
          .withArgs(tokenId, sourceId, 100, newPriority);

        const sources = await knowledgeRegistry.getKnowledgeSources(tokenId);
        expect(sources[0].priority).to.equal(newPriority);
      });

      it('Should return sources sorted by priority', async function () {
        // Add more sources with different priorities
        await knowledgeRegistry.connect(addr1).addKnowledgeSource(
          tokenId,
          'ipfs://QmLowPriority',
          KnowledgeType.CONTEXT,
          50,
          'Low priority',
          contentHash
        );

        await knowledgeRegistry.connect(addr1).addKnowledgeSource(
          tokenId,
          'ipfs://QmHighPriority',
          KnowledgeType.INSTRUCTION,
          150,
          'High priority',
          contentHash
        );

        const sortedSources = await knowledgeRegistry.getKnowledgeSourcesByPriority(tokenId);
        
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
          knowledgeRegistry.connect(addr1).removeKnowledgeSource(tokenId, sourceId)
        ).to.emit(knowledgeRegistry, 'KnowledgeSourceRemoved')
          .withArgs(tokenId, sourceId);

        const sources = await knowledgeRegistry.getKnowledgeSources(tokenId);
        expect(sources.length).to.equal(0);
      });

      it('Should update URI tracking when source is removed', async function () {
        await knowledgeRegistry.connect(addr1).removeKnowledgeSource(tokenId, sourceId);

        const agentsUsingUri = await knowledgeRegistry.getAgentsUsingUri(uri);
        expect(agentsUsingUri).to.not.include(tokenId);
      });

      it('Should update config counts correctly', async function () {
        const configBefore = await knowledgeRegistry.getKnowledgeConfig(tokenId);
        
        await knowledgeRegistry.connect(addr1).removeKnowledgeSource(tokenId, sourceId);
        
        const configAfter = await knowledgeRegistry.getKnowledgeConfig(tokenId);
        expect(configAfter.totalSources).to.equal(configBefore.totalSources - 1);
        expect(configAfter.activeSources).to.equal(configBefore.activeSources - 1);
      });
    });
  });

  describe('Knowledge Configuration', function () {
    const tokenId = 1;

    it('Should initialize with default configuration', async function () {
      const config = await knowledgeRegistry.getKnowledgeConfig(tokenId);
      
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
          tokenId,
          newMaxSources,
          allowDynamic
        )
      ).to.emit(knowledgeRegistry, 'KnowledgeConfigUpdated')
        .withArgs(tokenId, newMaxSources, allowDynamic);

      const config = await knowledgeRegistry.getKnowledgeConfig(tokenId);
      expect(config.maxSources).to.equal(newMaxSources);
      expect(config.allowDynamicSources).to.equal(allowDynamic);
    });

    it('Should not allow non-owner to update configuration', async function () {
      await expect(
        knowledgeRegistry.connect(addr2).updateKnowledgeConfig(tokenId, 20, true)
      ).to.be.revertedWith('KnowledgeRegistry: caller is not token owner');
    });

    it('Should not allow max sources less than current total', async function () {
      // Add 5 sources
      for (let i = 0; i < 5; i++) {
        await knowledgeRegistry.connect(addr1).addKnowledgeSource(
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
        knowledgeRegistry.connect(addr1).updateKnowledgeConfig(tokenId, 3, true)
      ).to.be.revertedWith('KnowledgeRegistry: max sources less than current total');
    });
  });

  describe('View Functions', function () {
    const tokenId = 1;

    beforeEach(async function () {
      // Add various knowledge sources
      await knowledgeRegistry.connect(addr1).addKnowledgeSource(
        tokenId,
        'ipfs://QmBase',
        KnowledgeType.BASE,
        100,
        'Base knowledge',
        ethers.utils.formatBytes32String('base')
      );

      await knowledgeRegistry.connect(addr1).addKnowledgeSource(
        tokenId,
        'ipfs://QmContext',
        KnowledgeType.CONTEXT,
        80,
        'Context knowledge',
        ethers.utils.formatBytes32String('context')
      );

      await knowledgeRegistry.connect(addr1).addKnowledgeSource(
        tokenId,
        'ipfs://QmMemory',
        KnowledgeType.MEMORY,
        60,
        'Memory knowledge',
        ethers.utils.formatBytes32String('memory')
      );

      // Toggle one source to inactive
      await knowledgeRegistry.connect(addr1).toggleKnowledgeSource(tokenId, 3);
    });

    it('Should return all knowledge sources', async function () {
      const sources = await knowledgeRegistry.getKnowledgeSources(tokenId);
      expect(sources.length).to.equal(3);
    });

    it('Should return only active knowledge sources', async function () {
      const activeSources = await knowledgeRegistry.getActiveKnowledgeSources(tokenId);
      expect(activeSources.length).to.equal(2); // One is toggled inactive
    });

    it('Should return sources by type', async function () {
      const baseSources = await knowledgeRegistry.getKnowledgeSourcesByType(
        tokenId,
        KnowledgeType.BASE
      );
      expect(baseSources.length).to.equal(1);
      expect(baseSources[0].sourceType).to.equal(KnowledgeType.BASE);

      const contextSources = await knowledgeRegistry.getKnowledgeSourcesByType(
        tokenId,
        KnowledgeType.CONTEXT
      );
      expect(contextSources.length).to.equal(1);
      expect(contextSources[0].sourceType).to.equal(KnowledgeType.CONTEXT);
    });

    it('Should return sources sorted by priority', async function () {
      const sortedSources = await knowledgeRegistry.getKnowledgeSourcesByPriority(tokenId);
      
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

    it('Should allow owner to update BAP578 token address', async function () {
      const newAddress = addr2.address; // Using any address for testing
      
      await knowledgeRegistry.connect(owner).updateBAP578Token(newAddress);
      expect(await knowledgeRegistry.bap578Token()).to.equal(newAddress);
    });

    it('Should not allow setting zero address for BAP578 token', async function () {
      await expect(
        knowledgeRegistry.connect(owner).updateBAP578Token(ethers.constants.AddressZero)
      ).to.be.revertedWith('KnowledgeRegistry: invalid BAP578 address');
    });
  });

  describe('Edge Cases', function () {
    const tokenId = 1;

    it('Should handle multiple sources with same priority', async function () {
      // Add sources with same priority
      for (let i = 0; i < 3; i++) {
        await knowledgeRegistry.connect(addr1).addKnowledgeSource(
          tokenId,
          `ipfs://QmSamePriority${i}`,
          KnowledgeType.BASE,
          100, // Same priority
          `Same priority ${i}`,
          ethers.utils.formatBytes32String(`same${i}`)
        );
      }

      const sources = await knowledgeRegistry.getKnowledgeSources(tokenId);
      expect(sources.length).to.equal(3);
      sources.forEach(source => {
        expect(source.priority).to.equal(100);
      });
    });

    it('Should handle removing and re-adding sources', async function () {
      // Add source
      await knowledgeRegistry.connect(addr1).addKnowledgeSource(
        tokenId,
        'ipfs://QmRemoveAdd',
        KnowledgeType.BASE,
        100,
        'Remove and add test',
        ethers.utils.formatBytes32String('test')
      );

      // Remove it
      await knowledgeRegistry.connect(addr1).removeKnowledgeSource(tokenId, 1);

      // Add again with same URI
      await knowledgeRegistry.connect(addr1).addKnowledgeSource(
        tokenId,
        'ipfs://QmRemoveAdd',
        KnowledgeType.BASE,
        100,
        'Remove and add test 2',
        ethers.utils.formatBytes32String('test2')
      );

      const sources = await knowledgeRegistry.getKnowledgeSources(tokenId);
      expect(sources.length).to.equal(1);
      expect(sources[0].id).to.equal(2); // New ID assigned
    });

    it('Should handle priority value of 0', async function () {
      await knowledgeRegistry.connect(addr1).addKnowledgeSource(
        tokenId,
        'ipfs://QmZeroPriority',
        KnowledgeType.BASE,
        0, // Zero priority
        'Zero priority source',
        ethers.utils.formatBytes32String('zero')
      );

      const sources = await knowledgeRegistry.getKnowledgeSources(tokenId);
      expect(sources[0].priority).to.equal(0);
    });
  });
});
