# DeFi Agent Template Documentation

## Overview

The DeFi Agent is a specialized template for creating DeFi-focused agents with learning capabilities that serve as personalized DeFi assistants and portfolio managers. It extends the BAP-578 Non-Fungible Agent standard with DeFi-specific functionality including trading, portfolio management, risk assessment, and adaptive learning.

## Architecture

### Core Components

1. **DeFi Profile Management**: Customizable trading preferences and risk parameters
2. **Trading Engine**: Token swaps and position management across multiple protocols
3. **Risk Management**: Comprehensive risk controls and emergency mechanisms
4. **Portfolio Tracking**: Real-time portfolio valuation and performance metrics
5. **Learning Integration**: Adaptive behavior based on trading performance and user preferences

### Key Features

- **Multi-Protocol Support**: Integrate with various DeFi protocols (DEXs, lending, yield farming)
- **Risk-Based Configuration**: Automatic parameter adjustment based on risk tolerance
- **Performance Tracking**: Comprehensive trading metrics and analytics
- **Emergency Controls**: Circuit breakers and emergency withdrawal mechanisms
- **Learning Capabilities**: Adaptive strategies based on historical performance

## Contract Structure

### DeFi Profile

```solidity
struct DeFiProfile {
    string name;                    // Agent name
    string tradingStyle;           // Conservative, Aggressive, Balanced
    string[] supportedProtocols;   // Supported DeFi protocols
    uint256 riskTolerance;         // 0-100 scale (0 = very conservative, 100 = very aggressive)
    uint256 experienceLevel;      // 0-100 scale (0 = beginner, 100 = expert)
    uint256 maxSlippage;           // Maximum allowed slippage in basis points
    bool autoRebalanceEnabled;    // Whether auto-rebalancing is enabled
}
```

### Trading Metrics

```solidity
struct TradingMetrics {
    uint256 totalTrades;           // Total number of trades executed
    uint256 successfulTrades;      // Number of profitable trades
    uint256 totalVolume;           // Total trading volume in USD (scaled by 1e18)
    uint256 totalPnL;              // Total profit/loss in USD (scaled by 1e18)
    uint256 bestTradeReturn;       // Best single trade return percentage
    uint256 worstTradeReturn;      // Worst single trade return percentage
    uint256 averageHoldTime;       // Average position hold time in seconds
    uint256 lastTradeTimestamp;    // Timestamp of last trade
}
```

### Risk Parameters

```solidity
struct RiskParameters {
    uint256 maxPositionSize;       // Maximum position size as percentage of portfolio
    uint256 stopLossPercentage;    // Stop loss percentage
    uint256 takeProfitPercentage;  // Take profit percentage
    uint256 maxDailyLoss;          // Maximum daily loss limit
    uint256 portfolioValueAtRisk;  // Value at Risk calculation
    bool emergencyStopEnabled;     // Emergency stop mechanism
}
```

## Risk Tolerance Configurations

### Conservative (0-33)
- Max Position Size: 10%
- Stop Loss: 5%
- Take Profit: 10%
- Max Daily Loss: 2%
- Portfolio VaR: 5%

### Balanced (34-66)
- Max Position Size: 20%
- Stop Loss: 10%
- Take Profit: 20%
- Max Daily Loss: 5%
- Portfolio VaR: 10%

### Aggressive (67-100)
- Max Position Size: 30%
- Stop Loss: 15%
- Take Profit: 30%
- Max Daily Loss: 10%
- Portfolio VaR: 20%

## Core Functions

### Profile Management

```solidity
function updateProfile(
    string memory _name,
    string memory _tradingStyle,
    uint256 _riskTolerance,
    uint256 _experienceLevel,
    uint256 _maxSlippage,
    bool _autoRebalanceEnabled
) external onlyOwner
```

### Protocol and Token Management

```solidity
function addSupportedProtocol(string memory _protocol, address _address) external onlyOwner
function addSupportedToken(address _token) external onlyOwner
function removeSupportedToken(address _token) external onlyOwner
```

### Trading Operations

```solidity
function executeSwap(
    address _tokenIn,
    address _tokenOut,
    uint256 _amountIn,
    uint256 _minAmountOut,
    string memory _protocol
) external onlyOwner nonReentrant whenNotEmergencyStopped returns (uint256 amountOut)

function openPosition(
    address _token,
    uint256 _amount,
    string memory _protocol
) external onlyOwner nonReentrant whenNotEmergencyStopped returns (uint256 positionId)

function closePosition(uint256 _positionId) external onlyOwner nonReentrant returns (int256 pnl)
```

### Risk Management

```solidity
function updateRiskParameters(
    uint256 _maxPositionSize,
    uint256 _stopLossPercentage,
    uint256 _takeProfitPercentage,
    uint256 _maxDailyLoss
) external onlyOwner

function emergencyStop(string memory _reason) external onlyOwner
function disableEmergencyStop() external onlyOwner
```

### Learning Integration

```solidity
function enableLearning(address _learningModule) external onlyOwner
```

## Events

```solidity
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

event LearningUpdate(
    string updateType,
    bytes32 dataHash,
    uint256 timestamp
);
```

## Usage Examples

### Basic Setup

```javascript
// Deploy DeFi Agent
const defiAgent = await DeFiAgent.deploy(
    agentTokenAddress,
    "My DeFi Agent",
    "Balanced",
    50 // Medium risk tolerance
);

// Add supported tokens
await defiAgent.addSupportedToken(tokenA.address);
await defiAgent.addSupportedToken(tokenB.address);

// Add supported protocols
await defiAgent.addSupportedProtocol("PancakeSwap", pancakeSwapRouter.address);
await defiAgent.addSupportedProtocol("Venus", venusComptroller.address);
```

### Enable Learning

```javascript
// Enable learning capabilities
await defiAgent.enableLearning(merkleTreeLearning.address);
```

### Execute Trading Operations

```javascript
// Execute a token swap
await defiAgent.executeSwap(
    tokenA.address,
    tokenB.address,
    ethers.utils.parseEther("100"),
    ethers.utils.parseEther("95"), // 5% slippage tolerance
    "PancakeSwap"
);

// Open a position
const positionId = await defiAgent.openPosition(
    tokenA.address,
    ethers.utils.parseEther("200"),
    "Venus"
);

// Close the position
const pnl = await defiAgent.closePosition(positionId);
```

### Risk Management

```javascript
// Update risk parameters
await defiAgent.updateRiskParameters(
    ethers.utils.parseEther("25"), // 25% max position size
    ethers.utils.parseEther("8"),  // 8% stop loss
    ethers.utils.parseEther("15"), // 15% take profit
    ethers.utils.parseEther("3")   // 3% max daily loss
);

// Emergency stop
await defiAgent.emergencyStop("Market crash detected");
```

## Security Features

### Access Control
- **Owner-only functions**: All critical operations require owner authorization
- **Agent token integration**: Compatible with BAP-578 agent token ownership
- **Emergency controls**: Circuit breakers for risk management

### Risk Management
- **Position size limits**: Prevent over-concentration
- **Daily loss limits**: Automatic trading suspension on excessive losses
- **Slippage protection**: Configurable maximum slippage tolerance
- **Emergency withdrawal**: Secure fund recovery mechanism

### Learning Security
- **Cryptographic verification**: All learning updates are cryptographically verified
- **Rate limiting**: Prevents spam and gaming of learning system
- **Privacy protection**: Learning data access is controlled and auditable

## Integration with BAP-578 Ecosystem

### Agent Factory Integration
The DeFi Agent can be deployed through the AgentFactory with template approval:

```javascript
// Register DeFi Agent template
await agentFactory.approveTemplate(
    defiAgent.address,
    "DeFi",
    "v1.0.0"
);

// Create DeFi agent through factory
const agent = await agentFactory.createAgent(
    "My DeFi Agent",
    "MDA",
    defiTemplate,
    "ipfs://metadata-uri",
    extendedMetadata
);
```

### Learning Module Compatibility
Compatible with all approved learning modules in the BAP-578 ecosystem:

- **MerkleTreeLearning**: Default cryptographically verifiable learning
- **Custom Learning Modules**: Extensible for specialized DeFi strategies
- **Cross-Agent Learning**: Potential for shared learning across agent instances

## Future Enhancements

### Phase 2 Features
- **Advanced Strategy Engine**: Automated trading strategies based on market conditions
- **Cross-Protocol Arbitrage**: Automated arbitrage opportunities detection
- **Yield Optimization**: Automated yield farming across multiple protocols
- **Social Trading**: Copy trading and strategy sharing capabilities

### Phase 3 Features
- **AI-Powered Analytics**: Machine learning for market prediction
- **Cross-Chain Operations**: Multi-chain DeFi operations
- **Institutional Features**: Advanced portfolio management for institutions
- **Regulatory Compliance**: Built-in compliance and reporting features

## Testing

The DeFi Agent includes comprehensive test coverage with 69 test cases covering:

- **Deployment and initialization**
- **Profile and risk parameter management**
- **Protocol and token management**
- **Trading functionality**
- **Position management**
- **Risk management and emergency controls**
- **Learning module integration**
- **Portfolio management**
- **Access control and security**
- **Edge cases and error handling**
- **Integration scenarios**

Run tests with:
```bash
npm test -- test/DeFiAgent.test.js
```

## Conclusion

The DeFi Agent template provides a robust foundation for creating intelligent, adaptive DeFi assistants that can learn and evolve based on user preferences and market conditions. With comprehensive risk management, multi-protocol support, and learning capabilities, it represents a significant advancement in autonomous DeFi portfolio management.
