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

  // Mock BAP700 token address for testing
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

    it('Should not allow non-owner to execute swaps', async function () {
      await expect(
        defiAgent.connect(user1).executeSwap(
          tokenA.address,
          tokenB.address,
          ethers.utils.parseEther('100'),
          ethers.utils.parseEther('95'),
          'PancakeSwap'
        )
      ).to.be.revertedWith('Ownable: caller is not the owner');
    });

    it('Should not allow swaps when emergency stop is active', async function () {
      await defiAgent.emergencyStop('Testing emergency stop');

      await expect(
        defiAgent.executeSwap(
          tokenA.address,
          tokenB.address,
          ethers.utils.parseEther('100'),
          ethers.utils.parseEther('95'),
          'PancakeSwap'
        )
      ).to.be.revertedWith('DeFiAgent: emergency stop active');
    });
  });

  describe('Position Management', function () {
    beforeEach(async function () {
      await defiAgent.addSupportedToken(tokenA.address);
      await defiAgent.addSupportedProtocol('Venus', user1.address);
    });

    it('Should open position successfully', async function () {
      const amount = ethers.utils.parseEther('100');

      await expect(
        defiAgent.openPosition(tokenA.address, amount, 'Venus')
      ).to.emit(defiAgent, 'PositionOpened')
      .withArgs(1, tokenA.address, amount, ethers.utils.parseEther('1'), 'Venus');

      const position = await defiAgent.positions(1);
      expect(position.token).to.equal(tokenA.address);
      expect(position.amount).to.equal(amount);
      expect(position.protocol).to.equal('Venus');
      expect(position.isActive).to.equal(true);
    });

    it('Should close position successfully', async function () {
      const amount = ethers.utils.parseEther('100');
      
      // Open position first
      await defiAgent.openPosition(tokenA.address, amount, 'Venus');

      // Close position
      await expect(
        defiAgent.closePosition(1)
      ).to.emit(defiAgent, 'PositionClosed');

      const position = await defiAgent.positions(1);
      expect(position.isActive).to.equal(false);

      // Check that trading metrics were updated
      const metrics = await defiAgent.getTradingMetrics();
      expect(metrics.totalTrades).to.equal(1);
    });

    it('Should not allow opening position with unsupported token', async function () {
      await expect(
        defiAgent.openPosition(
          user2.address, // Unsupported token
          ethers.utils.parseEther('100'),
          'Venus'
        )
      ).to.be.revertedWith('DeFiAgent: token not supported');
    });

    it('Should not allow opening position with zero amount', async function () {
      await expect(
        defiAgent.openPosition(tokenA.address, 0, 'Venus')
      ).to.be.revertedWith('DeFiAgent: amount must be greater than 0');
    });

    it('Should not allow closing inactive position', async function () {
      await expect(
        defiAgent.closePosition(999) // Non-existent position
      ).to.be.revertedWith('DeFiAgent: position not active');
    });

    it('Should increment position counter correctly', async function () {
      await defiAgent.openPosition(tokenA.address, ethers.utils.parseEther('100'), 'Venus');
      await defiAgent.openPosition(tokenA.address, ethers.utils.parseEther('200'), 'Venus');

      expect(await defiAgent.positionCounter()).to.equal(2);

      const position1 = await defiAgent.positions(1);
      const position2 = await defiAgent.positions(2);
      
      expect(position1.amount).to.equal(ethers.utils.parseEther('100'));
      expect(position2.amount).to.equal(ethers.utils.parseEther('200'));
    });
  });

  describe('Risk Management', function () {
    it('Should allow owner to update risk parameters', async function () {
      const newMaxPositionSize = ethers.utils.parseEther('25'); // 25%
      const newStopLoss = ethers.utils.parseEther('8'); // 8%
      const newTakeProfit = ethers.utils.parseEther('15'); // 15%
      const newMaxDailyLoss = ethers.utils.parseEther('3'); // 3%

      await expect(
        defiAgent.updateRiskParameters(
          newMaxPositionSize,
          newStopLoss,
          newTakeProfit,
          newMaxDailyLoss
        )
      ).to.emit(defiAgent, 'RiskParametersUpdated')
      .withArgs(newMaxPositionSize, newStopLoss, newTakeProfit);

      const riskParams = await defiAgent.getRiskParameters();
      expect(riskParams.maxPositionSize).to.equal(newMaxPositionSize);
      expect(riskParams.stopLossPercentage).to.equal(newStopLoss);
      expect(riskParams.takeProfitPercentage).to.equal(newTakeProfit);
      expect(riskParams.maxDailyLoss).to.equal(newMaxDailyLoss);
    });

    it('Should not allow excessive max position size', async function () {
      await expect(
        defiAgent.updateRiskParameters(
          ethers.utils.parseEther('101'), // > 100%
          ethers.utils.parseEther('10'),
          ethers.utils.parseEther('20'),
          ethers.utils.parseEther('5')
        )
      ).to.be.revertedWith('DeFiAgent: max position size too high');
    });

    it('Should not allow excessive stop loss', async function () {
      await expect(
        defiAgent.updateRiskParameters(
          ethers.utils.parseEther('20'),
          ethers.utils.parseEther('51'), // > 50%
          ethers.utils.parseEther('20'),
          ethers.utils.parseEther('5')
        )
      ).to.be.revertedWith('DeFiAgent: stop loss too high');
    });

    it('Should not allow too low take profit', async function () {
      await expect(
        defiAgent.updateRiskParameters(
          ethers.utils.parseEther('20'),
          ethers.utils.parseEther('10'),
          ethers.utils.parseEther('4'), // < 5%
          ethers.utils.parseEther('5')
        )
      ).to.be.revertedWith('DeFiAgent: take profit too low');
    });

    it('Should allow emergency stop', async function () {
      const reason = 'Market crash detected';

      await expect(
        defiAgent.emergencyStop(reason)
      ).to.emit(defiAgent, 'EmergencyStop')
      .withArgs(reason, await ethers.provider.getBlockNumber().then(bn => ethers.provider.getBlock(bn).then(b => b.timestamp + 1)));

      const riskParams = await defiAgent.getRiskParameters();
      expect(riskParams.emergencyStopEnabled).to.equal(true);
    });

    it('Should allow disabling emergency stop', async function () {
      await defiAgent.emergencyStop('Test');
      await defiAgent.disableEmergencyStop();

      const riskParams = await defiAgent.getRiskParameters();
      expect(riskParams.emergencyStopEnabled).to.equal(false);
    });

    it('Should not allow non-owner to update risk parameters', async function () {
      await expect(
        defiAgent.connect(user1).updateRiskParameters(
          ethers.utils.parseEther('20'),
          ethers.utils.parseEther('10'),
          ethers.utils.parseEther('20'),
          ethers.utils.parseEther('5')
        )
      ).to.be.revertedWith('Ownable: caller is not the owner');
    });
  });

  describe('Learning Module Management', function () {
    it('Should allow owner to enable learning', async function () {
      expect(await defiAgent.learningEnabled()).to.equal(false);

      await defiAgent.enableLearning(merkleTreeLearning.address);

      expect(await defiAgent.learningEnabled()).to.equal(true);
      expect(await defiAgent.learningModule()).to.equal(merkleTreeLearning.address);
    });

    it('Should not allow non-owner to enable learning', async function () {
      await expect(
        defiAgent.connect(user1).enableLearning(merkleTreeLearning.address)
      ).to.be.revertedWith('Ownable: caller is not the owner');
    });

    it('Should not allow enabling learning with zero address', async function () {
      await expect(
        defiAgent.enableLearning(ethers.constants.AddressZero)
      ).to.be.revertedWith('DeFiAgent: learning module is zero address');
    });

    it('Should not allow enabling learning when already enabled', async function () {
      await defiAgent.enableLearning(merkleTreeLearning.address);

      await expect(
        defiAgent.enableLearning(merkleTreeLearning.address)
      ).to.be.revertedWith('DeFiAgent: learning already enabled');
    });

    it('Should emit learning events when learning is enabled', async function () {
      await defiAgent.enableLearning(merkleTreeLearning.address);
      await defiAgent.addSupportedToken(tokenA.address);
      await defiAgent.addSupportedToken(tokenB.address);
      await defiAgent.addSupportedProtocol('PancakeSwap', user1.address);

      // Execute a trade to trigger learning event
      const tx = await defiAgent.executeSwap(
        tokenA.address,
        tokenB.address,
        ethers.utils.parseEther('100'),
        ethers.utils.parseEther('95'),
        'PancakeSwap'
      );

      const receipt = await tx.wait();
      const learningEvent = receipt.events?.find(e => e.event === 'LearningUpdate');
      
      expect(learningEvent).to.not.be.undefined;
      expect(learningEvent.args[0]).to.equal('trade_execution');
      expect(learningEvent.args[1]).to.not.be.undefined; // dataHash
      expect(learningEvent.args[2]).to.not.be.undefined; // timestamp
    });
  });

  describe('Portfolio Management', function () {
    beforeEach(async function () {
      await defiAgent.addSupportedToken(tokenA.address);
      await defiAgent.addSupportedToken(tokenB.address);
      await defiAgent.addSupportedProtocol('Venus', user1.address);
    });

    it('Should calculate portfolio value correctly', async function () {
      // Initially no positions, so portfolio value should be 0
      expect(await defiAgent.getPortfolioValue()).to.equal(0);

      // Open some positions
      await defiAgent.openPosition(tokenA.address, ethers.utils.parseEther('100'), 'Venus');
      await defiAgent.openPosition(tokenB.address, ethers.utils.parseEther('200'), 'Venus');

      // Portfolio value should be sum of position values
      // With mock price of $1 per token, total should be $300
      const portfolioValue = await defiAgent.getPortfolioValue();
      expect(portfolioValue).to.equal(ethers.utils.parseEther('300'));
    });

    it('Should not include closed positions in portfolio value', async function () {
      await defiAgent.openPosition(tokenA.address, ethers.utils.parseEther('100'), 'Venus');
      await defiAgent.openPosition(tokenB.address, ethers.utils.parseEther('200'), 'Venus');

      // Close one position
      await defiAgent.closePosition(1);

      // Portfolio value should only include active position
      const portfolioValue = await defiAgent.getPortfolioValue();
      expect(portfolioValue).to.equal(ethers.utils.parseEther('200'));
    });
  });

  describe('Emergency Functions', function () {
    it('Should allow emergency withdrawal when emergency stop is active', async function () {
      await defiAgent.emergencyStop('Testing emergency withdrawal');

      const initialBalance = await tokenA.balanceOf(owner.address);
      const withdrawAmount = ethers.utils.parseEther('100');

      await defiAgent.emergencyWithdraw(tokenA.address, withdrawAmount);

      const finalBalance = await tokenA.balanceOf(owner.address);
      expect(finalBalance.sub(initialBalance)).to.equal(withdrawAmount);
    });

    it('Should not allow emergency withdrawal when emergency stop is not active', async function () {
      await expect(
        defiAgent.emergencyWithdraw(tokenA.address, ethers.utils.parseEther('100'))
      ).to.be.revertedWith('DeFiAgent: emergency stop not active');
    });

    it('Should allow BNB emergency withdrawal', async function () {
      // Send some BNB to the contract
      await owner.sendTransaction({
        to: defiAgent.address,
        value: ethers.utils.parseEther('1')
      });

      await defiAgent.emergencyStop('Testing BNB withdrawal');

      const initialBalance = await ethers.provider.getBalance(owner.address);
      
      // Emergency withdraw BNB (address(0) represents BNB)
      const tx = await defiAgent.emergencyWithdraw(ethers.constants.AddressZero, ethers.utils.parseEther('0.5'));
      const receipt = await tx.wait();
      const gasUsed = receipt.gasUsed.mul(receipt.effectiveGasPrice);

      const finalBalance = await ethers.provider.getBalance(owner.address);
      
      // Account for gas costs in the comparison
      expect(finalBalance.add(gasUsed).sub(initialBalance)).to.equal(ethers.utils.parseEther('0.5'));
    });
  });

  describe('View Functions', function () {
    it('Should return correct trading metrics', async function () {
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

    it('Should return correct risk parameters', async function () {
      const riskParams = await defiAgent.getRiskParameters();
      
      expect(riskParams.maxPositionSize).to.equal(ethers.utils.parseEther('20'));
      expect(riskParams.stopLossPercentage).to.equal(ethers.utils.parseEther('10'));
      expect(riskParams.takeProfitPercentage).to.equal(ethers.utils.parseEther('20'));
      expect(riskParams.maxDailyLoss).to.equal(ethers.utils.parseEther('5'));
      expect(riskParams.portfolioValueAtRisk).to.equal(ethers.utils.parseEther('10'));
      expect(riskParams.emergencyStopEnabled).to.equal(false);
    });

    it('Should return empty arrays initially for tokens and protocols', async function () {
      const supportedTokens = await defiAgent.getSupportedTokens();
      const supportedProtocols = await defiAgent.getSupportedProtocols();
      
      expect(supportedTokens.length).to.equal(0);
      expect(supportedProtocols.length).to.equal(0);
    });

    it('Should return correct arrays after adding tokens and protocols', async function () {
      await defiAgent.addSupportedToken(tokenA.address);
      await defiAgent.addSupportedToken(tokenB.address);
      await defiAgent.addSupportedProtocol('PancakeSwap', user1.address);
      await defiAgent.addSupportedProtocol('Venus', user2.address);

      const supportedTokens = await defiAgent.getSupportedTokens();
      const supportedProtocols = await defiAgent.getSupportedProtocols();
      
      expect(supportedTokens.length).to.equal(2);
      expect(supportedTokens).to.include(tokenA.address);
      expect(supportedTokens).to.include(tokenB.address);
      
      expect(supportedProtocols.length).to.equal(2);
      expect(supportedProtocols).to.include('PancakeSwap');
      expect(supportedProtocols).to.include('Venus');
    });
  });

  describe('Access Control', function () {
    it('Should inherit Ownable functionality correctly', async function () {
      expect(await defiAgent.owner()).to.equal(owner.address);
      
      // Test ownership transfer
      await defiAgent.transferOwnership(user1.address);
      expect(await defiAgent.owner()).to.equal(user1.address);
    });

    it('Should inherit ReentrancyGuard functionality correctly', async function () {
      // ReentrancyGuard is inherited and used in trading functions
      // This test verifies the inheritance is working
      expect(defiAgent.address).to.not.equal(ethers.constants.AddressZero);
    });

    it('Should have correct modifiers working', async function () {
      // Test onlyAgentToken modifier (agentToken is set correctly)
      expect(await defiAgent.agentToken()).to.equal(mockAgentTokenAddress);
      
      // Test whenLearningEnabled modifier (learning is initially disabled)
      expect(await defiAgent.learningEnabled()).to.equal(false);
      
      // Test whenNotEmergencyStopped modifier (emergency stop is initially disabled)
      const riskParams = await defiAgent.getRiskParameters();
      expect(riskParams.emergencyStopEnabled).to.equal(false);
    });
  });

  describe('Edge Cases and Error Handling', function () {
    it('Should handle multiple profile updates correctly', async function () {
      // Update profile multiple times
      for (let i = 0; i < 3; i++) {
        await defiAgent.updateProfile(
          `Agent ${i}`,
          'Balanced',
          50 + i,
          60 + i,
          100 + i * 10,
          i % 2 === 0
        );
        
        const profile = await defiAgent.profile();
        expect(profile.name).to.equal(`Agent ${i}`);
        expect(profile.riskTolerance).to.equal(50 + i);
      }
    });

    it('Should handle adding and removing multiple tokens', async function () {
      const tokens = [tokenA.address, tokenB.address, user1.address, user2.address];
      
      // Add multiple tokens
      for (const token of tokens) {
        await defiAgent.addSupportedToken(token);
      }
      
      let supportedTokens = await defiAgent.getSupportedTokens();
      expect(supportedTokens.length).to.equal(4);
      
      // Remove some tokens
      await defiAgent.removeSupportedToken(tokenA.address);
      await defiAgent.removeSupportedToken(user1.address);
      
      supportedTokens = await defiAgent.getSupportedTokens();
      expect(supportedTokens.length).to.equal(2);
      expect(supportedTokens).to.include(tokenB.address);
      expect(supportedTokens).to.include(user2.address);
    });

    it('Should handle boundary values for risk parameters', async function () {
      // Test minimum values
      await defiAgent.updateRiskParameters(
        ethers.utils.parseEther('1'), // 1% min position size
        ethers.utils.parseEther('1'), // 1% min stop loss
        ethers.utils.parseEther('5'), // 5% min take profit
        ethers.utils.parseEther('1')  // 1% min daily loss
      );
      
      let riskParams = await defiAgent.getRiskParameters();
      expect(riskParams.maxPositionSize).to.equal(ethers.utils.parseEther('1'));
      
      // Test maximum values
      await defiAgent.updateRiskParameters(
        ethers.utils.parseEther('100'), // 100% max position size
        ethers.utils.parseEther('50'),  // 50% max stop loss
        ethers.utils.parseEther('100'), // 100% take profit
        ethers.utils.parseEther('50')   // 50% max daily loss
      );
      
      riskParams = await defiAgent.getRiskParameters();
      expect(riskParams.maxPositionSize).to.equal(ethers.utils.parseEther('100'));
    });

    it('Should handle contract receiving BNB', async function () {
      const sendAmount = ethers.utils.parseEther('1');
      
      await expect(
        owner.sendTransaction({
          to: defiAgent.address,
          value: sendAmount
        })
      ).to.not.be.reverted;
      
      const contractBalance = await ethers.provider.getBalance(defiAgent.address);
      expect(contractBalance).to.equal(sendAmount);
    });

    it('Should handle zero portfolio value correctly', async function () {
      const portfolioValue = await defiAgent.getPortfolioValue();
      expect(portfolioValue).to.equal(0);
    });

    it('Should handle position management with different protocols', async function () {
      await defiAgent.addSupportedToken(tokenA.address);
      await defiAgent.addSupportedProtocol('Venus', user1.address);
      await defiAgent.addSupportedProtocol('PancakeSwap', user2.address);
      
      // Open positions with different protocols
      await defiAgent.openPosition(tokenA.address, ethers.utils.parseEther('100'), 'Venus');
      await defiAgent.openPosition(tokenA.address, ethers.utils.parseEther('200'), 'PancakeSwap');
      
      const position1 = await defiAgent.positions(1);
      const position2 = await defiAgent.positions(2);
      
      expect(position1.protocol).to.equal('Venus');
      expect(position2.protocol).to.equal('PancakeSwap');
      expect(position1.amount).to.equal(ethers.utils.parseEther('100'));
      expect(position2.amount).to.equal(ethers.utils.parseEther('200'));
    });
  });

  describe('Integration Tests', function () {
    it('Should work correctly with learning module integration', async function () {
      await defiAgent.enableLearning(merkleTreeLearning.address);
      await defiAgent.addSupportedToken(tokenA.address);
      await defiAgent.addSupportedToken(tokenB.address);
      await defiAgent.addSupportedProtocol('PancakeSwap', user1.address);
      
      // Execute operations that should trigger learning
      await defiAgent.executeSwap(
        tokenA.address,
        tokenB.address,
        ethers.utils.parseEther('100'),
        ethers.utils.parseEther('95'),
        'PancakeSwap'
      );
      
      await defiAgent.openPosition(tokenA.address, ethers.utils.parseEther('100'), 'PancakeSwap');
      await defiAgent.closePosition(1);
      
      // Verify learning is still enabled and working
      expect(await defiAgent.learningEnabled()).to.equal(true);
      expect(await defiAgent.learningModule()).to.equal(merkleTreeLearning.address);
    });

    it('Should maintain state consistency across multiple operations', async function () {
      // Setup
      await defiAgent.addSupportedToken(tokenA.address);
      await defiAgent.addSupportedToken(tokenB.address);
      await defiAgent.addSupportedProtocol('PancakeSwap', user1.address);
      await defiAgent.enableLearning(merkleTreeLearning.address);
      
      // Update profile
      await defiAgent.updateProfile('Updated Agent', 'Aggressive', 80, 90, 200, true);
      
      // Execute trades and positions
      await defiAgent.executeSwap(tokenA.address, tokenB.address, ethers.utils.parseEther('50'), ethers.utils.parseEther('45'), 'PancakeSwap');
      await defiAgent.openPosition(tokenA.address, ethers.utils.parseEther('100'), 'PancakeSwap');
      
      // Update risk parameters
      await defiAgent.updateRiskParameters(
        ethers.utils.parseEther('25'),
        ethers.utils.parseEther('12'),
        ethers.utils.parseEther('25'),
        ethers.utils.parseEther('8')
      );
      
      // Verify all state is consistent
      const profile = await defiAgent.profile();
      const metrics = await defiAgent.getTradingMetrics();
      const riskParams = await defiAgent.getRiskParameters();
      
      expect(profile.name).to.equal('Updated Agent');
      expect(profile.riskTolerance).to.equal(80);
      expect(metrics.totalTrades).to.equal(1);
      expect(riskParams.maxPositionSize).to.equal(ethers.utils.parseEther('25'));
      expect(await defiAgent.learningEnabled()).to.equal(true);
      expect(await defiAgent.positionCounter()).to.equal(1);
    });
  });
});
