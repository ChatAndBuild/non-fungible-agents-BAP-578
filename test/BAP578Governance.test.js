const { expect } = require('chai');
const { ethers, upgrades } = require('hardhat');
const { time } = require('@nomicfoundation/hardhat-network-helpers');

describe('BAP578Governance', function () {
  let BAP578Governance;
  let governance;
  let CircuitBreaker;
  let circuitBreaker;
  let BAP578;
  let bap578Token;
  let MockTarget;
  let mockTarget;
  let owner;
  let proposer;
  let voter1;
  let voter2;
  let voter3;
  let addrs;

  const VOTING_PERIOD = 7; // 7 days
  const QUORUM_PERCENTAGE = 10; // 10%
  const EXECUTION_DELAY = 2; // 2 days

  beforeEach(async function () {
    // Get the ContractFactory and Signers
    BAP578Governance = await ethers.getContractFactory('BAP578Governance');
    BAP578 = await ethers.getContractFactory('BAP578');
    CircuitBreaker = await ethers.getContractFactory('CircuitBreaker');
    MockTarget = await ethers.getContractFactory('MockTarget');
    [owner, proposer, voter1, voter2, voter3, ...addrs] = await ethers.getSigners();

    // Deploy CircuitBreaker first
    circuitBreaker = await upgrades.deployProxy(CircuitBreaker, [owner.address, owner.address], {
      initializer: 'initialize',
    });
    await circuitBreaker.deployed();

    // Deploy BAP578 token first (needed for governance)
    bap578Token = await upgrades.deployProxy(
      BAP578,
      ['BAP578 Token', 'BAP578', await circuitBreaker.address],
      { initializer: 'initialize', kind: 'uups' },
    );
    await bap578Token.deployed();

    // Deploy BAP578Governance - note the correct parameter order
    governance = await upgrades.deployProxy(
      BAP578Governance,
      [
        await bap578Token.address,
        owner.address,
        VOTING_PERIOD,
        QUORUM_PERCENTAGE,
        EXECUTION_DELAY,
      ],
      { initializer: 'initialize', kind: 'uups' },
    );
    await governance.deployed();

    // Deploy mock target contract for testing proposal execution
    mockTarget = await MockTarget.deploy();
    await mockTarget.deployed();

    // Mint some tokens to voters for testing
    // Note: BAP578 is an NFT, so we need to create agents for voting weight
    const metadataURI = 'ipfs://QmTest';
    const extendedMetadata = {
      persona: 'Test Persona',
      experience: 'Test Experience',
      voiceHash: 'Test Voice Hash',
      animationURI: 'ipfs://QmTestAnimation',
      vaultURI: 'ipfs://QmTestVault',
      vaultHash: ethers.utils.formatBytes32String('test-vault-hash'),
    };

    // Create multiple agents for different voters to simulate voting weight
    for (let i = 0; i < 5; i++) {
      await bap578Token[
        'createAgent(address,address,string,(string,string,string,string,string,bytes32))'
      ](voter1.address, await mockTarget.address, metadataURI, extendedMetadata);
    }

    for (let i = 0; i < 3; i++) {
      await bap578Token[
        'createAgent(address,address,string,(string,string,string,string,string,bytes32))'
      ](voter2.address, await mockTarget.address, metadataURI, extendedMetadata);
    }

    for (let i = 0; i < 2; i++) {
      await bap578Token[
        'createAgent(address,address,string,(string,string,string,string,string,bytes32))'
      ](voter3.address, await mockTarget.address, metadataURI, extendedMetadata);
    }
  });

  describe('Deployment', function () {
    it('Should set the correct initial parameters', async function () {
      expect(await governance.owner()).to.equal(owner.address);
      expect(await governance.bap578Token()).to.equal(await bap578Token.address);
      expect(await governance.votingPeriod()).to.equal(VOTING_PERIOD);
      expect(await governance.quorumPercentage()).to.equal(QUORUM_PERCENTAGE);
      expect(await governance.executionDelay()).to.equal(EXECUTION_DELAY);
    });

  });

  describe('Proposal Creation', function () {
    it('Should create a proposal successfully', async function () {
      const description = 'Test proposal to update mock target';
      const callData = mockTarget.interface.encodeFunctionData('setValue', [42]);

      const tx = await governance
        .connect(proposer)
        .createProposal(description, callData, await mockTarget.address);

      const receipt = await tx.wait();
      const event = receipt.logs.find(log => {
        try {
          return governance.interface.parseLog(log).name === 'ProposalCreated';
        } catch {
          return false;
        }
      });

      expect(event).to.not.be.undefined;
      const parsedEvent = governance.interface.parseLog(event);
      expect(parsedEvent.args.proposalId).to.equal(1);
      expect(parsedEvent.args.proposer).to.equal(proposer.address);
      expect(parsedEvent.args.description).to.equal(description);

      // Check proposal details
      const proposal = await governance.proposals(1);
      expect(proposal.id).to.equal(1);
      expect(proposal.proposer).to.equal(proposer.address);
      expect(proposal.description).to.equal(description);
      expect(proposal.targetContract).to.equal(await mockTarget.address);
      expect(proposal.executed).to.be.false;
      expect(proposal.canceled).to.be.false;
    });

    it('Should increment proposal ID correctly', async function () {
      const description1 = 'First proposal';
      const description2 = 'Second proposal';
      const callData = mockTarget.interface.encodeFunctionData('setValue', [42]);

      await governance
        .connect(proposer)
        .createProposal(description1, callData, await mockTarget.address);
      
      await governance
        .connect(proposer)
        .createProposal(description2, callData, await mockTarget.address);

      const proposal1 = await governance.proposals(1);
      const proposal2 = await governance.proposals(2);

      expect(proposal1.id).to.equal(1);
      expect(proposal2.id).to.equal(2);
      expect(proposal1.description).to.equal(description1);
      expect(proposal2.description).to.equal(description2);
    });

    it('Should allow empty call data', async function () {
      const description = 'Proposal with empty call data';
      const callData = '0x';

      await expect(
        governance
          .connect(proposer)
          .createProposal(description, callData, await mockTarget.address)
      ).to.not.be.reverted;
    });
  });

  describe('Voting', function () {
    let proposalId;

    beforeEach(async function () {
      const description = 'Test proposal for voting';
      const callData = mockTarget.interface.encodeFunctionData('setValue', [100]);

      const tx = await governance
        .connect(proposer)
        .createProposal(description, callData, await mockTarget.address);
      const receipt = await tx.wait();
      const event = receipt.logs.find(log => {
        try {
          return governance.interface.parseLog(log).name === 'ProposalCreated';
        } catch {
          return false;
        }
      });
      proposalId = governance.interface.parseLog(event).args.proposalId;
    });

    it('Should allow voting with correct weight', async function () {
      // voter1 has 5 tokens, so voting weight should be 5
      const tx = await governance.connect(voter1).castVote(proposalId, true);
      const receipt = await tx.wait();
      const event = receipt.logs.find(log => {
        try {
          return governance.interface.parseLog(log).name === 'VoteCast';
        } catch {
          return false;
        }
      });

      const parsedEvent = governance.interface.parseLog(event);
      expect(parsedEvent.args.proposalId).to.equal(proposalId);
      expect(parsedEvent.args.voter).to.equal(voter1.address);
      expect(parsedEvent.args.support).to.be.true;
      expect(parsedEvent.args.weight).to.equal(5); // voter1 has 5 NFTs

      const proposal = await governance.proposals(proposalId);
      expect(proposal.votesFor).to.equal(5);
      expect(proposal.votesAgainst).to.equal(0);
    });

    it('Should allow voting against', async function () {
      await governance.connect(voter2).castVote(proposalId, false);

      const proposal = await governance.proposals(proposalId);
      expect(proposal.votesFor).to.equal(0);
      expect(proposal.votesAgainst).to.equal(3); // voter2 has 3 NFTs
    });

    it('Should prevent double voting', async function () {
      await governance.connect(voter1).castVote(proposalId, true);

      await expect(governance.connect(voter1).castVote(proposalId, true)).to.be.revertedWith(
        'BAP578Governance: already voted',
      );
    });

    it('Should prevent voting with zero weight', async function () {
      // Use an address that has no tokens
      await expect(governance.connect(addrs[0]).castVote(proposalId, true)).to.be.revertedWith(
        'BAP578Governance: no voting weight',
      );
    });

    it('Should prevent voting on non-existent proposal', async function () {
      await expect(governance.connect(voter1).castVote(999, true)).to.be.revertedWith(
        'BAP578Governance: proposal does not exist',
      );
    });

    it('Should prevent voting after voting period ends', async function () {
      // Fast forward past voting period
      await time.increase(time.duration.days(VOTING_PERIOD + 1));

      await expect(governance.connect(voter1).castVote(proposalId, true)).to.be.revertedWith(
        'BAP578Governance: voting period ended',
      );
    });

    it('Should track multiple votes correctly', async function () {
      await governance.connect(voter1).castVote(proposalId, true); // 5 votes for
      await governance.connect(voter2).castVote(proposalId, false); // 3 votes against
      await governance.connect(voter3).castVote(proposalId, true); // 2 votes for

      const proposal = await governance.proposals(proposalId);
      expect(proposal.votesFor).to.equal(7); // 5 + 2
      expect(proposal.votesAgainst).to.equal(3);
    });
  });

  describe('Proposal Execution', function () {
    let proposalId;

    beforeEach(async function () {
      const description = 'Test proposal for execution';
      const callData = mockTarget.interface.encodeFunctionData('setValue', [200]);

      const tx = await governance
        .connect(proposer)
        .createProposal(description, callData, await mockTarget.address);
      const receipt = await tx.wait();
      const event = receipt.logs.find(log => {
        try {
          return governance.interface.parseLog(log).name === 'ProposalCreated';
        } catch {
          return false;
        }
      });
      proposalId = governance.interface.parseLog(event).args.proposalId;
    });

    it('Should execute a successful proposal', async function () {
      // Vote in favor with enough votes to meet quorum
      await governance.connect(voter1).castVote(proposalId, true); // 5 votes
      await governance.connect(voter2).castVote(proposalId, true); // 3 votes
      // Total: 8 votes, total supply: 10, quorum: 10% = 1 vote (minimum)

      // Fast forward past voting period and execution delay
      await time.increase(time.duration.days(VOTING_PERIOD + EXECUTION_DELAY + 1));

      // Execute the proposal
      const tx = await governance.executeProposal(proposalId);
      const receipt = await tx.wait();
      const event = receipt.logs.find(log => {
        try {
          return governance.interface.parseLog(log).name === 'ProposalExecuted';
        } catch {
          return false;
        }
      });

      const parsedEvent = governance.interface.parseLog(event);
      expect(parsedEvent.args.proposalId).to.equal(proposalId);

      // Check that the proposal was executed
      const proposal = await governance.proposals(proposalId);
      expect(proposal.executed).to.be.true;

      // Check that the target contract was called
      expect(await mockTarget.value()).to.equal(200);
    });

    it('Should not execute proposal that failed to reach quorum', async function () {
      // First update to higher quorum to test this scenario
      await governance.connect(owner).updateVotingParameters(VOTING_PERIOD, 50, EXECUTION_DELAY); // 50% quorum

      // Vote with insufficient votes for quorum
      await governance.connect(voter3).castVote(proposalId, true); // Only 2 votes, need 5 for 50% quorum

      // Fast forward past voting period and execution delay
      await time.increase(time.duration.days(VOTING_PERIOD + EXECUTION_DELAY + 1));

      await expect(governance.executeProposal(proposalId)).to.be.revertedWith(
        'BAP578Governance: quorum not reached',
      );
    });

    it('Should not execute proposal that was rejected', async function () {
      // Vote against the proposal
      await governance.connect(voter1).castVote(proposalId, false); // 5 votes against
      await governance.connect(voter2).castVote(proposalId, true); // 3 votes for

      // Fast forward past voting period and execution delay
      await time.increase(time.duration.days(VOTING_PERIOD + EXECUTION_DELAY + 1));

      await expect(governance.executeProposal(proposalId)).to.be.revertedWith(
        'BAP578Governance: proposal rejected',
      );
    });

    it('Should not execute proposal before voting period ends', async function () {
      await governance.connect(voter1).castVote(proposalId, true);

      await expect(governance.executeProposal(proposalId)).to.be.revertedWith(
        'BAP578Governance: voting period not ended',
      );
    });

    it('Should not execute proposal before execution delay passes', async function () {
      await governance.connect(voter1).castVote(proposalId, true);

      // Fast forward past voting period but not execution delay
      await time.increase(time.duration.days(VOTING_PERIOD + 1));

      await expect(governance.executeProposal(proposalId)).to.be.revertedWith(
        'BAP578Governance: execution delay not passed',
      );
    });

    it('Should not execute already executed proposal', async function () {
      await governance.connect(voter1).castVote(proposalId, true);
      await time.increase(time.duration.days(VOTING_PERIOD + EXECUTION_DELAY + 1));

      // Execute once
      await governance.executeProposal(proposalId);

      // Try to execute again
      await expect(governance.executeProposal(proposalId)).to.be.revertedWith(
        'BAP578Governance: proposal already executed',
      );
    });

    it('Should not execute non-existent proposal', async function () {
      await expect(governance.executeProposal(999)).to.be.revertedWith(
        'BAP578Governance: proposal does not exist',
      );
    });

    it('Should handle execution failure gracefully', async function () {
      // Create a proposal that will fail during execution
      const description = 'Failing proposal';
      const callData = '0x12345678'; // Invalid call data

      const tx = await governance
        .connect(proposer)
        .createProposal(description, callData, await mockTarget.address);
      const receipt = await tx.wait();
      const event = receipt.logs.find(log => {
        try {
          return governance.interface.parseLog(log).name === 'ProposalCreated';
        } catch {
          return false;
        }
      });
      const failingProposalId = governance.interface.parseLog(event).args.proposalId;

      // Vote and wait
      await governance.connect(voter1).castVote(failingProposalId, true);
      await time.increase(time.duration.days(VOTING_PERIOD + EXECUTION_DELAY + 1));

      // Should revert with execution failed
      await expect(governance.executeProposal(failingProposalId)).to.be.revertedWith(
        'BAP578Governance: execution failed',
      );
    });
  });

  describe('Proposal Cancellation', function () {
    let proposalId;

    beforeEach(async function () {
      const description = 'Test proposal for cancellation';
      const callData = mockTarget.interface.encodeFunctionData('setValue', [300]);

      const tx = await governance
        .connect(proposer)
        .createProposal(description, callData, await mockTarget.address);
      const receipt = await tx.wait();
      const event = receipt.logs.find(log => {
        try {
          return governance.interface.parseLog(log).name === 'ProposalCreated';
        } catch {
          return false;
        }
      });
      proposalId = governance.interface.parseLog(event).args.proposalId;
    });

    it('Should allow proposer to cancel their proposal', async function () {
      const tx = await governance.connect(proposer).cancelProposal(proposalId);
      const receipt = await tx.wait();
      const event = receipt.logs.find(log => {
        try {
          return governance.interface.parseLog(log).name === 'ProposalCanceled';
        } catch {
          return false;
        }
      });

      const parsedEvent = governance.interface.parseLog(event);
      expect(parsedEvent.args.proposalId).to.equal(proposalId);

      const proposal = await governance.proposals(proposalId);
      expect(proposal.canceled).to.be.true;
    });

    it('Should allow owner to cancel any proposal', async function () {
      await governance.connect(owner).cancelProposal(proposalId);

      const proposal = await governance.proposals(proposalId);
      expect(proposal.canceled).to.be.true;
    });

    it('Should not allow others to cancel proposal', async function () {
      await expect(governance.connect(voter1).cancelProposal(proposalId)).to.be.revertedWith(
        'BAP578Governance: not proposer or owner',
      );
    });

    it('Should not cancel already executed proposal', async function () {
      await governance.connect(voter1).castVote(proposalId, true);
      await time.increase(time.duration.days(VOTING_PERIOD + EXECUTION_DELAY + 1));
      await governance.executeProposal(proposalId);

      await expect(governance.connect(proposer).cancelProposal(proposalId)).to.be.revertedWith(
        'BAP578Governance: proposal already executed',
      );
    });

    it('Should not vote on canceled proposal', async function () {
      await governance.connect(proposer).cancelProposal(proposalId);

      await expect(governance.connect(voter1).castVote(proposalId, true)).to.be.revertedWith(
        'BAP578Governance: proposal canceled',
      );
    });

    it('Should not cancel non-existent proposal', async function () {
      await expect(governance.connect(proposer).cancelProposal(999)).to.be.revertedWith(
        'BAP578Governance: proposal does not exist',
      );
    });

    it('Should not cancel already canceled proposal', async function () {
      await governance.connect(proposer).cancelProposal(proposalId);

      await expect(governance.connect(proposer).cancelProposal(proposalId)).to.be.revertedWith(
        'BAP578Governance: proposal already canceled',
      );
    });
  });

  describe('Administrative Functions', function () {
    it('Should allow owner to set agent factory', async function () {
      const newFactory = addrs[1].address;

      const tx = await governance.connect(owner).setAgentFactory(newFactory);
      const receipt = await tx.wait();
      const event = receipt.logs.find(log => {
        try {
          return governance.interface.parseLog(log).name === 'AgentFactoryUpdated';
        } catch {
          return false;
        }
      });

      const parsedEvent = governance.interface.parseLog(event);
      expect(parsedEvent.args.newAgentFactory).to.equal(newFactory);
      expect(await governance.agentFactory()).to.equal(newFactory);
    });

    it('Should not allow non-owner to set agent factory', async function () {
      await expect(governance.connect(voter1).setAgentFactory(addrs[0].address)).to.be.revertedWith(
        'Ownable: caller is not the owner',
      );
    });

    it('Should allow owner to update voting parameters', async function () {
      const newVotingPeriod = 14;
      const newQuorumPercentage = 20;
      const newExecutionDelay = 3;

      const tx = await governance
        .connect(owner)
        .updateVotingParameters(newVotingPeriod, newQuorumPercentage, newExecutionDelay);
      const receipt = await tx.wait();
      const event = receipt.logs.find(log => {
        try {
          return governance.interface.parseLog(log).name === 'VotingParametersUpdated';
        } catch {
          return false;
        }
      });

      const parsedEvent = governance.interface.parseLog(event);
      expect(parsedEvent.args[0]).to.equal(newVotingPeriod);
      expect(parsedEvent.args[1]).to.equal(newQuorumPercentage);
      expect(parsedEvent.args[2]).to.equal(newExecutionDelay);

      expect(await governance.votingPeriod()).to.equal(newVotingPeriod);
      expect(await governance.quorumPercentage()).to.equal(newQuorumPercentage);
      expect(await governance.executionDelay()).to.equal(newExecutionDelay);
    });

    it('Should not allow setting quorum percentage above 100', async function () {
      await expect(
        governance.connect(owner).updateVotingParameters(VOTING_PERIOD, 101, EXECUTION_DELAY),
      ).to.be.revertedWith('BAP578Governance: quorum percentage exceeds 100');
    });

    it('Should not allow non-owner to update voting parameters', async function () {
      await expect(
        governance.connect(voter1).updateVotingParameters(14, 20, 3),
      ).to.be.revertedWith('Ownable: caller is not the owner');
    });
  });

  describe('UUPS Upgrade Functions', function () {
    it('Should allow owner to upgrade contract', async function () {
      // This test verifies the upgrade authorization works
      // In a real scenario, you would deploy a new implementation
      await expect(governance.connect(owner).upgradeTo(await governance.address)).to.not.be.reverted;
    });

    it('Should not allow non-owner to upgrade contract', async function () {
      await expect(
        governance.connect(voter1).upgradeTo(await governance.address)
      ).to.be.revertedWith('Ownable: caller is not the owner');
    });

    it('Should allow owner to upgrade and call', async function () {
      const data = '0x';
      await expect(
        governance.connect(owner).upgradeToAndCall(await governance.address, data)
      ).to.not.be.reverted;
    });

    it('Should not allow non-owner to upgrade and call', async function () {
      const data = '0x';
      await expect(
        governance.connect(voter1).upgradeToAndCall(await governance.address, data)
      ).to.be.revertedWith('Ownable: caller is not the owner');
    });
  });

  describe('Edge Cases and Complex Scenarios', function () {
    it('Should handle proposal with empty call data', async function () {
      const description = 'Empty call data proposal';
      const callData = '0x';

      await governance.connect(proposer).createProposal(description, callData, await mockTarget.address);

      // Should not revert during creation
      const proposal = await governance.proposals(1);
      expect(proposal.description).to.equal(description);
    });

    it('Should handle multiple proposals correctly', async function () {
      const description1 = 'First proposal';
      const description2 = 'Second proposal';
      const callData = mockTarget.interface.encodeFunctionData('setValue', [1]);

      await governance.connect(proposer).createProposal(description1, callData, await mockTarget.address);
      await governance.connect(voter1).createProposal(description2, callData, await mockTarget.address);

      const proposal1 = await governance.proposals(1);
      const proposal2 = await governance.proposals(2);

      expect(proposal1.description).to.equal(description1);
      expect(proposal1.proposer).to.equal(proposer.address);
      expect(proposal2.description).to.equal(description2);
      expect(proposal2.proposer).to.equal(voter1.address);
    });

    it('Should handle zero quorum percentage correctly', async function () {
      await governance.connect(owner).updateVotingParameters(VOTING_PERIOD, 0, EXECUTION_DELAY);

      const description = 'Zero quorum test';
      const callData = mockTarget.interface.encodeFunctionData('setValue', [999]);

      const tx = await governance
        .connect(proposer)
        .createProposal(description, callData, await mockTarget.address);
      const receipt = await tx.wait();
      const event = receipt.logs.find(log => {
        try {
          return governance.interface.parseLog(log).name === 'ProposalCreated';
        } catch {
          return false;
        }
      });
      const proposalId = governance.interface.parseLog(event).args.proposalId;

      // Vote for with minimal votes
      await governance.connect(voter3).castVote(proposalId, true); // 2 votes

      await time.increase(time.duration.days(VOTING_PERIOD + EXECUTION_DELAY + 1));

      // Should execute successfully with zero quorum
      await expect(governance.executeProposal(proposalId)).to.not.be.reverted;
      expect(await mockTarget.value()).to.equal(999);
    });

    it('Should handle tie votes correctly', async function () {
      const description = 'Tie vote test';
      const callData = mockTarget.interface.encodeFunctionData('setValue', [500]);

      const tx = await governance
        .connect(proposer)
        .createProposal(description, callData, await mockTarget.address);
      const receipt = await tx.wait();
      const event = receipt.logs.find(log => {
        try {
          return governance.interface.parseLog(log).name === 'ProposalCreated';
        } catch {
          return false;
        }
      });
      const proposalId = governance.interface.parseLog(event).args.proposalId;

      // Create a tie: 5 votes for, 5 votes against
      await governance.connect(voter1).castVote(proposalId, true); // 5 votes for
      await governance.connect(voter2).castVote(proposalId, false); // 3 votes against
      await governance.connect(voter3).castVote(proposalId, false); // 2 votes against (total 5 against)

      await time.increase(time.duration.days(VOTING_PERIOD + EXECUTION_DELAY + 1));

      // Tie should be rejected (not more votes for than against)
      await expect(governance.executeProposal(proposalId)).to.be.revertedWith(
        'BAP578Governance: proposal rejected',
      );
    });

    it('Should handle very long descriptions', async function () {
      const longDescription = 'A'.repeat(1000);
      const callData = mockTarget.interface.encodeFunctionData('setValue', [123]);

      await expect(
        governance.connect(proposer).createProposal(longDescription, callData, await mockTarget.address)
      ).to.not.be.reverted;

      const proposal = await governance.proposals(1);
      expect(proposal.description).to.equal(longDescription);
    });

    it('Should handle proposal execution with complex call data', async function () {
      // Test multiple function calls in sequence
      const description = 'Complex proposal with multiple calls';
      const callData1 = mockTarget.interface.encodeFunctionData('setValue', [777]);
      const callData2 = mockTarget.interface.encodeFunctionData('pause', []);

      // Create first proposal
      const tx1 = await governance
        .connect(proposer)
        .createProposal(description + ' - setValue', callData1, await mockTarget.address);
      const receipt1 = await tx1.wait();
      const event1 = receipt1.logs.find(log => {
        try {
          return governance.interface.parseLog(log).name === 'ProposalCreated';
        } catch {
          return false;
        }
      });
      const proposalId1 = governance.interface.parseLog(event1).args.proposalId;

     

      // Vote and execute first proposal
      await governance.connect(voter1).castVote(proposalId1, true);
      await time.increase(time.duration.days(VOTING_PERIOD + EXECUTION_DELAY + 10));
      await governance.executeProposal(proposalId1);

      // Check first execution result
      expect(await mockTarget.value()).to.equal(777);

       // Create second proposal
      const tx2 = await governance
        .connect(proposer)
        .createProposal(description + ' - pause', callData2, await mockTarget.address);
      const receipt2 = await tx2.wait();
      const event2 = receipt2.logs.find(log => {
        try {
          return governance.interface.parseLog(log).name === 'ProposalCreated';
        } catch {
          return false;
        }
      });
      const proposalId2 = governance.interface.parseLog(event2).args.proposalId;
      
      // Vote and execute second proposal
      await governance.connect(voter1).castVote(proposalId2, true);
      await time.increase(time.duration.days(VOTING_PERIOD + EXECUTION_DELAY + 10));
      await governance.executeProposal(proposalId2);

      // Check second execution result
      expect(await mockTarget.paused()).to.be.true;
    });

    it('Should handle timestamp edge cases', async function () {
      const description = 'Timestamp edge case test';
      const callData = mockTarget.interface.encodeFunctionData('setValue', [888]);

      const tx = await governance
        .connect(proposer)
        .createProposal(description, callData, await mockTarget.address);
      const receipt = await tx.wait();
      const event = receipt.logs.find(log => {
        try {
          return governance.interface.parseLog(log).name === 'ProposalCreated';
        } catch {
          return false;
        }
      });
      const proposalId = governance.interface.parseLog(event).args.proposalId;

      // Vote
      await governance.connect(voter1).castVote(proposalId, true);

      // Fast forward to exactly the end of voting period
      await time.increase(time.duration.days(VOTING_PERIOD));

      // Should not be able to execute yet (need execution delay)
      await expect(governance.executeProposal(proposalId)).to.be.revertedWith(
        'BAP578Governance: execution delay not passed',
      );

      // Fast forward to exactly when execution delay passes
      await time.increase(time.duration.days(EXECUTION_DELAY));

      // Should be able to execute now
      await expect(governance.executeProposal(proposalId)).to.not.be.reverted;
    });
  });

  describe('Gas Optimization Tests', function () {
    it('Should handle large number of voters efficiently', async function () {
      const description = 'Large voter test';
      const callData = mockTarget.interface.encodeFunctionData('setValue', [1000]);

      const tx = await governance
        .connect(proposer)
        .createProposal(description, callData, await mockTarget.address);
      const receipt = await tx.wait();
      const event = receipt.logs.find(log => {
        try {
          return governance.interface.parseLog(log).name === 'ProposalCreated';
        } catch {
          return false;
        }
      });
      const proposalId = governance.interface.parseLog(event).args.proposalId;

      // All voters vote
      await governance.connect(voter1).castVote(proposalId, true);
      await governance.connect(voter2).castVote(proposalId, true);
      await governance.connect(voter3).castVote(proposalId, true);

      const proposal = await governance.proposals(proposalId);
      expect(proposal.votesFor).to.equal(10); // 5 + 3 + 2 = 10 total votes
    });
  });
});
