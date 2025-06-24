const { expect } = require('chai');
const { ethers, upgrades } = require('hardhat');

describe('BEP007Treasury', function () {
  let BEP007Treasury;
  let treasury;
  let owner;
  let governance;
  let agentFactory;
  let foundationWallet;
  let treasuryWallet;
  let stakingPoolWallet;
  let user1;
  let user2;
  let addrs;

  const PROTOCOL_MINTING_FEE = ethers.utils.parseEther('0.01'); // 0.01 BNB
  const FOUNDATION_PERCENTAGE = 6000; // 60%
  const TREASURY_PERCENTAGE = 2500; // 25%
  const STAKING_PERCENTAGE = 1500; // 15%

  beforeEach(async function () {
    // Get the ContractFactory and Signers
    BEP007Treasury = await ethers.getContractFactory('BEP007Treasury');
    [owner, governance, agentFactory, foundationWallet, treasuryWallet, stakingPoolWallet, user1, user2, ...addrs] = await ethers.getSigners();

    // Deploy BEP007Treasury
    treasury = await upgrades.deployProxy(
      BEP007Treasury,
      [
        governance.address,
        agentFactory.address,
        foundationWallet.address,
        treasuryWallet.address,
        stakingPoolWallet.address
      ],
      { initializer: "initialize" }
    );
    await treasury.deployed();
  });

  describe('Deployment', function () {
    it('Should set the correct initial parameters', async function () {
      expect(await treasury.owner()).to.equal(owner.address);
      expect(await treasury.governance()).to.equal(governance.address);
      expect(await treasury.agentFactory()).to.equal(agentFactory.address);
      expect(await treasury.foundationWallet()).to.equal(foundationWallet.address);
      expect(await treasury.treasuryWallet()).to.equal(treasuryWallet.address);
      expect(await treasury.stakingPoolWallet()).to.equal(stakingPoolWallet.address);
    });

    it('Should set the correct protocol fee and percentages', async function () {
      expect(await treasury.getProtocolFee()).to.equal(PROTOCOL_MINTING_FEE);
      
      const [foundationPercentage, treasuryPercentage, stakingPercentage] = await treasury.getDistributionPercentages();
      expect(foundationPercentage).to.equal(FOUNDATION_PERCENTAGE);
      expect(treasuryPercentage).to.equal(TREASURY_PERCENTAGE);
      expect(stakingPercentage).to.equal(STAKING_PERCENTAGE);
    });

    it('Should initialize with zero fee statistics', async function () {
      const [totalCollected, foundationTotal, treasuryTotal, stakingTotal, pendingBalance] = await treasury.getFeeStatistics();
      expect(totalCollected).to.equal(0);
      expect(foundationTotal).to.equal(0);
      expect(treasuryTotal).to.equal(0);
      expect(stakingTotal).to.equal(0);
      expect(pendingBalance).to.equal(0);
    });

    it('Should initialize with emergency controls disabled', async function () {
      const [feeCollectionPaused, distributionPaused] = await treasury.getEmergencyStatus();
      expect(feeCollectionPaused).to.be.false;
      expect(distributionPaused).to.be.false;
    });

    it('Should revert if initialized with zero addresses', async function () {
      await expect(
        upgrades.deployProxy(
          BEP007Treasury,
          [
            ethers.constants.AddressZero, // governance
            agentFactory.address,
            foundationWallet.address,
            treasuryWallet.address,
            stakingPoolWallet.address
          ],
          { initializer: "initialize" }
        )
      ).to.be.revertedWith('BEP007Treasury: governance is zero address');

      await expect(
        upgrades.deployProxy(
          BEP007Treasury,
          [
            governance.address,
            ethers.constants.AddressZero, // agentFactory
            foundationWallet.address,
            treasuryWallet.address,
            stakingPoolWallet.address
          ],
          { initializer: "initialize" }
        )
      ).to.be.revertedWith('BEP007Treasury: agent factory is zero address');

      await expect(
        upgrades.deployProxy(
          BEP007Treasury,
          [
            governance.address,
            agentFactory.address,
            ethers.constants.AddressZero, // foundationWallet
            treasuryWallet.address,
            stakingPoolWallet.address
          ],
          { initializer: "initialize" }
        )
      ).to.be.revertedWith('BEP007Treasury: foundation wallet is zero address');
    });
  });

  describe('Protocol Fee Collection', function () {
    it('Should collect protocol fee and distribute correctly', async function () {
      const initialFoundationBalance = await foundationWallet.getBalance();
      const initialTreasuryBalance = await treasuryWallet.getBalance();
      const initialStakingBalance = await stakingPoolWallet.getBalance();

      const tx = await treasury.connect(agentFactory).collectProtocolFee(user1.address, {
        value: PROTOCOL_MINTING_FEE
      });

      const receipt = await tx.wait();
      const event = receipt.events?.find(e => e.event === 'ProtocolFeeCollected');

      expect(event).to.not.be.undefined;
      expect(event.args.payer).to.equal(user1.address);
      expect(event.args.totalFee).to.equal(PROTOCOL_MINTING_FEE);

      // Calculate expected distribution
      const expectedFoundationAmount = PROTOCOL_MINTING_FEE.mul(FOUNDATION_PERCENTAGE).div(10000);
      const expectedTreasuryAmount = PROTOCOL_MINTING_FEE.mul(TREASURY_PERCENTAGE).div(10000);
      const expectedStakingAmount = PROTOCOL_MINTING_FEE.mul(STAKING_PERCENTAGE).div(10000);

      expect(event.args.foundationAmount).to.equal(expectedFoundationAmount);
      expect(event.args.treasuryAmount).to.equal(expectedTreasuryAmount);
      expect(event.args.stakingAmount).to.equal(expectedStakingAmount);

      // Check balances were updated
      const finalFoundationBalance = await foundationWallet.getBalance();
      const finalTreasuryBalance = await treasuryWallet.getBalance();
      const finalStakingBalance = await stakingPoolWallet.getBalance();

      expect(finalFoundationBalance.sub(initialFoundationBalance)).to.equal(expectedFoundationAmount);
      expect(finalTreasuryBalance.sub(initialTreasuryBalance)).to.equal(expectedTreasuryAmount);
      expect(finalStakingBalance.sub(initialStakingBalance)).to.equal(expectedStakingAmount);

      // Check fee statistics
      const [totalCollected, foundationTotal, treasuryTotal, stakingTotal] = await treasury.getFeeStatistics();
      expect(totalCollected).to.equal(PROTOCOL_MINTING_FEE);
      expect(foundationTotal).to.equal(expectedFoundationAmount);
      expect(treasuryTotal).to.equal(expectedTreasuryAmount);
      expect(stakingTotal).to.equal(expectedStakingAmount);
    });

    it('Should revert if incorrect fee amount is sent', async function () {
      const incorrectFee = ethers.utils.parseEther('0.005'); // Wrong amount

      await expect(
        treasury.connect(agentFactory).collectProtocolFee(user1.address, {
          value: incorrectFee
        })
      ).to.be.revertedWith('BEP007Treasury: incorrect protocol fee');
    });

    it('Should revert if called by non-agent factory', async function () {
      await expect(
        treasury.connect(user1).collectProtocolFee(user1.address, {
          value: PROTOCOL_MINTING_FEE
        })
      ).to.be.revertedWith('BEP007Treasury: caller is not agent factory');
    });

    it('Should revert if minter address is zero', async function () {
      await expect(
        treasury.connect(agentFactory).collectProtocolFee(ethers.constants.AddressZero, {
          value: PROTOCOL_MINTING_FEE
        })
      ).to.be.revertedWith('BEP007Treasury: minter is zero address');
    });

    it('Should handle multiple fee collections correctly', async function () {
      // Collect fees multiple times
      await treasury.connect(agentFactory).collectProtocolFee(user1.address, {
        value: PROTOCOL_MINTING_FEE
      });

      await treasury.connect(agentFactory).collectProtocolFee(user2.address, {
        value: PROTOCOL_MINTING_FEE
      });

      // Check accumulated statistics
      const [totalCollected, foundationTotal, treasuryTotal, stakingTotal] = await treasury.getFeeStatistics();
      expect(totalCollected).to.equal(PROTOCOL_MINTING_FEE.mul(2));
      
      const expectedFoundationTotal = PROTOCOL_MINTING_FEE.mul(2).mul(FOUNDATION_PERCENTAGE).div(10000);
      const expectedTreasuryTotal = PROTOCOL_MINTING_FEE.mul(2).mul(TREASURY_PERCENTAGE).div(10000);
      const expectedStakingTotal = PROTOCOL_MINTING_FEE.mul(2).mul(STAKING_PERCENTAGE).div(10000);

      expect(foundationTotal).to.equal(expectedFoundationTotal);
      expect(treasuryTotal).to.equal(expectedTreasuryTotal);
      expect(stakingTotal).to.equal(expectedStakingTotal);
    });
  });

  describe('Fee Distribution', function () {
    beforeEach(async function () {
      // Pause distribution to accumulate fees
      await treasury.connect(governance).setDistributionPaused(true);
    });

    it('Should distribute pending fees manually', async function () {
      // Collect some fees while distribution is paused
      await treasury.connect(agentFactory).collectProtocolFee(user1.address, {
        value: PROTOCOL_MINTING_FEE
      });

      await treasury.connect(agentFactory).collectProtocolFee(user2.address, {
        value: PROTOCOL_MINTING_FEE
      });

      // Check contract has pending balance
      const [, , , , pendingBalance] = await treasury.getFeeStatistics();
      expect(pendingBalance).to.equal(PROTOCOL_MINTING_FEE.mul(2));

      // Record initial balances
      const initialFoundationBalance = await foundationWallet.getBalance();
      const initialTreasuryBalance = await treasuryWallet.getBalance();
      const initialStakingBalance = await stakingPoolWallet.getBalance();

      // Unpause distribution and distribute pending fees
      await treasury.connect(governance).setDistributionPaused(false);
      
      const tx = await treasury.connect(governance).distributePendingFees();
      const receipt = await tx.wait();
      const event = receipt.events?.find(e => e.event === 'FeeDistributionExecuted');

      expect(event).to.not.be.undefined;

      // Check balances were updated
      const finalFoundationBalance = await foundationWallet.getBalance();
      const finalTreasuryBalance = await treasuryWallet.getBalance();
      const finalStakingBalance = await stakingPoolWallet.getBalance();

      const totalFees = PROTOCOL_MINTING_FEE.mul(2);
      const expectedFoundationAmount = totalFees.mul(FOUNDATION_PERCENTAGE).div(10000);
      const expectedTreasuryAmount = totalFees.mul(TREASURY_PERCENTAGE).div(10000);
      const expectedStakingAmount = totalFees.mul(STAKING_PERCENTAGE).div(10000);

      expect(finalFoundationBalance.sub(initialFoundationBalance)).to.equal(expectedFoundationAmount);
      expect(finalTreasuryBalance.sub(initialTreasuryBalance)).to.equal(expectedTreasuryAmount);
      expect(finalStakingBalance.sub(initialStakingBalance)).to.equal(expectedStakingAmount);

      // Contract should have no pending balance
      const [, , , , finalPendingBalance] = await treasury.getFeeStatistics();
      expect(finalPendingBalance).to.equal(0);
    });

    it('Should revert if no pending fees to distribute', async function () {
      await treasury.connect(governance).setDistributionPaused(false);
      
      await expect(
        treasury.connect(governance).distributePendingFees()
      ).to.be.revertedWith('BEP007Treasury: no pending fees to distribute');
    });

    it('Should revert if distribution is paused', async function () {
      // Add some fees
      await treasury.connect(agentFactory).collectProtocolFee(user1.address, {
        value: PROTOCOL_MINTING_FEE
      });

      // Try to distribute while paused
      await expect(
        treasury.connect(governance).distributePendingFees()
      ).to.be.revertedWith('BEP007Treasury: distribution is paused');
    });

    it('Should revert if called by non-governance', async function () {
      await treasury.connect(governance).setDistributionPaused(false);
      
      await expect(
        treasury.connect(user1).distributePendingFees()
      ).to.be.revertedWith('BEP007Treasury: caller is not governance');
    });
  });

  describe('Wallet Management', function () {
    it('Should update foundation wallet', async function () {
      const newFoundationWallet = addrs[0].address;
      
      await treasury.connect(governance).setFoundationWallet(newFoundationWallet);
      expect(await treasury.foundationWallet()).to.equal(newFoundationWallet);
    });

    it('Should update treasury wallet', async function () {
      const newTreasuryWallet = addrs[1].address;
      
      await treasury.connect(governance).setTreasuryWallet(newTreasuryWallet);
      expect(await treasury.treasuryWallet()).to.equal(newTreasuryWallet);
    });

    it('Should update staking pool wallet', async function () {
      const newStakingPoolWallet = addrs[2].address;
      
      await treasury.connect(governance).setStakingPoolWallet(newStakingPoolWallet);
      expect(await treasury.stakingPoolWallet()).to.equal(newStakingPoolWallet);
    });

    it('Should update all wallets at once', async function () {
      const newFoundation = addrs[0].address;
      const newTreasury = addrs[1].address;
      const newStaking = addrs[2].address;

      await treasury.connect(governance).updateAllWallets(newFoundation, newTreasury, newStaking);

      expect(await treasury.foundationWallet()).to.equal(newFoundation);
      expect(await treasury.treasuryWallet()).to.equal(newTreasury);
      expect(await treasury.stakingPoolWallet()).to.equal(newStaking);
    });

    it('Should revert when setting zero address wallets', async function () {
      await expect(
        treasury.connect(governance).setFoundationWallet(ethers.constants.AddressZero)
      ).to.be.revertedWith('BEP007Treasury: foundation wallet is zero address');

      await expect(
        treasury.connect(governance).setTreasuryWallet(ethers.constants.AddressZero)
      ).to.be.revertedWith('BEP007Treasury: treasury wallet is zero address');

      await expect(
        treasury.connect(governance).setStakingPoolWallet(ethers.constants.AddressZero)
      ).to.be.revertedWith('BEP007Treasury: staking wallet is zero address');
    });

    it('Should revert when setting same wallet address', async function () {
      await expect(
        treasury.connect(governance).setFoundationWallet(foundationWallet.address)
      ).to.be.revertedWith('BEP007Treasury: same foundation wallet');

      await expect(
        treasury.connect(governance).setTreasuryWallet(treasuryWallet.address)
      ).to.be.revertedWith('BEP007Treasury: same treasury wallet');

      await expect(
        treasury.connect(governance).setStakingPoolWallet(stakingPoolWallet.address)
      ).to.be.revertedWith('BEP007Treasury: same staking wallet');
    });

    it('Should revert if called by non-governance', async function () {
      await expect(
        treasury.connect(user1).setFoundationWallet(addrs[0].address)
      ).to.be.revertedWith('BEP007Treasury: caller is not governance');
    });
  });

  describe('Agent Factory Management', function () {
    it('Should update agent factory address', async function () {
      const newAgentFactory = addrs[0].address;
      
      const tx = await treasury.connect(governance).setAgentFactory(newAgentFactory);
      const receipt = await tx.wait();
      const event = receipt.events?.find(e => e.event === 'AgentFactoryUpdated');

      expect(event.args.oldFactory).to.equal(agentFactory.address);
      expect(event.args.newFactory).to.equal(newAgentFactory);

      expect(await treasury.agentFactory()).to.equal(newAgentFactory);
    });

    it('Should revert when setting zero address agent factory', async function () {
      await expect(
        treasury.connect(governance).setAgentFactory(ethers.constants.AddressZero)
      ).to.be.revertedWith('BEP007Treasury: agent factory is zero address');
    });

    it('Should revert when setting same agent factory', async function () {
      await expect(
        treasury.connect(governance).setAgentFactory(agentFactory.address)
      ).to.be.revertedWith('BEP007Treasury: same agent factory');
    });

    it('Should revert if called by non-governance', async function () {
      await expect(
        treasury.connect(user1).setAgentFactory(addrs[0].address)
      ).to.be.revertedWith('BEP007Treasury: caller is not governance');
    });
  });

  describe('Governance Management', function () {
    it('Should update governance address', async function () {
      const newGovernance = addrs[0].address;
      
      await treasury.connect(owner).setGovernance(newGovernance);
      expect(await treasury.governance()).to.equal(newGovernance);
    });

    it('Should revert when setting zero address governance', async function () {
      await expect(
        treasury.connect(owner).setGovernance(ethers.constants.AddressZero)
      ).to.be.revertedWith('BEP007Treasury: governance is zero address');
    });

    it('Should revert when setting same governance', async function () {
      await expect(
        treasury.connect(owner).setGovernance(governance.address)
      ).to.be.revertedWith('BEP007Treasury: same governance');
    });

    it('Should revert if called by non-owner', async function () {
      await expect(
        treasury.connect(user1).setGovernance(addrs[0].address)
      ).to.be.revertedWith('Ownable: caller is not the owner');
    });
  });

  describe('Emergency Controls', function () {
    it('Should pause and unpause fee collection', async function () {
      // Pause fee collection
      const tx1 = await treasury.connect(governance).setFeeCollectionPaused(true);
      const receipt1 = await tx1.wait();
      const event1 = receipt1.events?.find(e => e.event === 'EmergencyControlUpdated');

      expect(event1.args.controlType).to.equal('feeCollection');
      expect(event1.args.status).to.be.true;

      const [feeCollectionPaused] = await treasury.getEmergencyStatus();
      expect(feeCollectionPaused).to.be.true;

      // Try to collect fee while paused
      await expect(
        treasury.connect(agentFactory).collectProtocolFee(user1.address, {
          value: PROTOCOL_MINTING_FEE
        })
      ).to.be.revertedWith('BEP007Treasury: fee collection is paused');

      // Unpause fee collection
      await treasury.connect(governance).setFeeCollectionPaused(false);
      
      const [feeCollectionUnpaused] = await treasury.getEmergencyStatus();
      expect(feeCollectionUnpaused).to.be.false;

      // Should work now
      await treasury.connect(agentFactory).collectProtocolFee(user1.address, {
        value: PROTOCOL_MINTING_FEE
      });
    });

    it('Should pause and unpause distribution', async function () {
      // Pause distribution
      await treasury.connect(governance).setDistributionPaused(true);
      
      const [, distributionPaused] = await treasury.getEmergencyStatus();
      expect(distributionPaused).to.be.true;

      // Collect fee (should work but not distribute)
      await treasury.connect(agentFactory).collectProtocolFee(user1.address, {
        value: PROTOCOL_MINTING_FEE
      });

      // Check contract has pending balance
      const [, , , , pendingBalance] = await treasury.getFeeStatistics();
      expect(pendingBalance).to.equal(PROTOCOL_MINTING_FEE);

      // Unpause distribution
      await treasury.connect(governance).setDistributionPaused(false);
      
      const [, distributionUnpaused] = await treasury.getEmergencyStatus();
      expect(distributionUnpaused).to.be.false;
    });

    it('Should revert when setting same pause state', async function () {
      await expect(
        treasury.connect(governance).setFeeCollectionPaused(false)
      ).to.be.revertedWith('BEP007Treasury: same pause state');

      await expect(
        treasury.connect(governance).setDistributionPaused(false)
      ).to.be.revertedWith('BEP007Treasury: same pause state');
    });

    it('Should revert if called by non-governance', async function () {
      await expect(
        treasury.connect(user1).setFeeCollectionPaused(true)
      ).to.be.revertedWith('BEP007Treasury: caller is not governance');

      await expect(
        treasury.connect(user1).setDistributionPaused(true)
      ).to.be.revertedWith('BEP007Treasury: caller is not governance');
    });
  });

  describe('Emergency Withdrawal', function () {
    beforeEach(async function () {
      // Pause distribution to keep funds in contract
      await treasury.connect(governance).setDistributionPaused(true);
      
      // Add some funds to the contract
      await treasury.connect(agentFactory).collectProtocolFee(user1.address, {
        value: PROTOCOL_MINTING_FEE
      });
    });

    it('Should allow emergency withdrawal by governance', async function () {
      const withdrawAmount = ethers.utils.parseEther('0.005');
      const recipient = addrs[0].address;
      const reason = "Emergency maintenance";

      const initialRecipientBalance = await ethers.provider.getBalance(recipient);
      
      const tx = await treasury.connect(governance).emergencyWithdraw(
        recipient,
        withdrawAmount,
        reason
      );

      const receipt = await tx.wait();
      const event = receipt.events?.find(e => e.event === 'FundsWithdrawn');

      expect(event.args.recipient).to.equal(recipient);
      expect(event.args.amount).to.equal(withdrawAmount);
      expect(event.args.reason).to.equal(reason);

      const finalRecipientBalance = await ethers.provider.getBalance(recipient);
      expect(finalRecipientBalance.sub(initialRecipientBalance)).to.equal(withdrawAmount);
    });

    it('Should revert emergency withdrawal with invalid parameters', async function () {
      const withdrawAmount = ethers.utils.parseEther('0.005');

      // Zero recipient
      await expect(
        treasury.connect(governance).emergencyWithdraw(
          ethers.constants.AddressZero,
          withdrawAmount,
          "Test reason"
        )
      ).to.be.revertedWith('BEP007Treasury: recipient is zero address');

      // Zero amount
      await expect(
        treasury.connect(governance).emergencyWithdraw(
          addrs[0].address,
          0,
          "Test reason"
        )
      ).to.be.revertedWith('BEP007Treasury: amount is zero');

      // Amount exceeds balance
      const excessiveAmount = ethers.utils.parseEther('1.0');
      await expect(
        treasury.connect(governance).emergencyWithdraw(
          addrs[0].address,
          excessiveAmount,
          "Test reason"
        )
      ).to.be.revertedWith('BEP007Treasury: insufficient balance');

      // Empty reason - test with smaller amount first
      const smallAmount = ethers.utils.parseEther('0.001');
      await expect(
        treasury.connect(governance).emergencyWithdraw(
          addrs[0].address,
          smallAmount,
          ""
        )
      ).to.be.revertedWith('BEP007Treasury: reason required');
    });

    it('Should revert if called by non-governance', async function () {
      await expect(
        treasury.connect(user1).emergencyWithdraw(
          addrs[0].address,
          ethers.utils.parseEther('0.005'),
          "Unauthorized withdrawal"
        )
      ).to.be.revertedWith('BEP007Treasury: caller is not governance');
    });
  });

  describe('View Functions', function () {
    it('Should return correct entity wallets', async function () {
      const [foundation, treasuryAddr, staking] = await treasury.getEntityWallets();
      
      expect(foundation).to.equal(foundationWallet.address);
      expect(treasuryAddr).to.equal(treasuryWallet.address);
      expect(staking).to.equal(stakingPoolWallet.address);
    });

    it('Should calculate distribution correctly', async function () {
      const testAmount = ethers.utils.parseEther('1.0');
      
      const [foundationAmount, treasuryAmount, stakingAmount] = await treasury.calculateDistribution(testAmount);
      
      const expectedFoundation = testAmount.mul(FOUNDATION_PERCENTAGE).div(10000);
      const expectedTreasury = testAmount.mul(TREASURY_PERCENTAGE).div(10000);
      const expectedStaking = testAmount.mul(STAKING_PERCENTAGE).div(10000);

      expect(foundationAmount).to.equal(expectedFoundation);
      expect(treasuryAmount).to.equal(expectedTreasury);
      expect(stakingAmount).to.equal(expectedStaking);

      // Check total equals input (with rounding handling)
      const total = foundationAmount.add(treasuryAmount).add(stakingAmount);
      expect(total).to.equal(testAmount);
    });

    it('Should handle rounding in distribution calculation', async function () {
      // Use an amount that doesn't divide evenly
      const testAmount = ethers.utils.parseEther('0.0123');
      
      const [foundationAmount, treasuryAmount, stakingAmount] = await treasury.calculateDistribution(testAmount);
      
      // Total should still equal input amount
      const total = foundationAmount.add(treasuryAmount).add(stakingAmount);
      expect(total).to.equal(testAmount);
    });
  });

  describe('Receive Function', function () {
    it('Should accept direct BNB transfers', async function () {
      const sendAmount = ethers.utils.parseEther('0.1');
      
      const initialBalance = await ethers.provider.getBalance(treasury.address);
      
      await user1.sendTransaction({
        to: treasury.address,
        value: sendAmount
      });

      const finalBalance = await ethers.provider.getBalance(treasury.address);
      expect(finalBalance.sub(initialBalance)).to.equal(sendAmount);
    });
  });

  describe('Integration Tests', function () {
    it('Should handle complete fee collection and distribution workflow', async function () {
      // Record initial balances
      const initialFoundationBalance = await foundationWallet.getBalance();
      const initialTreasuryBalance = await treasuryWallet.getBalance();
      const initialStakingBalance = await stakingPoolWallet.getBalance();

      // Collect multiple fees
      const numFees = 5;
      for (let i = 0; i < numFees; i++) {
        await treasury.connect(agentFactory).collectProtocolFee(user1.address, {
          value: PROTOCOL_MINTING_FEE
        });
      }

      // Check final balances
      const finalFoundationBalance = await foundationWallet.getBalance();
      const finalTreasuryBalance = await treasuryWallet.getBalance();
      const finalStakingBalance = await stakingPoolWallet.getBalance();

      const totalFees = PROTOCOL_MINTING_FEE.mul(numFees);
      const expectedFoundationAmount = totalFees.mul(FOUNDATION_PERCENTAGE).div(10000);
      const expectedTreasuryAmount = totalFees.mul(TREASURY_PERCENTAGE).div(10000);
      const expectedStakingAmount = totalFees.mul(STAKING_PERCENTAGE).div(10000);

      expect(finalFoundationBalance.sub(initialFoundationBalance)).to.equal(expectedFoundationAmount);
      expect(finalTreasuryBalance.sub(initialTreasuryBalance)).to.equal(expectedTreasuryAmount);
      expect(finalStakingBalance.sub(initialStakingBalance)).to.equal(expectedStakingAmount);

      // Check statistics
      const [totalCollected, foundationTotal, treasuryTotal, stakingTotal, pendingBalance] = await treasury.getFeeStatistics();
      expect(totalCollected).to.equal(totalFees);
      expect(foundationTotal).to.equal(expectedFoundationAmount);
      expect(treasuryTotal).to.equal(expectedTreasuryAmount);
      expect(stakingTotal).to.equal(expectedStakingAmount);
      expect(pendingBalance).to.equal(0); // Should be distributed immediately
    });

    it('Should handle wallet updates during operation', async function () {
      // Collect initial fee
      await treasury.connect(agentFactory).collectProtocolFee(user1.address, {
        value: PROTOCOL_MINTING_FEE
      });

      // Update wallets
      const newFoundation = addrs[0];
      const newTreasury = addrs[1];
      const newStaking = addrs[2];

      await treasury.connect(governance).updateAllWallets(
        newFoundation.address,
        newTreasury.address,
        newStaking.address
      );

      // Record new wallet balances
      const initialNewFoundationBalance = await newFoundation.getBalance();
      const initialNewTreasuryBalance = await newTreasury.getBalance();
      const initialNewStakingBalance = await newStaking.getBalance();

      // Collect another fee (should go to new wallets)
      await treasury.connect(agentFactory).collectProtocolFee(user2.address, {
        value: PROTOCOL_MINTING_FEE
      });

      // Check new wallets received the funds
      const finalNewFoundationBalance = await newFoundation.getBalance();
      const finalNewTreasuryBalance = await newTreasury.getBalance();
      const finalNewStakingBalance = await newStaking.getBalance();

      const expectedFoundationAmount = PROTOCOL_MINTING_FEE.mul(FOUNDATION_PERCENTAGE).div(10000);
      const expectedTreasuryAmount = PROTOCOL_MINTING_FEE.mul(TREASURY_PERCENTAGE).div(10000);
      const expectedStakingAmount = PROTOCOL_MINTING_FEE.mul(STAKING_PERCENTAGE).div(10000);

      expect(finalNewFoundationBalance.sub(initialNewFoundationBalance)).to.equal(expectedFoundationAmount);
      expect(finalNewTreasuryBalance.sub(initialNewTreasuryBalance)).to.equal(expectedTreasuryAmount);
      expect(finalNewStakingBalance.sub(initialNewStakingBalance)).to.equal(expectedStakingAmount);
    });

    it('Should handle emergency scenarios correctly', async function () {
      // Collect some fees
      await treasury.connect(agentFactory).collectProtocolFee(user1.address, {
        value: PROTOCOL_MINTING_FEE
      });

      // Pause fee collection
      await treasury.connect(governance).setFeeCollectionPaused(true);

      // Should not be able to collect more fees
      await expect(
        treasury.connect(agentFactory).collectProtocolFee(user2.address, {
          value: PROTOCOL_MINTING_FEE
        })
      ).to.be.revertedWith('BEP007Treasury: fee collection is paused');

      // Pause distribution and collect more fees after unpausing collection
      await treasury.connect(governance).setDistributionPaused(true);
      await treasury.connect(governance).setFeeCollectionPaused(false);

      await treasury.connect(agentFactory).collectProtocolFee(user2.address, {
        value: PROTOCOL_MINTING_FEE
      });

      // Should have pending balance
      const [, , , , pendingBalance] = await treasury.getFeeStatistics();
      expect(pendingBalance).to.equal(PROTOCOL_MINTING_FEE);

      // Emergency withdraw some funds
      const withdrawAmount = ethers.utils.parseEther('0.005');
      await treasury.connect(governance).emergencyWithdraw(
        addrs[0].address,
        withdrawAmount,
        "Emergency test withdrawal"
      );

      // Unpause distribution and distribute remaining
      await treasury.connect(governance).setDistributionPaused(false);
      await treasury.connect(governance).distributePendingFees();
    });
  });

  describe('Edge Cases', function () {
    it('Should handle zero fee amounts in calculations', async function () {
      const [foundationAmount, treasuryAmount, stakingAmount] = await treasury.calculateDistribution(0);
      
      expect(foundationAmount).to.equal(0);
      expect(treasuryAmount).to.equal(0);
      expect(stakingAmount).to.equal(0);
    });

    it('Should handle very small fee amounts', async function () {
      const smallAmount = 1; // 1 wei
      const [foundationAmount, treasuryAmount, stakingAmount] = await treasury.calculateDistribution(smallAmount);
      
      // Total should still equal input
      const total = foundationAmount.add(treasuryAmount).add(stakingAmount);
      expect(total).to.equal(smallAmount);
    });

    it('Should handle very large fee amounts', async function () {
      const largeAmount = ethers.utils.parseEther('1000000'); // 1M BNB
      const [foundationAmount, treasuryAmount, stakingAmount] = await treasury.calculateDistribution(largeAmount);
      
      const expectedFoundation = largeAmount.mul(FOUNDATION_PERCENTAGE).div(10000);
      const expectedTreasury = largeAmount.mul(TREASURY_PERCENTAGE).div(10000);
      const expectedStaking = largeAmount.mul(STAKING_PERCENTAGE).div(10000);

      expect(foundationAmount).to.equal(expectedFoundation);
      expect(treasuryAmount).to.equal(expectedTreasury);
      expect(stakingAmount).to.equal(expectedStaking);

      // Total should equal input
      const total = foundationAmount.add(treasuryAmount).add(stakingAmount);
      expect(total).to.equal(largeAmount);
    });

    it('Should handle contract with no balance for emergency withdrawal', async function () {
      // Contract should have no balance initially
      const contractBalance = await ethers.provider.getBalance(treasury.address);
      expect(contractBalance).to.equal(0);

      await expect(
        treasury.connect(governance).emergencyWithdraw(
          addrs[0].address,
          ethers.utils.parseEther('0.001'),
          "Test withdrawal"
        )
      ).to.be.revertedWith('BEP007Treasury: insufficient balance');
    });

    it('Should handle multiple wallet updates without affecting pending distributions', async function () {
      // Pause distribution and collect fees
      await treasury.connect(governance).setDistributionPaused(true);
      
      await treasury.connect(agentFactory).collectProtocolFee(user1.address, {
        value: PROTOCOL_MINTING_FEE
      });

      // Update wallets multiple times
      for (let i = 0; i < 3; i++) {
        await treasury.connect(governance).updateAllWallets(
          addrs[i * 3].address,
          addrs[i * 3 + 1].address,
          addrs[i * 3 + 2].address
        );
      }

      // Unpause and distribute - should go to latest wallets
      await treasury.connect(governance).setDistributionPaused(false);
      
      const finalFoundation = addrs[6].address;
      const finalTreasury = addrs[7].address;
      const finalStaking = addrs[8].address;

      const initialFoundationBalance = await ethers.provider.getBalance(finalFoundation);
      const initialTreasuryBalance = await ethers.provider.getBalance(finalTreasury);
      const initialStakingBalance = await ethers.provider.getBalance(finalStaking);

      await treasury.connect(governance).distributePendingFees();

      const finalFoundationBalance = await ethers.provider.getBalance(finalFoundation);
      const finalTreasuryBalance = await ethers.provider.getBalance(finalTreasury);
      const finalStakingBalance = await ethers.provider.getBalance(finalStaking);

      const expectedFoundationAmount = PROTOCOL_MINTING_FEE.mul(FOUNDATION_PERCENTAGE).div(10000);
      const expectedTreasuryAmount = PROTOCOL_MINTING_FEE.mul(TREASURY_PERCENTAGE).div(10000);
      const expectedStakingAmount = PROTOCOL_MINTING_FEE.mul(STAKING_PERCENTAGE).div(10000);

      expect(finalFoundationBalance.sub(initialFoundationBalance)).to.equal(expectedFoundationAmount);
      expect(finalTreasuryBalance.sub(initialTreasuryBalance)).to.equal(expectedTreasuryAmount);
      expect(finalStakingBalance.sub(initialStakingBalance)).to.equal(expectedStakingAmount);
    });
  });
});
