const { expect } = require('chai');
const { ethers, upgrades } = require('hardhat');

describe('ImprintModuleRegistry', function () {
  let ImprintModuleRegistry;
  let registry;
  let BEP007;
  let bep007Token;
  let CircuitBreaker;
  let circuitBreaker;
  let MockExperienceModule;
  let mockModule1;
  let mockModule2;
  let owner;
  let agentOwner;
  let moduleProvider;
  let unauthorized;
  let addrs;

  beforeEach(async function () {
    // Get the ContractFactory and Signers
    ImprintModuleRegistry = await ethers.getContractFactory('ExperienceModuleRegistry');
    BEP007 = await ethers.getContractFactory('BEP007');
    CircuitBreaker = await ethers.getContractFactory('CircuitBreaker');
    MockExperienceModule = await ethers.getContractFactory('MockExperienceModule');
    [owner, agentOwner, moduleProvider, unauthorized, ...addrs] = await ethers.getSigners();

    // Deploy CircuitBreaker first
    circuitBreaker = await upgrades.deployProxy(
      CircuitBreaker,
      [owner.address, owner.address],
      { initializer: "initialize"}
    );
    await circuitBreaker.deployed();

    // Deploy BEP007 token
    bep007Token = await upgrades.deployProxy(
      BEP007,
      ["Imprint Agent Token", "IAT", circuitBreaker.address],
      { initializer: "initialize", kind: "uups" }
    );
    await bep007Token.deployed();

    // Deploy ImprintModuleRegistry (ExperienceModuleRegistry)
    registry = await upgrades.deployProxy(
      ImprintModuleRegistry,
      [bep007Token.address],
      { initializer: "initialize" }
    );
    await registry.deployed();

    // Deploy mock experience modules for testing
    mockModule1 = await MockExperienceModule.deploy("Imprint Module 1", "v1.0.0");
    await mockModule1.deployed();

    mockModule2 = await MockExperienceModule.deploy("Imprint Module 2", "v2.0.0");
    await mockModule2.deployed();

    // Create an agent for testing
    const metadataURI = 'ipfs://QmImprintTest';
    const extendedMetadata = {
      persona: 'Imprint Agent Persona',
      experience: 'Imprint Agent Experience',
      voiceHash: 'Imprint Voice Hash',
      animationURI: 'ipfs://QmImprintAnimation',
      vaultURI: 'ipfs://QmImprintVault',
      vaultHash: ethers.utils.formatBytes32String('imprint-vault-hash'),
    };

    await bep007Token["createAgent(address,address,string,(string,string,string,string,string,bytes32))"](
      agentOwner.address,
      mockModule1.address,
      metadataURI,
      extendedMetadata
    );
  });

  describe('Deployment', function () {
    it('Should set the correct BEP007 token address', async function () {
      expect(await registry.bep007Token()).to.equal(bep007Token.address);
    });

    it('Should set the correct owner', async function () {
      expect(await registry.owner()).to.equal(owner.address);
    });

    it('Should revert if initialized with zero address token', async function () {
      await expect(
        upgrades.deployProxy(
          ImprintModuleRegistry,
          [ethers.constants.AddressZero],
          { initializer: "initialize" }
        )
      ).to.be.revertedWith('ExperienceModuleRegistry: token is zero address');
    });
  });

  describe('Imprint Module Registration', function () {
    const tokenId = 1;
    const moduleMetadata = "Imprint module for experience tracking and learning";

    it('Should register an imprint module with valid signature', async function () {
      // Create signature
      const messageHash = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'string'],
        [tokenId, mockModule1.address, moduleMetadata]
      );
      const signature = await agentOwner.signMessage(ethers.utils.arrayify(messageHash));

      const tx = await registry.registerModule(
        tokenId,
        mockModule1.address,
        moduleMetadata,
        signature
      );

      const receipt = await tx.wait();
      const event = receipt.events?.find(e => e.event === 'ModuleRegistered');

      expect(event).to.not.be.undefined;
      expect(event.args.tokenId).to.equal(tokenId);
      expect(event.args.moduleAddress).to.equal(mockModule1.address);
      expect(event.args.metadata).to.equal(moduleMetadata);

      // Verify module is registered and approved
      expect(await registry.isModuleApproved(tokenId, mockModule1.address)).to.be.true;
      expect(await registry.getModuleMetadata(tokenId, mockModule1.address)).to.equal(moduleMetadata);

      const registeredModules = await registry.getRegisteredModules(tokenId);
      expect(registeredModules).to.include(mockModule1.address);
    });

    it('Should revert with invalid signature for imprint module', async function () {
      // Create signature with wrong signer
      const messageHash = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'string'],
        [tokenId, mockModule1.address, moduleMetadata]
      );
      const signature = await unauthorized.signMessage(ethers.utils.arrayify(messageHash));

      await expect(
        registry.registerModule(tokenId, mockModule1.address, moduleMetadata, signature)
      ).to.be.revertedWith('ExperienceModuleRegistry: invalid signature');
    });

    it('Should revert with zero address imprint module', async function () {
      const messageHash = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'string'],
        [tokenId, ethers.constants.AddressZero, moduleMetadata]
      );
      const signature = await agentOwner.signMessage(ethers.utils.arrayify(messageHash));

      await expect(
        registry.registerModule(tokenId, ethers.constants.AddressZero, moduleMetadata, signature)
      ).to.be.revertedWith('ExperienceModuleRegistry: module is zero address');
    });

    it('Should revert when registering already registered imprint module', async function () {
      // First registration
      const messageHash = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'string'],
        [tokenId, mockModule1.address, moduleMetadata]
      );
      const signature = await agentOwner.signMessage(ethers.utils.arrayify(messageHash));

      await registry.registerModule(tokenId, mockModule1.address, moduleMetadata, signature);

      // Second registration should fail
      await expect(
        registry.registerModule(tokenId, mockModule1.address, moduleMetadata, signature)
      ).to.be.revertedWith('ExperienceModuleRegistry: module already registered');
    });

    it('Should revert when agent token does not exist', async function () {
      const nonExistentTokenId = 999;
      const messageHash = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'string'],
        [nonExistentTokenId, mockModule1.address, moduleMetadata]
      );
      const signature = await agentOwner.signMessage(ethers.utils.arrayify(messageHash));

      await expect(
        registry.registerModule(nonExistentTokenId, mockModule1.address, moduleMetadata, signature)
      ).to.be.revertedWith('ERC721: invalid token ID');
    });
  });

  describe('Imprint Module Approval Management', function () {
    const tokenId = 1;
    const moduleMetadata = "Imprint module for approval management testing";

    beforeEach(async function () {
      // Register an imprint module first
      const messageHash = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'string'],
        [tokenId, mockModule1.address, moduleMetadata]
      );
      const signature = await agentOwner.signMessage(ethers.utils.arrayify(messageHash));

      await registry.registerModule(tokenId, mockModule1.address, moduleMetadata, signature);
    });

    it('Should allow agent owner to revoke imprint module approval', async function () {
      // Initially approved
      expect(await registry.isModuleApproved(tokenId, mockModule1.address)).to.be.true;

      // Revoke approval
      const tx = await registry.connect(agentOwner).setModuleApproval(tokenId, mockModule1.address, false);
      const receipt = await tx.wait();
      const event = receipt.events?.find(e => e.event === 'ModuleApproved');

      expect(event.args.tokenId).to.equal(tokenId);
      expect(event.args.moduleAddress).to.equal(mockModule1.address);
      expect(event.args.approved).to.be.false;

      expect(await registry.isModuleApproved(tokenId, mockModule1.address)).to.be.false;
    });

    it('Should allow agent owner to re-approve revoked imprint module', async function () {
      // Revoke first
      await registry.connect(agentOwner).setModuleApproval(tokenId, mockModule1.address, false);
      expect(await registry.isModuleApproved(tokenId, mockModule1.address)).to.be.false;

      // Re-approve
      await registry.connect(agentOwner).setModuleApproval(tokenId, mockModule1.address, true);
      expect(await registry.isModuleApproved(tokenId, mockModule1.address)).to.be.true;
    });

    it('Should not allow non-owner to change imprint module approval', async function () {
      await expect(
        registry.connect(unauthorized).setModuleApproval(tokenId, mockModule1.address, false)
      ).to.be.revertedWith('ExperienceModuleRegistry: not token owner');
    });

    it('Should allow approval of non-registered imprint modules', async function () {
      // This should work even if module wasn't registered through registerModule
      await registry.connect(agentOwner).setModuleApproval(tokenId, mockModule2.address, true);
      expect(await registry.isModuleApproved(tokenId, mockModule2.address)).to.be.true;
    });
  });

  describe('Imprint Module Metadata Management', function () {
    const tokenId = 1;
    const moduleMetadata = "Original imprint metadata";
    const updatedMetadata = "Updated imprint metadata with enhanced features";

    beforeEach(async function () {
      // Register an imprint module first
      const messageHash = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'string'],
        [tokenId, mockModule1.address, moduleMetadata]
      );
      const signature = await agentOwner.signMessage(ethers.utils.arrayify(messageHash));

      await registry.registerModule(tokenId, mockModule1.address, moduleMetadata, signature);
    });

    it('Should allow agent owner to update imprint module metadata', async function () {
      const tx = await registry.connect(agentOwner).updateModuleMetadata(
        tokenId,
        mockModule1.address,
        updatedMetadata
      );

      const receipt = await tx.wait();
      const event = receipt.events?.find(e => e.event === 'ModuleMetadataUpdated');

      expect(event.args.tokenId).to.equal(tokenId);
      expect(event.args.moduleAddress).to.equal(mockModule1.address);
      expect(event.args.metadata).to.equal(updatedMetadata);

      expect(await registry.getModuleMetadata(tokenId, mockModule1.address)).to.equal(updatedMetadata);
    });

    it('Should not allow non-owner to update imprint module metadata', async function () {
      await expect(
        registry.connect(unauthorized).updateModuleMetadata(tokenId, mockModule1.address, updatedMetadata)
      ).to.be.revertedWith('ExperienceModuleRegistry: not token owner');
    });

    it('Should not allow updating metadata for non-approved imprint module', async function () {
      // Revoke approval first
      await registry.connect(agentOwner).setModuleApproval(tokenId, mockModule1.address, false);

      await expect(
        registry.connect(agentOwner).updateModuleMetadata(tokenId, mockModule1.address, updatedMetadata)
      ).to.be.revertedWith('ExperienceModuleRegistry: module not approved');
    });
  });

  describe('Imprint Module View Functions', function () {
    const tokenId = 1;
    const metadata1 = "Imprint Module 1 metadata - Learning patterns";
    const metadata2 = "Imprint Module 2 metadata - Experience tracking";

    beforeEach(async function () {
      // Register multiple imprint modules
      const messageHash1 = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'string'],
        [tokenId, mockModule1.address, metadata1]
      );
      const signature1 = await agentOwner.signMessage(ethers.utils.arrayify(messageHash1));

      const messageHash2 = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'string'],
        [tokenId, mockModule2.address, metadata2]
      );
      const signature2 = await agentOwner.signMessage(ethers.utils.arrayify(messageHash2));

      await registry.registerModule(tokenId, mockModule1.address, metadata1, signature1);
      await registry.registerModule(tokenId, mockModule2.address, metadata2, signature2);
    });

    it('Should return all registered imprint modules for an agent', async function () {
      const registeredModules = await registry.getRegisteredModules(tokenId);
      
      expect(registeredModules).to.have.length(2);
      expect(registeredModules).to.include(mockModule1.address);
      expect(registeredModules).to.include(mockModule2.address);
    });

    it('Should return correct approval status for imprint modules', async function () {
      expect(await registry.isModuleApproved(tokenId, mockModule1.address)).to.be.true;
      expect(await registry.isModuleApproved(tokenId, mockModule2.address)).to.be.true;

      // Revoke one module
      await registry.connect(agentOwner).setModuleApproval(tokenId, mockModule1.address, false);

      expect(await registry.isModuleApproved(tokenId, mockModule1.address)).to.be.false;
      expect(await registry.isModuleApproved(tokenId, mockModule2.address)).to.be.true;
    });

    it('Should return correct metadata for imprint modules', async function () {
      expect(await registry.getModuleMetadata(tokenId, mockModule1.address)).to.equal(metadata1);
      expect(await registry.getModuleMetadata(tokenId, mockModule2.address)).to.equal(metadata2);
    });

    it('Should return empty array for agent with no registered imprint modules', async function () {
      // Create another agent
      const metadataURI = 'ipfs://QmImprintTest2';
      const extendedMetadata = {
        persona: 'Imprint Agent 2',
        experience: 'Imprint Experience 2',
        voiceHash: 'Imprint Voice Hash 2',
        animationURI: 'ipfs://QmImprintAnimation2',
        vaultURI: 'ipfs://QmImprintVault2',
        vaultHash: ethers.utils.formatBytes32String('imprint-vault-hash-2'),
      };

      await bep007Token["createAgent(address,address,string,(string,string,string,string,string,bytes32))"](
        agentOwner.address,
        mockModule1.address,
        metadataURI,
        extendedMetadata
      );

      const tokenId2 = 2;
      const registeredModules = await registry.getRegisteredModules(tokenId2);
      expect(registeredModules).to.have.length(0);
    });

    it('Should return false for non-approved imprint modules', async function () {
      const nonExistentModule = addrs[0].address;
      expect(await registry.isModuleApproved(tokenId, nonExistentModule)).to.be.false;
    });

    it('Should return empty string for non-existent imprint module metadata', async function () {
      const nonExistentModule = addrs[0].address;
      expect(await registry.getModuleMetadata(tokenId, nonExistentModule)).to.equal("");
    });
  });

  describe('Multiple Agents and Imprint Modules', function () {
    let tokenId1, tokenId2;
    const metadata1 = "Agent 1 Imprint Module metadata - Pattern recognition";
    const metadata2 = "Agent 2 Imprint Module metadata - Behavioral learning";

    beforeEach(async function () {
      tokenId1 = 1; // Already created in main beforeEach

      // Create second agent
      const metadataURI = 'ipfs://QmImprintTest2';
      const extendedMetadata = {
        persona: 'Imprint Agent 2',
        experience: 'Imprint Experience 2',
        voiceHash: 'Imprint Voice Hash 2',
        animationURI: 'ipfs://QmImprintAnimation2',
        vaultURI: 'ipfs://QmImprintVault2',
        vaultHash: ethers.utils.formatBytes32String('imprint-vault-hash-2'),
      };

      await bep007Token["createAgent(address,address,string,(string,string,string,string,string,bytes32))"](
        agentOwner.address,
        mockModule2.address,
        metadataURI,
        extendedMetadata
      );
      tokenId2 = 2;
    });

    it('Should handle imprint module registration for different agents independently', async function () {
      // Register module for agent 1
      const messageHash1 = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'string'],
        [tokenId1, mockModule1.address, metadata1]
      );
      const signature1 = await agentOwner.signMessage(ethers.utils.arrayify(messageHash1));

      await registry.registerModule(tokenId1, mockModule1.address, metadata1, signature1);

      // Register same module for agent 2 with different metadata
      const messageHash2 = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'string'],
        [tokenId2, mockModule1.address, metadata2]
      );
      const signature2 = await agentOwner.signMessage(ethers.utils.arrayify(messageHash2));

      await registry.registerModule(tokenId2, mockModule1.address, metadata2, signature2);

      // Verify independent registration
      expect(await registry.isModuleApproved(tokenId1, mockModule1.address)).to.be.true;
      expect(await registry.isModuleApproved(tokenId2, mockModule1.address)).to.be.true;
      expect(await registry.getModuleMetadata(tokenId1, mockModule1.address)).to.equal(metadata1);
      expect(await registry.getModuleMetadata(tokenId2, mockModule1.address)).to.equal(metadata2);
    });

    it('Should handle approval changes independently for different agents', async function () {
      // Register module for both agents
      const messageHash1 = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'string'],
        [tokenId1, mockModule1.address, metadata1]
      );
      const signature1 = await agentOwner.signMessage(ethers.utils.arrayify(messageHash1));

      const messageHash2 = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'string'],
        [tokenId2, mockModule1.address, metadata2]
      );
      const signature2 = await agentOwner.signMessage(ethers.utils.arrayify(messageHash2));

      await registry.registerModule(tokenId1, mockModule1.address, metadata1, signature1);
      await registry.registerModule(tokenId2, mockModule1.address, metadata2, signature2);

      // Revoke approval for agent 1 only
      await registry.connect(agentOwner).setModuleApproval(tokenId1, mockModule1.address, false);

      // Verify independent approval states
      expect(await registry.isModuleApproved(tokenId1, mockModule1.address)).to.be.false;
      expect(await registry.isModuleApproved(tokenId2, mockModule1.address)).to.be.true;
    });
  });

  describe('Imprint Security and Access Control', function () {
    const tokenId = 1;
    const moduleMetadata = "Security test imprint metadata";

    it('Should prevent signature replay attacks for imprint modules', async function () {
      const messageHash = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'string'],
        [tokenId, mockModule1.address, moduleMetadata]
      );
      const signature = await agentOwner.signMessage(ethers.utils.arrayify(messageHash));

      // First registration should succeed
      await registry.registerModule(tokenId, mockModule1.address, moduleMetadata, signature);

      // Second registration with same signature should fail
      await expect(
        registry.registerModule(tokenId, mockModule1.address, moduleMetadata, signature)
      ).to.be.revertedWith('ExperienceModuleRegistry: module already registered');
    });

    it('Should require exact signature match for imprint module registration', async function () {
      // Create signature with slightly different data
      const messageHash = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'string'],
        [tokenId, mockModule1.address, "different imprint metadata"]
      );
      const signature = await agentOwner.signMessage(ethers.utils.arrayify(messageHash));

      // Try to register with different metadata than signed
      await expect(
        registry.registerModule(tokenId, mockModule1.address, moduleMetadata, signature)
      ).to.be.revertedWith('ExperienceModuleRegistry: invalid signature');
    });

    it('Should handle agent ownership transfer correctly for imprint modules', async function () {
      // Register imprint module
      const messageHash = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'string'],
        [tokenId, mockModule1.address, moduleMetadata]
      );
      const signature = await agentOwner.signMessage(ethers.utils.arrayify(messageHash));

      await registry.registerModule(tokenId, mockModule1.address, moduleMetadata, signature);

      // Transfer agent to new owner
      await bep007Token.connect(agentOwner).transferFrom(agentOwner.address, unauthorized.address, tokenId);

      // Old owner should not be able to manage imprint modules
      await expect(
        registry.connect(agentOwner).setModuleApproval(tokenId, mockModule1.address, false)
      ).to.be.revertedWith('ExperienceModuleRegistry: not token owner');

      // New owner should be able to manage imprint modules
      await registry.connect(unauthorized).setModuleApproval(tokenId, mockModule1.address, false);
      expect(await registry.isModuleApproved(tokenId, mockModule1.address)).to.be.false;
    });
  });

  describe('Imprint Edge Cases', function () {
    const tokenId = 1;

    it('Should handle empty imprint metadata', async function () {
      const emptyMetadata = "";
      const messageHash = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'string'],
        [tokenId, mockModule1.address, emptyMetadata]
      );
      const signature = await agentOwner.signMessage(ethers.utils.arrayify(messageHash));

      await registry.registerModule(tokenId, mockModule1.address, emptyMetadata, signature);

      expect(await registry.getModuleMetadata(tokenId, mockModule1.address)).to.equal(emptyMetadata);
    });

    it('Should handle very long imprint metadata', async function () {
      const longMetadata = "Imprint learning module: " + "a".repeat(1000); // 1000+ character string
      const messageHash = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'string'],
        [tokenId, mockModule1.address, longMetadata]
      );
      const signature = await agentOwner.signMessage(ethers.utils.arrayify(messageHash));

      await registry.registerModule(tokenId, mockModule1.address, longMetadata, signature);

      expect(await registry.getModuleMetadata(tokenId, mockModule1.address)).to.equal(longMetadata);
    });

    it('Should handle special characters in imprint metadata', async function () {
      const specialMetadata = "Imprint test with special chars: !@#$%^&*()_+-={}[]|\\:;\"'<>?,./";
      const messageHash = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'string'],
        [tokenId, mockModule1.address, specialMetadata]
      );
      const signature = await agentOwner.signMessage(ethers.utils.arrayify(messageHash));

      await registry.registerModule(tokenId, mockModule1.address, specialMetadata, signature);

      expect(await registry.getModuleMetadata(tokenId, mockModule1.address)).to.equal(specialMetadata);
    });

    it('Should handle JSON metadata for imprint modules', async function () {
      const jsonMetadata = JSON.stringify({
        name: "Advanced Imprint Module",
        version: "2.1.0",
        capabilities: ["pattern_recognition", "behavioral_learning", "memory_formation"],
        config: {
          learning_rate: 0.01,
          memory_capacity: 10000,
          retention_period: "30d"
        }
      });
      
      const messageHash = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'string'],
        [tokenId, mockModule1.address, jsonMetadata]
      );
      const signature = await agentOwner.signMessage(ethers.utils.arrayify(messageHash));

      await registry.registerModule(tokenId, mockModule1.address, jsonMetadata, signature);

      const retrievedMetadata = await registry.getModuleMetadata(tokenId, mockModule1.address);
      expect(retrievedMetadata).to.equal(jsonMetadata);
      
      // Verify JSON can be parsed
      const parsedMetadata = JSON.parse(retrievedMetadata);
      expect(parsedMetadata.name).to.equal("Advanced Imprint Module");
      expect(parsedMetadata.capabilities).to.include("pattern_recognition");
    });
  });

  describe('Imprint Module Integration Tests', function () {
    const tokenId = 1;

    it('Should support complex imprint module workflows', async function () {
      const moduleMetadata = JSON.stringify({
        type: "imprint_learning",
        algorithm: "neural_pattern_matching",
        version: "3.0.0"
      });

      // Register imprint module
      const messageHash = ethers.utils.solidityKeccak256(
        ['uint256', 'address', 'string'],
        [tokenId, mockModule1.address, moduleMetadata]
      );
      const signature = await agentOwner.signMessage(ethers.utils.arrayify(messageHash));

      await registry.registerModule(tokenId, mockModule1.address, moduleMetadata, signature);

      // Verify registration
      expect(await registry.isModuleApproved(tokenId, mockModule1.address)).to.be.true;

      // Update metadata
      const updatedMetadata = JSON.stringify({
        type: "imprint_learning",
        algorithm: "neural_pattern_matching",
        version: "3.1.0",
        features: ["enhanced_memory", "faster_learning"]
      });

      await registry.connect(agentOwner).updateModuleMetadata(
        tokenId,
        mockModule1.address,
        updatedMetadata
      );

      // Verify update
      expect(await registry.getModuleMetadata(tokenId, mockModule1.address)).to.equal(updatedMetadata);

      // Temporarily revoke and re-approve
      await registry.connect(agentOwner).setModuleApproval(tokenId, mockModule1.address, false);
      expect(await registry.isModuleApproved(tokenId, mockModule1.address)).to.be.false;

      await registry.connect(agentOwner).setModuleApproval(tokenId, mockModule1.address, true);
      expect(await registry.isModuleApproved(tokenId, mockModule1.address)).to.be.true;
    });

    it('Should handle multiple imprint modules per agent efficiently', async function () {
      const modules = [mockModule1.address, mockModule2.address];
      const metadataList = [
        "Primary imprint learning module",
        "Secondary pattern recognition module"
      ];

      // Register multiple modules
      for (let i = 0; i < modules.length; i++) {
        const messageHash = ethers.utils.solidityKeccak256(
          ['uint256', 'address', 'string'],
          [tokenId, modules[i], metadataList[i]]
        );
        const signature = await agentOwner.signMessage(ethers.utils.arrayify(messageHash));

        await registry.registerModule(tokenId, modules[i], metadataList[i], signature);
      }

      // Verify all modules are registered
      const registeredModules = await registry.getRegisteredModules(tokenId);
      expect(registeredModules).to.have.length(2);
      expect(registeredModules).to.include.members(modules);

      // Verify all modules are approved
      for (const module of modules) {
        expect(await registry.isModuleApproved(tokenId, module)).to.be.true;
      }

      // Verify metadata for all modules
      for (let i = 0; i < modules.length; i++) {
        expect(await registry.getModuleMetadata(tokenId, modules[i])).to.equal(metadataList[i]);
      }
    });
  });
});
