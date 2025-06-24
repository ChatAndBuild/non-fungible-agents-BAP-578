const { expect } = require('chai');
const { ethers, upgrades } = require('hardhat');
const { time } = require('@nomicfoundation/hardhat-network-helpers');

describe('BEP007Governance', function () {
  let BEP007Governance;
  let governance;
  let CircuitBreaker;
  let circuitBreaker;
  let BEP007;
  let bep007Token;
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
    BEP007Governance = await ethers.getContractFactory('BEP007Governance');
    BEP007 = await ethers.getContractFactory('BEP007');
    MockTarget = await ethers.getContractFactory('MockTarget');
    CircuitBreaker = await ethers.getContractFactory('CircuitBreaker');
    MockTarget = await ethers.getContractFactory('MockTarget');
    [owner, proposer, voter1, voter2, voter3, ...addrs] = await ethers.getSigners();

    // Deploy CircuitBreaker first
    circuitBreaker = await upgrades.deployProxy(CircuitBreaker, [owner.address, owner.address], {
      initializer: 'initialize',
    });
    await circuitBreaker.deployed();

    // Deploy BEP007 token first (needed for governance)
    bep007Token = await upgrades.deployProxy(
      BEP007,
      ['BEP007 Token', 'BEP007', circuitBreaker.address],
      { initializer: 'initialize', kind: 'uups' },
    );
    await bep007Token.deployed();

    // Deploy BEP007Governance
    governance = await upgrades.deployProxy(
      BEP007Governance,
      [
        'BEP007 Governance',
        bep007Token.address,
        owner.address,
        VOTING_PERIOD,
        QUORUM_PERCENTAGE,
        EXECUTION_DELAY,
      ],
      { initializer: 'initialize', kind: 'uups' },
    );
    await governance.deployed();

    // Deploy mock target contract for testing proposal execution
    MockTarget = await ethers.getContractFactory('MockTarget');
    mockTarget = await MockTarget.deploy();
    await mockTarget.deployed();

    // Mint some tokens to voters for testing
    // Note: BEP007 is an NFT, so we need to create agents for voting weight
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
      await bep007Token[
        'createAgent(address,address,string,(string,string,string,string,string,bytes32))'
      ](voter1.address, mockTarget.address, metadataURI, extendedMetadata);
    }

    for (let i = 0; i < 3; i++) {
      await bep007Token[
        'createAgent(address,address,string,(string,string,string,string,string,bytes32))'
      ](voter2.address, mockTarget.address, metadataURI, extendedMetadata);
    }

    for (let i = 0; i < 2; i++) {
      await bep007Token[
        'createAgent(address,address,string,(string,string,string,string,string,bytes32))'
      ](voter3.address, mockTarget.address, metadataURI, extendedMetadata);
    }
  });

  describe('Deployment', function () {
    it('Should set the correct initial parameters', async function () {
      expect(await governance.owner()).to.equal(owner.address);
      expect(await governance.bep007Token()).to.equal(bep007Token.address);
      expect(await governance.votingPeriod()).to.equal(VOTING_PERIOD);
      expect(await governance.quorumPercentage()).to.equal(QUORUM_PERCENTAGE);
      expect(await governance.executionDelay()).to.equal(EXECUTION_DELAY);
    });

    it('Should revert if initialized with invalid parameters', async function () {
      await expect(
        upgrades.deployProxy(
          BEP007Governance,
          [
            'BEP007 Governance',
            ethers.constants.AddressZero, // Invalid token address
            owner.address,
            VOTING_PERIOD,
            QUORUM_PERCENTAGE,
            EXECUTION_DELAY,
          ],
          { initializer: 'initialize', kind: 'uups' },
        ),
      ).to.be.revertedWith('BEP007Governance: token is zero address');

      await expect(
        upgrades.deployProxy(
          BEP007Governance,
          [
            'BEP007 Governance',
            bep007Token.address,
            owner.address,
            VOTING_PERIOD,
            101, // Invalid quorum percentage > 100
            EXECUTION_DELAY,
          ],
          { initializer: 'initialize', kind: 'uups' },
        ),
      ).to.be.revertedWith('BEP007Governance: quorum percentage exceeds 100');
    });
  });

  describe('Proposal Creation', function () {
    it('Should create a proposal successfully', async function () {
      const description = 'Test proposal to update mock target';
      const callData = mockTarget.interface.encodeFunctionData('setValue', [42]);

      const tx = await governance
        .connect(proposer)
        .createProposal(description, callData, mockTarget.address);

      const receipt = await tx.wait();
      const event = receipt.events?.find((e) => e.event === 'ProposalCreated');

      expect(event).to.not.be.undefined;
      expect(event.args.proposalId).to.equal(1);
      expect(event.args.proposer).to.equal(proposer.address);
      expect(event.args.description).to.equal(description);

      // Check proposal details
      const proposal = await governance.proposals(1);
      expect(proposal.id).to.equal(1);
      expect(proposal.proposer).to.equal(proposer.address);
      expect(proposal.description).to.equal(description);
      expect(proposal.targetContract).to.equal(mockTarget.address);
      expect(proposal.executed).to.be.false;
      expect(proposal.canceled).to.be.false;
    });

    it('Should revert when creating proposal with zero target address', async function () {
      const description = 'Invalid proposal';
      const callData = '0x';

      await expect(
        governance
          .connect(proposer)
          .createProposal(description, callData, ethers.constants.AddressZero),
      ).to.be.revertedWith('BEP007Governance: target is zero address');
    });
  });

  describe('Voting', function () {
    let proposalId;

    beforeEach(async function () {
      const description = 'Test proposal for voting';
      const callData = mockTarget.interface.encodeFunctionData('setValue', [100]);

      const tx = await governance
        .connect(proposer)
        .createProposal(description, callData, mockTarget.address);
      const receipt = await tx.wait();
      proposalId = receipt.events?.find((e) => e.event === 'ProposalCreated')?.args.proposalId;
    });

    it('Should allow voting with correct weight', async function () {
      // voter1 has 5 tokens, so voting weight should be 5
      const tx = await governance.connect(voter1).castVote(proposalId, true);
      const receipt = await tx.wait();
      const event = receipt.events?.find((e) => e.event === 'VoteCast');

      expect(event.args.proposalId).to.equal(proposalId);
      expect(event.args.voter).to.equal(voter1.address);
      expect(event.args.support).to.be.true;
      expect(event.args.weight).to.equal(5); // voter1 has 5 NFTs

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
        'BEP007Governance: already voted',
      );
    });

    it('Should prevent voting with zero weight', async function () {
      // Use an address that has no tokens
      await expect(governance.connect(addrs[0]).castVote(proposalId, true)).to.be.revertedWith(
        'BEP007Governance: no voting weight',
      );
    });

    it('Should prevent voting on non-existent proposal', async function () {
      await expect(governance.connect(voter1).castVote(999, true)).to.be.revertedWith(
        'BEP007Governance: proposal does not exist',
      );
    });

    it('Should prevent voting after voting period ends', async function () {
      // Fast forward past voting period
      await time.increase(time.duration.days(VOTING_PERIOD + 1));

      await expect(governance.connect(voter1).castVote(proposalId, true)).to.be.revertedWith(
        'BEP007Governance: voting period ended',
      );
    });
  });

  describe('Proposal Execution', function () {
    let proposalId;

    beforeEach(async function () {
      const description = 'Test proposal for execution';
      const callData = mockTarget.interface.encodeFunctionData('setValue', [200]);

      const tx = await governance
        .connect(proposer)
        .createProposal(description, callData, mockTarget.address);
      const receipt = await tx.wait();
      proposalId = receipt.events?.find((e) => e.event === 'ProposalCreated')?.args.proposalId;
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
      const event = receipt.events?.find((e) => e.event === 'ProposalExecuted');

      expect(event.args.proposalId).to.equal(proposalId);

      // Check that the proposal was executed
      const proposal = await governance.proposals(proposalId);
      expect(proposal.executed).to.be.true;

      // Check that the target contract was called
      expect(await mockTarget.value()).to.equal(200);
    });

    it('Should not execute proposal that failed to reach quorum', async function () {
      // Vote with insufficient votes for quorum
      await governance.connect(voter3).castVote(proposalId, true); // Only 2 votes, need at least 1 for 10% quorum

      // Fast forward past voting period and execution delay
      await time.increase(time.duration.days(VOTING_PERIOD + EXECUTION_DELAY + 1));

      // Since we have 10 total supply and 10% quorum, we need 1 vote minimum
      // voter3 has 2 votes, so this should actually pass
      // Let's create a scenario where quorum is not met by using higher quorum
      await governance.connect(owner).updateVotingParameters(VOTING_PERIOD, 50, EXECUTION_DELAY); // 50% quorum

      await expect(governance.executeProposal(proposalId)).to.be.revertedWith(
        'BEP007Governance: quorum not reached',
      );
    });

    it('Should not execute proposal that was rejected', async function () {
      // Vote against the proposal
      await governance.connect(voter1).castVote(proposalId, false); // 5 votes against
      await governance.connect(voter2).castVote(proposalId, true); // 3 votes for

      // Fast forward past voting period and execution delay
      await time.increase(time.duration.days(VOTING_PERIOD + EXECUTION_DELAY + 1));

      await expect(governance.executeProposal(proposalId)).to.be.revertedWith(
        'BEP007Governance: proposal rejected',
      );
    });

    it('Should not execute proposal before voting period ends', async function () {
      await governance.connect(voter1).castVote(proposalId, true);

      await expect(governance.executeProposal(proposalId)).to.be.revertedWith(
        'BEP007Governance: voting period not ended',
      );
    });

    it('Should not execute proposal before execution delay passes', async function () {
      await governance.connect(voter1).castVote(proposalId, true);

      // Fast forward past voting period but not execution delay
      await time.increase(time.duration.days(VOTING_PERIOD + 1));

      await expect(governance.executeProposal(proposalId)).to.be.revertedWith(
        'BEP007Governance: execution delay not passed',
      );
    });

    it('Should not execute already executed proposal', async function () {
      await governance.connect(voter1).castVote(proposalId, true);
      await time.increase(time.duration.days(VOTING_PERIOD + EXECUTION_DELAY + 1));

      // Execute once
      await governance.executeProposal(proposalId);

      // Try to execute again
      await expect(governance.executeProposal(proposalId)).to.be.revertedWith(
        'BEP007Governance: proposal already executed',
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
        .createProposal(description, callData, mockTarget.address);
      const receipt = await tx.wait();
      proposalId = receipt.events?.find((e) => e.event === 'ProposalCreated')?.args.proposalId;
    });

    it('Should allow proposer to cancel their proposal', async function () {
      const tx = await governance.connect(proposer).cancelProposal(proposalId);
      const receipt = await tx.wait();
      const event = receipt.events?.find((e) => e.event === 'ProposalCanceled');

      expect(event.args.proposalId).to.equal(proposalId);

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
        'BEP007Governance: not proposer or owner',
      );
    });

    it('Should not cancel already executed proposal', async function () {
      await governance.connect(voter1).castVote(proposalId, true);
      await time.increase(time.duration.days(VOTING_PERIOD + EXECUTION_DELAY + 1));
      await governance.executeProposal(proposalId);

      await expect(governance.connect(proposer).cancelProposal(proposalId)).to.be.revertedWith(
        'BEP007Governance: proposal already executed',
      );
    });

    it('Should not vote on canceled proposal', async function () {
      await governance.connect(proposer).cancelProposal(proposalId);

      await expect(governance.connect(voter1).castVote(proposalId, true)).to.be.revertedWith(
        'BEP007Governance: proposal canceled',
      );
    });
  });

  describe('Administrative Functions', function () {
    it('Should allow owner to set treasury', async function () {
      const newTreasury = addrs[0].address;

      const tx = await governance.connect(owner).setTreasury(newTreasury);
      const receipt = await tx.wait();
      const event = receipt.events?.find((e) => e.event === 'TreasuryUpdated');

      expect(event.args.newTreasury).to.equal(newTreasury);
      expect(await governance.treasury()).to.equal(newTreasury);
    });

    it('Should not allow non-owner to set treasury', async function () {
      await expect(governance.connect(voter1).setTreasury(addrs[0].address)).to.be.revertedWith(
        'Ownable: caller is not the owner',
      );
    });

    it('Should not allow setting treasury to zero address', async function () {
      await expect(
        governance.connect(owner).setTreasury(ethers.constants.AddressZero),
      ).to.be.revertedWith('BEP007Governance: treasury is zero address');
    });

    it('Should allow owner to set agent factory', async function () {
      const newFactory = addrs[1].address;

      await governance.connect(owner).setAgentFactory(newFactory);
      expect(await governance.agentFactory()).to.equal(newFactory);
    });

    it('Should allow owner to update voting parameters', async function () {
      const newVotingPeriod = 14;
      const newQuorumPercentage = 20;
      const newExecutionDelay = 3;

      const tx = await governance
        .connect(owner)
        .updateVotingParameters(newVotingPeriod, newQuorumPercentage, newExecutionDelay);
      const receipt = await tx.wait();
      const event = receipt.events?.find((e) => e.event === 'VotingParametersUpdated');

      expect(event.args[0]).to.equal(newVotingPeriod);
      expect(event.args[1]).to.equal(newQuorumPercentage);
      expect(event.args[2]).to.equal(newExecutionDelay);

      expect(await governance.votingPeriod()).to.equal(newVotingPeriod);
      expect(await governance.quorumPercentage()).to.equal(newQuorumPercentage);
      expect(await governance.executionDelay()).to.equal(newExecutionDelay);
    });

    it('Should not allow setting quorum percentage above 100', async function () {
      await expect(
        governance.connect(owner).updateVotingParameters(VOTING_PERIOD, 101, EXECUTION_DELAY),
      ).to.be.revertedWith('BEP007Governance: quorum percentage exceeds 100');
    });
  });

  describe('Edge Cases', function () {
    it('Should handle proposal with empty call data', async function () {
      const description = 'Empty call data proposal';
      const callData = '0x';

      await governance.connect(proposer).createProposal(description, callData, mockTarget.address);

      // Should not revert during creation
      const proposal = await governance.proposals(1);
      expect(proposal.description).to.equal(description);
    });

    it('Should handle multiple proposals correctly', async function () {
      const description1 = 'First proposal';
      const description2 = 'Second proposal';
      const callData = mockTarget.interface.encodeFunctionData('setValue', [1]);

      await governance.connect(proposer).createProposal(description1, callData, mockTarget.address);
      await governance.connect(voter1).createProposal(description2, callData, mockTarget.address);

      const proposal1 = await governance.proposals(1);
      const proposal2 = await governance.proposals(2);

      expect(proposal1.description).to.equal(description1);
      expect(proposal1.proposer).to.equal(proposer.address);
      expect(proposal2.description).to.equal(description2);
      expect(proposal2.proposer).to.equal(voter1.address);
    });

    it('Should handle zero quorum percentage', async function () {
      await governance.connect(owner).updateVotingParameters(VOTING_PERIOD, 0, EXECUTION_DELAY);

      const description = 'Zero quorum test';
      const callData = mockTarget.interface.encodeFunctionData('setValue', [999]);

      const tx = await governance
        .connect(proposer)
        .createProposal(description, callData, mockTarget.address);
      const receipt = await tx.wait();
      const proposalId = receipt.events?.find((e) => e.event === 'ProposalCreated')?.args
        .proposalId;

      // Even with zero votes, should pass if no opposition
      await time.increase(time.duration.days(VOTING_PERIOD + EXECUTION_DELAY + 1));


      // This should fail because we need at least one vote for
      await expect(governance.executeProposal(proposalId)).to.be.revertedWith(
        'BEP007Governance: proposal rejected',
      );
    });
  });
});
