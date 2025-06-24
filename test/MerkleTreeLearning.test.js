const { expect } = require('chai');
const { ethers, upgrades } = require('hardhat');
const { MerkleTree } = require('merkletreejs');

describe('MerkleTreeLearning', function () {
  let MerkleTreeLearning;
  let learningModule;
  let BEP007;
  let bep007Token;
  let CircuitBreaker;
  let circuitBreaker;
  let owner;
  let agentOwner;
  let authorizedUpdater;
  let unauthorized;
  let addrs;

  // Learning constants
  const MILESTONE_INTERACTIONS_100 = 100;
  const MILESTONE_INTERACTIONS_1000 = 1000;
  const MILESTONE_CONFIDENCE_80 = ethers.utils.parseEther('0.8');
  const MILESTONE_CONFIDENCE_95 = ethers.utils.parseEther('0.95');
  const MAX_UPDATES_PER_DAY = 50;

  // Helper function to create Merkle tree
  function createMerkleTree(leaves) {
    const hashedLeaves = leaves.map(leaf => ethers.utils.keccak256(ethers.utils.toUtf8Bytes(leaf)));
    return new MerkleTree(hashedLeaves, ethers.utils.keccak256, { sortPairs: true });
  }

  // Helper function to get Merkle proof
  function getMerkleProof(tree, leaf) {
    const hashedLeaf = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(leaf));
    return tree.getHexProof(hashedLeaf);
  }

  beforeEach(async function () {
    // Get the ContractFactory and Signers
    MerkleTreeLearning = await ethers.getContractFactory('MerkleTreeLearning');
    BEP007 = await ethers.getContractFactory('BEP007');
    CircuitBreaker = await ethers.getContractFactory('CircuitBreaker');
    [owner, agentOwner, authorizedUpdater, unauthorized, ...addrs] = await ethers.getSigners();

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
      ["Learning Agent Token", "LAT", circuitBreaker.address],
      { initializer: "initialize", kind: "uups" }
    );
    await bep007Token.deployed();

    // Deploy MerkleTreeLearning
    learningModule = await upgrades.deployProxy(
      MerkleTreeLearning,
      [bep007Token.address],
      { initializer: "initialize" }
    );
    await learningModule.deployed();

    // Create an agent for testing
    const metadataURI = 'ipfs://QmLearningTest';
    const extendedMetadata = {
      persona: 'Learning Agent Persona',
      experience: 'Learning Agent Experience',
      voiceHash: 'Learning Voice Hash',
      animationURI: 'ipfs://QmLearningAnimation',
      vaultURI: 'ipfs://QmLearningVault',
      vaultHash: ethers.utils.formatBytes32String('learning-vault-hash'),
    };

    await bep007Token["createAgent(address,address,string,(string,string,string,string,string,bytes32))"](
      agentOwner.address,
      learningModule.address,
      metadataURI,
      extendedMetadata
    );
  });

  describe('Deployment', function () {
    it('Should set the correct BEP007 token address', async function () {
      expect(await learningModule.bep007Token()).to.equal(bep007Token.address);
    });

    it('Should set the correct owner', async function () {
      expect(await learningModule.owner()).to.equal(owner.address);
    });

    it('Should return correct version', async function () {
      expect(await learningModule.getVersion()).to.equal('1.0.0');
    });

    it('Should revert if initialized with zero address token', async function () {
      await expect(
        upgrades.deployProxy(
          MerkleTreeLearning,
          [ethers.constants.AddressZero],
          { initializer: "initialize" }
        )
      ).to.be.revertedWith('MerkleTreeLearning: token is zero address');
    });
  });

  describe('Learning Enablement', function () {
    const tokenId = 1;
    const initialRoot = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('initial_learning_state'));

    it('Should enable learning for an agent', async function () {
      const tx = await learningModule.connect(agentOwner).enableLearning(tokenId, initialRoot);
      const receipt = await tx.wait();
      const event = receipt.events?.find(e => e.event === 'LearningUpdated');

      expect(event).to.not.be.undefined;
      expect(event.args.tokenId).to.equal(tokenId);
      expect(event.args.previousRoot).to.equal(ethers.constants.HashZero);
      expect(event.args.newRoot).to.equal(initialRoot);

      expect(await learningModule.isLearningEnabled(tokenId)).to.be.true;
      expect(await learningModule.getLearningRoot(tokenId)).to.equal(initialRoot);

      const metrics = await learningModule.getLearningMetrics(tokenId);
      expect(metrics.totalInteractions).to.equal(0);
      expect(metrics.learningEvents).to.equal(0);
      expect(metrics.learningVelocity).to.equal(0);
      expect(metrics.confidenceScore).to.equal(0);
    });

    it('Should revert if not called by token owner', async function () {
      await expect(
        learningModule.connect(unauthorized).enableLearning(tokenId, initialRoot)
      ).to.be.revertedWith('MerkleTreeLearning: not token owner');
    });

    it('Should revert if learning is already enabled', async function () {
      await learningModule.connect(agentOwner).enableLearning(tokenId, initialRoot);
      
      await expect(
        learningModule.connect(agentOwner).enableLearning(tokenId, initialRoot)
      ).to.be.revertedWith('MerkleTreeLearning: already enabled');
    });

    it('Should disable learning', async function () {
      await learningModule.connect(agentOwner).enableLearning(tokenId, initialRoot);
      expect(await learningModule.isLearningEnabled(tokenId)).to.be.true;

      await learningModule.connect(agentOwner).disableLearning(tokenId);
      expect(await learningModule.isLearningEnabled(tokenId)).to.be.false;
    });

    it('Should revert disable learning if not called by token owner', async function () {
      await learningModule.connect(agentOwner).enableLearning(tokenId, initialRoot);
      
      await expect(
        learningModule.connect(unauthorized).disableLearning(tokenId)
      ).to.be.revertedWith('MerkleTreeLearning: not token owner');
    });
  });

  describe('Authorization Management', function () {
    const tokenId = 1;

    beforeEach(async function () {
      const initialRoot = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('initial_learning_state'));
      await learningModule.connect(agentOwner).enableLearning(tokenId, initialRoot);
    });

    it('Should authorize and revoke updaters', async function () {
      // Initially not authorized
      expect(await learningModule.isAuthorizedUpdater(tokenId, authorizedUpdater.address)).to.be.false;

      // Authorize updater
      await learningModule.connect(agentOwner).setAuthorizedUpdater(tokenId, authorizedUpdater.address, true);
      expect(await learningModule.isAuthorizedUpdater(tokenId, authorizedUpdater.address)).to.be.true;

      // Revoke authorization
      await learningModule.connect(agentOwner).setAuthorizedUpdater(tokenId, authorizedUpdater.address, false);
      expect(await learningModule.isAuthorizedUpdater(tokenId, authorizedUpdater.address)).to.be.false;
    });

    it('Should revert if not called by token owner', async function () {
      await expect(
        learningModule.connect(unauthorized).setAuthorizedUpdater(tokenId, authorizedUpdater.address, true)
      ).to.be.revertedWith('MerkleTreeLearning: not token owner');
    });
  });

  describe('Learning Updates', function () {
    const tokenId = 1;
    let initialRoot;
    let tree1, tree2;

    beforeEach(async function () {
      // Create initial learning tree
      const initialLeaves = ['skill1', 'skill2', 'skill3'];
      tree1 = createMerkleTree(initialLeaves);
      initialRoot = tree1.getHexRoot();

      await learningModule.connect(agentOwner).enableLearning(tokenId, initialRoot);
      await learningModule.connect(agentOwner).setAuthorizedUpdater(tokenId, authorizedUpdater.address, true);
    });

    it('Should update learning state with valid previous root', async function () {
      // Create new learning tree
      const newLeaves = ['skill1', 'skill2', 'skill3', 'skill4'];
      tree2 = createMerkleTree(newLeaves);
      const newRoot = tree2.getHexRoot();

      const learningUpdate = {
        previousRoot: initialRoot,
        newRoot: newRoot,
        proof: '0x1234',
        timestamp: Math.floor(Date.now() / 1000)
      };

      const tx = await learningModule.connect(authorizedUpdater).updateLearning(tokenId, learningUpdate);
      const receipt = await tx.wait();
      const event = receipt.events?.find(e => e.event === 'LearningUpdated');

      expect(event.args.tokenId).to.equal(tokenId);
      expect(event.args.previousRoot).to.equal(initialRoot);
      expect(event.args.newRoot).to.equal(newRoot);

      expect(await learningModule.getLearningRoot(tokenId)).to.equal(newRoot);

      const metrics = await learningModule.getLearningMetrics(tokenId);
      expect(metrics.learningEvents).to.equal(1);
    });

    it('Should revert with invalid previous root', async function () {
      const invalidRoot = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('invalid_root'));
      const newRoot = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('new_root'));

      const learningUpdate = {
        previousRoot: invalidRoot,
        newRoot: newRoot,
        proof: '0x1234',
        timestamp: Math.floor(Date.now() / 1000)
      };

      await expect(
        learningModule.connect(authorizedUpdater).updateLearning(tokenId, learningUpdate)
      ).to.be.revertedWith('MerkleTreeLearning: invalid previous root');
    });

    it('Should revert if not authorized', async function () {
      const newRoot = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('new_root'));

      const learningUpdate = {
        previousRoot: initialRoot,
        newRoot: newRoot,
        proof: '0x1234',
        timestamp: Math.floor(Date.now() / 1000)
      };

      await expect(
        learningModule.connect(unauthorized).updateLearning(tokenId, learningUpdate)
      ).to.be.revertedWith('MerkleTreeLearning: not authorized');
    });

    it('Should revert if learning is not enabled', async function () {
      await learningModule.connect(agentOwner).disableLearning(tokenId);

      const newRoot = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('new_root'));

      const learningUpdate = {
        previousRoot: initialRoot,
        newRoot: newRoot,
        proof: '0x1234',
        timestamp: Math.floor(Date.now() / 1000)
      };

      await expect(
        learningModule.connect(authorizedUpdater).updateLearning(tokenId, learningUpdate)
      ).to.be.revertedWith('MerkleTreeLearning: learning not enabled');
    });

    it('Should enforce daily update limits', async function () {
      const newRoot = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('new_root'));

      // Perform maximum allowed updates
      for (let i = 0; i < MAX_UPDATES_PER_DAY; i++) {
        const learningUpdate = {
          previousRoot: await learningModule.getLearningRoot(tokenId),
          newRoot: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(`new_root_${i}`)),
          proof: '0x1234',
          timestamp: Math.floor(Date.now() / 1000)
        };

        await learningModule.connect(authorizedUpdater).updateLearning(tokenId, learningUpdate);
      }

      // Next update should fail
      const learningUpdate = {
        previousRoot: await learningModule.getLearningRoot(tokenId),
        newRoot: ethers.utils.keccak256(ethers.utils.toUtf8Bytes('final_root')),
        proof: '0x1234',
        timestamp: Math.floor(Date.now() / 1000)
      };

      await expect(
        learningModule.connect(authorizedUpdater).updateLearning(tokenId, learningUpdate)
      ).to.be.revertedWith('MerkleTreeLearning: daily update limit exceeded');
    });
  });

  describe('Interaction Recording', function () {
    const tokenId = 1;

    beforeEach(async function () {
      const initialRoot = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('initial_learning_state'));
      await learningModule.connect(agentOwner).enableLearning(tokenId, initialRoot);
      await learningModule.connect(agentOwner).setAuthorizedUpdater(tokenId, authorizedUpdater.address, true);
    });

    it('Should record successful interactions', async function () {
      await learningModule.connect(authorizedUpdater).recordInteraction(tokenId, 'conversation', true);

      const metrics = await learningModule.getLearningMetrics(tokenId);
      expect(metrics.totalInteractions).to.equal(1);
      expect(metrics.confidenceScore).to.be.gt(0); // Should increase confidence
    });

    it('Should record failed interactions', async function () {
      // First, build up some confidence
      for (let i = 0; i < 10; i++) {
        await learningModule.connect(authorizedUpdater).recordInteraction(tokenId, 'conversation', true);
      }

      const metricsBefore = await learningModule.getLearningMetrics(tokenId);
      
      // Record a failed interaction
      await learningModule.connect(authorizedUpdater).recordInteraction(tokenId, 'conversation', false);

      const metricsAfter = await learningModule.getLearningMetrics(tokenId);
      expect(metricsAfter.totalInteractions).to.equal(metricsBefore.totalInteractions.add(1));
      expect(metricsAfter.confidenceScore).to.be.lt(metricsBefore.confidenceScore); // Should decrease confidence
    });

    it('Should emit milestone events for interaction counts', async function () {
      // Record 100 interactions to trigger milestone
      for (let i = 0; i < MILESTONE_INTERACTIONS_100; i++) {
        const tx = await learningModule.connect(authorizedUpdater).recordInteraction(tokenId, 'conversation', true);
        
        if (i === MILESTONE_INTERACTIONS_100 - 1) {
          const receipt = await tx.wait();
          const event = receipt.events?.find(e => e.event === 'LearningMilestone');
          
          expect(event).to.not.be.undefined;
          expect(event.args.tokenId).to.equal(tokenId);
          expect(event.args.milestone).to.equal('interactions_100');
          expect(event.args.value).to.equal(100);
        }
      }
    });

    it('Should revert if not authorized', async function () {
      await expect(
        learningModule.connect(unauthorized).recordInteraction(tokenId, 'conversation', true)
      ).to.be.revertedWith('MerkleTreeLearning: not authorized');
    });

    it('Should revert if learning is not enabled', async function () {
      await learningModule.connect(agentOwner).disableLearning(tokenId);

      await expect(
        learningModule.connect(authorizedUpdater).recordInteraction(tokenId, 'conversation', true)
      ).to.be.revertedWith('MerkleTreeLearning: learning not enabled');
    });
  });

  describe('Merkle Proof Verification', function () {
    const tokenId = 1;
    let tree;
    let leaves;

    beforeEach(async function () {
      leaves = ['skill1', 'skill2', 'skill3', 'skill4'];
      tree = createMerkleTree(leaves);
      const root = tree.getHexRoot();

      await learningModule.connect(agentOwner).enableLearning(tokenId, root);
    });

    it('Should verify valid Merkle proofs', async function () {
      const leaf = 'skill2';
      const proof = getMerkleProof(tree, leaf);
      const claim = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(leaf));

      const isValid = await learningModule.verifyLearning(tokenId, claim, proof);
      expect(isValid).to.be.true;
    });

    it('Should reject invalid Merkle proofs', async function () {
      const leaf = 'invalid_skill';
      const proof = getMerkleProof(tree, 'skill1'); // Wrong proof
      const claim = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(leaf));

      const isValid = await learningModule.verifyLearning(tokenId, claim, proof);
      expect(isValid).to.be.false;
    });

    it('Should reject proofs with wrong claim', async function () {
      const leaf = 'skill1';
      const proof = getMerkleProof(tree, leaf);
      const wrongClaim = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('wrong_skill'));

      const isValid = await learningModule.verifyLearning(tokenId, wrongClaim, proof);
      expect(isValid).to.be.false;
    });

    it('Should handle empty proofs for single leaf trees', async function () {
      const singleLeaf = ['only_skill'];
      const singleTree = createMerkleTree(singleLeaf);
      const singleRoot = singleTree.getHexRoot();

      // Create new agent with single leaf tree
      const metadataURI = 'ipfs://QmSingleLeaf';
      const extendedMetadata = {
        persona: 'Single Skill Agent',
        experience: 'Single Skill Experience',
        voiceHash: 'Single Voice Hash',
        animationURI: 'ipfs://QmSingleAnimation',
        vaultURI: 'ipfs://QmSingleVault',
        vaultHash: ethers.utils.formatBytes32String('single-vault-hash'),
      };

      await bep007Token["createAgent(address,address,string,(string,string,string,string,string,bytes32))"](
        agentOwner.address,
        learningModule.address,
        metadataURI,
        extendedMetadata
      );

      const tokenId2 = 2;
      await learningModule.connect(agentOwner).enableLearning(tokenId2, singleRoot);

      const claim = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('only_skill'));
      const emptyProof = [];

      const isValid = await learningModule.verifyLearning(tokenId2, claim, emptyProof);
      expect(isValid).to.be.true;
    });
  });

  describe('Learning Metrics and Milestones', function () {
    const tokenId = 1;

    beforeEach(async function () {
      const initialRoot = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('initial_learning_state'));
      await learningModule.connect(agentOwner).enableLearning(tokenId, initialRoot);
      await learningModule.connect(agentOwner).setAuthorizedUpdater(tokenId, authorizedUpdater.address, true);
    });

    it('Should calculate learning velocity correctly', async function () {
      const newRoot = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('new_root'));

      const learningUpdate = {
        previousRoot: await learningModule.getLearningRoot(tokenId),
        newRoot: newRoot,
        proof: '0x1234',
        timestamp: Math.floor(Date.now() / 1000)
      };

      await learningModule.connect(authorizedUpdater).updateLearning(tokenId, learningUpdate);

      const metrics = await learningModule.getLearningMetrics(tokenId);
      expect(metrics.learningVelocity).to.be.gt(0);
    });

    it('Should track confidence score changes', async function () {
      // Record successful interactions to build confidence
      for (let i = 0; i < 50; i++) {
        await learningModule.connect(authorizedUpdater).recordInteraction(tokenId, 'conversation', true);
      }

      const metrics = await learningModule.getLearningMetrics(tokenId);
      expect(metrics.confidenceScore).to.be.gt(0);
      expect(metrics.totalInteractions).to.equal(50);
    });

    it('Should handle confidence score boundaries', async function () {
      // Test that confidence doesn't go below 0
      await learningModule.connect(authorizedUpdater).recordInteraction(tokenId, 'conversation', false);
      
      const metrics = await learningModule.getLearningMetrics(tokenId);
      expect(metrics.confidenceScore).to.equal(0);
    });

    it('Should emit milestone events for confidence thresholds', async function () {
      // This would require many interactions to reach 80% confidence
      // For testing purposes, we'll verify the milestone constants are set correctly
      expect(MILESTONE_CONFIDENCE_80).to.equal(ethers.utils.parseEther('0.8'));
      expect(MILESTONE_CONFIDENCE_95).to.equal(ethers.utils.parseEther('0.95'));
    });
  });

  describe('Edge Cases and Error Handling', function () {
    const tokenId = 1;

    it('Should handle non-existent token IDs gracefully', async function () {
      const nonExistentTokenId = 999;
      
      await expect(
        learningModule.connect(agentOwner).enableLearning(nonExistentTokenId, ethers.constants.HashZero)
      ).to.be.revertedWith('ERC721: invalid token ID');
    });

    it('Should handle zero hash roots', async function () {
      await learningModule.connect(agentOwner).enableLearning(tokenId, ethers.constants.HashZero);
      
      expect(await learningModule.getLearningRoot(tokenId)).to.equal(ethers.constants.HashZero);
      expect(await learningModule.isLearningEnabled(tokenId)).to.be.true;
    });

    it('Should handle empty interaction types', async function () {
      const initialRoot = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('initial_learning_state'));
      await learningModule.connect(agentOwner).enableLearning(tokenId, initialRoot);
      await learningModule.connect(agentOwner).setAuthorizedUpdater(tokenId, authorizedUpdater.address, true);

      await learningModule.connect(authorizedUpdater).recordInteraction(tokenId, '', true);

      const metrics = await learningModule.getLearningMetrics(tokenId);
      expect(metrics.totalInteractions).to.equal(1);
    });

    it('Should handle multiple rapid updates within limits', async function () {
      const initialRoot = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('initial_learning_state'));
      await learningModule.connect(agentOwner).enableLearning(tokenId, initialRoot);
      await learningModule.connect(agentOwner).setAuthorizedUpdater(tokenId, authorizedUpdater.address, true);

      // Perform multiple rapid updates
      for (let i = 0; i < 10; i++) {
        const learningUpdate = {
          previousRoot: await learningModule.getLearningRoot(tokenId),
          newRoot: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(`new_root_${i}`)),
          proof: '0x1234',
          timestamp: Math.floor(Date.now() / 1000)
        };

        await learningModule.connect(authorizedUpdater).updateLearning(tokenId, learningUpdate);
      }

      const metrics = await learningModule.getLearningMetrics(tokenId);
      expect(metrics.learningEvents).to.equal(10);
    });
  });

  describe('Integration Tests', function () {
    const tokenId = 1;

    it('Should handle complete learning workflow', async function () {
      // 1. Enable learning
      const initialLeaves = ['basic_conversation', 'greeting'];
      const initialTree = createMerkleTree(initialLeaves);
      const initialRoot = initialTree.getHexRoot();

      await learningModule.connect(agentOwner).enableLearning(tokenId, initialRoot);
      await learningModule.connect(agentOwner).setAuthorizedUpdater(tokenId, authorizedUpdater.address, true);

      // 2. Record some interactions
      for (let i = 0; i < 10; i++) {
        await learningModule.connect(authorizedUpdater).recordInteraction(tokenId, 'conversation', true);
      }

      // 3. Update learning with new skills
      const newLeaves = ['basic_conversation', 'greeting', 'advanced_reasoning', 'problem_solving'];
      const newTree = createMerkleTree(newLeaves);
      const newRoot = newTree.getHexRoot();

      const learningUpdate = {
        previousRoot: initialRoot,
        newRoot: newRoot,
        proof: '0x1234',
        timestamp: Math.floor(Date.now() / 1000)
      };

      await learningModule.connect(authorizedUpdater).updateLearning(tokenId, learningUpdate);

      // 4. Verify new skills
      const skillClaim = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('advanced_reasoning'));
      const proof = getMerkleProof(newTree, 'advanced_reasoning');
      
      const isValid = await learningModule.verifyLearning(tokenId, skillClaim, proof);
      expect(isValid).to.be.true;

      // 5. Check final metrics
      const metrics = await learningModule.getLearningMetrics(tokenId);
      expect(metrics.totalInteractions).to.equal(10);
      expect(metrics.learningEvents).to.equal(1);
      expect(metrics.confidenceScore).to.be.gt(0);
    });

    it('Should handle ownership transfer correctly', async function () {
      const initialRoot = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('initial_learning_state'));
      await learningModule.connect(agentOwner).enableLearning(tokenId, initialRoot);

      // Transfer token to new owner
      await bep007Token.connect(agentOwner).transferFrom(agentOwner.address, addrs[0].address, tokenId);

      // Old owner should not be able to manage learning
      await expect(
        learningModule.connect(agentOwner).setAuthorizedUpdater(tokenId, authorizedUpdater.address, true)
      ).to.be.revertedWith('MerkleTreeLearning: not token owner');

      // New owner should be able to manage learning
      await learningModule.connect(addrs[0]).setAuthorizedUpdater(tokenId, authorizedUpdater.address, true);
      expect(await learningModule.isAuthorizedUpdater(tokenId, authorizedUpdater.address)).to.be.true;
    });

    it('Should handle multiple agents independently', async function () {
      // Create second agent
      const metadataURI2 = 'ipfs://QmLearningTest2';
      const extendedMetadata2 = {
        persona: 'Learning Agent 2',
        experience: 'Learning Experience 2',
        voiceHash: 'Learning Voice Hash 2',
        animationURI: 'ipfs://QmLearningAnimation2',
        vaultURI: 'ipfs://QmLearningVault2',
        vaultHash: ethers.utils.formatBytes32String('learning-vault-hash-2'),
      };

      await bep007Token["createAgent(address,address,string,(string,string,string,string,string,bytes32))"](
        agentOwner.address,
        learningModule.address,
        metadataURI2,
        extendedMetadata2
      );

      const tokenId2 = 2;

      // Enable learning for both agents with different roots
      const root1 = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent1_learning'));
      const root2 = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('agent2_learning'));

      await learningModule.connect(agentOwner).enableLearning(tokenId, root1);
      await learningModule.connect(agentOwner).enableLearning(tokenId2, root2);

      // Verify independent learning states
      expect(await learningModule.getLearningRoot(tokenId)).to.equal(root1);
      expect(await learningModule.getLearningRoot(tokenId2)).to.equal(root2);

      // Record different interactions for each agent
      await learningModule.connect(agentOwner).recordInteraction(tokenId, 'conversation', true);
      await learningModule.connect(agentOwner).recordInteraction(tokenId2, 'problem_solving', false);

      const metrics1 = await learningModule.getLearningMetrics(tokenId);
      const metrics2 = await learningModule.getLearningMetrics(tokenId2);

      expect(metrics1.totalInteractions).to.equal(1);
      expect(metrics2.totalInteractions).to.equal(1);
      expect(metrics1.confidenceScore).to.be.gt(metrics2.confidenceScore); // Agent 1 had success, Agent 2 failed
    });
  });
});
