// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "../interfaces/ILearningModule.sol";

/**
 * @title DeFiAgent
 * @dev Enhanced template for DeFi agents that can execute trades and manage portfolios with learning capabilities
 */
contract DeFiAgent is Ownable {
    // The address of the BEP007 token that owns this logic
    address public agentToken;

    // The address of the DEX router
    address public dexRouter;

    // The address of the treasury
    address public treasury;

    // Learning module integration
    address public learningModule;
    bool public learningEnabled;
    uint256 public learningVersion;

    // Enhanced trading strategy parameters with learning
    struct TradingStrategy {
        uint256 buyThreshold; // Price threshold to buy (in basis points below moving average)
        uint256 sellThreshold; // Price threshold to sell (in basis points above moving average)
        uint256 maxSlippage; // Maximum allowed slippage (in basis points)
        uint256 tradeSize; // Size of each trade (in percentage of available balance)
        uint256 cooldownPeriod; // Cooldown period between trades (in seconds)
        // Learning enhancements
        uint256 confidenceThreshold; // Minimum confidence to execute trade (scaled by 1e18)
        uint256 learningWeight; // Weight given to learning recommendations (0-100)
        bool adaptiveStrategy; // Whether to adapt strategy based on learning
    }

    // Market analysis structure for learning
    struct MarketAnalysis {
        uint256 timestamp;
        uint256 priceVolatility; // Volatility score (0-100)
        uint256 trendStrength; // Trend strength (0-100)
        uint256 riskScore; // Overall risk assessment (0-100)
        uint256 opportunityScore; // Opportunity assessment (0-100)
        uint256 confidenceScore; // Analysis confidence (scaled by 1e18)
        bool bullishSignal; // Whether analysis suggests bullish trend
    }

    // Trade execution record with learning data
    struct TradeRecord {
        uint256 timestamp;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        uint256 priceAtExecution;
        uint256 confidenceLevel;
        bool wasLearningBased;
        bool wasSuccessful; // Determined post-execution
        uint256 profitLoss; // P&L in basis points
    }

    // Learning metrics for DeFi operations
    struct DeFiLearningMetrics {
        uint256 totalTrades;
        uint256 successfulTrades;
        uint256 totalAnalyses;
        uint256 averageConfidence;
        uint256 profitabilityScore; // Overall profitability (0-100)
        uint256 riskAdjustedReturn; // Risk-adjusted return metric
        uint256 lastLearningUpdate;
        uint256 adaptationCount; // Number of strategy adaptations
    }

    // The trading strategy
    TradingStrategy public strategy;

    // The last trade timestamp
    uint256 public lastTradeTimestamp;

    // The price oracle
    AggregatorV3Interface public priceOracle;

    // Enhanced moving average with learning
    uint256 public movingAverage;
    uint256 public volatilityIndex;
    uint256 public trendIndicator;

    // The tokens that the agent can trade
    mapping(address => bool) public allowedTokens;

    // Trade history with learning data
    mapping(uint256 => TradeRecord) public tradeHistory;
    uint256 public tradeCount;

    // Market analysis history
    mapping(uint256 => MarketAnalysis) public marketAnalyses;
    uint256 public analysisCount;

    // Learning metrics
    DeFiLearningMetrics public learningMetrics;

    // Price history for learning (last 24 data points)
    uint256[24] public priceHistory;
    uint256 public priceHistoryIndex;

    // Event emitted when a trade is executed
    event TradeExecuted(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 confidence,
        bool learningBased
    );

    // Event emitted when the strategy is updated
    event StrategyUpdated(
        uint256 buyThreshold,
        uint256 sellThreshold,
        uint256 maxSlippage,
        uint256 tradeSize,
        uint256 cooldownPeriod
    );

    // Event emitted when learning is enabled/disabled
    event LearningToggled(bool enabled, address learningModule);

    // Event emitted when market analysis is performed
    event MarketAnalyzed(
        uint256 indexed analysisId,
        uint256 volatility,
        uint256 trendStrength,
        uint256 riskScore,
        bool bullishSignal
    );

    // Event emitted when strategy is adapted based on learning
    event StrategyAdapted(
        uint256 oldBuyThreshold,
        uint256 newBuyThreshold,
        uint256 oldSellThreshold,
        uint256 newSellThreshold,
        string reason
    );

    // Event emitted when learning metrics are updated
    event LearningMetricsUpdated(
        uint256 totalTrades,
        uint256 successfulTrades,
        uint256 profitabilityScore
    );

    /**
     * @dev Initializes the contract
     * @param _agentToken The address of the BEP007 token
     * @param _dexRouter The address of the DEX router
     * @param _treasury The address of the treasury
     * @param _priceOracle The address of the price oracle
     */
    constructor(address _agentToken, address _dexRouter, address _treasury, address _priceOracle) {
        require(_agentToken != address(0), "DeFiAgent: agent token is zero address");
        require(_dexRouter != address(0), "DeFiAgent: DEX router is zero address");
        require(_treasury != address(0), "DeFiAgent: treasury is zero address");
        require(_priceOracle != address(0), "DeFiAgent: price oracle is zero address");

        agentToken = _agentToken;
        dexRouter = _dexRouter;
        treasury = _treasury;
        priceOracle = AggregatorV3Interface(_priceOracle);

        // Set enhanced default strategy with learning parameters
        strategy = TradingStrategy({
            buyThreshold: 500, // 5% below moving average
            sellThreshold: 500, // 5% above moving average
            maxSlippage: 100, // 1% max slippage
            tradeSize: 2000, // 20% of available balance
            cooldownPeriod: 3600, // 1 hour cooldown
            confidenceThreshold: 70e16, // 70% confidence minimum
            learningWeight: 50, // 50% weight to learning
            adaptiveStrategy: false // Disabled by default
        });

        // Initialize moving average with current price
        (, int256 price, , , ) = priceOracle.latestRoundData();
        movingAverage = uint256(price);

        // Initialize price history
        for (uint256 i = 0; i < 24; i++) {
            priceHistory[i] = uint256(price);
        }

        // Initialize learning metrics
        learningMetrics = DeFiLearningMetrics({
            totalTrades: 0,
            successfulTrades: 0,
            totalAnalyses: 0,
            averageConfidence: 0,
            profitabilityScore: 50, // Start neutral
            riskAdjustedReturn: 0,
            lastLearningUpdate: block.timestamp,
            adaptationCount: 0
        });
    }

    /**
     * @dev Modifier to check if the caller is the agent token
     */
    modifier onlyAgentToken() {
        require(msg.sender == agentToken, "DeFiAgent: caller is not agent token");
        _;
    }

    /**
     * @dev Enables learning for the DeFi agent
     * @param _learningModule The address of the learning module
     * @param _confidenceThreshold The minimum confidence threshold for trading
     * @param _learningWeight The weight given to learning recommendations (0-100)
     * @param _adaptiveStrategy Whether to enable adaptive strategy
     */
    function enableLearning(
        address _learningModule,
        uint256 _confidenceThreshold,
        uint256 _learningWeight,
        bool _adaptiveStrategy
    ) external onlyOwner {
        require(_learningModule != address(0), "DeFiAgent: learning module is zero address");
        require(_confidenceThreshold <= 1e18, "DeFiAgent: confidence threshold too high");
        require(_learningWeight <= 100, "DeFiAgent: learning weight too high");

        learningModule = _learningModule;
        learningEnabled = true;
        learningVersion++;

        strategy.confidenceThreshold = _confidenceThreshold;
        strategy.learningWeight = _learningWeight;
        strategy.adaptiveStrategy = _adaptiveStrategy;

        emit LearningToggled(true, _learningModule);
    }

    /**
     * @dev Disables learning for the DeFi agent
     */
    function disableLearning() external onlyOwner {
        learningEnabled = false;
        strategy.adaptiveStrategy = false;

        emit LearningToggled(false, address(0));
    }

    /**
     * @dev Performs comprehensive market analysis using learning capabilities
     * @param tokenAddress The address of the token to analyze
     * @return analysis The market analysis result
     */
    function analyzeMarket(
        address tokenAddress
    ) external onlyOwner returns (MarketAnalysis memory analysis) {
        require(
            allowedTokens[tokenAddress] || tokenAddress == address(0),
            "DeFiAgent: token not allowed"
        );

        // Update price history
        _updatePriceHistory();

        // Calculate market metrics
        uint256 volatility = _calculateVolatility();
        uint256 trendStrength = _calculateTrendStrength();
        uint256 riskScore = _calculateRiskScore(volatility, trendStrength);
        uint256 opportunityScore = _calculateOpportunityScore(volatility, trendStrength);
        uint256 confidenceScore = _calculateAnalysisConfidence(volatility, trendStrength);
        bool bullishSignal = _generateMarketSignal(trendStrength, opportunityScore);

        // Store analysis
        analysisCount++;
        analysis = MarketAnalysis({
            timestamp: block.timestamp,
            priceVolatility: volatility,
            trendStrength: trendStrength,
            riskScore: riskScore,
            opportunityScore: opportunityScore,
            confidenceScore: confidenceScore,
            bullishSignal: bullishSignal
        });

        marketAnalyses[analysisCount] = analysis;

        // Update learning metrics
        learningMetrics.totalAnalyses++;
        learningMetrics.lastLearningUpdate = block.timestamp;

        // Record interaction with learning module
        if (learningEnabled && learningModule != address(0)) {
            try
                ILearningModule(learningModule).recordInteraction(
                    uint256(uint160(agentToken)),
                    "market_analysis",
                    true
                )
            {} catch {
                // Silently fail to not break functionality
            }
        }

        emit MarketAnalyzed(analysisCount, volatility, trendStrength, riskScore, bullishSignal);

        return analysis;
    }

    /**
     * @dev Updates the trading strategy with enhanced learning parameters
     * @param _buyThreshold The new buy threshold
     * @param _sellThreshold The new sell threshold
     * @param _maxSlippage The new max slippage
     * @param _tradeSize The new trade size
     * @param _cooldownPeriod The new cooldown period
     * @param _confidenceThreshold The new confidence threshold
     * @param _learningWeight The new learning weight
     */
    function updateStrategy(
        uint256 _buyThreshold,
        uint256 _sellThreshold,
        uint256 _maxSlippage,
        uint256 _tradeSize,
        uint256 _cooldownPeriod,
        uint256 _confidenceThreshold,
        uint256 _learningWeight
    ) external onlyOwner {
        require(_buyThreshold <= 2000, "DeFiAgent: buy threshold too high");
        require(_sellThreshold <= 2000, "DeFiAgent: sell threshold too high");
        require(_maxSlippage <= 500, "DeFiAgent: max slippage too high");
        require(_tradeSize <= 5000, "DeFiAgent: trade size too high");
        require(_confidenceThreshold <= 1e18, "DeFiAgent: confidence threshold too high");
        require(_learningWeight <= 100, "DeFiAgent: learning weight too high");

        strategy.buyThreshold = _buyThreshold;
        strategy.sellThreshold = _sellThreshold;
        strategy.maxSlippage = _maxSlippage;
        strategy.tradeSize = _tradeSize;
        strategy.cooldownPeriod = _cooldownPeriod;
        strategy.confidenceThreshold = _confidenceThreshold;
        strategy.learningWeight = _learningWeight;

        emit StrategyUpdated(
            _buyThreshold,
            _sellThreshold,
            _maxSlippage,
            _tradeSize,
            _cooldownPeriod
        );
    }

    /**
     * @dev Adapts trading strategy based on learning outcomes
     * @param reason The reason for adaptation
     */
    function adaptStrategy(string calldata reason) external onlyOwner {
        require(strategy.adaptiveStrategy, "DeFiAgent: adaptive strategy not enabled");
        require(learningEnabled, "DeFiAgent: learning not enabled");

        uint256 oldBuyThreshold = strategy.buyThreshold;
        uint256 oldSellThreshold = strategy.sellThreshold;

        // Adapt based on recent performance
        if (learningMetrics.profitabilityScore < 40) {
            // Poor performance - be more conservative
            strategy.buyThreshold = (strategy.buyThreshold * 120) / 100; // Increase by 20%
            strategy.sellThreshold = (strategy.sellThreshold * 120) / 100;
            strategy.tradeSize = (strategy.tradeSize * 80) / 100; // Decrease trade size
        } else if (learningMetrics.profitabilityScore > 70) {
            // Good performance - be more aggressive
            strategy.buyThreshold = (strategy.buyThreshold * 90) / 100; // Decrease by 10%
            strategy.sellThreshold = (strategy.sellThreshold * 90) / 100;
            strategy.tradeSize = (strategy.tradeSize * 110) / 100; // Increase trade size
        }

        // Ensure thresholds stay within bounds
        if (strategy.buyThreshold > 2000) strategy.buyThreshold = 2000;
        if (strategy.sellThreshold > 2000) strategy.sellThreshold = 2000;
        if (strategy.tradeSize > 5000) strategy.tradeSize = 5000;
        if (strategy.tradeSize < 500) strategy.tradeSize = 500;

        learningMetrics.adaptationCount++;

        emit StrategyAdapted(
            oldBuyThreshold,
            strategy.buyThreshold,
            oldSellThreshold,
            strategy.sellThreshold,
            reason
        );
    }

    /**
     * @dev Adds a token to the allowed tokens list
     * @param token The address of the token
     */
    function addAllowedToken(address token) external onlyOwner {
        require(token != address(0), "DeFiAgent: token is zero address");
        allowedTokens[token] = true;
    }

    /**
     * @dev Removes a token from the allowed tokens list
     * @param token The address of the token
     */
    function removeAllowedToken(address token) external onlyOwner {
        allowedTokens[token] = false;
    }

    /**
     * @dev Executes a trade with enhanced learning-based validation
     * @param tokenIn The address of the input token
     * @param tokenOut The address of the output token
     * @param amountIn The amount of input tokens
     * @param minAmountOut The minimum amount of output tokens
     * @param path The path of the trade
     */
    function executeTrade(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address[] calldata path
    ) external onlyAgentToken {
        require(allowedTokens[tokenIn], "DeFiAgent: token in not allowed");
        require(allowedTokens[tokenOut], "DeFiAgent: token out not allowed");
        require(
            block.timestamp >= lastTradeTimestamp + strategy.cooldownPeriod,
            "DeFiAgent: cooldown period not elapsed"
        );

        // Update market data
        updateMovingAverage();
        _updatePriceHistory();

        // Perform market analysis if learning is enabled
        uint256 confidence = 0;
        bool wasLearningBased = false;

        if (learningEnabled) {
            MarketAnalysis memory analysis = this.analyzeMarket(tokenIn);
            confidence = analysis.confidenceScore;
            wasLearningBased = true;

            // Check if confidence meets threshold
            require(
                confidence >= strategy.confidenceThreshold,
                "DeFiAgent: confidence below threshold"
            );

            // Additional learning-based validation
            require(
                _validateLearningBasedTrade(tokenIn, tokenOut, analysis),
                "DeFiAgent: learning validation failed"
            );
        } else {
            // Standard validation without learning
            require(
                validateTrade(tokenIn, tokenOut, amountIn, minAmountOut),
                "DeFiAgent: trade does not meet strategy criteria"
            );
            confidence = 5e17; // 50% default confidence
        }

        // Get current price for record keeping
        (, int256 price, , , ) = priceOracle.latestRoundData();
        uint256 currentPrice = uint256(price);

        // Execute the trade
        // Note: In a real implementation, this would call the DEX router
        // For simplicity, we'll just record the trade

        // Record the trade
        tradeCount++;
        tradeHistory[tradeCount] = TradeRecord({
            timestamp: block.timestamp,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            amountOut: minAmountOut,
            priceAtExecution: currentPrice,
            confidenceLevel: confidence,
            wasLearningBased: wasLearningBased,
            wasSuccessful: true, // Will be updated later
            profitLoss: 0 // Will be calculated later
        });

        // Update metrics
        learningMetrics.totalTrades++;
        if (wasLearningBased && learningModule != address(0)) {
            try
                ILearningModule(learningModule).recordInteraction(
                    uint256(uint160(agentToken)),
                    "trade_execution",
                    true
                )
            {} catch {
                // Silently fail
            }
        }

        // Update the last trade timestamp
        lastTradeTimestamp = block.timestamp;

        emit TradeExecuted(tokenIn, tokenOut, amountIn, minAmountOut, confidence, wasLearningBased);
    }

    /**
     * @dev Updates the success status and P&L of a trade
     * @param tradeId The ID of the trade
     * @param wasSuccessful Whether the trade was successful
     * @param profitLoss The profit/loss in basis points
     */
    function updateTradeOutcome(
        uint256 tradeId,
        bool wasSuccessful,
        uint256 profitLoss
    ) external onlyOwner {
        require(tradeId <= tradeCount && tradeId > 0, "DeFiAgent: invalid trade ID");

        TradeRecord storage trade = tradeHistory[tradeId];
        trade.wasSuccessful = wasSuccessful;
        trade.profitLoss = profitLoss;

        // Update learning metrics
        if (wasSuccessful) {
            learningMetrics.successfulTrades++;
        }

        // Recalculate profitability score
        _updateProfitabilityScore();

        emit LearningMetricsUpdated(
            learningMetrics.totalTrades,
            learningMetrics.successfulTrades,
            learningMetrics.profitabilityScore
        );
    }

    /**
     * @dev Gets the learning metrics for the DeFi agent
     * @return The current learning metrics
     */
    function getLearningMetrics() external view returns (DeFiLearningMetrics memory) {
        return learningMetrics;
    }

    /**
     * @dev Gets the recent market analysis
     * @param count The number of analyses to return
     * @return An array of market analyses
     */
    function getMarketAnalysisHistory(
        uint256 count
    ) external view returns (MarketAnalysis[] memory) {
        uint256 resultCount = count > analysisCount ? analysisCount : count;
        MarketAnalysis[] memory analyses = new MarketAnalysis[](resultCount);

        for (uint256 i = 0; i < resultCount; i++) {
            analyses[i] = marketAnalyses[analysisCount - i];
        }

        return analyses;
    }

    /**
     * @dev Gets the trade history with learning data
     * @param count The number of trades to return
     * @return An array of trade records
     */
    function getTradeHistory(uint256 count) external view returns (TradeRecord[] memory) {
        uint256 resultCount = count > tradeCount ? tradeCount : count;
        TradeRecord[] memory trades = new TradeRecord[](resultCount);

        for (uint256 i = 0; i < resultCount; i++) {
            trades[i] = tradeHistory[tradeCount - i];
        }

        return trades;
    }

    /**
     * @dev Validates a trade against the strategy criteria (legacy function)
     * @param tokenIn The address of the input token
     * @param tokenOut The address of the output token
     * @param amountIn The amount of input tokens
     * @param minAmountOut The minimum amount of output tokens
     * @return Whether the trade is valid
     */
    function validateTrade(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) public view returns (bool) {
        // Get the current price
        (, int256 price, , , ) = priceOracle.latestRoundData();
        uint256 currentPrice = uint256(price);

        // Check if the price meets the buy/sell thresholds
        if (tokenIn == address(0)) {
            // Buying - check if price is below buy threshold
            uint256 buyPrice = movingAverage - ((movingAverage * strategy.buyThreshold) / 10_000);
            return currentPrice <= buyPrice;
        } else {
            // Selling - check if price is above sell threshold
            uint256 sellPrice = movingAverage + ((movingAverage * strategy.sellThreshold) / 10_000);
            return currentPrice >= sellPrice;
        }
    }

    /**
     * @dev Validates a trade using learning-based analysis
     * @param tokenIn The address of the input token
     * @param tokenOut The address of the output token
     * @param analysis The market analysis
     * @return Whether the trade is valid based on learning
     */
    function _validateLearningBasedTrade(
        address tokenIn,
        address tokenOut,
        MarketAnalysis memory analysis
    ) internal view returns (bool) {
        // Combine traditional validation with learning insights
        bool traditionalValid = validateTrade(tokenIn, tokenOut, 0, 0);

        // Learning-based validation
        bool learningValid = true;

        // Check risk tolerance
        if (analysis.riskScore > 80) {
            learningValid = false; // Too risky
        }

        // Check opportunity score
        if (analysis.opportunityScore < 30) {
            learningValid = false; // Poor opportunity
        }

        // Check trend alignment
        bool isBuyTrade = (tokenIn == address(0));
        if (isBuyTrade && !analysis.bullishSignal) {
            learningValid = false; // Buying in bearish market
        } else if (!isBuyTrade && analysis.bullishSignal) {
            learningValid = false; // Selling in bullish market
        }

        // Combine validations based on learning weight
        if (strategy.learningWeight >= 50) {
            return learningValid; // Prioritize learning
        } else {
            return traditionalValid && (learningValid || strategy.learningWeight < 25);
        }
    }

    /**
     * @dev Updates the moving average with the current price
     */
    function updateMovingAverage() public {
        // Get the current price
        (, int256 price, , , ) = priceOracle.latestRoundData();
        uint256 currentPrice = uint256(price);

        // Update the moving average (simple EMA with 0.1 weight)
        movingAverage = ((movingAverage * 9) + currentPrice) / 10;

        // Update volatility and trend indicators
        _updateMarketIndicators(currentPrice);
    }

    /**
     * @dev Updates price history for learning analysis
     */
    function _updatePriceHistory() internal {
        (, int256 price, , , ) = priceOracle.latestRoundData();
        uint256 currentPrice = uint256(price);

        priceHistory[priceHistoryIndex] = currentPrice;
        priceHistoryIndex = (priceHistoryIndex + 1) % 24;
    }

    /**
     * @dev Updates market indicators for learning
     * @param currentPrice The current price
     */
    function _updateMarketIndicators(uint256 currentPrice) internal {
        // Update volatility index (simplified calculation)
        uint256 priceChange = currentPrice > movingAverage
            ? currentPrice - movingAverage
            : movingAverage - currentPrice;
        volatilityIndex = (priceChange * 100) / movingAverage;

        // Update trend indicator (simplified momentum)
        if (currentPrice > movingAverage) {
            trendIndicator = trendIndicator < 100 ? trendIndicator + 1 : 100;
        } else {
            trendIndicator = trendIndicator > 0 ? trendIndicator - 1 : 0;
        }
    }

    /**
     * @dev Calculates market volatility from price history
     * @return The volatility score (0-100)
     */
    function _calculateVolatility() internal view returns (uint256) {
        uint256 sum = 0;
        uint256 mean = 0;

        // Calculate mean
        for (uint256 i = 0; i < 24; i++) {
            sum += priceHistory[i];
        }
        mean = sum / 24;

        // Calculate variance
        uint256 variance = 0;
        for (uint256 i = 0; i < 24; i++) {
            uint256 diff = priceHistory[i] > mean ? priceHistory[i] - mean : mean - priceHistory[i];
            variance += (diff * diff);
        }
        variance = variance / 24;

        // Convert to 0-100 scale (simplified)
        return variance > mean ? 100 : (variance * 100) / mean;
    }

    /**
     * @dev Calculates trend strength from price history
     * @return The trend strength (0-100)
     */
    function _calculateTrendStrength() internal view returns (uint256) {
        uint256 upMoves = 0;
        uint256 downMoves = 0;

        for (uint256 i = 1; i < 24; i++) {
            if (priceHistory[i] > priceHistory[i - 1]) {
                upMoves++;
            } else if (priceHistory[i] < priceHistory[i - 1]) {
                downMoves++;
            }
        }

        uint256 totalMoves = upMoves + downMoves;
        if (totalMoves == 0) return 50; // Neutral

        uint256 dominantMoves = upMoves > downMoves ? upMoves : downMoves;
        return (dominantMoves * 100) / totalMoves;
    }

    /**
     * @dev Calculates risk score based on volatility and trend
     * @param volatility The volatility score
     * @param trendStrength The trend strength
     * @return The risk score (0-100)
     */
    function _calculateRiskScore(
        uint256 volatility,
        uint256 trendStrength
    ) internal pure returns (uint256) {
        // High volatility = high risk, weak trend = high risk
        uint256 volatilityRisk = volatility;
        uint256 trendRisk = trendStrength < 50 ? (50 - trendStrength) * 2 : 0;

        return (volatilityRisk + trendRisk) / 2;
    }

    /**
     * @dev Calculates opportunity score
     * @param volatility The volatility score
     * @param trendStrength The trend strength
     * @return The opportunity score (0-100)
     */
    function _calculateOpportunityScore(
        uint256 volatility,
        uint256 trendStrength
    ) internal pure returns (uint256) {
        // Moderate volatility + strong trend = good opportunity
        uint256 volatilityScore = volatility > 20 && volatility < 60 ? 80 : 40;
        uint256 trendScore = trendStrength > 70 ? 90 : trendStrength;

        return (volatilityScore + trendScore) / 2;
    }

    /**
     * @dev Calculates analysis confidence
     * @param volatility The volatility score
     * @param trendStrength The trend strength
     * @return The confidence score (scaled by 1e18)
     */
    function _calculateAnalysisConfidence(
        uint256 volatility,
        uint256 trendStrength
    ) internal pure returns (uint256) {
        // Higher confidence with clear trends and moderate volatility
        uint256 baseConfidence = 50;

        if (trendStrength > 70) baseConfidence += 30;
        else if (trendStrength > 50) baseConfidence += 15;

        if (volatility < 30) baseConfidence += 20;
        else if (volatility > 70) baseConfidence -= 20;

        if (baseConfidence > 100) baseConfidence = 100;

        return (baseConfidence * 1e18) / 100;
    }

    /**
     * @dev Generates market signal based on analysis
     * @param trendStrength The trend strength
     * @param opportunityScore The opportunity score
     * @return Whether the signal is bullish
     */
    function _generateMarketSignal(
        uint256 trendStrength,
        uint256 opportunityScore
    ) internal pure returns (bool) {
        return trendStrength > 60 && opportunityScore > 50;
    }

    /**
     * @dev Updates the profitability score based on trade history
     */
    function _updateProfitabilityScore() internal {
        if (learningMetrics.totalTrades == 0) {
            learningMetrics.profitabilityScore = 50;
            return;
        }

        // Calculate success rate
        uint256 successRate = (learningMetrics.successfulTrades * 100) /
            learningMetrics.totalTrades;

        // Calculate average P&L (simplified)
        uint256 totalPnL = 0;
        uint256 validTrades = 0;

        for (uint256 i = 1; i <= tradeCount && i <= 10; i++) {
            // Last 10 trades
            if (tradeHistory[tradeCount - i + 1].profitLoss > 0) {
                totalPnL += tradeHistory[tradeCount - i + 1].profitLoss;
                validTrades++;
            }
        }

        uint256 avgPnL = validTrades > 0 ? totalPnL / validTrades : 0;

        // Combine success rate and P&L
        learningMetrics.profitabilityScore = (successRate + (avgPnL / 100)) / 2;
        if (learningMetrics.profitabilityScore > 100) {
            learningMetrics.profitabilityScore = 100;
        }
    }

    /**
     * @dev Withdraws tokens from the agent
     * @param token The address of the token
     * @param amount The amount of tokens to withdraw
     * @param recipient The address to send the tokens to
     */
    function withdrawTokens(address token, uint256 amount, address recipient) external onlyOwner {
        require(recipient != address(0), "DeFiAgent: recipient is zero address");

        if (token == address(0)) {
            // Withdraw BNB
            payable(recipient).transfer(amount);
        } else {
            // Withdraw tokens
            require(IERC20(token).transfer(recipient, amount), "DeFiAgent: token transfer failed");
        }
    }

    /**
     * @dev Receive function to accept BNB
     */
    receive() external payable {}
}
