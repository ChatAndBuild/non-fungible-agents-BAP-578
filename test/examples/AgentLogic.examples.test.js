const { expect } = require('chai');
const { ethers } = require('hardhat');

/**
 * Focused tests for the example logic modules in contracts/examples/logic.
 *
 * Each contract is deployed standalone with a placeholder BAP-578 address, so
 * the tests exercise the BAP-578-relevant surface (constructor, ownership,
 * authorization, pause, getMetrics, the handleAction guard rails) without
 * needing routers, tokens, or a full agent deployment. Deep trading-path tests
 * live with the production contracts; these verify the standard interface.
 */
const CONTRACTS = [
  { name: 'HunterAgentLogic', version: '1.0.0' },
  { name: 'TradingAgentLogicV5', version: '5.0.0' },
  { name: 'CTOAgentLogic', version: '1.0.0' },
];

for (const c of CONTRACTS) {
  describe(`${c.name} (example logic module)`, function () {
    let logic, owner, placeholderBap578, stranger;

    beforeEach(async function () {
      [owner, placeholderBap578, stranger] = await ethers.getSigners();
      const Factory = await ethers.getContractFactory(c.name);
      logic = await Factory.deploy(placeholderBap578.address);
      await logic.deployed();
    });

    it('deploys with the expected name and version', async function () {
      expect(await logic.name()).to.equal(c.name);
      expect(await logic.version()).to.equal(c.version);
    });

    it('sets the deployer as owner and an authorized caller', async function () {
      expect(await logic.owner()).to.equal(owner.address);
      expect(await logic.authorizedCallers(owner.address)).to.equal(true);
    });

    it('rejects a zero address for BAP-578 in the constructor', async function () {
      const Factory = await ethers.getContractFactory(c.name);
      await expect(Factory.deploy(ethers.constants.AddressZero)).to.be.reverted;
    });

    it('pauses and unpauses', async function () {
      await logic.pause();
      expect(await logic.paused()).to.equal(true);
      await logic.unpause();
      expect(await logic.paused()).to.equal(false);
    });

    it('returns zeroed metrics for a fresh agent', async function () {
      const m = await logic.getMetrics(1);
      expect(m._totalActions).to.equal(0);
      expect(m._successfulActions).to.equal(0);
      expect(m._totalTrades).to.equal(0);
    });

    it('rejects handleAction from an unauthorized caller', async function () {
      const payload = ethers.utils.defaultAbiCoder.encode(['uint256'], [0]);
      await expect(
        logic.connect(stranger).handleAction(1, 'check_balance', payload),
      ).to.be.reverted;
    });

    it('rejects handleAction while paused', async function () {
      await logic.pause();
      const payload = ethers.utils.defaultAbiCoder.encode(['uint256'], [0]);
      await expect(logic.handleAction(1, 'check_balance', payload)).to.be.reverted;
    });
  });
}
