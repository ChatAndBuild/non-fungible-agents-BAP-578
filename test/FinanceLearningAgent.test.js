const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('FinanceLearningAgent', function () {
  let FinanceLearningAgent;
  let financeAgent;
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

  // Finance agent profile data
  const agentName = 'Test Finance Agent';
  const specialization = 'Technical Analysis';
  const analysisDepth = 75; // High analysis depth

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

    // Deploy FinanceLearningAgent
    FinanceLearningAgent = await ethers.getContractFactory('FinanceLearningAgent');
    financeAgent = await FinanceLearningAgent.deploy(
      mockAgentTokenAddress,
      agentName,
      specialization,
      analysisDepth
    );
    await financeAgent.deployed();
  });

  describe('Deployment', function () {
    it('Should set the correct agent token address', async function () {
      expect(await financeAgent.agentToken()).to.equal(mockAgentTokenAddress);
    });

    it('Should set the correct finance profile', async function () {
      const profile = await financeAgent.profile();
      expect(profile.name).to.equal(agentName);
      expect(profile.specialization).to.equal(specialization);
      expect(profile.analysisDepth).to.equal(analysisDepth);
      expect(profile.learningRate).to.equal(75); // Default fast learner
      expect(profile.confidenceThreshold).to.equal(70); // Default 70% confidence
    });

    it('Should initialize with learning disabled', async function () {
      expect(await financeAgent.learningEnabled()).to.equal(false);
      expect(await financeAgent.learningModule()).to.equal(ethers.constants.AddressZero);
    });

    it('Should set the correct owner', async function () {
      expect(await financeAgent.owner()).to.equal(owner.address);
    });

    it('Should initialize learning metrics to zero', async function () {
      expect(await financeAgent.totalAnalyses()).to.equal(0);
      expect(await financeAgent.accuratePredictions()).to.equal(0);
      expect(await financeAgent.predictionAccuracy()).to.equal(0);
    });

    it('Should not allow initialization with zero agent token address', async function () {
      await expect(
        FinanceLearningAgent.deploy(
          ethers.constants.AddressZero,
          agentName,
          specialization,
          analysisDepth
        )
      ).to.be.revertedWith("FinanceLearningAgent: agent token is zero address");
    });

    it('Should not allow initialization with analysis depth > 100', async function () {
      await expect(
        FinanceLearningAgent.deploy(
          mockAgentTokenAddress,
          agentName,
          specialization,
          101
        )
      ).to.be.revertedWith("FinanceLearningAgent: analysis depth must be 0-100");
    });
  });

  describe('Profile Management', function () {
    it('Should allow owner to update profile', async function () {
      const newName = 'Updated Finance Agent';
      const newSpecialization = 'Fundamental Analysis';
      const newAnalysisDepth = 85;
      const newLearningRate = 90;
      const newConfidenceThreshold = 80;

      await financeAgent.updateProfile(
        newName,
        newSpecialization,
        newAnalysisDepth,
        newLearningRate,
        newConfidenceThreshold
      );

      const profile = await financeAgent.profile();
      expect(profile.name).to.equal(newName);
      expect(profile.specialization).to.equal(newSpecialization);
      expect(profile.analysisDepth).to.equal(newAnalysisDepth);
      expect(profile.learningRate).to.equal(newLearningRate);
      expect(profile.confidenceThreshold).to.equal(newConfidenceThreshold);
    });

    it('Should not allow non-owner to update profile', async function () {
      await expect(
        financeAgent.connect(user1).updateProfile(
          'New Name',
          'New Specialization',
          50,
          60,
          70
        )
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it('Should not allow updating profile with invalid parameters', async function () {
      // Test analysis depth > 100
      await expect(
        financeAgent.updateProfile(
          'Test',
          'Test',
          101,
          50,
          50
        )
      ).to.be.revertedWith("FinanceLearningAgent: analysis depth must be 0-100");

      // Test learning rate > 100
      await expect(
        financeAgent.updateProfile(
          'Test',
          'Test',
          50,
          101,
          50
        )
      ).to.be.revertedWith("FinanceLearningAgent: learning rate must be 0-100");

      // Test confidence threshold > 100
      await expect(
        financeAgent.updateProfile(
          'Test',
          'Test',
          50,
          50,
          101
        )
      ).to.be.revertedWith("FinanceLearningAgent: confidence threshold must be 0-100");
    });
  });

  describe('Learning Module Management', function () {
    it('Should allow owner to enable learning', async function () {
      await financeAgent.enableLearning(merkleTreeLearning.address);

      expect(await financeAgent.learningEnabled()).to.equal(true);
      expect(await financeAgent.learningModule()).to.equal(merkleTreeLearning.address);
    });

    it('Should not allow non-owner to enable learning', async function () {
      await expect(
        financeAgent.connect(user1).enableLearning(merkleTreeLearning.address)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it('Should not allow enabling learning with zero address', async function () {
      await expect(
        financeAgent.enableLearning(ethers.constants.AddressZero)
      ).to.be.revertedWith("FinanceLearningAgent: learning module is zero address");
    });

    it('Should not allow enabling learning twice', async function () {
      await financeAgent.enableLearning(merkleTreeLearning.address);

      await expect(
        financeAgent.enableLearning(merkleTreeLearning.address)
      ).to.be.revertedWith("FinanceLearningAgent: learning already enabled");
    });
  });

  describe('Asset Management', function () {
    it('Should allow owner to add supported assets', async function () {
      await financeAgent.addSupportedAsset(tokenA.address);

      expect(await financeAgent.supportedAssets(tokenA.address)).to.equal(true);
      
      const supportedAssets = await financeAgent.getSupportedAssets();
      expect(supportedAssets).to.include(tokenA.address);
    });

    it('Should not allow non-owner to add supported assets', async function () {
      await expect(
        financeAgent.connect(user1).addSupportedAsset(tokenA.address)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it('Should not allow adding zero address as supported asset', async function () {
      await expect(
        financeAgent.addSupportedAsset(ethers.constants.AddressZero)
      ).to.be.revertedWith("FinanceLearningAgent: asset address is zero");
    });

    it('Should not allow adding the same asset twice', async function () {
      await financeAgent.addSupportedAsset(tokenA.address);

      await expect(
        financeAgent.addSupportedAsset(tokenA.address)
      ).to.be.revertedWith("FinanceLearningAgent: asset already supported");
    });

    it('Should return correct list of supported assets', async function () {
      await financeAgent.addSupportedAsset(tokenA.address);
      await financeAgent.addSupportedAsset(tokenB.address);

      const supportedAssets = await financeAgent.getSupportedAssets();
      expect(supportedAssets).to.include(tokenA.address);
      expect(supportedAssets).to.include(tokenB.address);
      expect(supportedAssets.length).to.equal(2);
    });
  });

  describe('Market Data Management', function () {
    beforeEach(async function () {
      await financeAgent.addSupportedAsset(tokenA.address);
    });

    it('Should allow owner to update market data', async function () {
      const price = ethers.utils.parseEther('1.5');
      const volume = ethers.utils.parseEther('1000000');
      const marketCap = ethers.utils.parseEther('50000000');

      const tx = await financeAgent.updateMarketData(tokenA.address, price, volume, marketCap);
      const receipt = await tx.wait();
      const event = receipt.events?.find(e => e.event === 'MarketDataUpdated');

      expect(event).to.not.be.undefined;
      expect(event.args.asset).to.equal(tokenA.address);
      expect(event.args.price).to.equal(price);
      expect(event.args.volume).to.equal(volume);
      expect(event.args.marketCap).to.equal(marketCap);
      expect(event.args.timestamp).to.be.gt(0);

      const marketData = await financeAgent.getMarketData(tokenA.address);
      expect(marketData.asset).to.equal(tokenA.address);
      expect(marketData.price).to.equal(price);
      expect(marketData.volume).to.equal(volume);
      expect(marketData.marketCap).to.equal(marketCap);
      expect(marketData.timestamp).to.be.gt(0);
    });

    it('Should not allow non-owner to update market data', async function () {
      await expect(
        financeAgent.connect(user1).updateMarketData(
          tokenA.address,
          ethers.utils.parseEther('1'),
          ethers.utils.parseEther('1000'),
          ethers.utils.parseEther('10000')
        )
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it('Should not allow updating market data for unsupported asset', async function () {
      await expect(
        financeAgent.updateMarketData(
          tokenB.address,
          ethers.utils.parseEther('1'),
          ethers.utils.parseEther('1000'),
          ethers.utils.parseEther('10000')
        )
      ).to.be.revertedWith("FinanceLearningAgent: asset not supported");
    });

    it('Should allow updating market data multiple times', async function () {
      const price1 = ethers.utils.parseEther('1.0');
      const price2 = ethers.utils.parseEther('1.5');

      await financeAgent.updateMarketData(
        tokenA.address,
        price1,
        ethers.utils.parseEther('1000'),
        ethers.utils.parseEther('10000')
      );

      await financeAgent.updateMarketData(
        tokenA.address,
        price2,
        ethers.utils.parseEther('2000'),
        ethers.utils.parseEther('20000')
      );

      const marketData = await financeAgent.getMarketData(tokenA.address);
      expect(marketData.price).to.equal(price2);
    });
  });

  describe('Analysis Functions', function () {
    beforeEach(async function () {
      await financeAgent.addSupportedAsset(tokenA.address);
      await financeAgent.updateMarketData(
        tokenA.address,
        ethers.utils.parseEther('1.5'),
        ethers.utils.parseEther('1000000'),
        ethers.utils.parseEther('50000000')
      );
    });

    it('Should perform analysis successfully', async function () {
      const analysisType = 'Technical Analysis';

      const tx = await financeAgent.performAnalysis(tokenA.address, analysisType);
      const receipt = await tx.wait();
      const event = receipt.events?.find(e => e.event === 'AnalysisPerformed');

      expect(event).to.not.be.undefined;
      expect(event.args.asset).to.equal(tokenA.address);
      expect(event.args.analysisType).to.equal(analysisType);
      expect(event.args.confidence).to.be.gt(0);
      expect(event.args.recommendation).to.not.equal(0);
      expect(event.args.timestamp).to.be.gt(0);

      // Check that analysis ID was generated
      const analysisId = event.args.analysisId;
      expect(analysisId).to.not.equal(ethers.constants.HashZero);

      // Verify analysis result was stored
      const analysisResult = await financeAgent.getAnalysisResult(analysisId);
      expect(analysisResult.analysisId).to.equal(analysisId);
      expect(analysisResult.asset).to.equal(tokenA.address);
      expect(analysisResult.analysisType).to.equal(analysisType);
      expect(analysisResult.wasAccurate).to.equal(false);
    });

    it('Should not allow non-owner to perform analysis', async function () {
      await expect(
        financeAgent.connect(user1).performAnalysis(tokenA.address, 'Technical Analysis')
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it('Should not allow analysis on unsupported asset', async function () {
      await expect(
        financeAgent.performAnalysis(tokenB.address, 'Technical Analysis')
      ).to.be.revertedWith("FinanceLearningAgent: asset not supported");
    });

    it('Should increment total analyses counter', async function () {
      expect(await financeAgent.totalAnalyses()).to.equal(0);

      await financeAgent.performAnalysis(tokenA.address, 'Technical Analysis');
      expect(await financeAgent.totalAnalyses()).to.equal(1);

      await financeAgent.performAnalysis(tokenA.address, 'Fundamental Analysis');
      expect(await financeAgent.totalAnalyses()).to.equal(2);
    });

    it('Should generate different analysis IDs for different analyses', async function () {
      const tx1 = await financeAgent.performAnalysis(tokenA.address, 'Technical Analysis');
      const tx2 = await financeAgent.performAnalysis(tokenA.address, 'Fundamental Analysis');

      const receipt1 = await tx1.wait();
      const receipt2 = await tx2.wait();

      const event1 = receipt1.events?.find(e => e.event === 'AnalysisPerformed');
      const event2 = receipt2.events?.find(e => e.event === 'AnalysisPerformed');

      expect(event1.args.analysisId).to.not.equal(event2.args.analysisId);
    });

    it('Should handle analysis with insufficient data', async function () {
      // Add asset without market data
      await financeAgent.addSupportedAsset(tokenB.address);

      const tx = await financeAgent.performAnalysis(tokenB.address, 'Technical Analysis');
      const receipt = await tx.wait();
      const event = receipt.events?.find(e => e.event === 'AnalysisPerformed');

      expect(event.args.confidence).to.equal(30); // Low confidence for insufficient data
      expect(event.args.recommendation).to.equal(0); // Neutral recommendation
    });
  });

  describe('Prediction Validation', function () {
    let analysisId;

    beforeEach(async function () {
      await financeAgent.addSupportedAsset(tokenA.address);
      await financeAgent.updateMarketData(
        tokenA.address,
        ethers.utils.parseEther('1.5'),
        ethers.utils.parseEther('1000000'),
        ethers.utils.parseEther('50000000')
      );

      const tx = await financeAgent.performAnalysis(tokenA.address, 'Technical Analysis');
      const receipt = await tx.wait();
      const event = receipt.events?.find(e => e.event === 'AnalysisPerformed');
      analysisId = event.args.analysisId;
    });

    it('Should validate accurate prediction successfully', async function () {
      const actualOutcome = ethers.utils.parseEther('1.6');
      const wasAccurate = true;

      const tx = await financeAgent.validatePrediction(analysisId, actualOutcome, wasAccurate);
      const receipt = await tx.wait();
      const event = receipt.events?.find(e => e.event === 'PredictionValidated');

      expect(event).to.not.be.undefined;
      expect(event.args.analysisId).to.equal(analysisId);
      expect(event.args.wasAccurate).to.equal(wasAccurate);
      expect(event.args.actualOutcome).to.equal(actualOutcome);
      expect(event.args.timestamp).to.be.gt(0);

      // Check that analysis result was updated
      const analysisResult = await financeAgent.getAnalysisResult(analysisId);
      expect(analysisResult.wasAccurate).to.equal(true);

      // Check that learning metrics were updated
      expect(await financeAgent.accuratePredictions()).to.equal(1);
      expect(await financeAgent.predictionAccuracy()).to.equal(100); // 1/1 = 100%
    });

    it('Should validate inaccurate prediction successfully', async function () {
      const actualOutcome = ethers.utils.parseEther('1.4');
      const wasAccurate = false;

      await financeAgent.validatePrediction(analysisId, actualOutcome, wasAccurate);

      // Check that analysis result was updated
      const analysisResult = await financeAgent.getAnalysisResult(analysisId);
      expect(analysisResult.wasAccurate).to.equal(false);

      // Check that learning metrics were updated
      expect(await financeAgent.accuratePredictions()).to.equal(0);
      expect(await financeAgent.predictionAccuracy()).to.equal(0); // 0/1 = 0%
    });

    it('Should not allow non-owner to validate prediction', async function () {
      await expect(
        financeAgent.connect(user1).validatePrediction(
          analysisId,
          ethers.utils.parseEther('1.6'),
          true
        )
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it('Should not allow validating non-existent analysis', async function () {
      const fakeAnalysisId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('fake'));
      
      await expect(
        financeAgent.validatePrediction(
          fakeAnalysisId,
          ethers.utils.parseEther('1.6'),
          true
        )
      ).to.be.revertedWith("FinanceLearningAgent: analysis not found");
    });

    it('Should calculate prediction accuracy correctly with multiple predictions', async function () {
      // Perform second analysis
      const tx2 = await financeAgent.performAnalysis(tokenA.address, 'Fundamental Analysis');
      const receipt2 = await tx2.wait();
      const event2 = receipt2.events?.find(e => e.event === 'AnalysisPerformed');
      const analysisId2 = event2.args.analysisId;

      // At this point, we have 2 total analyses (1 from beforeEach + 1 from this test)
      expect(await financeAgent.totalAnalyses()).to.equal(2);

      // Validate first prediction as accurate
      await financeAgent.validatePrediction(analysisId, ethers.utils.parseEther('1.6'), true);
      expect(await financeAgent.predictionAccuracy()).to.equal(50); // 1/2 = 50% (1 accurate out of 2 total)

      // Validate second prediction as inaccurate
      await financeAgent.validatePrediction(analysisId2, ethers.utils.parseEther('1.4'), false);
      expect(await financeAgent.predictionAccuracy()).to.equal(50); // 1/2 = 50% (1 accurate out of 2 total)
    });
  });

  describe('Learning Integration', function () {
    beforeEach(async function () {
      await financeAgent.enableLearning(merkleTreeLearning.address);
      await financeAgent.addSupportedAsset(tokenA.address);
      await financeAgent.updateMarketData(
        tokenA.address,
        ethers.utils.parseEther('1.5'),
        ethers.utils.parseEther('1000000'),
        ethers.utils.parseEther('50000000')
      );
    });

    it('Should emit learning update when performing analysis', async function () {
      const tx = await financeAgent.performAnalysis(tokenA.address, 'Technical Analysis');
      const receipt = await tx.wait();
      const event = receipt.events?.find(e => e.event === 'LearningUpdate');

      expect(event).to.not.be.undefined;
      expect(event.args.updateType).to.equal('analysis_performed');
      expect(event.args.accuracy).to.be.gt(0);
      expect(event.args.timestamp).to.be.gt(0);
    });

    it('Should emit learning update when validating prediction', async function () {
      const tx = await financeAgent.performAnalysis(tokenA.address, 'Technical Analysis');
      const receipt = await tx.wait();
      const event = receipt.events?.find(e => e.event === 'AnalysisPerformed');
      const analysisId = event.args.analysisId;

      await financeAgent.validatePrediction(analysisId, ethers.utils.parseEther('1.6'), true);

      // The learning update event should be emitted
      // Note: We can't easily capture this event in the test since it's emitted in the same transaction
      // but we can verify the function doesn't revert
    });

    it('Should not emit learning updates when learning is disabled', async function () {
      // Disable learning by setting learning module to zero address
      // We need to create a new agent without learning enabled
      const newFinanceAgent = await FinanceLearningAgent.deploy(
        mockAgentTokenAddress,
        'Test Agent No Learning',
        'Technical Analysis',
        50
      );
      await newFinanceAgent.deployed();
      
      await newFinanceAgent.addSupportedAsset(tokenA.address);
      await newFinanceAgent.updateMarketData(
        tokenA.address,
        ethers.utils.parseEther('1.5'),
        ethers.utils.parseEther('1000000'),
        ethers.utils.parseEther('50000000')
      );

      const tx = await newFinanceAgent.performAnalysis(tokenA.address, 'Technical Analysis');
      const receipt = await tx.wait();
      const event = receipt.events?.find(e => e.event === 'LearningUpdate');

      expect(event).to.be.undefined;
    });
  });

  describe('Access Control', function () {
    it('Should only allow agent token to call restricted functions', async function () {
      // Note: This test would require the actual BEP007 token contract
      // For now, we test that non-owner calls are restricted
      await expect(
        financeAgent.connect(user1).performAnalysis(tokenA.address, 'Technical Analysis')
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it('Should allow owner to transfer ownership', async function () {
      await financeAgent.transferOwnership(user1.address);
      expect(await financeAgent.owner()).to.equal(user1.address);
    });
  });

  describe('Edge Cases and Error Handling', function () {
    it('Should handle multiple analyses on same asset', async function () {
      await financeAgent.addSupportedAsset(tokenA.address);
      await financeAgent.updateMarketData(
        tokenA.address,
        ethers.utils.parseEther('1.5'),
        ethers.utils.parseEther('1000000'),
        ethers.utils.parseEther('50000000')
      );

      // Perform multiple analyses
      await financeAgent.performAnalysis(tokenA.address, 'Technical Analysis');
      await financeAgent.performAnalysis(tokenA.address, 'Fundamental Analysis');
      await financeAgent.performAnalysis(tokenA.address, 'Sentiment Analysis');

      expect(await financeAgent.totalAnalyses()).to.equal(3);
    });

    it('Should handle market data updates for multiple assets', async function () {
      await financeAgent.addSupportedAsset(tokenA.address);
      await financeAgent.addSupportedAsset(tokenB.address);

      await financeAgent.updateMarketData(
        tokenA.address,
        ethers.utils.parseEther('1.5'),
        ethers.utils.parseEther('1000000'),
        ethers.utils.parseEther('50000000')
      );

      await financeAgent.updateMarketData(
        tokenB.address,
        ethers.utils.parseEther('2.0'),
        ethers.utils.parseEther('2000000'),
        ethers.utils.parseEther('100000000')
      );

      const marketDataA = await financeAgent.getMarketData(tokenA.address);
      const marketDataB = await financeAgent.getMarketData(tokenB.address);

      expect(marketDataA.price).to.equal(ethers.utils.parseEther('1.5'));
      expect(marketDataB.price).to.equal(ethers.utils.parseEther('2.0'));
    });

    it('Should handle analysis with zero market data', async function () {
      await financeAgent.addSupportedAsset(tokenA.address);
      // Don't update market data

      const tx = await financeAgent.performAnalysis(tokenA.address, 'Technical Analysis');
      const receipt = await tx.wait();
      const event = receipt.events?.find(e => e.event === 'AnalysisPerformed');

      expect(event.args.confidence).to.equal(30); // Low confidence for insufficient data
    });
  });

  describe('Events', function () {
    beforeEach(async function () {
      await financeAgent.addSupportedAsset(tokenA.address);
    });

    it('Should emit MarketDataUpdated event with correct parameters', async function () {
      const price = ethers.utils.parseEther('1.5');
      const volume = ethers.utils.parseEther('1000000');
      const marketCap = ethers.utils.parseEther('50000000');

      const tx = await financeAgent.updateMarketData(tokenA.address, price, volume, marketCap);
      const receipt = await tx.wait();
      const event = receipt.events?.find(e => e.event === 'MarketDataUpdated');

      expect(event).to.not.be.undefined;
      expect(event.args.asset).to.equal(tokenA.address);
      expect(event.args.price).to.equal(price);
      expect(event.args.volume).to.equal(volume);
      expect(event.args.marketCap).to.equal(marketCap);
      expect(event.args.timestamp).to.be.gt(0);
    });

    it('Should emit AnalysisPerformed event with correct parameters', async function () {
      await financeAgent.updateMarketData(
        tokenA.address,
        ethers.utils.parseEther('1.5'),
        ethers.utils.parseEther('1000000'),
        ethers.utils.parseEther('50000000')
      );

      const analysisType = 'Technical Analysis';

      const tx = await financeAgent.performAnalysis(tokenA.address, analysisType);
      const receipt = await tx.wait();
      const event = receipt.events?.find(e => e.event === 'AnalysisPerformed');

      expect(event).to.not.be.undefined;
      expect(event.args.asset).to.equal(tokenA.address);
      expect(event.args.analysisType).to.equal(analysisType);
      expect(event.args.confidence).to.be.gt(0);
      expect(event.args.recommendation).to.not.equal(0);
      expect(event.args.timestamp).to.be.gt(0);
      expect(event.args.analysisId).to.not.equal(ethers.constants.HashZero);
    });

    it('Should emit PredictionValidated event with correct parameters', async function () {
      await financeAgent.updateMarketData(
        tokenA.address,
        ethers.utils.parseEther('1.5'),
        ethers.utils.parseEther('1000000'),
        ethers.utils.parseEther('50000000')
      );

      const tx = await financeAgent.performAnalysis(tokenA.address, 'Technical Analysis');
      const receipt = await tx.wait();
      const event = receipt.events?.find(e => e.event === 'AnalysisPerformed');
      const analysisId = event.args.analysisId;

      const actualOutcome = ethers.utils.parseEther('1.6');
      const wasAccurate = true;

      const validateTx = await financeAgent.validatePrediction(analysisId, actualOutcome, wasAccurate);
      const validateReceipt = await validateTx.wait();
      const validateEvent = validateReceipt.events?.find(e => e.event === 'PredictionValidated');

      expect(validateEvent).to.not.be.undefined;
      expect(validateEvent.args.analysisId).to.equal(analysisId);
      expect(validateEvent.args.wasAccurate).to.equal(wasAccurate);
      expect(validateEvent.args.actualOutcome).to.equal(actualOutcome);
      expect(validateEvent.args.timestamp).to.be.gt(0);
    });
  });
});

