const { expect } = require('chai');
const { ethers, upgrades } = require('hardhat');

describe('StrategicAgent Template Integration', function () {
  let StrategicAgent;
  let strategicAgent;
  let BEP007;
  let bep007;
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

    // Deploy BEP007 with CircuitBreaker as governance
    BEP007 = await ethers.getContractFactory('BEP007');
    bep007 = await upgrades.deployProxy(
      BEP007,
      ['Non-Fungible Agent', 'NFA', circuitBreaker.address],
      { initializer: 'initialize', kind: 'uups' },
    );
    await bep007.deployed();

    // Deploy StrategicAgent template
    StrategicAgent = await ethers.getContractFactory('StrategicAgent');
    strategicAgent = await StrategicAgent.deploy(
      bep007.address,
      'Strategic Monitor',
      'Crypto Analysis',
      75 // monitoring intensity
    );
    await strategicAgent.deployed();
  });

  describe('Deployment', function () {
    it('Should set the right agent token address', async function () {
      expect(await strategicAgent.agentToken()).to.equal(bep007.address);
    });

    it('Should initialize with correct profile', async function () {
      const profile = await strategicAgent.getProfile();
      expect(profile.name).to.equal('Strategic Monitor');
      expect(profile.specialization).to.equal('Crypto Analysis');
      expect(profile.monitoringIntensity).to.equal(75);
      expect(profile.analysisDepth).to.equal(50); // default value
      expect(profile.realTimeMonitoring).to.equal(true);
      expect(profile.crossPlatformAnalysis).to.equal(true);
    });

    it('Should initialize with empty target keywords and entities', async function () {
      const keywords = await strategicAgent.getTargetKeywords();
      const entities = await strategicAgent.getTargetEntities();
      expect(keywords).to.have.lengthOf(0);
      expect(entities).to.have.lengthOf(0);
    });

    it('Should initialize with zero metrics', async function () {
      const metrics = await strategicAgent.getMetrics();
      expect(metrics.totalTrendsDetected).to.equal(0);
      expect(metrics.totalMentionsTracked).to.equal(0);
      expect(metrics.totalAnalysesPerformed).to.equal(0);
      expect(metrics.accuracyScore).to.equal(0);
      expect(metrics.responseTime).to.equal(0);
    });
  });

  describe('Profile Management', function () {
    it('Should allow owner to update profile', async function () {
      await strategicAgent.updateProfile(
        'Advanced Monitor',
        'Tech Analysis',
        85, // monitoring intensity
        75, // analysis depth
        false, // real-time monitoring
        true  // cross-platform analysis
      );

      const profile = await strategicAgent.getProfile();
      expect(profile.name).to.equal('Advanced Monitor');
      expect(profile.specialization).to.equal('Tech Analysis');
      expect(profile.monitoringIntensity).to.equal(85);
      expect(profile.analysisDepth).to.equal(75);
      expect(profile.realTimeMonitoring).to.equal(false);
      expect(profile.crossPlatformAnalysis).to.equal(true);
    });

    it('Should reject invalid monitoring intensity', async function () {
      await expect(
        strategicAgent.updateProfile(
          'Test',
          'Test',
          101, // invalid intensity
          50,
          true,
          true
        )
      ).to.be.revertedWith('StrategicAgent: monitoring intensity must be 0-100');
    });

    it('Should reject invalid analysis depth', async function () {
      await expect(
        strategicAgent.updateProfile(
          'Test',
          'Test',
          50,
          101, // invalid depth
          true,
          true
        )
      ).to.be.revertedWith('StrategicAgent: analysis depth must be 0-100');
    });
  });

  describe('Target Management', function () {
    it('Should allow owner to add target keywords', async function () {
      await strategicAgent.addTargetKeyword('Bitcoin');
      await strategicAgent.addTargetKeyword('Ethereum');
      await strategicAgent.addTargetKeyword('DeFi');

      const keywords = await strategicAgent.getTargetKeywords();
      expect(keywords).to.have.lengthOf(3);
      expect(keywords[0]).to.equal('Bitcoin');
      expect(keywords[1]).to.equal('Ethereum');
      expect(keywords[2]).to.equal('DeFi');
    });

    it('Should allow owner to add target entities', async function () {
      await strategicAgent.addTargetEntity('Vitalik Buterin');
      await strategicAgent.addTargetEntity('Binance');
      await strategicAgent.addTargetEntity('Coinbase');

      const entities = await strategicAgent.getTargetEntities();
      expect(entities).to.have.lengthOf(3);
      expect(entities[0]).to.equal('Vitalik Buterin');
      expect(entities[1]).to.equal('Binance');
      expect(entities[2]).to.equal('Coinbase');
    });

    it('Should reject duplicate keywords', async function () {
      await strategicAgent.addTargetKeyword('Bitcoin');
      
      await expect(
        strategicAgent.addTargetKeyword('Bitcoin')
      ).to.be.revertedWith('StrategicAgent: keyword already exists');
    });

    it('Should reject duplicate entities', async function () {
      await strategicAgent.addTargetEntity('Vitalik Buterin');
      
      await expect(
        strategicAgent.addTargetEntity('Vitalik Buterin')
      ).to.be.revertedWith('StrategicAgent: entity already exists');
    });

    it('Should reject empty keywords', async function () {
      await expect(
        strategicAgent.addTargetKeyword('')
      ).to.be.revertedWith('StrategicAgent: keyword cannot be empty');
    });

    it('Should reject empty entities', async function () {
      await expect(
        strategicAgent.addTargetEntity('')
      ).to.be.revertedWith('StrategicAgent: entity cannot be empty');
    });
  });

  describe('Platform Configuration', function () {
    it('Should allow owner to configure platforms', async function () {
      await strategicAgent.configurePlatform(
        'Twitter',
        addr1.address, // mock oracle address
        true,
        8, // priority
        300 // update frequency (5 minutes)
      );

      const platform = await strategicAgent.getPlatformConfig('Twitter');
      expect(platform.name).to.equal('Twitter');
      expect(platform.oracleAddress).to.equal(addr1.address);
      expect(platform.enabled).to.equal(true);
      expect(platform.priority).to.equal(8);
      expect(platform.updateFrequency).to.equal(300);

      const platforms = await strategicAgent.getPlatforms();
      expect(platforms).to.have.lengthOf(1);
      expect(platforms[0]).to.equal('Twitter');
    });

    it('Should reject invalid priority levels', async function () {
      await expect(
        strategicAgent.configurePlatform(
          'Twitter',
          addr1.address,
          true,
          0, // invalid priority
          300
        )
      ).to.be.revertedWith('StrategicAgent: priority must be 1-10');

      await expect(
        strategicAgent.configurePlatform(
          'Twitter',
          addr1.address,
          true,
          11, // invalid priority
          300
        )
      ).to.be.revertedWith('StrategicAgent: priority must be 1-10');
    });

    it('Should reject zero update frequency', async function () {
      await expect(
        strategicAgent.configurePlatform(
          'Twitter',
          addr1.address,
          true,
          5,
          0 // invalid frequency
        )
      ).to.be.revertedWith('StrategicAgent: update frequency must be greater than 0');
    });
  });

  describe('Alert Configuration', function () {
    it('Should allow owner to configure alerts', async function () {
      await strategicAgent.configureAlert(
        'trend',
        100, // threshold
        true,
        3600 // cooldown period (1 hour)
      );

      const alert = await strategicAgent.getAlertConfig('trend');
      expect(alert.alertType).to.equal('trend');
      expect(alert.threshold).to.equal(100);
      expect(alert.enabled).to.equal(true);
      expect(alert.cooldownPeriod).to.equal(3600);

      const alertTypes = await strategicAgent.getAlertTypes();
      expect(alertTypes).to.have.lengthOf(1);
      expect(alertTypes[0]).to.equal('trend');
    });
  });

  describe('Trend Detection', function () {
    it('Should allow owner to detect trends', async function () {
      const platforms = ['Twitter', 'Reddit'];
      const topPosts = ['Post 1', 'Post 2'];

      await expect(
        strategicAgent.detectTrend(
          'Bitcoin',
          150, // mentions
          75, // sentiment score (positive)
          85, // confidence
          platforms,
          topPosts
        )
      ).to.emit(strategicAgent, 'TrendDetected')
        .withArgs('Bitcoin', 150, 75, 85, platforms);

      const trend = await strategicAgent.getTrend('Bitcoin');
      expect(trend.keyword).to.equal('Bitcoin');
      expect(trend.mentions).to.equal(150);
      expect(trend.sentimentScore).to.equal(75);
      expect(trend.confidence).to.equal(85);
      expect(trend.platforms).to.deep.equal(platforms);
      expect(trend.topPosts).to.deep.equal(topPosts);

      const metrics = await strategicAgent.getMetrics();
      expect(metrics.totalTrendsDetected).to.equal(1);
    });

    it('Should reject invalid sentiment scores', async function () {
      await expect(
        strategicAgent.detectTrend(
          'Bitcoin',
          100,
          101, // invalid sentiment score
          80,
          ['Twitter'],
          ['Post 1']
        )
      ).to.be.revertedWith('StrategicAgent: sentiment score must be -100 to +100');

      await expect(
        strategicAgent.detectTrend(
          'Bitcoin',
          100,
          -101, // invalid sentiment score
          80,
          ['Twitter'],
          ['Post 1']
        )
      ).to.be.revertedWith('StrategicAgent: sentiment score must be -100 to +100');
    });

    it('Should reject invalid confidence levels', async function () {
      await expect(
        strategicAgent.detectTrend(
          'Bitcoin',
          100,
          50,
          101, // invalid confidence
          ['Twitter'],
          ['Post 1']
        )
      ).to.be.revertedWith('StrategicAgent: confidence must be 0-100');
    });
  });

  describe('Mention Detection', function () {
    it('Should allow owner to record mentions', async function () {
      await expect(
        strategicAgent.recordMention(
          'Vitalik Buterin',
          'Great work on Ethereum 2.0!',
          'Twitter',
          80, // positive sentiment
          5000, // reach
          150, // engagement
          addr1.address // author
        )
      ).to.emit(strategicAgent, 'MentionDetected')
        .withArgs('Vitalik Buterin', 'Twitter', 80, 5000, 150);

      const mentionIds = await strategicAgent.getMentionIds();
      expect(mentionIds).to.have.lengthOf(1);

      const mention = await strategicAgent.getMention(mentionIds[0]);
      expect(mention.entity).to.equal('Vitalik Buterin');
      expect(mention.content).to.equal('Great work on Ethereum 2.0!');
      expect(mention.platform).to.equal('Twitter');
      expect(mention.sentimentScore).to.equal(80);
      expect(mention.reach).to.equal(5000);
      expect(mention.engagement).to.equal(150);
      expect(mention.author).to.equal(addr1.address);

      const metrics = await strategicAgent.getMetrics();
      expect(metrics.totalMentionsTracked).to.equal(1);
    });
  });

  describe('Sentiment Analysis', function () {
    it('Should allow owner to analyze sentiment', async function () {
      const emotions = ['joy', 'excitement'];
      const emotionScores = [85, 70];

      await expect(
        strategicAgent.analyzeSentiment(
          'This is amazing news!',
          90, // very positive sentiment
          95, // high confidence
          emotions,
          emotionScores
        )
      ).to.emit(strategicAgent, 'SentimentAnalyzed');

      const sentimentIds = await strategicAgent.getSentimentIds();
      expect(sentimentIds).to.have.lengthOf(1);

      const analysis = await strategicAgent.getSentimentAnalysis(sentimentIds[0]);
      expect(analysis.content).to.equal('This is amazing news!');
      expect(analysis.overallSentiment).to.equal(90);
      expect(analysis.confidence).to.equal(95);
      expect(analysis.emotions).to.deep.equal(emotions);
      expect(analysis.emotionScores[0].toNumber()).to.equal(emotionScores[0]);
      expect(analysis.emotionScores[1].toNumber()).to.equal(emotionScores[1]);

      const metrics = await strategicAgent.getMetrics();
      expect(metrics.totalAnalysesPerformed).to.equal(1);
    });

    it('Should reject mismatched emotions and scores arrays', async function () {
      const emotions = ['joy', 'excitement'];
      const emotionScores = [85]; // mismatched length

      await expect(
        strategicAgent.analyzeSentiment(
          'Test content',
          50,
          80,
          emotions,
          emotionScores
        )
      ).to.be.revertedWith('StrategicAgent: emotions and scores arrays must match');
    });
  });

  describe('Alert System', function () {
    beforeEach(async function () {
      // Configure a trend alert
      await strategicAgent.configureAlert(
        'trend',
        100, // threshold
        true,
        0 // no cooldown for testing
      );
    });

    it('Should trigger alerts when thresholds are met', async function () {
      const platforms = ['Twitter'];
      const topPosts = ['Post 1'];

      await expect(
        strategicAgent.detectTrend(
          'Bitcoin',
          150, // above threshold
          75,
          85,
          platforms,
          topPosts
        )
      ).to.emit(strategicAgent, 'AlertTriggered');
    });
  });

  describe('Metrics and Performance', function () {
    it('Should allow owner to update metrics', async function () {
      await strategicAgent.updateMetrics(95, 120); // 95% accuracy, 120s response time

      const metrics = await strategicAgent.getMetrics();
      expect(metrics.accuracyScore).to.equal(95);
      expect(metrics.responseTime).to.equal(120);
    });

    it('Should reject invalid accuracy scores', async function () {
      await expect(
        strategicAgent.updateMetrics(101, 120) // invalid accuracy
      ).to.be.revertedWith('StrategicAgent: accuracy score must be 0-100');
    });
  });

  describe('Access Control', function () {
    it('Should reject non-owner operations', async function () {
      await expect(
        strategicAgent.connect(addr1).updateProfile(
          'Hacked',
          'Hacked',
          50,
          50,
          true,
          true
        )
      ).to.be.revertedWith('Ownable: caller is not the owner');

      await expect(
        strategicAgent.connect(addr1).addTargetKeyword('Hacked')
      ).to.be.revertedWith('Ownable: caller is not the owner');

      await expect(
        strategicAgent.connect(addr1).detectTrend(
          'Hacked',
          100,
          50,
          80,
          ['Twitter'],
          ['Post']
        )
      ).to.be.revertedWith('Ownable: caller is not the owner');
    });
  });

  describe('BEP-007 Integration', function () {
    it('Should work with BEP-007 agent creation', async function () {
      // Create an agent using the StrategicAgent template
      const metadataURI = 'ipfs://strategic-agent-metadata';
      const extendedMetadata = {
        persona: 'Strategic monitoring agent specialized in crypto analysis',
        experience: 'Advanced trend detection and sentiment analysis',
        voiceHash: '',
        animationURI: '',
        vaultURI: '',
        vaultHash: ethers.constants.HashZero
      };

      // Create agent with StrategicAgent as logic
      await bep007['createAgent(address,address,string,(string,string,string,string,string,bytes32))'](
        addr1.address,
        strategicAgent.address, // Use StrategicAgent as logic
        metadataURI,
        extendedMetadata
      );

      const tokenId = 1;
      expect(await bep007.ownerOf(tokenId)).to.equal(addr1.address);
      expect(await bep007.tokenURI(tokenId)).to.equal(metadataURI);

      const agentMetadata = await bep007.getAgentMetadata(tokenId);
      expect(agentMetadata.persona).to.equal(extendedMetadata.persona);
      expect(agentMetadata.experience).to.equal(extendedMetadata.experience);
    });
  });
});
