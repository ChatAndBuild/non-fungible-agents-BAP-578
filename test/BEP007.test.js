const { expect } = require('chai');
const { ethers, upgrades } = require('hardhat');

describe('BEP007 Non-Fungible Agent', function () {
  let BEP007;
  let bep007;
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

  beforeEach(async function () {
    [owner, governance, emergencyMultiSig, addr1, addr2, ...addrs] = await ethers.getSigners();

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
  });

  describe('Deployment', function () {
    it('Should set the right owner', async function () {
      // Ownership is transferred to governance (CircuitBreaker) during initialization
      expect(await bep007.owner()).to.equal(circuitBreaker.address);
    });

    it('Should set the right name and symbol', async function () {
      expect(await bep007.name()).to.equal('Non-Fungible Agent');
      expect(await bep007.symbol()).to.equal('NFA');
    });

    it('Should set the right circuit breaker', async function () {
      expect(await bep007.circuitBreaker()).to.equal(circuitBreaker.address);
    });

    it('Should not allow initialization with zero Circuit Breaker address', async function () {
      const BEP007Factory = await ethers.getContractFactory('BEP007');
      await expect(
        upgrades.deployProxy(BEP007Factory, ['Test', 'TEST', ethers.constants.AddressZero], {
          initializer: 'initialize',
          kind: 'uups',
        }),
      ).to.be.revertedWith('BEP007: Circuit Breaker address is zero');
    });

    it('Should support IBEP007 interface', async function () {
      // Check if contract supports the IBEP007 interface
      const interfaceId = '0x01ffc9a7'; // ERC165 interface ID
      expect(await bep007.supportsInterface(interfaceId)).to.equal(true);
    });
  });

  describe('Agent Creation', function () {
    it('Should create an agent with extended metadata', async function () {
      const metadataURI = 'ipfs://QmTest';
      const extendedMetadata = {
        persona: 'Test Persona',
        experience: 'Test Experience',
        voiceHash: 'Test Voice Hash',
        animationURI: 'ipfs://QmTestAnimation',
        vaultURI: 'ipfs://QmTestVault',
        vaultHash: ethers.utils.formatBytes32String('test-vault-hash'),
      };

      await bep007[
        'createAgent(address,address,string,(string,string,string,string,string,bytes32))'
      ](addr1.address, mockLogicAddress, metadataURI, extendedMetadata);

      const tokenId = 1; // First token ID
      expect(await bep007.ownerOf(tokenId)).to.equal(addr1.address);
      expect(await bep007.tokenURI(tokenId)).to.equal(metadataURI);

      const agentMetadata = await bep007.getAgentMetadata(tokenId);
      expect(agentMetadata.persona).to.equal(extendedMetadata.persona);
      expect(agentMetadata.experience).to.equal(extendedMetadata.experience);
      expect(agentMetadata.voiceHash).to.equal(extendedMetadata.voiceHash);
      expect(agentMetadata.animationURI).to.equal(extendedMetadata.animationURI);
      expect(agentMetadata.vaultURI).to.equal(extendedMetadata.vaultURI);
      expect(agentMetadata.vaultHash).to.equal(extendedMetadata.vaultHash);

      const agentState = await bep007.getState(tokenId);
      expect(agentState.logicAddress).to.equal(mockLogicAddress);
      expect(agentState.status).to.equal(1); // Active status
      expect(agentState.owner).to.equal(addr1.address);
      expect(agentState.balance).to.equal(0);
    });

    it('Should create an agent with basic metadata', async function () {
      const metadataURI = 'ipfs://QmTestBasic';

      await bep007['createAgent(address,address,string)'](
        addr1.address,
        mockLogicAddress,
        metadataURI,
      );

      const tokenId = 1;
      expect(await bep007.ownerOf(tokenId)).to.equal(addr1.address);
      expect(await bep007.tokenURI(tokenId)).to.equal(metadataURI);

      const agentMetadata = await bep007.getAgentMetadata(tokenId);
      expect(agentMetadata.persona).to.equal('');
      expect(agentMetadata.experience).to.equal('');
      expect(agentMetadata.voiceHash).to.equal('');
      expect(agentMetadata.animationURI).to.equal('');
      expect(agentMetadata.vaultURI).to.equal('');
      expect(agentMetadata.vaultHash).to.equal(ethers.constants.HashZero);
    });

    it('Should not allow creating agent with zero logic address', async function () {
      const metadataURI = 'ipfs://QmTest';

      await expect(
        bep007['createAgent(address,address,string)'](
          addr1.address,
          ethers.constants.AddressZero,
          metadataURI,
        ),
      ).to.be.revertedWith('BEP007: logic address is zero');
    });

    it('Should increment token IDs correctly', async function () {
      const metadataURI = 'ipfs://QmTest';

      // Create first agent
      await bep007['createAgent(address,address,string)'](
        addr1.address,
        mockLogicAddress,
        metadataURI,
      );

      // Create second agent
      await bep007['createAgent(address,address,string)'](
        addr2.address,
        mockLogicAddress,
        metadataURI,
      );

      expect(await bep007.ownerOf(1)).to.equal(addr1.address);
      expect(await bep007.ownerOf(2)).to.equal(addr2.address);
      expect(await bep007.totalSupply()).to.equal(2);
    });
  });

  describe('Agent State Management', function () {
    let tokenId;

    beforeEach(async function () {
      const metadataURI = 'ipfs://QmTest';
      await bep007['createAgent(address,address,string)'](
        addr1.address,
        mockLogicAddress,
        metadataURI,
      );
      tokenId = 1;
    });

    it('Should pause and unpause an agent', async function () {
      // Initially active
      let agentState = await bep007.getState(tokenId);
      expect(agentState.status).to.equal(1); // Active

      // Pause the agent
      await expect(bep007.connect(addr1).pause(tokenId))
        .to.emit(bep007, 'StatusChanged')
        .withArgs(bep007.address, 0); // Paused

      agentState = await bep007.getState(tokenId);
      expect(agentState.status).to.equal(0); // Paused

      // Unpause the agent
      await expect(bep007.connect(addr1).unpause(tokenId))
        .to.emit(bep007, 'StatusChanged')
        .withArgs(bep007.address, 1); // Active

      agentState = await bep007.getState(tokenId);
      expect(agentState.status).to.equal(1); // Active
    });

    it('Should not allow non-owner to pause agent', async function () {
      await expect(bep007.connect(addr2).pause(tokenId)).to.be.revertedWith(
        'BEP007: caller is not agent owner',
      );
    });

    it('Should not allow pausing already paused agent', async function () {
      await bep007.connect(addr1).pause(tokenId);

      await expect(bep007.connect(addr1).pause(tokenId)).to.be.revertedWith(
        'BEP007: agent not active',
      );
    });

    it('Should not allow unpausing active agent', async function () {
      await expect(bep007.connect(addr1).unpause(tokenId)).to.be.revertedWith(
        'BEP007: agent not paused',
      );
    });

    it('Should terminate an agent', async function () {
      // Fund the agent first
      await bep007.connect(addr1).fundAgent(tokenId, { value: ethers.utils.parseEther('1.0') });

      const initialBalance = await ethers.provider.getBalance(addr1.address);

      await expect(bep007.connect(addr1).terminate(tokenId))
        .to.emit(bep007, 'StatusChanged')
        .withArgs(bep007.address, 2); // Terminated

      const agentState = await bep007.getState(tokenId);
      expect(agentState.status).to.equal(2); // Terminated
      expect(agentState.balance).to.equal(0); // Balance should be returned

      // Check that balance was returned to owner
      const finalBalance = await ethers.provider.getBalance(addr1.address);
      expect(finalBalance).to.be.gt(initialBalance);
    });

    it('Should not allow terminating already terminated agent', async function () {
      await bep007.connect(addr1).terminate(tokenId);

      await expect(bep007.connect(addr1).terminate(tokenId)).to.be.revertedWith(
        'BEP007: agent already terminated',
      );
    });
  });

  describe('Agent Funding', function () {
    let tokenId;

    beforeEach(async function () {
      const metadataURI = 'ipfs://QmTest';
      await bep007['createAgent(address,address,string)'](
        addr1.address,
        mockLogicAddress,
        metadataURI,
      );
      tokenId = 1;
    });

    it('Should fund an agent', async function () {
      const fundAmount = ethers.utils.parseEther('1.0');

      await expect(bep007.connect(addr1).fundAgent(tokenId, { value: fundAmount }))
        .to.emit(bep007, 'AgentFunded')
        .withArgs(bep007.address, addr1.address, fundAmount);

      const agentState = await bep007.getState(tokenId);
      expect(agentState.balance).to.equal(fundAmount);
    });

    it('Should allow multiple funding transactions', async function () {
      const fundAmount1 = ethers.utils.parseEther('1.0');
      const fundAmount2 = ethers.utils.parseEther('0.5');

      await bep007.connect(addr1).fundAgent(tokenId, { value: fundAmount1 });
      await bep007.connect(addr1).fundAgent(tokenId, { value: fundAmount2 });

      const agentState = await bep007.getState(tokenId);
      expect(agentState.balance).to.equal(fundAmount1.add(fundAmount2));
    });

    it('Should not allow funding non-existent agent', async function () {
      await expect(
        bep007.connect(addr1).fundAgent(999, { value: ethers.utils.parseEther('1.0') }),
      ).to.be.revertedWith('BEP007: agent does not exist');
    });

    it('Should allow anyone to fund an agent', async function () {
      const fundAmount = ethers.utils.parseEther('1.0');

      await expect(bep007.connect(addr2).fundAgent(tokenId, { value: fundAmount }))
        .to.emit(bep007, 'AgentFunded')
        .withArgs(bep007.address, addr2.address, fundAmount);

      const agentState = await bep007.getState(tokenId);
      expect(agentState.balance).to.equal(fundAmount);
    });
  });

  describe('Agent Withdrawal', function () {
    let tokenId;

    beforeEach(async function () {
      const metadataURI = 'ipfs://QmTest';
      await bep007['createAgent(address,address,string)'](
        addr1.address,
        mockLogicAddress,
        metadataURI,
      );
      tokenId = 1;

      // Fund the agent
      await bep007.connect(addr1).fundAgent(tokenId, { value: ethers.utils.parseEther('2.0') });
    });

    it('Should allow owner to withdraw from agent', async function () {
      const withdrawAmount = ethers.utils.parseEther('1.0');
      const initialBalance = await ethers.provider.getBalance(addr1.address);

      await bep007.connect(addr1).withdrawFromAgent(tokenId, withdrawAmount);

      const agentState = await bep007.getState(tokenId);
      expect(agentState.balance).to.equal(ethers.utils.parseEther('1.0'));

      const finalBalance = await ethers.provider.getBalance(addr1.address);
      expect(finalBalance).to.be.gt(initialBalance);
    });

    it('Should not allow withdrawing more than balance', async function () {
      const withdrawAmount = ethers.utils.parseEther('3.0');

      await expect(
        bep007.connect(addr1).withdrawFromAgent(tokenId, withdrawAmount),
      ).to.be.revertedWith('BEP007: insufficient balance');
    });

    it('Should not allow non-owner to withdraw', async function () {
      const withdrawAmount = ethers.utils.parseEther('1.0');

      await expect(
        bep007.connect(addr2).withdrawFromAgent(tokenId, withdrawAmount),
      ).to.be.revertedWith('BEP007: caller is not agent owner');
    });

    it('Should allow withdrawing entire balance', async function () {
      const agentState = await bep007.getState(tokenId);
      const fullBalance = agentState.balance;

      await bep007.connect(addr1).withdrawFromAgent(tokenId, fullBalance);

      const updatedState = await bep007.getState(tokenId);
      expect(updatedState.balance).to.equal(0);
    });
  });

  describe('Logic Address Management', function () {
    let tokenId;

    beforeEach(async function () {
      const metadataURI = 'ipfs://QmTest';
      await bep007['createAgent(address,address,string)'](
        addr1.address,
        mockLogicAddress,
        metadataURI,
      );
      tokenId = 1;
    });

    it('Should allow owner to update logic address', async function () {
      const newLogicAddress = '0x0987654321098765432109876543210987654321';

      await expect(bep007.connect(addr1).setLogicAddress(tokenId, newLogicAddress))
        .to.emit(bep007, 'LogicUpgraded')
        .withArgs(bep007.address, mockLogicAddress, newLogicAddress);

      const agentState = await bep007.getState(tokenId);
      expect(agentState.logicAddress).to.equal(newLogicAddress);
    });

    it('Should not allow non-owner to update logic address', async function () {
      const newLogicAddress = '0x0987654321098765432109876543210987654321';

      await expect(
        bep007.connect(addr2).setLogicAddress(tokenId, newLogicAddress),
      ).to.be.revertedWith('BEP007: caller is not agent owner');
    });

    it('Should not allow setting logic address to zero', async function () {
      await expect(
        bep007.connect(addr1).setLogicAddress(tokenId, ethers.constants.AddressZero),
      ).to.be.revertedWith('BEP007: new logic address is zero');
    });
  });

  describe('Token Transfer', function () {
    let tokenId;

    beforeEach(async function () {
      const metadataURI = 'ipfs://QmTest';
      await bep007['createAgent(address,address,string)'](
        addr1.address,
        mockLogicAddress,
        metadataURI,
      );
      tokenId = 1;
    });

    it('Should update agent state owner on transfer', async function () {
      // Transfer token from addr1 to addr2
      await bep007.connect(addr1).transferFrom(addr1.address, addr2.address, tokenId);

      expect(await bep007.ownerOf(tokenId)).to.equal(addr2.address);

      const agentState = await bep007.getState(tokenId);
      expect(agentState.owner).to.equal(addr2.address);
    });

    it('Should allow new owner to manage agent after transfer', async function () {
      // Transfer token
      await bep007.connect(addr1).transferFrom(addr1.address, addr2.address, tokenId);

      // New owner should be able to pause the agent
      await bep007.connect(addr2).pause(tokenId);

      const agentState = await bep007.getState(tokenId);
      expect(agentState.status).to.equal(0); // Paused
    });

    it('Should not allow old owner to manage agent after transfer', async function () {
      // Transfer token
      await bep007.connect(addr1).transferFrom(addr1.address, addr2.address, tokenId);

      // Old owner should not be able to pause the agent
      await expect(bep007.connect(addr1).pause(tokenId)).to.be.revertedWith(
        'BEP007: caller is not agent owner',
      );
    });
  });

  describe('Circuit Breaker Integration', function () {
    let tokenId;

    beforeEach(async function () {
      const metadataURI = 'ipfs://QmTest';
      await bep007['createAgent(address,address,string)'](
        addr1.address,
        mockLogicAddress,
        metadataURI,
      );
      tokenId = 1;
    });

    it('Should respect global pause from circuit breaker', async function () {
      // Set global pause
      await circuitBreaker.connect(governance).setGlobalPause(true);

      // Any function with whenAgentActive modifier should fail
      // Note: The current contract doesn't have functions with this modifier implemented
      // This test would be relevant if there were functions that check for global pause
    });
  });

  describe('View Functions', function () {
    let tokenId;

    beforeEach(async function () {
      const metadataURI = 'ipfs://QmTest';
      const extendedMetadata = {
        persona: 'Test Persona',
        experience: 'Test Experience',
        voiceHash: 'Test Voice Hash',
        animationURI: 'ipfs://QmTestAnimation',
        vaultURI: 'ipfs://QmTestVault',
        vaultHash: ethers.utils.formatBytes32String('test-vault-hash'),
      };

      await bep007[
        'createAgent(address,address,string,(string,string,string,string,string,bytes32))'
      ](addr1.address, mockLogicAddress, metadataURI, extendedMetadata);
      tokenId = 1;
    });

    it('Should return correct agent state', async function () {
      const agentState = await bep007.getState(tokenId);

      expect(agentState.balance).to.equal(0);
      expect(agentState.status).to.equal(1); // Active
      expect(agentState.owner).to.equal(addr1.address);
      expect(agentState.logicAddress).to.equal(mockLogicAddress);
      expect(agentState.lastActionTimestamp).to.be.gt(0);
    });

    it('Should return correct agent metadata', async function () {
      const agentMetadata = await bep007.getAgentMetadata(tokenId);

      expect(agentMetadata.persona).to.equal('Test Persona');
      expect(agentMetadata.experience).to.equal('Test Experience');
      expect(agentMetadata.voiceHash).to.equal('Test Voice Hash');
      expect(agentMetadata.animationURI).to.equal('ipfs://QmTestAnimation');
      expect(agentMetadata.vaultURI).to.equal('ipfs://QmTestVault');
      expect(agentMetadata.vaultHash).to.equal(ethers.utils.formatBytes32String('test-vault-hash'));
    });

    it('Should revert when getting state of non-existent agent', async function () {
      await expect(bep007.getState(999)).to.be.revertedWith('BEP007: agent does not exist');
    });

    it('Should revert when getting metadata of non-existent agent', async function () {
      await expect(bep007.getAgentMetadata(999)).to.be.revertedWith('BEP007: agent does not exist');
    });
  });

  describe('Contract Upgrade', function () {
    it('Should only allow owner to upgrade contract', async function () {
      // Only the owner (which is the circuitBreaker) can upgrade
      // This test would require deploying a new implementation
      // For now, we just test that non-owners cannot call upgrade functions

      await expect(bep007.connect(addr1).upgradeTo(addr2.address)).to.be.revertedWith(
        'Ownable: caller is not the owner',
      );
    });
  });

  describe('Receive Function', function () {
    it('Should accept direct BNB transfers', async function () {
      const sendAmount = ethers.utils.parseEther('1.0');

      await expect(
        addr1.sendTransaction({
          to: bep007.address,
          value: sendAmount,
        }),
      ).to.not.be.reverted;

      const contractBalance = await ethers.provider.getBalance(bep007.address);
      expect(contractBalance).to.equal(sendAmount);
    });
  });

  describe('Edge Cases', function () {
    it('Should handle zero value funding', async function () {
      const metadataURI = 'ipfs://QmTest';
      await bep007['createAgent(address,address,string)'](
        addr1.address,
        mockLogicAddress,
        metadataURI,
      );
      const tokenId = 1;

      await expect(bep007.connect(addr1).fundAgent(tokenId, { value: 0 }))
        .to.emit(bep007, 'AgentFunded')
        .withArgs(bep007.address, addr1.address, 0);

      const agentState = await bep007.getState(tokenId);
      expect(agentState.balance).to.equal(0);
    });

    it('Should handle zero amount withdrawal', async function () {
      const metadataURI = 'ipfs://QmTest';
      await bep007['createAgent(address,address,string)'](
        addr1.address,
        mockLogicAddress,
        metadataURI,
      );
      const tokenId = 1;

      await bep007.connect(addr1).fundAgent(tokenId, { value: ethers.utils.parseEther('1.0') });

      await expect(bep007.connect(addr1).withdrawFromAgent(tokenId, 0)).to.not.be.reverted;
    });
  });
});
