// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../interfaces/ILearningModule.sol";

/**
 * @title DeFiAgent
 * @dev Enhanced template for DeFi-focused agents with learning capabilities
 *      that serve as personalized DeFi assistants and portfolio managers
 */
contract DeFiAgent is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    // The address of the BAP578 token that owns this logic
    address public agentToken;

    // Learning module integration
    address public learningModule;
    bool public learningEnabled;

    // DeFi-specific profile
    struct DeFiProfile {
        string name; // Agent name
        string tradingStyle; // Conservative, Aggressive, Balanced
        string[] supportedProtocols; // Supported DeFi protocols
        uint256 riskTolerance; // 0-100 scale (0 = very conservative, 100 = very aggressive)
        uint256 experienceLevel; // 0-100 scale (0 = beginner, 100 = expert)
        uint256 maxSlippage; // Maximum allowed slippage in basis points (e.g., 100 = 1%)
        bool autoRebalanceEnabled; // Whether auto-rebalancing is enabled
    }

    // Trading performance tracking
    struct TradingMetrics {
        uint256 totalTrades; // Total number of trades executed
        uint256 successfulTrades; // Number of profitable trades
        uint256 totalVolume; // Total trading volume in USD (scaled by 1e18)
        uint256 totalPnL; // Total profit/loss in USD (scaled by 1e18)
        uint256 bestTradeReturn; // Best single trade return percentage (scaled by 1e18)
        uint256 worstTradeReturn; // Worst single trade return percentage (scaled by 1e18)
        uint256 averageHoldTime; // Average position hold time in seconds
        uint256 lastTradeTimestamp; // Timestamp of last trade
    }

    // Portfolio position tracking
    struct Position {
        address token; // Token contract address
        uint256 amount; // Amount held
        uint256 entryPrice; // Entry price (scaled by 1e18)
        uint256 entryTimestamp; // When position was opened
        string protocol; // Protocol where position is held
        bool isActive; // Whether position is currently active
    }

    // Risk management parameters
    struct RiskParameters {
        uint256 maxPositionSize; // Maximum position size as percentage of portfolio (scaled by 1e18)
        uint256 stopLossPercentage; // Stop loss percentage (scaled by 1e18)
        uint256 takeProfitPercentage; // Take profit percentage (scaled by 1e18)
        uint256 maxDailyLoss; // Maximum daily loss limit (scaled by 1e18)
        uint256 portfolioValueAtRisk; // Value at Risk calculation (scaled by 1e18)
        bool emergencyStopEnabled; // Emergency stop mechanism
    }

    // Agent's DeFi profile
    DeFiProfile public profile;

    // Trading performance metrics
    TradingMetrics public tradingMetrics;

    // Risk management parameters
    RiskParameters public riskParameters;

    // Portfolio positions mapping
    mapping(uint256 => Position) public positions;
    uint256 public positionCounter;

    // Supported tokens for trading
    mapping(address => bool) public supportedTokens;
    address[] public supportedTokenList;

    // Protocol integration addresses
    mapping(string => address) public protocolAddresses;

    // Daily loss tracking for risk management
    mapping(uint256 => uint256) public dailyLoss; // day => loss amount

    // Events
    event TradeExecuted(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        string protocol,
        uint256 timestamp
    );

    event PositionOpened(
        uint256 indexed positionId,
        address indexed token,
        uint256 amount,
        uint256 entryPrice,
        string protocol
    );

    event PositionClosed(
        uint256 indexed positionId,
        address indexed token,
        uint256 amount,
        uint256 exitPrice,
        int256 pnl
    );

    event RiskParametersUpdated(
        uint256 maxPositionSize,
        uint256 stopLossPercentage,
        uint256 takeProfitPercentage
    );

    event EmergencyStop(string reason, uint256 timestamp);

    event LearningUpdate(string updateType, bytes32 dataHash, uint256 timestamp);

    /**
     * @dev Initializes the DeFi agent contract
     * @param _agentToken The address of the BAP578 token
     * @param _name The agent's name
     * @param _tradingStyle The trading style (Conservative, Aggressive, Balanced)
     * @param _riskTolerance Risk tolerance level (0-100)
     */
    constructor(
        address _agentToken,
        string memory _name,
        string memory _tradingStyle,
        uint256 _riskTolerance
    ) {
        require(_agentToken != address(0), "DeFiAgent: agent token is zero address");
        require(_riskTolerance <= 100, "DeFiAgent: risk tolerance must be 0-100");

        agentToken = _agentToken;

        // Initialize DeFi profile with default values
        profile = DeFiProfile({
            name: _name,
            tradingStyle: _tradingStyle,
            supportedProtocols: new string[](0),
            riskTolerance: _riskTolerance,
            experienceLevel: 50, // Default medium experience
            maxSlippage: 100, // 1% default slippage
            autoRebalanceEnabled: false
        });

        // Initialize risk parameters based on risk tolerance
        _initializeRiskParameters(_riskTolerance);

        // Initialize trading metrics
        tradingMetrics = TradingMetrics({
            totalTrades: 0,
            successfulTrades: 0,
            totalVolume: 0,
            totalPnL: 0,
            bestTradeReturn: 0,
            worstTradeReturn: 0,
            averageHoldTime: 0,
            lastTradeTimestamp: 0
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
     * @dev Modifier to check if learning is enabled
     */
    modifier whenLearningEnabled() {
        require(learningEnabled && learningModule != address(0), "DeFiAgent: learning not enabled");
        _;
    }

    /**
     * @dev Modifier to check if emergency stop is not active
     */
    modifier whenNotEmergencyStopped() {
        require(!riskParameters.emergencyStopEnabled, "DeFiAgent: emergency stop active");
        _;
    }

    /**
     * @dev Enables learning for this agent
     * @param _learningModule The address of the learning module
     */
    function enableLearning(address _learningModule) external onlyOwner {
        require(_learningModule != address(0), "DeFiAgent: learning module is zero address");
        require(!learningEnabled, "DeFiAgent: learning already enabled");

        learningModule = _learningModule;
        learningEnabled = true;
    }

    /**
     * @dev Updates the DeFi agent's profile
     * @param _name The agent's name
     * @param _tradingStyle The trading style
     * @param _riskTolerance Risk tolerance level (0-100)
     * @param _experienceLevel Experience level (0-100)
     * @param _maxSlippage Maximum slippage in basis points
     * @param _autoRebalanceEnabled Whether auto-rebalancing is enabled
     */
    function updateProfile(
        string memory _name,
        string memory _tradingStyle,
        uint256 _riskTolerance,
        uint256 _experienceLevel,
        uint256 _maxSlippage,
        bool _autoRebalanceEnabled
    ) external onlyOwner {
        require(_riskTolerance <= 100, "DeFiAgent: risk tolerance must be 0-100");
        require(_experienceLevel <= 100, "DeFiAgent: experience level must be 0-100");
        require(_maxSlippage <= 1000, "DeFiAgent: max slippage must be <= 10%");

        profile.name = _name;
        profile.tradingStyle = _tradingStyle;
        profile.riskTolerance = _riskTolerance;
        profile.experienceLevel = _experienceLevel;
        profile.maxSlippage = _maxSlippage;
        profile.autoRebalanceEnabled = _autoRebalanceEnabled;

        // Update risk parameters based on new risk tolerance
        _updateRiskParameters(_riskTolerance);
    }

    /**
     * @dev Adds a supported protocol to the agent
     * @param _protocol The protocol name
     * @param _address The protocol contract address
     */
    function addSupportedProtocol(string memory _protocol, address _address) external onlyOwner {
        require(_address != address(0), "DeFiAgent: protocol address is zero");

        protocolAddresses[_protocol] = _address;
        profile.supportedProtocols.push(_protocol);
    }

    /**
     * @dev Adds a supported token for trading
     * @param _token The token contract address
     */
    function addSupportedToken(address _token) external onlyOwner {
        require(_token != address(0), "DeFiAgent: token address is zero");
        require(!supportedTokens[_token], "DeFiAgent: token already supported");

        supportedTokens[_token] = true;
        supportedTokenList.push(_token);
    }

    /**
     * @dev Removes a supported token
     * @param _token The token contract address
     */
    function removeSupportedToken(address _token) external onlyOwner {
        require(supportedTokens[_token], "DeFiAgent: token not supported");

        supportedTokens[_token] = false;

        // Remove from array
        for (uint256 i = 0; i < supportedTokenList.length; i++) {
            if (supportedTokenList[i] == _token) {
                supportedTokenList[i] = supportedTokenList[supportedTokenList.length - 1];
                supportedTokenList.pop();
                break;
            }
        }
    }

    /**
     * @dev Executes a token swap
     * @param _tokenIn Input token address
     * @param _tokenOut Output token address
     * @param _amountIn Amount of input tokens
     * @param _minAmountOut Minimum amount of output tokens expected
     * @param _protocol Protocol to use for the swap
     * @return amountOut Amount of output tokens received
     */
    function executeSwap(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _minAmountOut,
        string memory _protocol
    ) external onlyOwner nonReentrant whenNotEmergencyStopped returns (uint256 amountOut) {
        require(supportedTokens[_tokenIn], "DeFiAgent: input token not supported");
        require(supportedTokens[_tokenOut], "DeFiAgent: output token not supported");
        require(_amountIn > 0, "DeFiAgent: amount must be greater than 0");
        require(protocolAddresses[_protocol] != address(0), "DeFiAgent: protocol not supported");

        // Check daily loss limits
        _checkDailyLossLimits();

        // Record trade start time for learning
        uint256 tradeStartTime = block.timestamp;

        // Execute the swap (simplified - in real implementation, this would integrate with actual DEX)
        amountOut = _performSwap(_tokenIn, _tokenOut, _amountIn, _minAmountOut, _protocol);

        // Track losses if trade resulted in a loss
        uint256 inputPrice = _getTokenPrice(_tokenIn);
        uint256 outputPrice = _getTokenPrice(_tokenOut);
        uint256 inputValue = _amountIn.mul(inputPrice).div(1e18);
        uint256 outputValue = amountOut.mul(outputPrice).div(1e18);

        if (outputValue < inputValue) {
            uint256 lossAmount = inputValue.sub(outputValue);
            _updateDailyLoss(lossAmount);
        }

        // Update trading metrics
        _updateTradingMetrics(_tokenIn, _tokenOut, _amountIn, amountOut, tradeStartTime);

        // Record learning data if enabled
        if (learningEnabled) {
            _recordTradeForLearning(_tokenIn, _tokenOut, _amountIn, amountOut, _protocol, true);
        }

        emit TradeExecuted(_tokenIn, _tokenOut, _amountIn, amountOut, _protocol, block.timestamp);

        return amountOut;
    }

    /**
     * @dev Opens a new position
     * @param _token Token to open position in
     * @param _amount Amount to invest
     * @param _protocol Protocol to use
     * @return positionId The ID of the new position
     */
    function openPosition(
        address _token,
        uint256 _amount,
        string memory _protocol
    ) external onlyOwner nonReentrant whenNotEmergencyStopped returns (uint256 positionId) {
        require(supportedTokens[_token], "DeFiAgent: token not supported");
        require(_amount > 0, "DeFiAgent: amount must be greater than 0");
        require(protocolAddresses[_protocol] != address(0), "DeFiAgent: protocol not supported");

        // Check position size limits
        _checkPositionSizeLimits(_amount);

        positionCounter++;
        positionId = positionCounter;

        // Get current token price (simplified - would use oracle in real implementation)
        uint256 entryPrice = _getTokenPrice(_token);

        positions[positionId] = Position({
            token: _token,
            amount: _amount,
            entryPrice: entryPrice,
            entryTimestamp: block.timestamp,
            protocol: _protocol,
            isActive: true
        });

        emit PositionOpened(positionId, _token, _amount, entryPrice, _protocol);

        return positionId;
    }

    /**
     * @dev Closes an existing position
     * @param _positionId The ID of the position to close
     * @return pnl The profit/loss from closing the position
     */
    function closePosition(
        uint256 _positionId
    ) external onlyOwner nonReentrant returns (int256 pnl) {
        require(positions[_positionId].isActive, "DeFiAgent: position not active");

        Position storage position = positions[_positionId];

        // Get current token price
        uint256 exitPrice = _getTokenPrice(position.token);

        // Calculate P&L
        pnl = _calculatePnL(position.entryPrice, exitPrice, position.amount);

        // Update position
        position.isActive = false;

        // Track losses if position resulted in a loss
        if (pnl < 0) {
            uint256 lossAmount = uint256(-pnl);
            _updateDailyLoss(lossAmount);
        }

        // Update trading metrics
        tradingMetrics.totalTrades++;
        if (pnl > 0) {
            tradingMetrics.successfulTrades++;
        }

        // Update total P&L
        if (pnl >= 0) {
            tradingMetrics.totalPnL = tradingMetrics.totalPnL.add(uint256(pnl));
        } else {
            tradingMetrics.totalPnL = tradingMetrics.totalPnL.sub(uint256(-pnl));
        }

        // Record learning data if enabled
        if (learningEnabled) {
            _recordPositionForLearning(_positionId, pnl);
        }

        emit PositionClosed(_positionId, position.token, position.amount, exitPrice, pnl);

        return pnl;
    }

    /**
     * @dev Updates risk parameters
     * @param _maxPositionSize Maximum position size percentage
     * @param _stopLossPercentage Stop loss percentage
     * @param _takeProfitPercentage Take profit percentage
     * @param _maxDailyLoss Maximum daily loss limit
     */
    function updateRiskParameters(
        uint256 _maxPositionSize,
        uint256 _stopLossPercentage,
        uint256 _takeProfitPercentage,
        uint256 _maxDailyLoss
    ) external onlyOwner {
        require(_maxPositionSize <= 100e18, "DeFiAgent: max position size too high");
        require(_stopLossPercentage <= 50e18, "DeFiAgent: stop loss too high");
        require(_takeProfitPercentage >= 5e18, "DeFiAgent: take profit too low");

        riskParameters.maxPositionSize = _maxPositionSize;
        riskParameters.stopLossPercentage = _stopLossPercentage;
        riskParameters.takeProfitPercentage = _takeProfitPercentage;
        riskParameters.maxDailyLoss = _maxDailyLoss;

        emit RiskParametersUpdated(_maxPositionSize, _stopLossPercentage, _takeProfitPercentage);
    }

    /**
     * @dev Triggers emergency stop
     * @param _reason Reason for emergency stop
     */
    function emergencyStop(string memory _reason) external onlyOwner {
        riskParameters.emergencyStopEnabled = true;
        emit EmergencyStop(_reason, block.timestamp);
    }

    /**
     * @dev Disables emergency stop
     */
    function disableEmergencyStop() external onlyOwner {
        riskParameters.emergencyStopEnabled = false;
    }

    /**
     * @dev Gets the current portfolio value
     * @return totalValue Total portfolio value in USD (scaled by 1e18)
     */
    function getPortfolioValue() external view returns (uint256 totalValue) {
        totalValue = 0;

        for (uint256 i = 1; i <= positionCounter; i++) {
            if (positions[i].isActive) {
                uint256 currentPrice = _getTokenPrice(positions[i].token);
                uint256 positionValue = positions[i].amount.mul(currentPrice).div(1e18);
                totalValue = totalValue.add(positionValue);
            }
        }

        return totalValue;
    }

    /**
     * @dev Gets trading performance metrics
     * @return metrics Current trading metrics
     */
    function getTradingMetrics() external view returns (TradingMetrics memory metrics) {
        return tradingMetrics;
    }

    /**
     * @dev Gets risk parameters
     * @return parameters Current risk parameters
     */
    function getRiskParameters() external view returns (RiskParameters memory parameters) {
        return riskParameters;
    }

    /**
     * @dev Gets supported tokens list
     * @return tokens Array of supported token addresses
     */
    function getSupportedTokens() external view returns (address[] memory tokens) {
        return supportedTokenList;
    }

    /**
     * @dev Gets supported protocols list
     * @return protocols Array of supported protocol names
     */
    function getSupportedProtocols() external view returns (string[] memory protocols) {
        return profile.supportedProtocols;
    }

    /**
     * @dev Gets daily loss for a specific day
     * @param _day Day timestamp (in days since epoch)
     * @return loss Daily loss amount for the specified day
     */
    function getDailyLoss(uint256 _day) external view returns (uint256 loss) {
        return dailyLoss[_day];
    }

    /**
     * @dev Gets current day's loss
     * @return loss Current day's loss amount
     */
    function getCurrentDayLoss() external view returns (uint256 loss) {
        uint256 today = block.timestamp / 86400;
        return dailyLoss[today];
    }

    // Internal functions

    /**
     * @dev Initializes risk parameters based on risk tolerance
     * @param _riskTolerance Risk tolerance level (0-100)
     */
    function _initializeRiskParameters(uint256 _riskTolerance) internal {
        // Conservative: low risk tolerance (0-33)
        // Balanced: medium risk tolerance (34-66)
        // Aggressive: high risk tolerance (67-100)

        if (_riskTolerance <= 33) {
            // Conservative settings
            riskParameters = RiskParameters({
                maxPositionSize: 10e18, // 10% max position size
                stopLossPercentage: 5e18, // 5% stop loss
                takeProfitPercentage: 10e18, // 10% take profit
                maxDailyLoss: 2e18, // 2% max daily loss
                portfolioValueAtRisk: 5e18, // 5% VaR
                emergencyStopEnabled: false
            });
        } else if (_riskTolerance <= 66) {
            // Balanced settings
            riskParameters = RiskParameters({
                maxPositionSize: 20e18, // 20% max position size
                stopLossPercentage: 10e18, // 10% stop loss
                takeProfitPercentage: 20e18, // 20% take profit
                maxDailyLoss: 5e18, // 5% max daily loss
                portfolioValueAtRisk: 10e18, // 10% VaR
                emergencyStopEnabled: false
            });
        } else {
            // Aggressive settings
            riskParameters = RiskParameters({
                maxPositionSize: 30e18, // 30% max position size
                stopLossPercentage: 15e18, // 15% stop loss
                takeProfitPercentage: 30e18, // 30% take profit
                maxDailyLoss: 10e18, // 10% max daily loss
                portfolioValueAtRisk: 20e18, // 20% VaR
                emergencyStopEnabled: false
            });
        }
    }

    /**
     * @dev Updates risk parameters based on risk tolerance
     * @param _riskTolerance New risk tolerance level
     */
    function _updateRiskParameters(uint256 _riskTolerance) internal {
        _initializeRiskParameters(_riskTolerance);
    }

    /**
     * @dev Performs the actual token swap (simplified implementation)
     * @param _tokenIn Input token address
     * @param _tokenOut Output token address
     * @param _amountIn Amount of input tokens
     * @param _minAmountOut Minimum amount of output tokens expected
     * @param _protocol Protocol to use
     * @return amountOut Amount of output tokens received
     */
    function _performSwap(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _minAmountOut,
        string memory _protocol
    ) internal returns (uint256 amountOut) {
        // This is a simplified implementation
        // In a real implementation, this would integrate with actual DEX contracts

        // For now, simulate a swap with some slippage
        uint256 inputPrice = _getTokenPrice(_tokenIn);
        uint256 outputPrice = _getTokenPrice(_tokenOut);

        // Calculate expected output amount (avoid divide-before-multiply)
        uint256 expectedOutput = _amountIn.mul(inputPrice).div(outputPrice);

        // Apply slippage (simulate market impact)
        uint256 slippage = profile.maxSlippage; // basis points
        amountOut = expectedOutput.mul(10000 - slippage).div(10000);

        require(amountOut >= _minAmountOut, "DeFiAgent: insufficient output amount");

        return amountOut;
    }

    /**
     * @dev Gets the current price of a token (simplified implementation)
     * @param _token Token address
     * @return price Token price in USD (scaled by 1e18)
     */
    function _getTokenPrice(address _token) internal view returns (uint256 price) {
        // This is a simplified implementation
        // In a real implementation, this would use price oracles like Chainlink

        // For now, return a mock price
        return 1e18; // $1 USD
    }

    /**
     * @dev Calculates profit/loss for a position
     * @param _entryPrice Entry price
     * @param _exitPrice Exit price
     * @param _amount Position amount
     * @return pnl Profit/loss amount
     */
    function _calculatePnL(
        uint256 _entryPrice,
        uint256 _exitPrice,
        uint256 _amount
    ) internal pure returns (int256 pnl) {
        if (_exitPrice >= _entryPrice) {
            // Profit
            uint256 profit = _amount.mul(_exitPrice.sub(_entryPrice)).div(_entryPrice);
            return int256(profit);
        } else {
            // Loss
            uint256 loss = _amount.mul(_entryPrice.sub(_exitPrice)).div(_entryPrice);
            return -int256(loss);
        }
    }

    /**
     * @dev Updates trading metrics after a trade
     * @param _tokenIn Input token
     * @param _tokenOut Output token
     * @param _amountIn Input amount
     * @param _amountOut Output amount
     * @param _tradeStartTime Trade start timestamp
     */
    function _updateTradingMetrics(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _amountOut,
        uint256 _tradeStartTime
    ) internal {
        tradingMetrics.totalTrades++;
        tradingMetrics.lastTradeTimestamp = block.timestamp;

        // Calculate trade volume in USD
        uint256 inputPrice = _getTokenPrice(_tokenIn);
        uint256 tradeVolume = _amountIn.mul(inputPrice).div(1e18);
        tradingMetrics.totalVolume = tradingMetrics.totalVolume.add(tradeVolume);

        // Calculate trade return
        uint256 outputPrice = _getTokenPrice(_tokenOut);
        uint256 outputValue = _amountOut.mul(outputPrice).div(1e18);
        uint256 inputValue = _amountIn.mul(inputPrice).div(1e18);

        if (outputValue > inputValue) {
            tradingMetrics.successfulTrades++;
            uint256 returnPercentage = outputValue.sub(inputValue).mul(1e18).div(inputValue);

            if (returnPercentage > tradingMetrics.bestTradeReturn) {
                tradingMetrics.bestTradeReturn = returnPercentage;
            }
        } else if (outputValue < inputValue) {
            uint256 lossPercentage = inputValue.sub(outputValue).mul(1e18).div(inputValue);

            if (lossPercentage > tradingMetrics.worstTradeReturn) {
                tradingMetrics.worstTradeReturn = lossPercentage;
            }
        }
    }

    /**
     * @dev Records trade data for learning
     * @param _tokenIn Input token
     * @param _tokenOut Output token
     * @param _amountIn Input amount
     * @param _amountOut Output amount
     * @param _protocol Protocol used
     * @param _success Whether trade was successful
     */
    function _recordTradeForLearning(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _amountOut,
        string memory _protocol,
        bool _success
    ) internal whenLearningEnabled {
        // Create learning data hash
        bytes32 dataHash = keccak256(
            abi.encodePacked(
                _tokenIn,
                _tokenOut,
                _amountIn,
                _amountOut,
                _protocol,
                _success,
                block.timestamp
            )
        );

        emit LearningUpdate("trade_execution", dataHash, block.timestamp);

        // In a real implementation, this would call the learning module
        // to record the interaction and update the learning tree
    }

    /**
     * @dev Records position data for learning
     * @param _positionId Position ID
     * @param _pnl Profit/loss from position
     */
    function _recordPositionForLearning(
        uint256 _positionId,
        int256 _pnl
    ) internal whenLearningEnabled {
        Position memory position = positions[_positionId];

        bytes32 dataHash = keccak256(
            abi.encodePacked(
                _positionId,
                position.token,
                position.amount,
                position.entryPrice,
                _pnl,
                block.timestamp
            )
        );

        emit LearningUpdate("position_closed", dataHash, block.timestamp);
    }

    /**
     * @dev Checks daily loss limits
     */
    function _checkDailyLossLimits() internal view {
        uint256 today = block.timestamp / 86400; // Get current day
        uint256 todayLoss = dailyLoss[today];

        require(todayLoss < riskParameters.maxDailyLoss, "DeFiAgent: daily loss limit exceeded");
    }

    /**
     * @dev Updates daily loss tracking
     * @param _lossAmount Amount of loss to add to daily tracking
     */
    function _updateDailyLoss(uint256 _lossAmount) internal {
        uint256 today = block.timestamp / 86400; // Get current day
        dailyLoss[today] = dailyLoss[today].add(_lossAmount);

        // Ensure we don't exceed daily loss limits after update
        require(
            dailyLoss[today] <= riskParameters.maxDailyLoss,
            "DeFiAgent: daily loss limit exceeded"
        );
    }

    /**
     * @dev Checks position size limits
     * @param _amount Position amount
     */
    function _checkPositionSizeLimits(uint256 _amount) internal view {
        uint256 portfolioValue = this.getPortfolioValue();
        if (portfolioValue > 0) {
            uint256 positionPercentage = _amount.mul(1e18).div(portfolioValue);
            require(
                positionPercentage <= riskParameters.maxPositionSize,
                "DeFiAgent: position size exceeds limit"
            );
        }
    }

    /**
     * @dev Emergency withdrawal function
     * @param _token Token to withdraw
     * @param _amount Amount to withdraw
     */
    function emergencyWithdraw(address _token, uint256 _amount) external onlyOwner {
        require(riskParameters.emergencyStopEnabled, "DeFiAgent: emergency stop not active");

        if (_token == address(0)) {
            // Withdraw BNB
            payable(owner()).transfer(_amount);
        } else {
            // Withdraw ERC20 token
            IERC20(_token).safeTransfer(owner(), _amount);
        }
    }

    /**
     * @dev Allows contract to receive BNB
     */
    receive() external payable {}
}
