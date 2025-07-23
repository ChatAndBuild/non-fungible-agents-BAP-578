const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('DeFiAgent', function () {
  let DeFiAgent;
  let defiAgent;
  let MerkleTreeLearning;
  let merkleTreeLearning;
  let MockERC20;
  let tokenA;
  let tokenB;
  let owner;
  let user1;
  let user2;
  let addrs;

  // Mock BEP007 token address for testing
  const mockAgentTokenAddress = '0x1234567890123456789012345678901234567890';

  // DeFi agent profile data
  const agentName = 'Test DeFi Agent';
  const tradingStyle = 'Balanced';
  const riskTolerance = 50; // Medium risk

  beforeEach(async function () {
    [owner, user1, user2, ...addrs] = await ethers.getSigners();

    // Deploy mock ERC20 tokens for testing
    MockERC20 = await ethers.getContractFactory('MockERC20');
    tokenA = await MockERC20.deploy('Token A', 'TKNA', ethers.utils.parseEther('1000000'));
    await tokenA.deployed();
    
    tokenB = await MockERC20.deploy('Token B', 'TKNB', ethers.utils.parseEther('1000000'));
    await tokenB.deployed();

    // Deploy MerkleTreeLearning for testing learning functionality
    MerkleTreeLearning = await ethers.getContractFactory('MerkleTreeLearning');
    merkleTreeLearning = await MerkleTreeLearning.deploy();
    await merkleTreeLearning.deployed();

    // Deploy DeFiAgent
    DeFiAgent = await ethers.getContractFactory('DeFiAgent');
    defiAgent = await DeFiAgent.deploy(
      mockAgentTokenAddress,
      agentName,
      tradingStyle,
      riskTolerance
    );
    await defiAgent.deployed();

    // Transfer some tokens to the agent for testing
    await tokenA.transfer(defiAgent.address, ethers.utils.parseEther('1000'));
    await tokenB.transfer(defiAgent.address, ethers.utils.parseEther('1000'));
  });

  describe('Deployment', function () {
    it('Should set the correct agent token address', async function () {
      expect(await defiAgent.agentToken()).to.equal(mockAgentTokenAddress);
    });

    it('Should set the correct DeFi profile', async function () {
      const profile = await defiAgent.profile();
      expect(profile.name).to.equal(agentName);
      expect(profile.tradingStyle).to.equal(tradingStyle);
      expect(profile.riskTolerance).to.equal(riskTolerance);
      expect(profile.experienceLevel).to.equal(50); // Default medium experience
      expect(profile.maxSlippage).to.equal(100); // 1% default slippage
      expect(profile.autoRebalanceEnabled).to.equal(false);
    });

    it('Should initialize with learning disabled', async function () {
      expect(await defiAgent.learningEnabled()).to.equal(false);
      expect(await defiAgent.learningModule()).to.equal(ethers.constants.AddressZero);
    });

    it('Should set the correct owner', async function () {
      expect(await defiAgent.owner()).to.equal(owner.address);
    });

    it('Should initialize trading metrics to zero', async function () {
      const metrics = await defiAgent.getTradingMetrics();
      expect(metrics.totalTrades).to.equal(0);
      expect(metrics.successfulTrades).to.equal(0);
      expect(metrics.totalVolume).to.equal(0);
      expect(metrics.totalPnL).to.equal(0);
      expect(metrics.bestTradeReturn).to.equal(0);
      expect(metrics.worstTradeReturn).to.equal(0);
      expect(metrics.averageHoldTime).to.equal(0);
      expect(metrics.lastTradeTimestamp).to.equal(0);
    });

    it('Should initialize risk parameters based on risk tolerance', async function () {
      const riskParams = await defiAgent.getRiskParameters();
      // Medium risk tolerance (50) should use balanced settings
      expect(riskParams.maxPositionSize).to.equal(ethers.utils.parseEther('20')); // 20%
      expect(riskParams.stopLossPercentage).to.equal(ethers.utils.parseEther('10')); // 10%
      expect(riskParams.takeProfitPercentage).to.equal(ethers.utils.parseEther('20')); // 20%
      expect(riskParams.maxDailyLoss).to.equal(ethers.utils.parseEther('5')); // 5%
      expect(riskParams.portfolioValueAtRisk).to.equal(ethers.utils.parseEther('10')); // 10%
      expect(riskParams.emergencyStopEnabled).to.equal(false);
    });

    it('Should not allow deployment with zero agent token address', async function () {
      await expect(
        DeFiAgent.deploy(
          ethers.constants.AddressZero,
          agentName,
          tradingStyle,
          riskTolerance
        )
      ).to.be.revertedWith('DeFiAgent: agent token is zero address');
    });

    it('Should not allow deployment with invalid risk tolerance', async function () {
      await expect(
        DeFiAgent.deploy(
          mockAgentTokenAddress,
          agentName,
          tradingStyle,
          101 // Invalid risk tolerance > 100
        )
      ).to.be.revertedWith('DeFiAgent: risk tolerance must be 0-100');
    });
  });

  describe('Risk Parameter Initialization', function () {
    it('Should set conservative parameters for low risk tolerance', async function () {
      const conservativeAgent = await DeFiAgent.deploy(
        mockAgentTokenAddress,
        'Conservative Agent',
        'Conservative',
        20 // Low risk tolerance
      );
      await conservativeAgent.deployed();

      const riskParams = await conservativeAgent.getRiskParameters();
      expect(riskParams.maxPositionSize).to.equal(ethers.utils.parseEther('10')); // 10%
      expect(riskParams.stopLossPercentage).to.equal(ethers.utils.parseEther('5')); // 5%
      expect(riskParams.takeProfitPercentage).to.equal(ethers.utils.parseEther('10')); // 10%
      expect(riskParams.maxDailyLoss).to.equal(ethers.utils.parseEther('2')); // 2%
    });

    it('Should set aggressive parameters for high risk tolerance', async function () {
      const aggressiveAgent = await DeFiAgent.deploy(
        mockAgentTokenAddress,
        'Aggressive Agent',
        'Aggressive',
        80 // High risk tolerance
      );
      await aggressiveAgent.deployed();

      const riskParams = await aggressiveAgent.getRiskParameters();
      expect(riskParams.maxPositionSize).to.equal(ethers.utils.parseEther('30')); // 30%
      expect(riskParams.stopLossPercentage).to.equal(ethers.utils.parseEther('15')); // 15%
      expect(riskParams.takeProfitPercentage).to.equal(ethers.utils.parseEther('30')); // 30%
      expect(riskParams.maxDailyLoss).to.equal(ethers.utils.parseEther('10')); // 10%
    });
  });

  describe('Profile Management', function () {
    it('Should allow owner to update profile', async function () {
      const newName = 'Updated DeFi Agent';
      const newTradingStyle = 'Aggressive';
      const newRiskTolerance = 75;
      const newExperienceLevel = 80;
      const newMaxSlippage = 200; // 2%
      const newAutoRebalance = true;

      await defiAgent.updateProfile(
        newName,
        newTradingStyle,
        newRiskTolerance,
        newExperienceLevel,
        newMaxSlippage,
        newAutoRebalance
      );

      const profile = await defiAgent.profile();
      expect(profile.name).to.equal(newName);
      expect(profile.tradingStyle).to.equal(newTradingStyle);
      expect(profile.riskTolerance).to.equal(newRiskTolerance);
      expect(profile.experienceLevel).to.equal(newExperienceLevel);
      expect(profile.maxSlippage).to.equal(newMaxSlippage);
      expect(profile.autoRebalanceEnabled).to.equal(newAutoRebalance);
    });

    it('Should not allow non-owner to update profile', async function () {
      await expect(
        defiAgent.connect(user1).updateProfile(
          'Hacker Agent',
          'Malicious',
          100,
          100,
          1000,
          true
        )
      ).to.be.revertedWith('Ownable: caller is not the owner');
    });

    it('Should not allow invalid risk tolerance', async function () {
      await expect(
        defiAgent.updateProfile(
          'Test Agent',
          'Balanced',
          101, // Invalid
          50,
          100,
          false
        )
      ).to.be.revertedWith('DeFiAgent: risk tolerance must be 0-100');
    });

    it('Should not allow invalid experience level', async function () {
      await expect(
        defiAgent.updateProfile(
          'Test Agent',
          'Balanced',
          50,
          101, // Invalid
          100,
          false
        )
      ).to.be.revertedWith('DeFiAgent: experience level must be 0-100');
    });

    it('Should not allow excessive max slippage', async function () {
      await expect(
        defiAgent.updateProfile(
          'Test Agent',
          'Balanced',
          50,
          50,
          1001, // > 10%
          false
        )
      ).to.be.revertedWith('DeFiAgent: max slippage must be <= 10%');
    });

    it('Should update risk parameters when risk tolerance changes', async function () {
      // Start with balanced (50) risk tolerance
      let riskParams = await defiAgent.getRiskParameters();
      expect(riskParams.maxPositionSize).to.equal(ethers.utils.parseEther('20'));

      // Update to conservative (20) risk tolerance
      await defiAgent.updateProfile('Test', 'Conservative', 20, 50, 100, false);
      
      riskParams = await defiAgent.getRiskParameters();
      expect(riskParams.maxPositionSize).to.equal(ethers.utils.parseEther('10'));
    });
  });

  describe('Protocol and Token Management', function () {
    it('Should allow owner to add supported protocols', async function () {
      const protocolName = 'PancakeSwap';
      const protocolAddress = user1.address; // Mock address

      await defiAgent.addSupportedProtocol(protocolName, protocolAddress);

      expect(await defiAgent.protocolAddresses(protocolName)).to.equal(protocolAddress);
      
      const supportedProtocols = await defiAgent.getSupportedProtocols();
      expect(supportedProtocols).to.include(protocolName);
    });

    it('Should not allow adding protocol with zero address', async function () {
      await expect(
        defiAgent.addSupportedProtocol('TestProtocol', ethers.constants.AddressZero)
      ).to.be.revertedWith('DeFiAgent: protocol address is zero');
    });

    it('Should allow owner to add supported tokens', async function () {
      await defiAgent.addSupportedToken(tokenA.address);

      expect(await defiAgent.supportedTokens(tokenA.address)).to.equal(true);
      
      const supportedTokens = await defiAgent.getSupportedTokens();
      expect(supportedTokens).to.include(tokenA.address);
    });

    it('Should not allow adding token with zero address', async function () {
      await expect(
        defiAgent.addSupportedToken(ethers.constants.AddressZero)
      ).to.be.revertedWith('DeFiAgent: token address is zero');
    });

    it('Should not allow adding already supported token', async function () {
      await defiAgent.addSupportedToken(tokenA.address);
      
      await expect(
        defiAgent.addSupportedToken(tokenA.address)
      ).to.be.revertedWith('DeFiAgent: token already supported');
    });

    it('Should allow owner to remove supported tokens', async function () {
      await defiAgent.addSupportedToken(tokenA.address);
      expect(await defiAgent.supportedTokens(tokenA.address)).to.equal(true);

      await defiAgent.removeSupportedToken(tokenA.address);
      expect(await defiAgent.supportedTokens(tokenA.address)).to.equal(false);

      const supportedTokens = await defiAgent.getSupportedTokens();
      expect(supportedTokens).to.not.include(tokenA.address);
    });

    it('Should not allow removing non-supported token', async function () {
      await expect(
        defiAgent.removeSupportedToken(tokenA.address)
      ).to.be.revertedWith('DeFiAgent: token not supported');
    });

    it('Should not allow non-owner to manage protocols and tokens', async function () {
      await expect(
        defiAgent.connect(user1).addSupportedProtocol('Test', user1.address)
      ).to.be.revertedWith('Ownable: caller is not the owner');

      await expect(
        defiAgent.connect(user1).addSupportedToken(tokenA.address)
      ).to.be.revertedWith('Ownable: caller is not the owner');
    });
  });

  describe('Trading Functionality', function () {
    beforeEach(async function () {
      // Setup tokens and protocols for trading tests
      await defiAgent.addSupportedToken(tokenA.address);
      await defiAgent.addSupportedToken(tokenB.address);
      await defiAgent.addSupportedProtocol('PancakeSwap', user1.address);
    });

    it('Should execute token swap successfully', async function () {
      const amountIn = ethers.utils.parseEther('100');
      const minAmountOut = ethers.utils.parseEther('95'); // Expecting some slippage

      await expect(
        defiAgent.executeSwap(
          tokenA.address,
          tokenB.address,
          amountIn,
          minAmountOut,
          'PancakeSwap'
        )
      ).to.emit(defiAgent, 'TradeExecuted');

      // Check that trading metrics were updated
      const metrics = await defiAgent.getTradingMetrics();
      expect(metrics.totalTrades).to.equal(1);
      expect(metrics.lastTradeTimestamp).to.be.gt(0);
    });

    it('Should not allow swap with unsupported input token', async function () {
      const unsupportedToken = user2.address; // Mock unsupported token
      
      await expect(
        defiAgent.executeSwap(
          unsupportedToken,
          tokenB.address,
          ethers.utils.parseEther('100'),
          ethers.utils.parseEther('95'),
          'PancakeSwap'
        )
      ).to.be.revertedWith('DeFiAgent: input token not supported');
    });

    it('Should not allow swap with unsupported output token', async function () {
      const unsupportedToken = user2.address; // Mock unsupported token
      
      await expect(
        defiAgent.executeSwap(
          tokenA.address,
          unsupportedToken,
          ethers.utils.parseEther('100'),
          ethers.utils.parseEther('95'),
          'PancakeSwap'
        )
      ).to.be.revertedWith('DeFiAgent: output token not supported');
    });

    it('Should not allow swap with zero amount', async function () {
      await expect(
        defiAgent.executeSwap(
          tokenA.address,
          tokenB.address,
          0,
          0,
          'PancakeSwap'
        )
      ).to.be.revertedWith('DeFiAgent: amount must be greater than 0');
    });

    it('Should not allow swap with unsupported protocol', async function () {
      await expect(
        defiAgent.executeSwap(
          tokenA.address,
          tokenB.address,
          ethers.utils.parseEther('100'),
          ethers.utils.parseEther('95'),
          'UnsupportedDEX'
        )
      ).to.be.revertedWith('DeFiAgent: protocol not supported');
    });
  });
});
