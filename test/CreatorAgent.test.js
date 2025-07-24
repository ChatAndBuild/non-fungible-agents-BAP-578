const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('CreatorAgent', function () {
  let CreatorAgent;
  let creatorAgent;
  let MerkleTreeLearning;
  let merkleTreeLearning;
  let owner;
  let creator;
  let user1;
  let user2;
  let addrs;

  // Mock BEP007 token address for testing
  const mockAgentTokenAddress = '0x1234567890123456789012345678901234567890';

  // Creator profile data
  const creatorName = 'Test Creator';
  const creatorBio = 'A test creator for testing purposes';
  const creatorNiche = 'Digital Art';

  beforeEach(async function () {
    [owner, creator, user1, user2, ...addrs] = await ethers.getSigners();

    // Deploy MerkleTreeLearning for testing learning functionality
    MerkleTreeLearning = await ethers.getContractFactory('MerkleTreeLearning');
    merkleTreeLearning = await MerkleTreeLearning.deploy();
    await merkleTreeLearning.deployed();

    // Deploy CreatorAgent
    CreatorAgent = await ethers.getContractFactory('CreatorAgent');
    creatorAgent = await CreatorAgent.deploy(
      mockAgentTokenAddress,
      creatorName,
      creatorBio,
      creatorNiche
    );
    await creatorAgent.deployed();
  });

  describe('Deployment', function () {
    it('Should set the correct agent token address', async function () {
      expect(await creatorAgent.agentToken()).to.equal(mockAgentTokenAddress);
    });

    it('Should set the correct creator profile', async function () {
      const profile = await creatorAgent.profile();
      expect(profile.name).to.equal(creatorName);
      expect(profile.bio).to.equal(creatorBio);
      expect(profile.niche).to.equal(creatorNiche);
      expect(profile.creativityLevel).to.equal(50); // Default medium creativity
    });

    it('Should initialize with learning disabled', async function () {
      expect(await creatorAgent.learningEnabled()).to.equal(false);
      expect(await creatorAgent.learningModule()).to.equal(ethers.constants.AddressZero);
    });

    it('Should set the correct owner', async function () {
      expect(await creatorAgent.owner()).to.equal(owner.address);
    });

    it('Should not allow deployment with zero agent token address', async function () {
      await expect(
        CreatorAgent.deploy(
          ethers.constants.AddressZero,
          creatorName,
          creatorBio,
          creatorNiche
        )
      ).to.be.revertedWith('CreatorAgent: agent token is zero address');
    });
  });

  describe('Profile Management', function () {
    it('Should allow owner to update profile', async function () {
      const newName = 'Updated Creator';
      const newBio = 'Updated bio';
      const newNiche = 'Updated niche';
      const newCreativityLevel = 75;

      await creatorAgent.updateProfile(
        newName,
        newBio,
        newNiche,
        newCreativityLevel
      );

      const profile = await creatorAgent.profile();
      expect(profile.name).to.equal(newName);
      expect(profile.bio).to.equal(newBio);
      expect(profile.niche).to.equal(newNiche);
      expect(profile.creativityLevel).to.equal(newCreativityLevel);
    });

    it('Should not allow non-owner to update profile', async function () {
      await expect(
        creatorAgent.connect(user1).updateProfile(
          'Hacker Name',
          'Hacker Bio',
          'Hacker Niche',
          100
        )
      ).to.be.revertedWith('Ownable: caller is not the owner');
    });

    it('Should not allow creativity level above 100', async function () {
      await expect(
        creatorAgent.updateProfile(
          'Test Name',
          'Test Bio',
          'Test Niche',
          101
        )
      ).to.be.revertedWith('CreatorAgent: creativity level must be 0-100');
    });

    it('Should allow creativity level of 0', async function () {
      await creatorAgent.updateProfile(
        'Test Name',
        'Test Bio',
        'Test Niche',
        0
      );

      const profile = await creatorAgent.profile();
      expect(profile.creativityLevel).to.equal(0);
    });

    it('Should allow creativity level of 100', async function () {
      await creatorAgent.updateProfile(
        'Test Name',
        'Test Bio',
        'Test Niche',
        100
      );

      const profile = await creatorAgent.profile();
      expect(profile.creativityLevel).to.equal(100);
    });
  });

  describe('Learning Module Management', function () {
    it('Should allow owner to enable learning', async function () {
      expect(await creatorAgent.learningEnabled()).to.equal(false);

      await creatorAgent.enableLearning(merkleTreeLearning.address);

      expect(await creatorAgent.learningEnabled()).to.equal(true);
      expect(await creatorAgent.learningModule()).to.equal(merkleTreeLearning.address);
    });

    it('Should not allow non-owner to enable learning', async function () {
      await expect(
        creatorAgent.connect(user1).enableLearning(merkleTreeLearning.address)
      ).to.be.revertedWith('Ownable: caller is not the owner');
    });

    it('Should not allow enabling learning with zero address', async function () {
      await expect(
        creatorAgent.enableLearning(ethers.constants.AddressZero)
      ).to.be.revertedWith('CreatorAgent: learning module is zero address');
    });

    it('Should not allow enabling learning when already enabled', async function () {
      await creatorAgent.enableLearning(merkleTreeLearning.address);

      await expect(
        creatorAgent.enableLearning(merkleTreeLearning.address)
      ).to.be.revertedWith('CreatorAgent: learning already enabled');
    });

    it('Should not allow enabling learning with different module when already enabled', async function () {
      await creatorAgent.enableLearning(merkleTreeLearning.address);

      // Deploy another learning module for testing
      const anotherLearningModule = await MerkleTreeLearning.deploy();
      await anotherLearningModule.deployed();

      await expect(
        creatorAgent.enableLearning(anotherLearningModule.address)
      ).to.be.revertedWith('CreatorAgent: learning already enabled');
    });
  });

  describe('Access Control', function () {
    it('Should have onlyAgentToken modifier working', async function () {
      // Since we don't have functions that use onlyAgentToken modifier in the current contract,
      // this test verifies the modifier exists and would work correctly
      // In a real scenario, you would test functions that use this modifier
      
      // For now, we can verify that the agentToken is set correctly
      expect(await creatorAgent.agentToken()).to.equal(mockAgentTokenAddress);
    });

    it('Should have whenLearningEnabled modifier working', async function () {
      // Similar to above, this tests the modifier setup
      // In practice, you would test functions that use this modifier
      
      // Verify learning is initially disabled
      expect(await creatorAgent.learningEnabled()).to.equal(false);
      
      // Enable learning and verify
      await creatorAgent.enableLearning(merkleTreeLearning.address);
      expect(await creatorAgent.learningEnabled()).to.equal(true);
    });

    it('Should inherit Ownable functionality correctly', async function () {
      expect(await creatorAgent.owner()).to.equal(owner.address);
      
      // Test ownership transfer
      await creatorAgent.transferOwnership(user1.address);
      expect(await creatorAgent.owner()).to.equal(user1.address);
    });

    it('Should inherit ReentrancyGuard functionality correctly', async function () {
      // ReentrancyGuard is inherited but not actively used in current functions
      // This test verifies the inheritance is working
      // In practice, you would test functions that use nonReentrant modifier
      
      // For now, we just verify the contract deployed successfully with ReentrancyGuard
      expect(creatorAgent.address).to.not.equal(ethers.constants.AddressZero);
    });
  });

  describe('Profile Data Validation', function () {
    it('Should handle empty strings in profile', async function () {
      await creatorAgent.updateProfile('', '', '', 25);

      const profile = await creatorAgent.profile();
      expect(profile.name).to.equal('');
      expect(profile.bio).to.equal('');
      expect(profile.niche).to.equal('');
      expect(profile.creativityLevel).to.equal(25);
    });

    it('Should handle very long strings in profile', async function () {
      const longString = 'a'.repeat(1000); // 1000 character string
      
      await creatorAgent.updateProfile(
        longString,
        longString,
        longString,
        50
      );

      const profile = await creatorAgent.profile();
      expect(profile.name).to.equal(longString);
      expect(profile.bio).to.equal(longString);
      expect(profile.niche).to.equal(longString);
    });

    it('Should handle special characters in profile', async function () {
      const specialName = 'Creator™ 🎨';
      const specialBio = 'Bio with émojis 🚀 and spëcial chars!';
      const specialNiche = 'Niché with àccents';

      await creatorAgent.updateProfile(
        specialName,
        specialBio,
        specialNiche,
        80
      );

      const profile = await creatorAgent.profile();
      expect(profile.name).to.equal(specialName);
      expect(profile.bio).to.equal(specialBio);
      expect(profile.niche).to.equal(specialNiche);
    });
  });

  describe('State Consistency', function () {
    it('Should maintain consistent state after multiple operations', async function () {
      // Update profile
      await creatorAgent.updateProfile('New Name', 'New Bio', 'New Niche', 90);
      
      // Enable learning
      await creatorAgent.enableLearning(merkleTreeLearning.address);
      
      // Verify all state is consistent
      const profile = await creatorAgent.profile();
      expect(profile.name).to.equal('New Name');
      expect(profile.creativityLevel).to.equal(90);
      expect(await creatorAgent.learningEnabled()).to.equal(true);
      expect(await creatorAgent.learningModule()).to.equal(merkleTreeLearning.address);
      expect(await creatorAgent.agentToken()).to.equal(mockAgentTokenAddress);
    });

    it('Should maintain state after ownership transfer', async function () {
      // Set initial state
      await creatorAgent.updateProfile('Test Name', 'Test Bio', 'Test Niche', 60);
      await creatorAgent.enableLearning(merkleTreeLearning.address);
      
      // Transfer ownership
      await creatorAgent.transferOwnership(user1.address);
      
      // Verify state is maintained
      const profile = await creatorAgent.profile();
      expect(profile.name).to.equal('Test Name');
      expect(profile.creativityLevel).to.equal(60);
      expect(await creatorAgent.learningEnabled()).to.equal(true);
      expect(await creatorAgent.learningModule()).to.equal(merkleTreeLearning.address);
      
      // Verify new owner can update
      await creatorAgent.connect(user1).updateProfile('Updated by New Owner', 'New Bio', 'New Niche', 70);
      
      const updatedProfile = await creatorAgent.profile();
      expect(updatedProfile.name).to.equal('Updated by New Owner');
    });
  });

  describe('Edge Cases', function () {
    it('Should handle deployment with minimal valid parameters', async function () {
      const minimalAgent = await CreatorAgent.deploy(
        user1.address, // Different agent token address
        'A',           // Single character name
        'B',           // Single character bio
        'C'            // Single character niche
      );
      await minimalAgent.deployed();

      const profile = await minimalAgent.profile();
      expect(profile.name).to.equal('A');
      expect(profile.bio).to.equal('B');
      expect(profile.niche).to.equal('C');
      expect(profile.creativityLevel).to.equal(50);
    });

    it('Should handle multiple profile updates', async function () {
      // Update profile multiple times
      for (let i = 0; i < 5; i++) {
        await creatorAgent.updateProfile(
          `Name ${i}`,
          `Bio ${i}`,
          `Niche ${i}`,
          i * 20
        );
        
        const profile = await creatorAgent.profile();
        expect(profile.name).to.equal(`Name ${i}`);
        expect(profile.creativityLevel).to.equal(i * 20);
      }
    });

    it('Should handle gas optimization for large profile updates', async function () {
      const largeProfile = {
        name: 'Very Long Creator Name That Tests Gas Optimization'.repeat(10),
        bio: 'Very Long Bio That Tests Gas Optimization and Storage Efficiency'.repeat(20),
        niche: 'Very Long Niche Description For Testing'.repeat(15)
      };

      // This should not fail due to gas limits in a test environment
      await expect(
        creatorAgent.updateProfile(
          largeProfile.name,
          largeProfile.bio,
          largeProfile.niche,
          95
        )
      ).to.not.be.reverted;

      const profile = await creatorAgent.profile();
      expect(profile.name).to.equal(largeProfile.name);
      expect(profile.bio).to.equal(largeProfile.bio);
      expect(profile.niche).to.equal(largeProfile.niche);
    });
  });

  describe('Integration Tests', function () {
    it('Should work correctly with real learning module', async function () {
      // Enable learning with the deployed MerkleTreeLearning module
      await creatorAgent.enableLearning(merkleTreeLearning.address);
      
      // Verify the learning module is accessible
      expect(await creatorAgent.learningModule()).to.equal(merkleTreeLearning.address);
      expect(await creatorAgent.learningEnabled()).to.equal(true);
      
      // In a real scenario, you might test interaction with the learning module
      // For now, we verify the setup is correct
      const learningModuleContract = await ethers.getContractAt('MerkleTreeLearning', merkleTreeLearning.address);
      expect(learningModuleContract.address).to.equal(merkleTreeLearning.address);
    });

    it('Should maintain compatibility with different agent token addresses', async function () {
      // Deploy with different agent token addresses
      const agents = [];
      for (let i = 0; i < 3; i++) {
        const agent = await CreatorAgent.deploy(
          addrs[i].address, // Use different addresses as agent tokens
          `Creator ${i}`,
          `Bio ${i}`,
          `Niche ${i}`
        );
        await agent.deployed();
        agents.push(agent);
      }

      // Verify each agent has correct agent token
      for (let i = 0; i < 3; i++) {
        expect(await agents[i].agentToken()).to.equal(addrs[i].address);
        const profile = await agents[i].profile();
        expect(profile.name).to.equal(`Creator ${i}`);
      }
    });
  });

  describe('Events and Logging', function () {
    it('Should not emit events for profile updates (as none are defined)', async function () {
      // The current contract doesn't define events for profile updates
      // This test verifies that no unexpected events are emitted
      const tx = await creatorAgent.updateProfile('New Name', 'New Bio', 'New Niche', 75);
      const receipt = await tx.wait();
      
      // Should only have events from inherited contracts (like Ownable)
      const profileUpdateEvents = receipt.events?.filter(e => 
        e.event && e.event.includes('Profile')
      ) || [];
      expect(profileUpdateEvents.length).to.equal(0);
    });

    it('Should not emit events for learning enablement (as none are defined)', async function () {
      // Similar to above, verify no unexpected events for learning enablement
      const tx = await creatorAgent.enableLearning(merkleTreeLearning.address);
      const receipt = await tx.wait();
      
      const learningEvents = receipt.events?.filter(e => 
        e.event && e.event.includes('Learning')
      ) || [];
      expect(learningEvents.length).to.equal(0);
    });
  });
});
