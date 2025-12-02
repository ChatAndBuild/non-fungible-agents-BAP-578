const { expect } = require('chai');
const { ethers, upgrades } = require('hardhat');

describe('BAP578', function () {
  let nfa;
  let owner;
  let addr1;
  let addr2;
  let treasury;

  // Helper function to create AgentMetadata
  function createAgentMetadata(overrides = {}) {
    return {
      persona: overrides.persona || '{"traits": "friendly", "style": "casual"}',
      experience: overrides.experience || 'AI Assistant specialized in blockchain',
      voiceHash: overrides.voiceHash || 'voice_001',
      animationURI: overrides.animationURI || 'ipfs://animation1',
      vaultURI: overrides.vaultURI || 'ipfs://vault1',
      vaultHash: overrides.vaultHash || ethers.utils.formatBytes32String('vault1'),
    };
  }

  beforeEach(async function () {
    [owner, addr1, addr2, treasury] = await ethers.getSigners();

    // Deploy upgradeable contract using OpenZeppelin Upgrades plugin
    const BAP578 = await ethers.getContractFactory('BAP578');
    nfa = await upgrades.deployProxy(BAP578, ['Non-Fungible Agents', 'NFA', treasury.address], {
      initializer: 'initialize',
      kind: 'uups',
    });
    await nfa.deployed();
  });

  describe('Deployment', function () {
    it('Should set the correct name and symbol', async function () {
      expect(await nfa.name()).to.equal('Non-Fungible Agents');
      expect(await nfa.symbol()).to.equal('NFA');
    });

    it('Should set the correct treasury address', async function () {
      expect(await nfa.treasuryAddress()).to.equal(treasury.address);
    });

    it('Should set the correct owner', async function () {
      expect(await nfa.owner()).to.equal(owner.address);
    });
  });

  describe('Free Mints', function () {
    it('Should give each user 3 free mints by default', async function () {
      expect(await nfa.getFreeMints(addr1.address)).to.equal(3);
      expect(await nfa.getFreeMints(addr2.address)).to.equal(3);
      expect(await nfa.FREE_MINTS_PER_USER()).to.equal(3);
    });

    it('Should allow first 3 mints for free', async function () {
      const metadata = createAgentMetadata();

      // First free mint
      await nfa
        .connect(addr1)
        .createAgent(addr1.address, ethers.constants.AddressZero, 'ipfs://metadata1', metadata);
      expect(await nfa.getFreeMints(addr1.address)).to.equal(2);

      // Second free mint
      await nfa
        .connect(addr1)
        .createAgent(addr1.address, ethers.constants.AddressZero, 'ipfs://metadata2', metadata);
      expect(await nfa.getFreeMints(addr1.address)).to.equal(1);

      // Third free mint
      await nfa
        .connect(addr1)
        .createAgent(addr1.address, ethers.constants.AddressZero, 'ipfs://metadata3', metadata);
      expect(await nfa.getFreeMints(addr1.address)).to.equal(0);

      // Fourth mint should require payment
      await expect(
        nfa
          .connect(addr1)
          .createAgent(addr1.address, ethers.constants.AddressZero, 'ipfs://metadata4', metadata),
      ).to.be.revertedWith('Incorrect fee');
    });

    it('Should require payment after free mints are used', async function () {
      const metadata = createAgentMetadata();

      // Use all 3 free mints
      for (let i = 0; i < 3; i++) {
        await nfa
          .connect(addr1)
          .createAgent(
            addr1.address,
            ethers.constants.AddressZero,
            `ipfs://metadata${i}`,
            metadata,
          );
      }

      // Next mint should require payment
      const fee = await nfa.MINT_FEE();
      const treasuryBefore = await treasury.getBalance();

      await nfa
        .connect(addr1)
        .createAgent(addr1.address, ethers.constants.AddressZero, 'ipfs://metadata4', metadata, {
          value: fee,
        });

      const treasuryAfter = await treasury.getBalance();
      expect(treasuryAfter.sub(treasuryBefore)).to.equal(fee);
    });
  });

  describe('Agent Creation', function () {
    it('Should create an agent with free mint', async function () {
      const metadata = createAgentMetadata();

      const tx = await nfa
        .connect(addr1)
        .createAgent(addr1.address, ethers.constants.AddressZero, 'ipfs://metadata1', metadata);

      await expect(tx)
        .to.emit(nfa, 'AgentCreated')
        .withArgs(1, addr1.address, ethers.constants.AddressZero, 'ipfs://metadata1');

      expect(await nfa.balanceOf(addr1.address)).to.equal(1);
      expect(await nfa.ownerOf(1)).to.equal(addr1.address);
      expect(await nfa.getFreeMints(addr1.address)).to.equal(2); // 2 free mints remaining
    });

    it('Should create an agent with payment after free mints', async function () {
      const metadata = createAgentMetadata();

      // Use all free mints
      for (let i = 0; i < 3; i++) {
        await nfa
          .connect(addr1)
          .createAgent(
            addr1.address,
            ethers.constants.AddressZero,
            `ipfs://metadata${i}`,
            metadata,
          );
      }

      // Pay for next mint
      const fee = await nfa.MINT_FEE();
      const tx = await nfa
        .connect(addr1)
        .createAgent(addr1.address, ethers.constants.AddressZero, 'ipfs://metadata4', metadata, {
          value: fee,
        });

      await expect(tx)
        .to.emit(nfa, 'AgentCreated')
        .withArgs(4, addr1.address, ethers.constants.AddressZero, 'ipfs://metadata4');
    });

    it('Should store extended metadata correctly', async function () {
      const metadata = createAgentMetadata({
        persona: '{"traits": "professional", "style": "formal"}',
        experience: 'Financial advisor agent',
      });

      await nfa.createAgent(
        addr1.address,
        ethers.constants.AddressZero,
        'ipfs://metadata1',
        metadata,
      );

      const [storedMetadata, metadataURI] = await nfa.getAgentMetadata(1);
      expect(storedMetadata.persona).to.equal(metadata.persona);
      expect(storedMetadata.experience).to.equal(metadata.experience);
      expect(storedMetadata.voiceHash).to.equal(metadata.voiceHash);
      expect(storedMetadata.animationURI).to.equal(metadata.animationURI);
      expect(storedMetadata.vaultURI).to.equal(metadata.vaultURI);
      expect(storedMetadata.vaultHash).to.equal(metadata.vaultHash);
      expect(metadataURI).to.equal('ipfs://metadata1');
    });
  });

  describe('Agent Management', function () {
    beforeEach(async function () {
      const metadata = createAgentMetadata();

      // Create an agent using free mint
      await nfa
        .connect(addr1)
        .createAgent(addr1.address, ethers.constants.AddressZero, 'ipfs://metadata1', metadata);
    });

    it('Should update agent status', async function () {
      await nfa.connect(addr1).setAgentStatus(1, false);
      const state = await nfa.getAgentState(1);
      expect(state.active).to.equal(false);
    });

    it('Should fund an agent', async function () {
      const amount = ethers.utils.parseEther('1');
      await nfa.fundAgent(1, { value: amount });

      const state = await nfa.getAgentState(1);
      expect(state.balance).to.equal(amount);
    });

    it('Should withdraw from agent', async function () {
      const amount = ethers.utils.parseEther('1');
      await nfa.fundAgent(1, { value: amount });

      const balanceBefore = await addr1.getBalance();
      const tx = await nfa.connect(addr1).withdrawFromAgent(1, amount);
      const receipt = await tx.wait();
      const gasUsed = receipt.gasUsed.mul(receipt.effectiveGasPrice);

      const balanceAfter = await addr1.getBalance();
      expect(balanceAfter.sub(balanceBefore).add(gasUsed)).to.equal(amount);

      const state = await nfa.getAgentState(1);
      expect(state.balance).to.equal(0);
    });

    it('Should update logic address', async function () {
      const newLogicAddress = addr2.address;
      await nfa.connect(addr1).setLogicAddress(1, newLogicAddress);

      const state = await nfa.getAgentState(1);
      expect(state.logicAddress).to.equal(newLogicAddress);
    });

    it('Should update agent metadata', async function () {
      const newMetadata = createAgentMetadata({
        persona: '{"traits": "analytical", "style": "technical"}',
        experience: 'Data analysis expert',
      });

      await nfa.connect(addr1).updateAgentMetadata(1, 'ipfs://newmetadata', newMetadata);

      const [storedMetadata, metadataURI] = await nfa.getAgentMetadata(1);
      expect(storedMetadata.persona).to.equal(newMetadata.persona);
      expect(storedMetadata.experience).to.equal(newMetadata.experience);
      expect(metadataURI).to.equal('ipfs://newmetadata');
    });

    it('Should not allow funding when contract is paused', async function () {
      // Create an agent first
      const metadata = createAgentMetadata();
      await nfa
        .connect(addr1)
        .createAgent(addr1.address, ethers.constants.AddressZero, 'ipfs://metadata1', metadata);

      // Pause the contract
      await nfa.setPaused(true);

      // Attempt to fund agent while paused - should revert
      await expect(
        nfa.connect(addr1).fundAgent(1, { value: ethers.utils.parseEther('0.1') }),
      ).to.be.revertedWith('Contract is paused');
    });

    it('Should only allow owner to manage agent', async function () {
      await expect(nfa.connect(addr2).setAgentStatus(1, false)).to.be.revertedWith(
        'Not token owner',
      );

      await expect(nfa.connect(addr2).withdrawFromAgent(1, 100)).to.be.revertedWith(
        'Not token owner',
      );

      await expect(nfa.connect(addr2).setLogicAddress(1, addr2.address)).to.be.revertedWith(
        'Not token owner',
      );
    });
  });

  describe('View Functions', function () {
    beforeEach(async function () {
      const metadata1 = createAgentMetadata();
      const metadata2 = createAgentMetadata({ experience: 'Second agent' });

      // Use free mints to create agents
      await nfa
        .connect(addr1)
        .createAgent(addr1.address, addr2.address, 'ipfs://metadata1', metadata1);

      await nfa
        .connect(addr1)
        .createAgent(addr1.address, ethers.constants.AddressZero, 'ipfs://metadata2', metadata2);
    });

    it('Should get agent state information', async function () {
      const state = await nfa.getAgentState(1);
      expect(state.balance).to.equal(0);
      expect(state.active).to.equal(true);
      expect(state.logicAddress).to.equal(addr2.address);
      expect(state.owner).to.equal(addr1.address);
      expect(state.createdAt).to.be.gt(0);
    });

    it('Should get tokens of owner', async function () {
      const tokens = await nfa.tokensOfOwner(addr1.address);
      expect(tokens.length).to.equal(2);
      expect(tokens[0]).to.equal(1);
      expect(tokens[1]).to.equal(2);
    });

    it('Should get total supply', async function () {
      expect(await nfa.getTotalSupply()).to.equal(2);
    });

    it('Should get free mints remaining', async function () {
      // addr1 used 2 free mints, should have 1 remaining
      expect(await nfa.getFreeMints(addr1.address)).to.equal(1);

      // addr2 hasn't used any, should have 3
      expect(await nfa.getFreeMints(addr2.address)).to.equal(3);
    });
  });

  describe('Admin Functions', function () {
    it('Should pause the contract', async function () {
      await nfa.setPaused(true);
      expect(await nfa.paused()).to.be.true;

      // Should not allow creation when paused
      const metadata = createAgentMetadata();
      await expect(
        nfa.createAgent(addr1.address, ethers.constants.AddressZero, 'ipfs://test', metadata),
      ).to.be.revertedWith('Contract is paused');
    });

    it('Should update treasury', async function () {
      await nfa.setTreasury(addr2.address);
      expect(await nfa.treasuryAddress()).to.equal(addr2.address);
    });

    it('Should only allow owner to call admin functions', async function () {
      await expect(nfa.connect(addr1).setPaused(true)).to.be.revertedWith(
        'Ownable: caller is not the owner',
      );

      await expect(nfa.connect(addr1).setTreasury(addr2.address)).to.be.revertedWith(
        'Ownable: caller is not the owner',
      );

      await expect(
        nfa.connect(addr1).grantAdditionalFreeMints(addr2.address, 5),
      ).to.be.revertedWith('Ownable: caller is not the owner');
    });

    it('Should perform emergency withdraw', async function () {
      // Send some ETH to contract
      await owner.sendTransaction({
        to: nfa.address,
        value: ethers.utils.parseEther('1'),
      });

      const balanceBefore = await owner.getBalance();
      const tx = await nfa.emergencyWithdraw();
      const receipt = await tx.wait();
      const gasUsed = receipt.gasUsed.mul(receipt.effectiveGasPrice);

      const balanceAfter = await owner.getBalance();
      expect(balanceAfter.sub(balanceBefore).add(gasUsed)).to.equal(ethers.utils.parseEther('1'));
    });
  });
});
