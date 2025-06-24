const { expect } = require('chai');
const { ethers, upgrades } = require('hardhat');

describe('BEP007 Non-Fungible Agent', function () {
  let BEP007;
  let bep007;
  let CircuitBreaker;
  let circuitBreaker;
  let MockAgentLogic;
  let mockAgentLogic;
  let owner;
  let addr1;
  let addr2;
  let addrs;

  beforeEach(async function () {
    // Get the ContractFactory and Signers
    CircuitBreaker = await ethers.getContractFactory('CircuitBreaker');
    BEP007 = await ethers.getContractFactory('BEP007');
    MockAgentLogic = await ethers.getContractFactory('MockAgentLogic');
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    // Deploy CircuitBreaker
    circuitBreaker = await upgrades.deployProxy(
      CircuitBreaker,
      [owner.address, owner.address],
      { initializer: "initialize"}
    );
    await circuitBreaker.deployed();

    // Deploy BEP007 with CircuitBreaker
    bep007 = await upgrades.deployProxy(
      BEP007,
      ["Non-Fungible Agent", "NFA", circuitBreaker.address],
      { initializer: "initialize", kind: "uups" }
    );
    await bep007.deployed();

    // Deploy MockAgentLogic
    mockAgentLogic = await MockAgentLogic.deploy(bep007.address, "Non-Fungible Agent", "NFA Description", "NFA Experience", ["capability 1"], ["domain.com"]);
    await mockAgentLogic.deployed();
  });

  describe('Deployment', function () {
    it('Should set the right owner', async function () {
      // After our security fix, ownership is transferred to governance (CircuitBreaker)
      expect(await bep007.owner()).to.equal(circuitBreaker.address);
    });

    it('Should set the right name and symbol', async function () {
      expect(await bep007.name()).to.equal('Non-Fungible Agent');
      expect(await bep007.symbol()).to.equal('NFA');
    });

    it('Should set the right circuit breaker', async function () {
      expect(await bep007.governance()).to.equal(circuitBreaker.address);
    });
  });

  describe('Agent Creation', function () {
    it('Should create an agent with the correct metadata', async function () {
      const metadataURI = 'ipfs://QmTest';
      const extendedMetadata = {
        persona: 'Test Persona',
        experience: 'Test Experience',
        voiceHash: 'Test Voice Hash',
        animationURI: 'ipfs://QmTestAnimation',
        vaultURI: 'ipfs://QmTestVault',
        vaultHash: ethers.utils.formatBytes32String('test-vault-hash'),
      };


      await bep007["createAgent(address,address,string,(string,string,string,string,string,bytes32))"](
        addr1.address,
        mockAgentLogic.address,
        metadataURI,
        extendedMetadata,
      );

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
      expect(agentState.logicAddress).to.equal(mockAgentLogic.address);
      expect(agentState.status).to.equal(1);
    });
  });

  describe('Agent Actions', function () {
    let tokenId;

    beforeEach(async function () {
      // Create an agent for testing
      const metadataURI = 'ipfs://QmTest';
      const extendedMetadata = {
        persona: 'Test Persona',
        experience: 'Test Experience',
        voiceHash: 'Test Voice Hash',
        animationURI: 'ipfs://QmTestAnimation',
        vaultURI: 'ipfs://QmTestVault',
        vaultHash: ethers.utils.formatBytes32String('test-vault-hash'),
      };

      await bep007["createAgent(address,address,string,(string,string,string,string,string,bytes32))"](
        addr1.address,
        mockAgentLogic.address,
        metadataURI,
        extendedMetadata,
      );

      tokenId = 1; // First token ID

      // Fund the agent
      await addr1.sendTransaction({
        to: bep007.address,
        value: ethers.utils.parseEther('1.0'),
      });
      await bep007.connect(addr1).fundAgent(tokenId, { value: ethers.utils.parseEther('0.5') });
    });

    it('Should execute an action successfully', async function () {
      // Encode the function call to the mock agent's startConversation method
      const data = mockAgentLogic.interface.encodeFunctionData('startConversation', [owner.address, "Topic 1"]);

      // Execute the action
      await bep007.connect(addr1).executeAction(tokenId, data);

      // Verify the action was executed (this would check a state change in a real test)
      // For this mock test, we're just ensuring it doesn't revert
    });

    it('Should update logic address', async function () {
      // Deploy a new logic contract
      const NewMockAgentLogic = await ethers.getContractFactory('MockAgentLogic');
      const newMockAgentLogic = await NewMockAgentLogic.deploy(bep007.address, "Non-Fungible Agent", "NFA", "asdf", ["asdf"], ["asdf"]);
      await newMockAgentLogic.deployed();

      // Update the logic address
      await bep007.connect(addr1).setLogicAddress(tokenId, newMockAgentLogic.address);

      // Verify the logic address was updated
      const agentState = await bep007.getState(tokenId);
      expect(agentState.logicAddress).to.equal(newMockAgentLogic.address);
    });

    it('Should update agent metadata', async function () {
      const newMetadata = {
        persona: 'Updated Persona',
        experience: 'Updated Experience',
        voiceHash: 'Updated Voice Hash',
        animationURI: 'ipfs://QmUpdatedAnimation',
        vaultURI: 'ipfs://QmUpdatedVault',
        vaultHash: ethers.utils.formatBytes32String('updated-vault-hash'),
      };

      // Update the metadata
      await bep007.connect(addr1).updateAgentMetadata(tokenId, newMetadata);

      // Verify the metadata was updated
      const agentMetadata = await bep007.getAgentMetadata(tokenId);
      expect(agentMetadata.persona).to.equal(newMetadata.persona);
      expect(agentMetadata.experience).to.equal(newMetadata.experience);
      expect(agentMetadata.voiceHash).to.equal(newMetadata.voiceHash);
      expect(agentMetadata.animationURI).to.equal(newMetadata.animationURI);
      expect(agentMetadata.vaultURI).to.equal(newMetadata.vaultURI);
      expect(agentMetadata.vaultHash).to.equal(newMetadata.vaultHash);
    });
  });

  describe('Circuit Breaker', function () {
    let tokenId;

    beforeEach(async function () {
      // Create an agent for testing
      const metadataURI = 'ipfs://QmTest';
      const extendedMetadata = {
        persona: 'Test Persona',
        experience: 'Test Experience',
        voiceHash: 'Test Voice Hash',
        animationURI: 'ipfs://QmTestAnimation',
        vaultURI: 'ipfs://QmTestVault',
        vaultHash: ethers.utils.formatBytes32String('test-vault-hash'),
      };

      await bep007["createAgent(address,address,string,(string,string,string,string,string,bytes32))"](
        addr1.address,
        mockAgentLogic.address,
        metadataURI,
        extendedMetadata,
      );

      tokenId = 1; // First token ID
    });

    it('Should pause and unpause an agent', async function () {
      // Pause the agent
      await bep007.connect(addr1).pause(tokenId);

      // Verify the agent is paused
      const agentState = await bep007.getState(tokenId);
      expect(agentState.status).to.equal(0);

      // Unpause the agent
      await bep007.connect(addr1).unpause(tokenId);

      // Verify the agent is unpaused
      const updatedAgentState = await bep007.getState(tokenId);
      expect(updatedAgentState.status).to.equal(1);
    });

    it('Should respect global circuit breaker', async function () {
      // Set global pause
      await circuitBreaker.setGlobalPause(true);

      // Try to execute an action (should fail)
      const data = mockAgentLogic.interface.encodeFunctionData('startConversation', [owner.address, "Topic 1"]);
      await expect(bep007.connect(addr1).executeAction(tokenId, data)).to.be.revertedWith(
        'CircuitBreaker: globally paused',
      );

      // Unpause
      await circuitBreaker.setGlobalPause(false);

      // Now it should work (assuming the agent is funded)
      await addr1.sendTransaction({
        to: bep007.address,
        value: ethers.utils.parseEther('1.0'),
      });
      await bep007.connect(addr1).fundAgent(tokenId, { value: ethers.utils.parseEther('0.5') });
      await bep007.connect(addr1).executeAction(tokenId, data);
    });
  });
});
