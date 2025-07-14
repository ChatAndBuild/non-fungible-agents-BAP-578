// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import "../interfaces/ILearningModule.sol";
import "../BEP007.sol";

/**
 * @title DeFiLearningModule
 * @dev Specialized learning module for DeFiAgent templates
 *      Focuses on trading performance, market analysis, risk management, and strategy optimization
 */
contract DeFiLearningModule is
    ILearningModule,
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using MerkleProofUpgradeable for bytes32[];

    // BEP007 token contract
    BEP007 public bep007Token;

    // DeFi-specific learning data structures
    struct DeFiLearningMetrics {
        uint256 totalInteractions;
        uint256 learningEvents;
        uint256 lastUpdateTimestamp;
        uint256 learningVelocity;
        uint256 confidenceScore;
        // DeFi-specific metrics
        uint256 totalTrades;
        uint256 successfulTrades;
        uint256 totalAnalyses;
        uint256 accurateAnalyses;
        uint256 profitabilityScore; // 0-100 scale
        uint256 riskManagementScore; // 0-100 scale
        uint256 marketTimingScore; // 0-100 scale
        uint256 strategyAdaptationScore; // 0-100 scale
        uint256 lastTradeTimestamp;
        uint256 lastAnalysisTimestamp;
    }

    struct TradeLearningData {
        uint256 tradeId;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        uint256 priceAtExecution;
        uint256 confidenceLevel;
        bool wasLearningBased;
        bool wasSuccessful;
        uint256 profitLoss; // In basis points
        uint256 timestamp;
        uint256 marketVolatility;
        uint256 trendStrength;
        string strategy; // Strategy used for the trade
    }

    struct MarketAnalysisData {
        uint256 analysisId;
        uint256 timestamp;
        uint256 priceVolatility;
        uint256 trendStrength;
        uint256 riskScore;
        uint256 opportunityScore;
        uint256 confidenceScore;
        bool bullishSignal;
        bool wasAccurate; // Determined later based on market movement
        uint256 accuracyScore; // 0-100 based on prediction accuracy
        uint256 marketCondition; // 0=bear, 1=sideways, 2=bull
    }

    struct RiskManagementData {
        uint256 timestamp;
        uint256 portfolioValue;
        uint256 maxDrawdown;
        uint256 volatilityExposure;
        uint256 diversificationScore;
        uint256 leverageRatio;
        uint256 stopLossEffectiveness;
        uint256 riskAdjustedReturn;
    }

    struct StrategyPerformanceData {
        string strategyName;
        uint256 totalTrades;
        uint256 successfulTrades;
        uint256 totalPnL;
        uint256 maxDrawdown;
        uint256 sharpeRatio;
        uint256 winRate;
        uint256 avgHoldingPeriod;
        uint256 lastUsed;
        bool isActive;
    }

    struct MarketConditionLearning {
        uint256 condition; // 0=bear, 1=sideways, 2=bull
        uint256 bestStrategy; // Index of best performing strategy
        uint256 avgSuccessRate;
        uint256 avgProfitability;
        uint256 optimalRiskLevel;
        uint256 sampleSize;
        uint256 lastUpdated;
    }

    // Mapping from token ID to learning tree root
    mapping(uint256 => bytes32) private _learningRoots;

    // Mapping from token ID to DeFi learning metrics
    mapping(uint256 => DeFiLearningMetrics) private _defiMetrics;

    // Mapping from token ID to learning enabled status
    mapping(uint256 => bool) private _learningEnabled;

    // Mapping from token ID to authorized updaters
    mapping(uint256 => mapping(address => bool)) private _authorizedUpdaters;

    // DeFi-specific learning data
    mapping(uint256 => mapping(uint256 => TradeLearningData)) private _tradeLearningData;
    mapping(uint256 => uint256) private _tradeLearningCount;

    mapping(uint256 => mapping(uint256 => MarketAnalysisData)) private _analysisLearningData;
    mapping(uint256 => uint256) private _analysisLearningCount;

    mapping(uint256 => mapping(uint256 => RiskManagementData)) private _riskLearningData;
    mapping(uint256 => uint256) private _riskLearningCount;

    mapping(uint256 => mapping(string => StrategyPerformanceData)) private _strategyPerformance;
    mapping(uint256 => string[]) private _strategyNames;

    mapping(uint256 => mapping(uint256 => MarketConditionLearning))
        private _marketConditionLearning;

    // Learning thresholds and constants
    uint256 public constant HIGH_PROFITABILITY_THRESHOLD = 70; // 70% profitability score
    uint256 public constant EXCELLENT_RISK_MANAGEMENT_THRESHOLD = 80; // 80% risk management score
    uint256 public constant ACCURATE_ANALYSIS_THRESHOLD = 75; // 75% analysis accuracy
    uint256 public constant STRATEGY_ADAPTATION_THRESHOLD = 60; // 60% adaptation score

    // Milestones specific to DeFi agents
    uint256 public constant MILESTONE_TRADES_10 = 10;
    uint256 public constant MILESTONE_TRADES_100 = 100;
    uint256 public constant MILESTONE_TRADES_1000 = 1000;
    uint256 public constant MILESTONE_PROFITABLE_TRADER = 70;
    uint256 public constant MILESTONE_RISK_MASTER = 80;
    uint256 public constant MILESTONE_MARKET_ANALYST = 75;
    uint256 public constant MILESTONE_STRATEGY_EXPERT = 85;

    // Maximum learning updates per day
    uint256 public constant MAX_UPDATES_PER_DAY = 200; // Higher for DeFi due to frequent trading
    mapping(uint256 => mapping(uint256 => uint256)) private _dailyUpdateCounts;

    // Events specific to DeFi learning
    event TradeLearningRecorded(
        uint256 indexed tokenId,
        uint256 indexed tradeId,
        bool wasSuccessful,
        uint256 profitLoss,
        uint256 confidenceLevel
    );

    event MarketAnalysisLearningRecorded(
        uint256 indexed tokenId,
        uint256 indexed analysisId,
        bool wasAccurate,
        uint256 accuracyScore,
        uint256 confidenceScore
    );

    event RiskManagementLearningRecorded(
        uint256 indexed tokenId,
        uint256 portfolioValue,
        uint256 riskScore,
        uint256 riskAdjustedReturn
    );

    event StrategyPerformanceUpdated(
        uint256 indexed tokenId,
        string strategyName,
        uint256 winRate,
        uint256 totalPnL
    );

    event DeFiMilestoneAchieved(
        uint256 indexed tokenId,
        string milestone,
        uint256 value,
        uint256 timestamp
    );

    event MarketConditionLearningUpdated(
        uint256 indexed tokenId,
        uint256 condition,
        uint256 bestStrategy,
        uint256 avgSuccessRate
    );

    /**
     * @dev Modifier to check if the caller is authorized to update learning
     */
    modifier onlyAuthorized(uint256 tokenId) {
        address owner = bep007Token.ownerOf(tokenId);

        require(
            address(bep007Token) == msg.sender ||
                msg.sender == owner ||
                _authorizedUpdaters[tokenId][msg.sender],
            "DeFiLearningModule: not authorized"
        );
        _;
    }

    /**
     * @dev Modifier to check if learning is enabled for the agent
     */
    modifier whenLearningEnabled(uint256 tokenId) {
        require(_learningEnabled[tokenId], "DeFiLearningModule: learning not enabled");
        _;
    }

    /**
     * @dev Initializes the contract
     * @param _bep007Token The address of the BEP007 token contract
     */
    function initialize(address payable _bep007Token) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();

        require(_bep007Token != address(0), "DeFiLearningModule: token is zero address");
        bep007Token = BEP007(_bep007Token);
    }

    /**
     * @dev Enables learning for a DeFi agent
     * @param tokenId The ID of the agent token
     * @param initialRoot The initial learning tree root
     * @param defiProfile Initial DeFi profile data
     */
    function enableDeFiLearning(
        uint256 tokenId,
        bytes32 initialRoot,
        bytes calldata defiProfile
    ) external {
        address owner = bep007Token.ownerOf(tokenId);
        require(msg.sender == owner, "DeFiLearningModule: not token owner");
        require(!_learningEnabled[tokenId], "DeFiLearningModule: already enabled");

        _learningEnabled[tokenId] = true;
        _learningRoots[tokenId] = initialRoot;

        // Initialize DeFi-specific learning metrics
        _defiMetrics[tokenId] = DeFiLearningMetrics({
            totalInteractions: 0,
            learningEvents: 0,
            lastUpdateTimestamp: block.timestamp,
            learningVelocity: 0,
            confidenceScore: 0,
            totalTrades: 0,
            successfulTrades: 0,
            totalAnalyses: 0,
            accurateAnalyses: 0,
            profitabilityScore: 50, // Start neutral
            riskManagementScore: 50, // Start neutral
            marketTimingScore: 50, // Start neutral
            strategyAdaptationScore: 50, // Start neutral
            lastTradeTimestamp: 0,
            lastAnalysisTimestamp: 0
        });

        emit LearningUpdated(tokenId, bytes32(0), initialRoot, block.timestamp);
    }

    /**
     * @dev Records trade execution and performance learning
     * @param tokenId The ID of the agent token
     * @param tradeId The ID of the trade
     * @param tokenIn The input token address
     * @param tokenOut The output token address
     * @param amountIn The input amount
     * @param amountOut The output amount
     * @param priceAtExecution The price at execution
     * @param confidenceLevel The confidence level of the trade
     * @param wasLearningBased Whether the trade was based on learning
     * @param marketVolatility The market volatility at trade time
     * @param trendStrength The trend strength at trade time
     * @param strategy The strategy used for the trade
     */
    function recordTradeLearning(
        uint256 tokenId,
        uint256 tradeId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 priceAtExecution,
        uint256 confidenceLevel,
        bool wasLearningBased,
        uint256 marketVolatility,
        uint256 trendStrength,
        string calldata strategy
    ) external onlyAuthorized(tokenId) whenLearningEnabled(tokenId) {
        DeFiLearningMetrics storage metrics = _defiMetrics[tokenId];

        // Update trade count
        metrics.totalTrades++;
        metrics.lastTradeTimestamp = block.timestamp;

        // Store trade learning data (outcome will be updated later)
        uint256 learningId = _tradeLearningCount[tokenId]++;
        _tradeLearningData[tokenId][learningId] = TradeLearningData({
            tradeId: tradeId,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            amountOut: amountOut,
            priceAtExecution: priceAtExecution,
            confidenceLevel: confidenceLevel,
            wasLearningBased: wasLearningBased,
            wasSuccessful: false, // Will be updated later
            profitLoss: 0, // Will be updated later
            timestamp: block.timestamp,
            marketVolatility: marketVolatility,
            trendStrength: trendStrength,
            strategy: strategy
        });

        // Update strategy performance tracking
        _updateStrategyPerformance(tokenId, strategy, false, 0); // Initial record

        emit TradeLearningRecorded(tokenId, tradeId, false, 0, confidenceLevel);

        // Record as general interaction
        _recordGeneralInteraction(tokenId, "trade_execution", true);
    }

    /**
     * @dev Updates trade outcome with success status and P&L
     * @param tokenId The ID of the agent token
     * @param tradeId The ID of the trade
     * @param wasSuccessful Whether the trade was successful
     * @param profitLoss The profit/loss in basis points
     */
    function updateTradeOutcome(
        uint256 tokenId,
        uint256 tradeId,
        bool wasSuccessful,
        uint256 profitLoss
    ) external onlyAuthorized(tokenId) whenLearningEnabled(tokenId) {
        DeFiLearningMetrics storage metrics = _defiMetrics[tokenId];

        // Find and update the trade record
        bool found = false;
        for (uint256 i = 0; i < _tradeLearningCount[tokenId]; i++) {
            if (_tradeLearningData[tokenId][i].tradeId == tradeId) {
                _tradeLearningData[tokenId][i].wasSuccessful = wasSuccessful;
                _tradeLearningData[tokenId][i].profitLoss = profitLoss;

                // Update strategy performance
                _updateStrategyPerformance(
                    tokenId,
                    _tradeLearningData[tokenId][i].strategy,
                    wasSuccessful,
                    profitLoss
                );

                found = true;
                break;
            }
        }

        require(found, "DeFiLearningModule: trade not found");

        // Update success count
        if (wasSuccessful) {
            metrics.successfulTrades++;
        }

        // Update profitability score
        _updateProfitabilityScore(tokenId);

        // Update market timing score
        _updateMarketTimingScore(tokenId);

        // Check for trading milestones
        _checkTradingMilestones(tokenId, metrics);

        emit TradeLearningRecorded(tokenId, tradeId, wasSuccessful, profitLoss, 0);

        // Record as general interaction
        _recordGeneralInteraction(tokenId, "trade_outcome_update", wasSuccessful);
    }

    /**
     * @dev Records market analysis and its accuracy
     * @param tokenId The ID of the agent token
     * @param analysisId The ID of the analysis
     * @param priceVolatility The predicted price volatility
     * @param trendStrength The predicted trend strength
     * @param riskScore The calculated risk score
     * @param opportunityScore The calculated opportunity score
     * @param confidenceScore The confidence in the analysis
     * @param bullishSignal Whether the analysis was bullish
     * @param marketCondition The current market condition (0=bear, 1=sideways, 2=bull)
     */
    function recordMarketAnalysisLearning(
        uint256 tokenId,
        uint256 analysisId,
        uint256 priceVolatility,
        uint256 trendStrength,
        uint256 riskScore,
        uint256 opportunityScore,
        uint256 confidenceScore,
        bool bullishSignal,
        uint256 marketCondition
    ) external onlyAuthorized(tokenId) whenLearningEnabled(tokenId) {
        DeFiLearningMetrics storage metrics = _defiMetrics[tokenId];

        // Update analysis count
        metrics.totalAnalyses++;
        metrics.lastAnalysisTimestamp = block.timestamp;

        // Store analysis learning data (accuracy will be updated later)
        uint256 learningId = _analysisLearningCount[tokenId]++;
        _analysisLearningData[tokenId][learningId] = MarketAnalysisData({
            analysisId: analysisId,
            timestamp: block.timestamp,
            priceVolatility: priceVolatility,
            trendStrength: trendStrength,
            riskScore: riskScore,
            opportunityScore: opportunityScore,
            confidenceScore: confidenceScore,
            bullishSignal: bullishSignal,
            wasAccurate: false, // Will be updated later
            accuracyScore: 0, // Will be updated later
            marketCondition: marketCondition
        });

        emit MarketAnalysisLearningRecorded(tokenId, analysisId, false, 0, confidenceScore);

        // Record as general interaction
        _recordGeneralInteraction(tokenId, "market_analysis", true);
    }

    /**
     * @dev Updates market analysis accuracy based on actual market movement
     * @param tokenId The ID of the agent token
     * @param analysisId The ID of the analysis
     * @param wasAccurate Whether the analysis was accurate
     * @param accuracyScore The accuracy score (0-100)
     */
    function updateAnalysisAccuracy(
        uint256 tokenId,
        uint256 analysisId,
        bool wasAccurate,
        uint256 accuracyScore
    ) external onlyAuthorized(tokenId) whenLearningEnabled(tokenId) {
        DeFiLearningMetrics storage metrics = _defiMetrics[tokenId];

        // Find and update the analysis record
        bool found = false;
        for (uint256 i = 0; i < _analysisLearningCount[tokenId]; i++) {
            if (_analysisLearningData[tokenId][i].analysisId == analysisId) {
                _analysisLearningData[tokenId][i].wasAccurate = wasAccurate;
                _analysisLearningData[tokenId][i].accuracyScore = accuracyScore;

                // Update market condition learning
                _updateMarketConditionLearning(
                    tokenId,
                    _analysisLearningData[tokenId][i].marketCondition,
                    wasAccurate,
                    accuracyScore
                );

                found = true;
                break;
            }
        }

        require(found, "DeFiLearningModule: analysis not found");

        // Update accurate analysis count
        if (wasAccurate) {
            metrics.accurateAnalyses++;
        }

        // Update market timing score based on analysis accuracy
        _updateMarketTimingScore(tokenId);

        // Check for analysis milestones
        _checkAnalysisMilestones(tokenId, metrics);

        emit MarketAnalysisLearningRecorded(tokenId, analysisId, wasAccurate, accuracyScore, 0);

        // Record as general interaction
        _recordGeneralInteraction(tokenId, "analysis_accuracy_update", wasAccurate);
    }

    /**
     * @dev Records risk management performance
     * @param tokenId The ID of the agent token
     * @param portfolioValue The current portfolio value
     * @param maxDrawdown The maximum drawdown experienced
     * @param volatilityExposure The volatility exposure level
     * @param diversificationScore The diversification score
     * @param leverageRatio The leverage ratio used
     * @param stopLossEffectiveness The effectiveness of stop losses
     * @param riskAdjustedReturn The risk-adjusted return
     */
    function recordRiskManagementLearning(
        uint256 tokenId,
        uint256 portfolioValue,
        uint256 maxDrawdown,
        uint256 volatilityExposure,
        uint256 diversificationScore,
        uint256 leverageRatio,
        uint256 stopLossEffectiveness,
        uint256 riskAdjustedReturn
    ) external onlyAuthorized(tokenId) whenLearningEnabled(tokenId) {
        // Store risk management learning data
        uint256 learningId = _riskLearningCount[tokenId]++;
        _riskLearningData[tokenId][learningId] = RiskManagementData({
            timestamp: block.timestamp,
            portfolioValue: portfolioValue,
            maxDrawdown: maxDrawdown,
            volatilityExposure: volatilityExposure,
            diversificationScore: diversificationScore,
            leverageRatio: leverageRatio,
            stopLossEffectiveness: stopLossEffectiveness,
            riskAdjustedReturn: riskAdjustedReturn
        });

        // Update risk management score
        _updateRiskManagementScore(tokenId);

        // Check for risk management milestones
        _checkRiskManagementMilestones(tokenId);

        emit RiskManagementLearningRecorded(
            tokenId,
            portfolioValue,
            maxDrawdown,
            riskAdjustedReturn
        );

        // Record as general interaction
        _recordGeneralInteraction(tokenId, "risk_management", true);
    }

    /**
     * @dev Records an interaction for learning metrics
     * @param tokenId The ID of the agent token
     * @param interactionType The type of interaction
     * @param success Whether the interaction was successful
     */
    function recordInteraction(
        uint256 tokenId,
        string calldata interactionType,
        bool success
    ) external override onlyAuthorized(tokenId) whenLearningEnabled(tokenId) {
        _recordGeneralInteraction(tokenId, interactionType, success);
    }

    /**
     * @dev Gets DeFi-specific learning metrics
     * @param tokenId The ID of the agent token
     * @return The DeFi learning metrics
     */
    function getDeFiLearningMetrics(
        uint256 tokenId
    ) external view returns (DeFiLearningMetrics memory) {
        return _defiMetrics[tokenId];
    }

    /**
     * @dev Gets trade learning insights
     * @param tokenId The ID of the agent token
     * @param limit Maximum number of insights to return
     * @return Array of trade learning data
     */
    function getTradeLearningInsights(
        uint256 tokenId,
        uint256 limit
    ) external view returns (TradeLearningData[] memory) {
        uint256 count = _tradeLearningCount[tokenId];
        uint256 returnCount = count > limit ? limit : count;

        TradeLearningData[] memory insights = new TradeLearningData[](returnCount);

        for (uint256 i = 0; i < returnCount; i++) {
            insights[i] = _tradeLearningData[tokenId][count - 1 - i]; // Most recent first
        }

        return insights;
    }

    /**
     * @dev Gets market analysis learning insights
     * @param tokenId The ID of the agent token
     * @param limit Maximum number of insights to return
     * @return Array of market analysis data
     */
    function getMarketAnalysisInsights(
        uint256 tokenId,
        uint256 limit
    ) external view returns (MarketAnalysisData[] memory) {
        uint256 count = _analysisLearningCount[tokenId];
        uint256 returnCount = count > limit ? limit : count;

        MarketAnalysisData[] memory insights = new MarketAnalysisData[](returnCount);

        for (uint256 i = 0; i < returnCount; i++) {
            insights[i] = _analysisLearningData[tokenId][count - 1 - i]; // Most recent first
        }

        return insights;
    }

    /**
     * @dev Gets strategy performance data
     * @param tokenId The ID of the agent token
     * @param strategyName The name of the strategy
     * @return The strategy performance data
     */
    function getStrategyPerformance(
        uint256 tokenId,
        string calldata strategyName
    ) external view returns (StrategyPerformanceData memory) {
        return _strategyPerformance[tokenId][strategyName];
    }

    /**
     * @dev Gets all strategy names for a token
     * @param tokenId The ID of the agent token
     * @return Array of strategy names
     */
    function getStrategyNames(uint256 tokenId) external view returns (string[] memory) {
        return _strategyNames[tokenId];
    }

    /**
     * @dev Gets market condition learning data
     * @param tokenId The ID of the agent token
     * @param condition The market condition (0=bear, 1=sideways, 2=bull)
     * @return The market condition learning data
     */
    function getMarketConditionLearning(
        uint256 tokenId,
        uint256 condition
    ) external view returns (MarketConditionLearning memory) {
        return _marketConditionLearning[tokenId][condition];
    }

    /**
     * @dev Verifies a learning claim using Merkle proof
     * @param tokenId The ID of the agent token
     * @param claim The claim to verify
     * @param proof The Merkle proof
     * @return Whether the claim is valid
     */
    function verifyLearning(
        uint256 tokenId,
        bytes32 claim,
        bytes32[] calldata proof
    ) external view override returns (bool) {
        bytes32 root = _learningRoots[tokenId];
        return proof.verify(root, claim);
    }

    /**
     * @dev Gets the current learning metrics for an agent (ILearningModule interface)
     * @param tokenId The ID of the agent token
     * @return The learning metrics
     */
    function getLearningMetrics(
        uint256 tokenId
    ) external view override returns (LearningMetrics memory) {
        DeFiLearningMetrics memory defiMetrics = _defiMetrics[tokenId];

        return
            LearningMetrics({
                totalInteractions: defiMetrics.totalInteractions,
                learningEvents: defiMetrics.learningEvents,
                lastUpdateTimestamp: defiMetrics.lastUpdateTimestamp,
                learningVelocity: defiMetrics.learningVelocity,
                confidenceScore: defiMetrics.confidenceScore
            });
    }

    /**
     * @dev Gets the current learning tree root for an agent
     * @param tokenId The ID of the agent token
     * @return The Merkle root of the learning tree
     */
    function getLearningRoot(uint256 tokenId) external view override returns (bytes32) {
        return _learningRoots[tokenId];
    }

    /**
     * @dev Checks if an agent has learning enabled
     * @param tokenId The ID of the agent token
     * @return Whether learning is enabled
     */
    function isLearningEnabled(uint256 tokenId) external view override returns (bool) {
        return _learningEnabled[tokenId];
    }

    /**
     * @dev Gets the learning module version
     * @return The version string
     */
    function getVersion() external pure override returns (string memory) {
        return "1.0.0-defi";
    }

    /**
     * @dev Authorizes an address to update learning for an agent
     * @param tokenId The ID of the agent token
     * @param updater The address to authorize
     * @param authorized Whether to authorize or revoke
     */
    function setAuthorizedUpdater(uint256 tokenId, address updater, bool authorized) external {
        address owner = bep007Token.ownerOf(tokenId);
        require(msg.sender == owner, "DeFiLearningModule: not token owner");

        _authorizedUpdaters[tokenId][updater] = authorized;
    }

    /**
     * @dev Internal function to record general interactions
     */
    function _recordGeneralInteraction(
        uint256 tokenId,
        string memory interactionType,
        bool success
    ) internal {
        DeFiLearningMetrics storage metrics = _defiMetrics[tokenId];
        metrics.totalInteractions++;

        // Update confidence score based on success rate
        if (success) {
            metrics.confidenceScore = _updateConfidence(metrics.confidenceScore, true);
        } else {
            metrics.confidenceScore = _updateConfidence(metrics.confidenceScore, false);
        }

        // Update learning velocity
        uint256 timeDiff = block.timestamp - metrics.lastUpdateTimestamp;
        if (timeDiff > 0) {
            metrics.learningVelocity =
                (metrics.learningEvents * 86400 * 1e18) /
                (block.timestamp - metrics.lastUpdateTimestamp + timeDiff);
        }

        metrics.lastUpdateTimestamp = block.timestamp;
        metrics.learningEvents++;
    }

    /**
     * @dev Internal function to update profitability score
     */
    function _updateProfitabilityScore(uint256 tokenId) internal {
        DeFiLearningMetrics storage metrics = _defiMetrics[tokenId];

        if (metrics.totalTrades == 0) {
            metrics.profitabilityScore = 50;
            return;
        }

        // Calculate win rate
        uint256 winRate = (metrics.successfulTrades * 100) / metrics.totalTrades;

        // Calculate average P&L from recent trades
        uint256 totalPnL = 0;
        uint256 validTrades = 0;
        uint256 startIndex = _tradeLearningCount[tokenId] > 20
            ? _tradeLearningCount[tokenId] - 20
            : 0;

        for (uint256 i = startIndex; i < _tradeLearningCount[tokenId]; i++) {
            if (_tradeLearningData[tokenId][i].profitLoss > 0) {
                totalPnL += _tradeLearningData[tokenId][i].profitLoss;
                validTrades++;
            }
        }

        uint256 avgPnL = validTrades > 0 ? totalPnL / validTrades : 0;

        // Combine win rate and average P&L
        metrics.profitabilityScore = (winRate + (avgPnL / 100)) / 2;
        if (metrics.profitabilityScore > 100) {
            metrics.profitabilityScore = 100;
        }
    }

    /**
     * @dev Internal function to update market timing score
     */
    function _updateMarketTimingScore(uint256 tokenId) internal {
        DeFiLearningMetrics storage metrics = _defiMetrics[tokenId];

        if (metrics.totalAnalyses == 0) {
            metrics.marketTimingScore = 50;
            return;
        }

        // Calculate analysis accuracy rate
        uint256 accuracyRate = (metrics.accurateAnalyses * 100) / metrics.totalAnalyses;

        // Factor in recent trade success in relation to analysis
        uint256 recentTradeSuccess = 50; // Default
        if (metrics.totalTrades > 0) {
            recentTradeSuccess = (metrics.successfulTrades * 100) / metrics.totalTrades;
        }

        // Combine analysis accuracy and trade success
        metrics.marketTimingScore = (accuracyRate + recentTradeSuccess) / 2;
        if (metrics.marketTimingScore > 100) {
            metrics.marketTimingScore = 100;
        }
    }

    /**
     * @dev Internal function to update risk management score
     */
    function _updateRiskManagementScore(uint256 tokenId) internal {
        DeFiLearningMetrics storage metrics = _defiMetrics[tokenId];

        if (_riskLearningCount[tokenId] == 0) {
            metrics.riskManagementScore = 50;
            return;
        }

        // Get recent risk management data
        uint256 recentIndex = _riskLearningCount[tokenId] - 1;
        RiskManagementData memory recentData = _riskLearningData[tokenId][recentIndex];

        // Calculate risk management score based on multiple factors
        uint256 drawdownScore = recentData.maxDrawdown < 1000
            ? 90 // <10% drawdown = excellent
            : recentData.maxDrawdown < 2000
                ? 70 // <20% drawdown = good
                : recentData.maxDrawdown < 3000
                    ? 50 // <30% drawdown = average
                    : 30; // >30% drawdown = poor

        uint256 diversificationScore = recentData.diversificationScore;
        uint256 stopLossScore = recentData.stopLossEffectiveness;

        // Combine scores
        metrics.riskManagementScore = (drawdownScore + diversificationScore + stopLossScore) / 3;
        if (metrics.riskManagementScore > 100) {
            metrics.riskManagementScore = 100;
        }
    }

    /**
     * @dev Internal function to update strategy performance
     */
    function _updateStrategyPerformance(
        uint256 tokenId,
        string memory strategyName,
        bool wasSuccessful,
        uint256 profitLoss
    ) internal {
        StrategyPerformanceData storage strategy = _strategyPerformance[tokenId][strategyName];

        // Initialize strategy if it doesn't exist
        if (bytes(strategy.strategyName).length == 0) {
            strategy.strategyName = strategyName;
            strategy.isActive = true;
            _strategyNames[tokenId].push(strategyName);
        }

        strategy.totalTrades++;
        strategy.lastUsed = block.timestamp;

        if (wasSuccessful) {
            strategy.successfulTrades++;
            strategy.totalPnL += profitLoss;
        }

        // Update win rate
        strategy.winRate = (strategy.successfulTrades * 100) / strategy.totalTrades;

        emit StrategyPerformanceUpdated(tokenId, strategyName, strategy.winRate, strategy.totalPnL);
    }

    /**
     * @dev Internal function to update market condition learning
     */
    function _updateMarketConditionLearning(
        uint256 tokenId,
        uint256 condition,
        bool wasAccurate,
        uint256 accuracyScore
    ) internal {
        MarketConditionLearning storage learning = _marketConditionLearning[tokenId][condition];

        learning.condition = condition;
        learning.sampleSize++;
        learning.lastUpdated = block.timestamp;

        // Update average success rate
        if (learning.avgSuccessRate == 0) {
            learning.avgSuccessRate = wasAccurate ? 100 : 0;
        } else {
            uint256 totalScore = learning.avgSuccessRate * (learning.sampleSize - 1);
            totalScore += wasAccurate ? 100 : 0;
            learning.avgSuccessRate = totalScore / learning.sampleSize;
        }

        emit MarketConditionLearningUpdated(
            tokenId,
            condition,
            learning.bestStrategy,
            learning.avgSuccessRate
        );
    }

    /**
     * @dev Internal function to check trading milestones
     */
    function _checkTradingMilestones(uint256 tokenId, DeFiLearningMetrics memory metrics) internal {
        if (metrics.totalTrades == MILESTONE_TRADES_10) {
            emit DeFiMilestoneAchieved(tokenId, "trader_10", 10, block.timestamp);
        } else if (metrics.totalTrades == MILESTONE_TRADES_100) {
            emit DeFiMilestoneAchieved(tokenId, "trader_100", 100, block.timestamp);
        } else if (metrics.totalTrades == MILESTONE_TRADES_1000) {
            emit DeFiMilestoneAchieved(tokenId, "trader_1000", 1000, block.timestamp);
        }

        if (metrics.profitabilityScore >= MILESTONE_PROFITABLE_TRADER) {
            emit DeFiMilestoneAchieved(
                tokenId,
                "profitable_trader",
                metrics.profitabilityScore,
                block.timestamp
            );
        }
    }

    /**
     * @dev Internal function to check analysis milestones
     */
    function _checkAnalysisMilestones(
        uint256 tokenId,
        DeFiLearningMetrics memory metrics
    ) internal {
        if (metrics.marketTimingScore >= MILESTONE_MARKET_ANALYST) {
            emit DeFiMilestoneAchieved(
                tokenId,
                "market_analyst",
                metrics.marketTimingScore,
                block.timestamp
            );
        }
    }

    /**
     * @dev Internal function to check risk management milestones
     */
    function _checkRiskManagementMilestones(uint256 tokenId) internal {
        DeFiLearningMetrics memory metrics = _defiMetrics[tokenId];

        if (metrics.riskManagementScore >= MILESTONE_RISK_MASTER) {
            emit DeFiMilestoneAchieved(
                tokenId,
                "risk_master",
                metrics.riskManagementScore,
                block.timestamp
            );
        }

        if (metrics.strategyAdaptationScore >= MILESTONE_STRATEGY_EXPERT) {
            emit DeFiMilestoneAchieved(
                tokenId,
                "strategy_expert",
                metrics.strategyAdaptationScore,
                block.timestamp
            );
        }
    }

    /**
     * @dev Internal function to update confidence score
     */
    function _updateConfidence(uint256 currentScore, bool success) internal pure returns (uint256) {
        if (success) {
            uint256 gap = 1e18 - currentScore;
            return currentScore + (gap / 100); // 1% of remaining gap
        } else {
            uint256 decrease = currentScore / 50; // 2% decrease
            return currentScore > decrease ? currentScore - decrease : 0;
        }
    }

    /**
     * @dev Disables learning for an agent (emergency function)
     * @param tokenId The ID of the agent token
     */
    function disableLearning(uint256 tokenId) external {
        address owner = bep007Token.ownerOf(tokenId);
        require(msg.sender == owner, "DeFiLearningModule: not token owner");

        _learningEnabled[tokenId] = false;
    }
}
