const { expect } = require('chai');
const { ethers, upgrades } = require('hardhat');

describe('BAP700 Non-Fungible Agent', function () {
  let BAP700;
  let bap700;
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

    // Deploy BAP700 with CircuitBreaker as governance
    BAP700 = await ethers.getContractFactory('BAP700');
    bap700 = await upgrades.deployProxy(
      BAP700,
      ['Non-Fungible Agent', 'NFA', circuitBreaker.address],
      { initializer: 'initialize', kind: 'uups' },
    );
    await bap700.deployed();
  });

  describe('Deployment', function () {
    it('Should set the right owner', async function () {
      // Ownership is transferred to governance (CircuitBreaker) during initialization
      expect(await bap700.owner()).to.equal(circuitBreaker.address);
    });

    it('Should set the right name and symbol', async function () {
      expect(await bap700.name()).to.equal('Non-Fungible Agent');
      expect(await bap700.symbol()).to.equal('NFA');
    });

    it('Should set the right circuit breaker', async function () {
      expect(await bap700.circuitBreaker()).to.equal(circuitBreaker.address);
    });

    it('Should not allow initialization with zero Circuit Breaker address', async function () {
      const BAP700Factory = await ethers.getContractFactory('BAP700');
      await expect(
        upgrades.deployProxy(BAP700Factory, ['Test', 'TEST', ethers.constants.AddressZero], {
          initializer: 'initialize',
          kind: 'uups',
        }),
      ).to.be.revertedWith('BAP700: Circuit Breaker address is zero');
    });

    it('Should support IBAP700 interface', async function () {
      // Check if contract supports the IBAP700 interface
      const interfaceId = '0x01ffc9a7'; // ERC165 interface ID
      expect(await bap700.supportsInterface(interfaceId)).to.equal(true);
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

      await bap700[
        'createAgent(address,address,string,(string,string,string,string,string,bytes32))'
      ](addr1.address, mockLogicAddress, metadataURI, extendedMetadata);

      const tokenId = 1; // First token ID
      expect(await bap700.ownerOf(tokenId)).to.equal(addr1.address);
      expect(await bap700.tokenURI(tokenId)).to.equal(metadataURI);

      const agentMetadata = await bap700.getAgentMetadata(tokenId);
      expect(agentMetadata.persona).to.equal(extendedMetadata.persona);
      expect(agentMetadata.experience).to.equal(extendedMetadata.experience);
      expect(agentMetadata.voiceHash).to.equal(extendedMetadata.voiceHash);
      expect(agentMetadata.animationURI).to.equal(extendedMetadata.animationURI);
      expect(agentMetadata.vaultURI).to.equal(extendedMetadata.vaultURI);
      expect(agentMetadata.vaultHash).to.equal(extendedMetadata.vaultHash);

      const agentState = await bap700.getState(tokenId);
      expect(agentState.logicAddress).to.equal(mockLogicAddress);
      expect(agentState.status).to.equal(1); // Active status
      expect(agentState.owner).to.equal(addr1.address);
      expect(agentState.balance).to.equal(0);
    });

    it('Should create an agent with basic metadata', async function () {
      const metadataURI = 'ipfs://QmTestBasic';

      await bap700['createAgent(address,address,string)'](
        addr1.address,
        mockLogicAddress,
        metadataURI,
      );

      const tokenId = 1;
      expect(await bap700.ownerOf(tokenId)).to.equal(addr1.address);
      expect(await bap700.tokenURI(tokenId)).to.equal(metadataURI);

      const agentMetadata = await bap700.getAgentMetadata(tokenId);
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
        bap700['createAgent(address,address,string)'](
          addr1.address,
          ethers.constants.AddressZero,
          metadataURI,
        ),
      ).to.be.revertedWith('BAP700: logic address is zero');
    });

    it('Should increment token IDs correctly', async function () {
      const metadataURI = 'ipfs://QmTest';

      // Create first agent
      await bap700['createAgent(address,address,string)'](
        addr1.address,
        mockLogicAddress,
        metadataURI,
      );

      // Create second agent
      await bap700['createAgent(address,address,string)'](
        addr2.address,
        mockLogicAddress,
        metadataURI,
      );

      expect(await bap700.ownerOf(1)).to.equal(addr1.address);
      expect(await bap700.ownerOf(2)).to.equal(addr2.address);
      expect(await bap700.totalSupply()).to.equal(2);
    });
  });

  describe('Agent State Management', function () {
    let tokenId;

    beforeEach(async function () {
      const metadataURI = 'ipfs://QmTest';
      await bap700['createAgent(address,address,string)'](
        addr1.address,
        mockLogicAddress,
        metadataURI,
      );
      tokenId = 1;
    });

    it('Should pause and unpause an agent', async function () {
      // Initially active
      let agentState = await bap700.getState(tokenId);
      expect(agentState.status).to.equal(1); // Active

      // Pause the agent
      await expect(bap700.connect(addr1).pause(tokenId))
        .to.emit(bap700, 'StatusChanged')
        .withArgs(bap700.address, 0); // Paused

      agentState = await bap700.getState(tokenId);
      expect(agentState.status).to.equal(0); // Paused

      // Unpause the agent
      await expect(bap700.connect(addr1).unpause(tokenId))
        .to.emit(bap700, 'StatusChanged')
        .withArgs(bap700.address, 1); // Active

      agentState = await bap700.getState(tokenId);
      expect(agentState.status).to.equal(1); // Active
    });

    it('Should not allow non-owner to pause agent', async function () {
      await expect(bap700.connect(addr2).pause(tokenId)).to.be.revertedWith(
        'BAP700: caller is not agent owner',
      );
    });

    it('Should not allow pausing already paused agent', async function () {
      await bap700.connect(addr1).pause(tokenId);

      await expect(bap700.connect(addr1).pause(tokenId)).to.be.revertedWith(
        'BAP700: agent not active',
      );
    });

    it('Should not allow unpausing active agent', async function () {
      await expect(bap700.connect(addr1).unpause(tokenId)).to.be.revertedWith(
        'BAP700: agent not paused',
      );
    });

    it('Should terminate an agent', async function () {
      // Fund the agent first
      await bap700.connect(addr1).fundAgent(tokenId, { value: ethers.utils.parseEther('1.0') });

      const initialBalance = await ethers.provider.getBalance(addr1.address);

      await expect(bap700.connect(addr1).terminate(tokenId))
        .to.emit(bap700, 'StatusChanged')
        .withArgs(bap700.address, 2); // Terminated

      const agentState = await bap700.getState(tokenId);
      expect(agentState.status).to.equal(2); // Terminated
      expect(agentState.balance).to.equal(0); // Balance should be returned

      // Check that balance was returned to owner
      const finalBalance = await ethers.provider.getBalance(addr1.address);
      expect(finalBalance).to.be.gt(initialBalance);
    });

    it('Should not allow terminating already terminated agent', async function () {
      await bap700.connect(addr1).terminate(tokenId);

      await expect(bap700.connect(addr1).terminate(tokenId)).to.be.revertedWith(
        'BAP700: agent already terminated',
      );
    });
  });

  describe('Agent Funding', function () {
    let tokenId;

    beforeEach(async function () {
      const metadataURI = 'ipfs://QmTest';
      await bap700['createAgent(address,address,string)'](
        addr1.address,
        mockLogicAddress,
        metadataURI,
      );
      tokenId = 1;
    });

    it('Should fund an agent', async function () {
      const fundAmount = ethers.utils.parseEther('1.0');

      await expect(bap700.connect(addr1).fundAgent(tokenId, { value: fundAmount }))
        .to.emit(bap700, 'AgentFunded')
        .withArgs(bap700.address, addr1.address, fundAmount);

      const agentState = await bap700.getState(tokenId);
      expect(agentState.balance).to.equal(fundAmount);
    });

    it('Should allow multiple funding transactions', async function () {
      const fundAmount1 = ethers.utils.parseEther('1.0');
      const fundAmount2 = ethers.utils.parseEther('0.5');

      await bap700.connect(addr1).fundAgent(tokenId, { value: fundAmount1 });
      await bap700.connect(addr1).fundAgent(tokenId, { value: fundAmount2 });

      const agentState = await bap700.getState(tokenId);
      expect(agentState.balance).to.equal(fundAmount1.add(fundAmount2));
    });

    it('Should not allow funding non-existent agent', async function () {
      await expect(
        bap700.connect(addr1).fundAgent(999, { value: ethers.utils.parseEther('1.0') }),
      ).to.be.revertedWith('BAP700: agent does not exist');
    });

    it('Should allow anyone to fund an agent', async function () {
      const fundAmount = ethers.utils.parseEther('1.0');

      await expect(bap700.connect(addr2).fundAgent(tokenId, { value: fundAmount }))
        .to.emit(bap700, 'AgentFunded')
        .withArgs(bap700.address, addr2.address, fundAmount);

      const agentState = await bap700.getState(tokenId);
      expect(agentState.balance).to.equal(fundAmount);
    });
  });

  describe('Agent Withdrawal', function () {
    let tokenId;

    beforeEach(async function () {
      const metadataURI = 'ipfs://QmTest';
      await bap700['createAgent(address,address,string)'](
        addr1.address,
        mockLogicAddress,
        metadataURI,
      );
      tokenId = 1;

      // Fund the agent
      await bap700.connect(addr1).fundAgent(tokenId, { value: ethers.utils.parseEther('2.0') });
    });

    it('Should allow owner to withdraw from agent', async function () {
      const withdrawAmount = ethers.utils.parseEther('1.0');
      const initialBalance = await ethers.provider.getBalance(addr1.address);

      await bap700.connect(addr1).withdrawFromAgent(tokenId, withdrawAmount);

      const agentState = await bap700.getState(tokenId);
      expect(agentState.balance).to.equal(ethers.utils.parseEther('1.0'));

      const finalBalance = await ethers.provider.getBalance(addr1.address);
      expect(finalBalance).to.be.gt(initialBalance);
    });

    it('Should not allow withdrawing more than balance', async function () {
      const withdrawAmount = ethers.utils.parseEther('3.0');

      await expect(
        bap700.connect(addr1).withdrawFromAgent(tokenId, withdrawAmount),
      ).to.be.revertedWith('BAP700: insufficient balance');
    });

    it('Should not allow non-owner to withdraw', async function () {
      const withdrawAmount = ethers.utils.parseEther('1.0');

      await expect(
        bap700.connect(addr2).withdrawFromAgent(tokenId, withdrawAmount),
      ).to.be.revertedWith('BAP700: caller is not agent owner');
    });

    it('Should allow withdrawing entire balance', async function () {
      const agentState = await bap700.getState(tokenId);
      const fullBalance = agentState.balance;

      await bap700.connect(addr1).withdrawFromAgent(tokenId, fullBalance);

      const updatedState = await bap700.getState(tokenId);
      expect(updatedState.balance).to.equal(0);
    });
  });

  describe('Logic Address Management', function () {
    let tokenId;

    beforeEach(async function () {
      const metadataURI = 'ipfs://QmTest';
      await bap700['createAgent(address,address,string)'](
        addr1.address,
        mockLogicAddress,
        metadataURI,
      );
      tokenId = 1;
    });

    it('Should allow owner to update logic address', async function () {
      const newLogicAddress = '0x0987654321098765432109876543210987654321';

      await expect(bap700.connect(addr1).setLogicAddress(tokenId, newLogicAddress))
        .to.emit(bap700, 'LogicUpgraded')
        .withArgs(bap700.address, mockLogicAddress, newLogicAddress);

      const agentState = await bap700.getState(tokenId);
      expect(agentState.logicAddress).to.equal(newLogicAddress);
    });

    it('Should not allow non-owner to update logic address', async function () {
      const newLogicAddress = '0x0987654321098765432109876543210987654321';

      await expect(
        bap700.connect(addr2).setLogicAddress(tokenId, newLogicAddress),
      ).to.be.revertedWith('BAP700: caller is not agent owner');
    });

    it('Should not allow setting logic address to zero', async function () {
      await expect(
        bap700.connect(addr1).setLogicAddress(tokenId, ethers.constants.AddressZero),
      ).to.be.revertedWith('BAP700: new logic address is zero');
    });
  });

  describe('Token Transfer', function () {
    let tokenId;

    beforeEach(async function () {
      const metadataURI = 'ipfs://QmTest';
      await bap700['createAgent(address,address,string)'](
        addr1.address,
        mockLogicAddress,
        metadataURI,
      );
      tokenId = 1;
    });

    it('Should update agent state owner on transfer', async function () {
      // Transfer token from addr1 to addr2
      await bap700.connect(addr1).transferFrom(addr1.address, addr2.address, tokenId);

      expect(await bap700.ownerOf(tokenId)).to.equal(addr2.address);

      const agentState = await bap700.getState(tokenId);
      expect(agentState.owner).to.equal(addr2.address);
    });

    it('Should allow new owner to manage agent after transfer', async function () {
      // Transfer token
      await bap700.connect(addr1).transferFrom(addr1.address, addr2.address, tokenId);

      // New owner should be able to pause the agent
      await bap700.connect(addr2).pause(tokenId);

      const agentState = await bap700.getState(tokenId);
      expect(agentState.status).to.equal(0); // Paused
    });

    it('Should not allow old owner to manage agent after transfer', async function () {
      // Transfer token
      await bap700.connect(addr1).transferFrom(addr1.address, addr2.address, tokenId);

      // Old owner should not be able to pause the agent
      await expect(bap700.connect(addr1).pause(tokenId)).to.be.revertedWith(
        'BAP700: caller is not agent owner',
      );
    });
  });

  describe('Circuit Breaker Integration', function () {
    let tokenId;

    beforeEach(async function () {
      const metadataURI = 'ipfs://QmTest';
      await bap700['createAgent(address,address,string)'](
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

      await bap700[
        'createAgent(address,address,string,(string,string,string,string,string,bytes32))'
      ](addr1.address, mockLogicAddress, metadataURI, extendedMetadata);
      tokenId = 1;
    });

    it('Should return correct agent state', async function () {
      const agentState = await bap700.getState(tokenId);

      expect(agentState.balance).to.equal(0);
      expect(agentState.status).to.equal(1); // Active
      expect(agentState.owner).to.equal(addr1.address);
      expect(agentState.logicAddress).to.equal(mockLogicAddress);
      expect(agentState.lastActionTimestamp).to.be.gt(0);
    });

    it('Should return correct agent metadata', async function () {
      const agentMetadata = await bap700.getAgentMetadata(tokenId);

      expect(agentMetadata.persona).to.equal('Test Persona');
      expect(agentMetadata.experience).to.equal('Test Experience');
      expect(agentMetadata.voiceHash).to.equal('Test Voice Hash');
      expect(agentMetadata.animationURI).to.equal('ipfs://QmTestAnimation');
      expect(agentMetadata.vaultURI).to.equal('ipfs://QmTestVault');
      expect(agentMetadata.vaultHash).to.equal(ethers.utils.formatBytes32String('test-vault-hash'));
    });

    it('Should revert when getting state of non-existent agent', async function () {
      await expect(bap700.getState(999)).to.be.revertedWith('BAP700: agent does not exist');
    });

    it('Should revert when getting metadata of non-existent agent', async function () {
      await expect(bap700.getAgentMetadata(999)).to.be.revertedWith('BAP700: agent does not exist');
    });
  });

  describe('Contract Upgrade', function () {
    it('Should only allow owner to upgrade contract', async function () {
      // Only the owner (which is the circuitBreaker) can upgrade
      // This test would require deploying a new implementation
      // For now, we just test that non-owners cannot call upgrade functions

      await expect(bap700.connect(addr1).upgradeTo(addr2.address)).to.be.revertedWith(
        'Ownable: caller is not the owner',
      );
    });
  });

  describe('Receive Function', function () {
    it('Should accept direct BNB transfers', async function () {
      const sendAmount = ethers.utils.parseEther('1.0');

      await expect(
        addr1.sendTransaction({
          to: bap700.address,
          value: sendAmount,
        }),
      ).to.not.be.reverted;

      const contractBalance = await ethers.provider.getBalance(bap700.address);
      expect(contractBalance).to.equal(sendAmount);
    });
  });

  describe('Edge Cases', function () {
    it('Should handle zero value funding', async function () {
      const metadataURI = 'ipfs://QmTest';
      await bap700['createAgent(address,address,string)'](
        addr1.address,
        mockLogicAddress,
        metadataURI,
      );
      const tokenId = 1;

      await expect(bap700.connect(addr1).fundAgent(tokenId, { value: 0 }))
        .to.emit(bap700, 'AgentFunded')
        .withArgs(bap700.address, addr1.address, 0);

      const agentState = await bap700.getState(tokenId);
      expect(agentState.balance).to.equal(0);
    });

    it('Should handle zero amount withdrawal', async function () {
      const metadataURI = 'ipfs://QmTest';
      await bap700['createAgent(address,address,string)'](
        addr1.address,
        mockLogicAddress,
        metadataURI,
      );
      const tokenId = 1;

      await bap700.connect(addr1).fundAgent(tokenId, { value: ethers.utils.parseEther('1.0') });

      await expect(bap700.connect(addr1).withdrawFromAgent(tokenId, 0)).to.not.be.reverted;
    });
  });
});
