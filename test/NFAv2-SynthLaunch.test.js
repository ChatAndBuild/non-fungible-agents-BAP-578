const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('NFAv2 (SynthLaunch community implementation)', function () {
  let nfa;
  let approvedLogic;
  let secondLogic;
  let owner;
  let user1;
  let user2;
  let treasury;

  const MINT_PRICE = ethers.utils.parseEther('0.05');

  beforeEach(async function () {
    [owner, user1, user2, treasury] = await ethers.getSigners();

    const NFAv2 = await ethers.getContractFactory('NFAv2');
    nfa = await NFAv2.deploy(treasury.address);
    await nfa.deployed();

    // Deploy two disposable contracts to use as "logic" addresses
    // (any deployed contract with code is fine for approveLogic's bytecode check)
    const FakeLogic = await ethers.getContractFactory('NFAv2');
    approvedLogic = await FakeLogic.deploy(treasury.address);
    await approvedLogic.deployed();
    secondLogic = await FakeLogic.deploy(treasury.address);
    await secondLogic.deployed();
  });

  // ============ Deployment ============
  describe('Deployment', function () {
    it('sets the correct name and symbol', async function () {
      expect(await nfa.name()).to.equal('Non-Fungible Agent');
      expect(await nfa.symbol()).to.equal('NFA');
    });

    it('sets the deployer as owner', async function () {
      expect(await nfa.owner()).to.equal(owner.address);
    });

    it('sets the correct treasury', async function () {
      expect(await nfa.treasury()).to.equal(treasury.address);
    });

    it('reverts when treasury is zero address', async function () {
      const NFAv2 = await ethers.getContractFactory('NFAv2');
      await expect(NFAv2.deploy(ethers.constants.AddressZero)).to.be.revertedWithCustomError(
        nfa,
        'TreasuryZero'
      );
    });
  });

  // ============ Logic Allowlist (admin) ============
  describe('Logic Allowlist — admin', function () {
    it('owner can approve a contract address', async function () {
      await expect(nfa.approveLogic(approvedLogic.address, 'audit-ref-1'))
        .to.emit(nfa, 'LogicApproved')
        .withArgs(approvedLogic.address, 'audit-ref-1');

      expect(await nfa.approvedLogic(approvedLogic.address)).to.equal(true);
      expect(await nfa.approvedLogicCount()).to.equal(1);
    });

    it('rejects zero address', async function () {
      await expect(
        nfa.approveLogic(ethers.constants.AddressZero, 'x')
      ).to.be.revertedWithCustomError(nfa, 'ZeroAddressNotAllowed');
    });

    it('rejects EOA (no bytecode)', async function () {
      await expect(nfa.approveLogic(user1.address, 'x')).to.be.revertedWith('Logic must be a contract');
    });

    it('rejects double-approve of same address', async function () {
      await nfa.approveLogic(approvedLogic.address, 'r1');
      await expect(
        nfa.approveLogic(approvedLogic.address, 'r2')
      ).to.be.revertedWithCustomError(nfa, 'LogicAlreadyApproved');
    });

    it('non-owner cannot approve', async function () {
      await expect(
        nfa.connect(user1).approveLogic(approvedLogic.address, 'x')
      ).to.be.revertedWith('Ownable: caller is not the owner');
    });

    it('owner can revoke an approved logic', async function () {
      await nfa.approveLogic(approvedLogic.address, 'r1');

      await expect(nfa.revokeLogic(approvedLogic.address, 'compromised'))
        .to.emit(nfa, 'LogicRevoked')
        .withArgs(approvedLogic.address, 'compromised');

      expect(await nfa.approvedLogic(approvedLogic.address)).to.equal(false);
      expect(await nfa.approvedLogicCount()).to.equal(0);
    });

    it('revoke removes address from list (swap-and-pop)', async function () {
      await nfa.approveLogic(approvedLogic.address, 'a');
      await nfa.approveLogic(secondLogic.address, 'b');
      expect(await nfa.approvedLogicCount()).to.equal(2);

      await nfa.revokeLogic(approvedLogic.address, 'x');

      expect(await nfa.approvedLogicCount()).to.equal(1);
      const list = await nfa.getApprovedLogicList();
      expect(list).to.have.lengthOf(1);
      expect(list[0]).to.equal(secondLogic.address);
    });

    it('rejects revoke of non-approved address', async function () {
      await expect(
        nfa.revokeLogic(approvedLogic.address, 'x')
      ).to.be.revertedWithCustomError(nfa, 'LogicNotInList');
    });

    it('isLogicApproved returns true for zero address (disabled state)', async function () {
      expect(await nfa.isLogicApproved(ethers.constants.AddressZero)).to.equal(true);
    });
  });

  // ============ Minting ============
  describe('Minting', function () {
    it('mints with address(0) logic (no logic attached)', async function () {
      await expect(
        nfa
          .connect(user1)
          .mintAgent('alice', 'ipfs://p', 'ipfs://v', 'ipfs://a', ethers.constants.AddressZero, 'ipfs://meta', {
            value: MINT_PRICE,
          })
      ).to.emit(nfa, 'AgentMinted');

      expect(await nfa.totalMinted()).to.equal(1);
      expect(await nfa.ownerOf(0)).to.equal(user1.address);
    });

    it('mints with an approved logic address', async function () {
      await nfa.approveLogic(approvedLogic.address, 'audit-1');

      await nfa
        .connect(user1)
        .mintAgent('bob', 'ipfs://p', 'ipfs://v', 'ipfs://a', approvedLogic.address, 'ipfs://meta', {
          value: MINT_PRICE,
        });

      const [, logic] = await nfa.getAgentDetails(0);
      expect(logic).to.equal(approvedLogic.address);
    });

    it('reverts when minting with a non-approved logic address', async function () {
      await expect(
        nfa
          .connect(user1)
          .mintAgent('carol', 'ipfs://p', 'ipfs://v', 'ipfs://a', approvedLogic.address, 'ipfs://meta', {
            value: MINT_PRICE,
          })
      ).to.be.revertedWithCustomError(nfa, 'LogicNotApproved');
    });

    it('reverts when underpaid', async function () {
      await expect(
        nfa
          .connect(user1)
          .mintAgent('dave', 'ipfs://p', 'ipfs://v', 'ipfs://a', ethers.constants.AddressZero, 'ipfs://meta', {
            value: ethers.utils.parseEther('0.01'),
          })
      ).to.be.revertedWithCustomError(nfa, 'InsufficientPayment');
    });

    it('rejects duplicate normalized names', async function () {
      await nfa
        .connect(user1)
        .mintAgent('Alice', 'p', 'v', 'a', ethers.constants.AddressZero, 'm', { value: MINT_PRICE });
      await expect(
        nfa
          .connect(user2)
          .mintAgent('ALICE', 'p', 'v', 'a', ethers.constants.AddressZero, 'm', { value: MINT_PRICE })
      ).to.be.revertedWithCustomError(nfa, 'NameTaken');
    });

    it('refunds excess payment and sends only MINT_PRICE to treasury', async function () {
      const excess = ethers.utils.parseEther('0.02');
      const treasuryBefore = await ethers.provider.getBalance(treasury.address);
      await nfa
        .connect(user1)
        .mintAgent('eve', 'p', 'v', 'a', ethers.constants.AddressZero, 'm', {
          value: MINT_PRICE.add(excess),
        });
      const treasuryAfter = await ethers.provider.getBalance(treasury.address);
      // Treasury receives exactly MINT_PRICE (excess refunded to caller)
      expect(treasuryAfter.sub(treasuryBefore)).to.equal(MINT_PRICE);
      // Contract should hold nothing
      expect(await ethers.provider.getBalance(nfa.address)).to.equal(0);
    });
  });

  // ============ setLogicAddress ============
  describe('setLogicAddress', function () {
    beforeEach(async function () {
      await nfa.approveLogic(approvedLogic.address, 'audit-1');
      await nfa
        .connect(user1)
        .mintAgent('alpha', 'p', 'v', 'a', ethers.constants.AddressZero, 'm', { value: MINT_PRICE });
    });

    it('owner can set approved logic', async function () {
      await expect(nfa.connect(user1).setLogicAddress(0, approvedLogic.address))
        .to.emit(nfa, 'AgentLogicUpdated')
        .withArgs(0, approvedLogic.address);
    });

    it('owner can clear logic by passing address(0)', async function () {
      await nfa.connect(user1).setLogicAddress(0, approvedLogic.address);
      await nfa.connect(user1).setLogicAddress(0, ethers.constants.AddressZero);
      const [, logic] = await nfa.getAgentDetails(0);
      expect(logic).to.equal(ethers.constants.AddressZero);
    });

    it('reverts when setting non-approved logic', async function () {
      await expect(
        nfa.connect(user1).setLogicAddress(0, secondLogic.address)
      ).to.be.revertedWithCustomError(nfa, 'LogicNotApproved');
    });

    it('only agent owner can setLogicAddress', async function () {
      await expect(
        nfa.connect(user2).setLogicAddress(0, approvedLogic.address)
      ).to.be.revertedWithCustomError(nfa, 'NotAgentOwner');
    });
  });

  // ============ Revocation + validAgentLogic modifier ============
  describe('Logic revocation propagation', function () {
    beforeEach(async function () {
      await nfa.approveLogic(approvedLogic.address, 'audit-1');
      await nfa
        .connect(user1)
        .mintAgent('beta', 'p', 'v', 'a', approvedLogic.address, 'm', { value: MINT_PRICE });
    });

    it('agent is valid while its logic is approved', async function () {
      expect(await nfa.isAgentLogicValid(0)).to.equal(true);
    });

    it('agent becomes invalid once logic is revoked', async function () {
      await nfa.revokeLogic(approvedLogic.address, 'compromised');
      expect(await nfa.isAgentLogicValid(0)).to.equal(false);
    });

    it('fundAgent reverts when agent is using revoked logic', async function () {
      await nfa.revokeLogic(approvedLogic.address, 'compromised');
      await expect(
        nfa.connect(user2).fundAgent(0, { value: ethers.utils.parseEther('0.1') })
      ).to.be.revertedWithCustomError(nfa, 'AgentUsingRevokedLogic');
    });

    it('evolve reverts when agent is using revoked logic', async function () {
      await nfa.revokeLogic(approvedLogic.address, 'compromised');
      await expect(nfa.connect(user1).evolve(0, 100)).to.be.revertedWithCustomError(
        nfa,
        'AgentUsingRevokedLogic'
      );
    });

    it('agent recovers when owner sets a new approved logic', async function () {
      await nfa.revokeLogic(approvedLogic.address, 'compromised');
      await nfa.approveLogic(secondLogic.address, 'audit-2');
      await nfa.connect(user1).setLogicAddress(0, secondLogic.address);
      expect(await nfa.isAgentLogicValid(0)).to.equal(true);
    });

    it('agent recovers when owner clears logic to address(0)', async function () {
      await nfa.revokeLogic(approvedLogic.address, 'compromised');
      await nfa.connect(user1).setLogicAddress(0, ethers.constants.AddressZero);
      expect(await nfa.isAgentLogicValid(0)).to.equal(true);
    });
  });

  // ============ forceResetLogic ============
  describe('forceResetLogic (admin emergency)', function () {
    beforeEach(async function () {
      await nfa.approveLogic(approvedLogic.address, 'audit-1');
      await nfa
        .connect(user1)
        .mintAgent('gamma', 'p', 'v', 'a', approvedLogic.address, 'm', { value: MINT_PRICE });
    });

    it('emits AgentLogicForceReset with tokenId + old logic + reason', async function () {
      // This emits the dedicated per-agent reset event, not LogicRevoked.
      // Indexers can rebuild the global allowlist from LogicApproved/LogicRevoked
      // alone without being misled by agent-level resets.
      await expect(nfa.forceResetLogic(0, 'emergency'))
        .to.emit(nfa, 'AgentLogicForceReset')
        .withArgs(0, approvedLogic.address, 'emergency');
    });

    it('does NOT emit LogicRevoked (that event is reserved for global allowlist changes)', async function () {
      await expect(nfa.forceResetLogic(0, 'emergency')).to.not.emit(nfa, 'LogicRevoked');
    });

    it('leaves the global allowlist untouched — approvedLogic[oldLogic] stays true', async function () {
      // This is the key invariant the P1 fix guarantees. A force-reset of one
      // agent must not implicitly remove the logic from the global allowlist,
      // otherwise re-approveLogic would revert with LogicAlreadyApproved despite
      // indexers believing it was revoked.
      expect(await nfa.approvedLogic(approvedLogic.address)).to.equal(true);
      await nfa.forceResetLogic(0, 'emergency');
      expect(await nfa.approvedLogic(approvedLogic.address)).to.equal(true);
      // Re-approving would fail if the allowlist were implicitly touched:
      await expect(
        nfa.approveLogic(approvedLogic.address, 're-approve attempt')
      ).to.be.revertedWithCustomError(nfa, 'LogicAlreadyApproved');
    });

    it('also emits AgentLogicUpdated to address(0)', async function () {
      await expect(nfa.forceResetLogic(0, 'emergency'))
        .to.emit(nfa, 'AgentLogicUpdated')
        .withArgs(0, ethers.constants.AddressZero);
    });

    it('only owner can forceResetLogic', async function () {
      await expect(nfa.connect(user1).forceResetLogic(0, 'x')).to.be.revertedWith(
        'Ownable: caller is not the owner'
      );
    });
  });

  // ============ Funding / evolution (happy path sanity) ============
  describe('Funding & evolution (happy path)', function () {
    beforeEach(async function () {
      await nfa
        .connect(user1)
        .mintAgent('fund', 'p', 'v', 'a', ethers.constants.AddressZero, 'm', { value: MINT_PRICE });
    });

    it('fundAgent deducts platform fee and credits the rest to agent balance', async function () {
      const amount = ethers.utils.parseEther('1');
      const feeBps = await nfa.platformFeeBps();
      const fee = amount.mul(feeBps).div(10000);
      const net = amount.sub(fee);

      await nfa.connect(user2).fundAgent(0, { value: amount });
      const [, , , , , balance] = await nfa.getAgentDetails(0);
      expect(balance).to.equal(net);
    });

    it('evolve raises level when XP crosses XP_PER_LEVEL', async function () {
      await nfa.connect(user1).evolve(0, 500);
      const [, , , , , , xp, level] = await nfa.getAgentDetails(0);
      expect(xp).to.equal(500);
      expect(level).to.equal(2);
    });
  });

  // ============ Ownership / safety ============
  describe('Ownership safety', function () {
    it('renounceOwnership is disabled', async function () {
      await expect(nfa.renounceOwnership()).to.be.revertedWith('Disabled');
    });

    it('direct ETH transfer is rejected', async function () {
      await expect(
        user1.sendTransaction({ to: nfa.address, value: ethers.utils.parseEther('0.1') })
      ).to.be.revertedWithCustomError(nfa, 'DirectReceiveDisabled');
    });
  });
});
