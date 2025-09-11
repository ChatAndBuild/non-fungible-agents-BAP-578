# StrategicAgent Template Documentation

## Overview

The **StrategicAgent** is a specialized template for BEP-007 Non-Fungible Agents (NFAs) designed for monitoring trends, detecting mentions, and analyzing sentiment across various platforms. This template enables agents to act as intelligent monitoring systems that can track and analyze social media, news, and other digital content in real-time.

## Table of Contents

1. [Features](#features)
2. [Architecture](#architecture)
3. [Data Structures](#data-structures)
4. [Core Functions](#core-functions)
5. [Platform Integration](#platform-integration)
6. [Alert System](#alert-system)
7. [Learning Integration](#learning-integration)
8. [Security](#security)
9. [Usage Examples](#usage-examples)
10. [API Reference](#api-reference)
11. [Events](#events)
12. [Error Handling](#error-handling)
13. [Best Practices](#best-practices)

## Features

### Core Capabilities
- **Trend Detection**: Monitor and track trending topics across multiple platforms
- **Mention Detection**: Track mentions of specific entities, brands, or topics
- **Sentiment Analysis**: Analyze emotional tone and sentiment of content
- **Cross-Platform Analysis**: Support for multiple platforms (Twitter, Reddit, Discord, etc.)
- **Real-time Monitoring**: Configurable real-time or batch processing
- **Learning Integration**: Records all interactions for machine learning adaptation

### Advanced Features
- **Multi-Platform Support**: Configure and monitor multiple social platforms
- **Priority-Based Monitoring**: Set priority levels for different platforms
- **Configurable Alerts**: Customizable alert thresholds and cooldown periods
- **Performance Metrics**: Track accuracy, response time, and activity levels
- **Historical Data**: Store and retrieve historical analysis data

## Architecture

### Contract Structure
```solidity
contract StrategicAgent is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    // Core state variables
    IBEP007 public agentToken;
    StrategicProfile public profile;
    MonitoringMetrics public metrics;
    
    // Platform and target management
    mapping(string => PlatformConfig) public platforms;
    mapping(string => bool) public targetKeywords;
    mapping(string => bool) public targetEntities;
    
    // Data storage
    mapping(uint256 => TrendData) public trends;
    mapping(uint256 => MentionData) public mentions;
    mapping(uint256 => SentimentData) public sentimentAnalyses;
    
    // Alert system
    AlertConfig public alertConfig;
    mapping(string => uint256) public lastAlertTime;
}
```

### Integration Points
- **BEP-007 Token System**: Uses BEP-007 for ownership and agent management
- **Learning Modules**: Integrates with BEP-007 learning infrastructure
- **Experience Modules**: Compatible with ExperienceModuleRegistry
- **Oracle Networks**: Supports external oracle integration for data feeds

## Data Structures

### StrategicProfile
```solidity
struct StrategicProfile {
    string name;                    // Agent name
    string specialization;          // Area of expertise
    string[] targetKeywords;        // Keywords to monitor
    string[] targetEntities;        // Entities to track
    uint256 monitoringIntensity;    // 1-100 intensity level
    uint256 analysisDepth;          // 1-100 analysis depth
    bool realTimeMonitoring;        // Real-time vs batch processing
    bool crossPlatformAnalysis;     // Cross-platform correlation
}
```

### PlatformConfig
```solidity
struct PlatformConfig {
    address oracleAddress;          // Oracle contract address
    bool isActive;                  // Platform status
    uint256 priority;               // 1-10 priority level
    uint256 updateFrequency;        // Update interval in seconds
    uint256 lastUpdate;             // Last update timestamp
}
```

### TrendData
```solidity
struct TrendData {
    string keyword;                 // Trending keyword
    uint256 mentions;               // Number of mentions
    uint256 sentimentScore;         // Overall sentiment (0-100)
    uint256 confidence;             // Confidence level (0-100)
    uint256 timestamp;              // Detection timestamp
    string[] platforms;             // Platforms where trend was detected
    string[] topPosts;              // Top posts related to trend
}
```

### MentionData
```solidity
struct MentionData {
    string entity;                  // Mentioned entity
    string content;                 // Content containing mention
    string platform;                // Source platform
    uint256 sentiment;              // Sentiment score (0-100)
    uint256 reach;                  // Estimated reach
    uint256 timestamp;              // Detection timestamp
    string[] hashtags;              // Associated hashtags
}
```

### SentimentData
```solidity
struct SentimentData {
    string content;                 // Analyzed content
    uint256 overallSentiment;       // Overall sentiment (0-100)
    uint256 confidence;             // Analysis confidence (0-100)
    string[] emotions;              // Detected emotions
    uint256[] emotionScores;        // Emotion intensity scores
    uint256 timestamp;              // Analysis timestamp
    string platform;                // Source platform
}
```

### AlertConfig
```solidity
struct AlertConfig {
    uint256 trendThreshold;         // Trend alert threshold
    uint256 mentionThreshold;       // Mention alert threshold
    uint256 sentimentThreshold;     // Sentiment alert threshold
    uint256 cooldownPeriod;         // Alert cooldown in seconds
    bool alertsEnabled;             // Global alert status
}
```

### MonitoringMetrics
```solidity
struct MonitoringMetrics {
    uint256 totalTrendsDetected;    // Total trends found
    uint256 totalMentionsTracked;   // Total mentions tracked
    uint256 totalAnalysesPerformed; // Total sentiment analyses
    uint256 averageResponseTime;    // Average response time (ms)
    uint256 accuracyScore;          // Overall accuracy (0-100)
    uint256 lastActivity;           // Last activity timestamp
}
```

## Core Functions

### Initialization
```solidity
function initialize(
    address _agentToken,
    string memory _name,
    string memory _specialization,
    uint256 _monitoringIntensity
) public initializer
```

### Profile Management
```solidity
function updateProfile(
    string memory _name,
    string memory _specialization,
    uint256 _monitoringIntensity,
    uint256 _analysisDepth,
    bool _realTimeMonitoring,
    bool _crossPlatformAnalysis
) external onlyOwner
```

### Target Management
```solidity
function addTargetKeyword(string memory _keyword) external onlyOwner
function removeTargetKeyword(string memory _keyword) external onlyOwner
function addTargetEntity(string memory _entity) external onlyOwner
function removeTargetEntity(string memory _entity) external onlyOwner
```

### Platform Configuration
```solidity
function configurePlatform(
    string memory _platformName,
    address _oracleAddress,
    bool _isActive,
    uint256 _priority,
    uint256 _updateFrequency
) external onlyOwner
```

### Trend Detection
```solidity
function detectTrend(
    string memory _keyword,
    uint256 _mentions,
    uint256 _sentimentScore,
    uint256 _confidence,
    string[] memory _platforms,
    string[] memory _topPosts
) external onlyOwner returns (uint256)
```

### Mention Tracking
```solidity
function recordMention(
    string memory _entity,
    string memory _content,
    string memory _platform,
    uint256 _sentiment,
    uint256 _reach,
    string[] memory _hashtags
) external onlyOwner returns (uint256)
```

### Sentiment Analysis
```solidity
function analyzeSentiment(
    string memory _content,
    uint256 _overallSentiment,
    uint256 _confidence,
    string[] memory _emotions,
    uint256[] memory _emotionScores,
    string memory _platform
) external onlyOwner returns (uint256)
```

## Platform Integration

### Supported Platforms
- **Twitter**: Social media monitoring
- **Reddit**: Community sentiment analysis
- **Discord**: Community engagement tracking
- **Telegram**: Channel monitoring
- **Custom Platforms**: Extensible for any platform with oracle support

### Oracle Integration
```solidity
// Configure platform with oracle
strategicAgent.configurePlatform(
    "Twitter",
    twitterOracleAddress,
    true,    // active
    8,       // priority (1-10)
    300      // 5-minute updates
);
```

### Data Flow
1. **Oracle Fetch**: External oracles fetch data from platforms
2. **Data Processing**: StrategicAgent processes and analyzes data
3. **Trend Detection**: Identifies trending topics and patterns
4. **Alert Generation**: Triggers alerts based on configured thresholds
5. **Learning Integration**: Records data for machine learning adaptation

## Alert System

### Alert Types
- **Trend Alerts**: Triggered when mentions exceed threshold
- **Mention Alerts**: Triggered when specific entities are mentioned
- **Sentiment Alerts**: Triggered when sentiment changes significantly

### Configuration
```solidity
function configureAlerts(
    uint256 _trendThreshold,
    uint256 _mentionThreshold,
    uint256 _sentimentThreshold,
    uint256 _cooldownPeriod,
    bool _alertsEnabled
) external onlyOwner
```

### Alert Events
```solidity
event AlertTriggered(
    string alertType,
    string message,
    uint256 severity,
    uint256 timestamp
);
```

### Cooldown System
- Prevents spam alerts
- Configurable cooldown periods per alert type
- Tracks last alert time for each type

## Learning Integration

### Experience Recording
The StrategicAgent automatically records all interactions for learning:

```solidity
function _recordTrendForLearning(
    string memory _keyword,
    uint256 _mentions,
    uint256 _sentimentScore,
    uint256 _confidence
) private
```

### Learning Module Compatibility
- Compatible with BEP-007 learning modules
- Records structured data for machine learning
- Supports both supervised and unsupervised learning

### Data Structure for Learning
```solidity
struct LearningData {
    string dataType;        // "trend", "mention", "sentiment"
    bytes32 dataHash;       // Hash of the data
    uint256 timestamp;      // When data was recorded
    string[] metadata;      // Additional metadata
}
```

## Security

### Access Control
- **Owner-Only Functions**: Only token owners can manage the agent
- **Reentrancy Protection**: Secure against reentrancy attacks
- **Input Validation**: Comprehensive validation of all inputs

### Ownership Verification
```solidity
modifier onlyOwner() {
    require(
        agentToken.getState(tokenId).owner == msg.sender,
        "StrategicAgent: caller is not token owner"
    );
    _;
}
```

### Input Validation
- Range checks for numeric inputs (1-100 for scores, 1-10 for priorities)
- String length validation
- Array length validation
- Address validation for oracle contracts

## Usage Examples

### Basic Setup
```solidity
// Deploy StrategicAgent
StrategicAgent strategicAgent = new StrategicAgent();

// Initialize with BEP-007 token
strategicAgent.initialize(
    bep007TokenAddress,
    "Crypto Monitor",
    "Cryptocurrency Analysis",
    75 // monitoring intensity
);

// Configure profile
strategicAgent.updateProfile(
    "Crypto Market Monitor",
    "Cryptocurrency and DeFi",
    80,  // monitoring intensity
    90,  // analysis depth
    true, // real-time monitoring
    true  // cross-platform analysis
);
```

### Platform Configuration
```solidity
// Configure Twitter monitoring
strategicAgent.configurePlatform(
    "Twitter",
    twitterOracleAddress,
    true,    // active
    9,       // high priority
    60       // 1-minute updates
);

// Configure Reddit monitoring
strategicAgent.configurePlatform(
    "Reddit",
    redditOracleAddress,
    true,    // active
    7,       // medium priority
    300      // 5-minute updates
);
```

### Target Management
```solidity
// Add keywords to monitor
strategicAgent.addTargetKeyword("Bitcoin");
strategicAgent.addTargetKeyword("Ethereum");
strategicAgent.addTargetKeyword("DeFi");

// Add entities to track
strategicAgent.addTargetEntity("Vitalik Buterin");
strategicAgent.addTargetEntity("Elon Musk");
strategicAgent.addTargetEntity("Binance");
```

### Alert Configuration
```solidity
// Configure alert thresholds
strategicAgent.configureAlerts(
    100,  // trend threshold (mentions)
    50,   // mention threshold
    80,   // sentiment threshold
    300,  // 5-minute cooldown
    true  // alerts enabled
);
```

### Trend Detection
```solidity
// Detect a trend
uint256 trendId = strategicAgent.detectTrend(
    "Bitcoin",
    150,  // mentions
    75,   // positive sentiment
    85,   // confidence
    ["Twitter", "Reddit"],
    ["Bitcoin hits new ATH!", "BTC to the moon!"]
);
```

### Mention Tracking
```solidity
// Record a mention
uint256 mentionId = strategicAgent.recordMention(
    "Vitalik Buterin",
    "Vitalik just announced new Ethereum upgrade",
    "Twitter",
    90,  // positive sentiment
    10000, // reach
    ["#Ethereum", "#ETH", "#Upgrade"]
);
```

### Sentiment Analysis
```solidity
// Analyze sentiment
uint256 analysisId = strategicAgent.analyzeSentiment(
    "This new DeFi protocol is amazing!",
    95,  // very positive
    90,  // high confidence
    ["joy", "excitement"],
    [90, 85], // emotion scores
    "Twitter"
);
```

## API Reference

### View Functions

#### Profile Information
```solidity
function getProfile() external view returns (StrategicProfile memory)
function getTargetKeywords() external view returns (string[] memory)
function getTargetEntities() external view returns (string[] memory)
```

#### Platform Information
```solidity
function getPlatformConfig(string memory _platform) external view returns (PlatformConfig memory)
function getActivePlatforms() external view returns (string[] memory)
```

#### Data Retrieval
```solidity
function getTrend(uint256 _trendId) external view returns (TrendData memory)
function getMention(uint256 _mentionId) external view returns (MentionData memory)
function getSentimentAnalysis(uint256 _analysisId) external view returns (SentimentData memory)
```

#### Metrics
```solidity
function getMetrics() external view returns (MonitoringMetrics memory)
function getAlertConfig() external view returns (AlertConfig memory)
```

### Utility Functions
```solidity
function isTargetKeyword(string memory _keyword) external view returns (bool)
function isTargetEntity(string memory _entity) external view returns (bool)
function getLastAlertTime(string memory _alertType) external view returns (uint256)
```

## Events

### Profile Events
```solidity
event ProfileUpdated(
    string name,
    string specialization,
    uint256 monitoringIntensity,
    uint256 analysisDepth
);
```

### Target Events
```solidity
event TargetKeywordAdded(string keyword);
event TargetKeywordRemoved(string keyword);
event TargetEntityAdded(string entity);
event TargetEntityRemoved(string entity);
```

### Platform Events
```solidity
event PlatformConfigured(
    string platformName,
    address oracleAddress,
    bool isActive,
    uint256 priority
);
```

### Data Events
```solidity
event TrendDetected(
    uint256 trendId,
    string keyword,
    uint256 mentions,
    uint256 sentimentScore
);

event MentionRecorded(
    uint256 mentionId,
    string entity,
    string platform,
    uint256 sentiment
);

event SentimentAnalyzed(
    uint256 analysisId,
    string content,
    uint256 overallSentiment,
    uint256 confidence
);
```

### Alert Events
```solidity
event AlertTriggered(
    string alertType,
    string message,
    uint256 severity,
    uint256 timestamp
);

event AlertsConfigured(
    uint256 trendThreshold,
    uint256 mentionThreshold,
    uint256 sentimentThreshold
);
```

### Metrics Events
```solidity
event MetricsUpdated(
    uint256 totalTrendsDetected,
    uint256 totalMentionsTracked,
    uint256 totalAnalysesPerformed,
    uint256 accuracyScore
);
```

## Error Handling

### Common Errors

#### Access Control Errors
```solidity
error("StrategicAgent: caller is not token owner");
error("StrategicAgent: only owner can perform this action");
```

#### Input Validation Errors
```solidity
error("StrategicAgent: invalid monitoring intensity (1-100)");
error("StrategicAgent: invalid analysis depth (1-100)");
error("StrategicAgent: invalid priority level (1-10)");
error("StrategicAgent: update frequency must be greater than 0");
error("StrategicAgent: keyword cannot be empty");
error("StrategicAgent: entity cannot be empty");
error("StrategicAgent: keyword already exists");
error("StrategicAgent: entity already exists");
error("StrategicAgent: keyword does not exist");
error("StrategicAgent: entity does not exist");
```

#### Data Validation Errors
```solidity
error("StrategicAgent: invalid sentiment score (0-100)");
error("StrategicAgent: invalid confidence level (0-100)");
error("StrategicAgent: emotions and scores arrays must have same length");
error("StrategicAgent: invalid accuracy score (0-100)");
```

#### Alert System Errors
```solidity
error("StrategicAgent: alert cooldown not expired");
error("StrategicAgent: alerts are disabled");
```

### Error Recovery
- All functions include comprehensive error checking
- Failed operations don't affect contract state
- Clear error messages for debugging
- Gas-efficient error handling

## Best Practices

### Configuration
1. **Start with Conservative Settings**: Begin with lower monitoring intensity and gradually increase
2. **Set Appropriate Thresholds**: Configure alert thresholds based on your specific use case
3. **Use Priority Levels**: Set higher priority for more important platforms
4. **Monitor Gas Usage**: Be aware of gas costs for real-time monitoring

### Platform Management
1. **Verify Oracle Addresses**: Always verify oracle contract addresses before configuration
2. **Set Reasonable Update Frequencies**: Balance between real-time monitoring and gas costs
3. **Monitor Platform Health**: Regularly check platform status and oracle connectivity
4. **Use Multiple Platforms**: Configure multiple platforms for comprehensive coverage

### Target Management
1. **Start with Specific Keywords**: Begin with specific, relevant keywords
2. **Regularly Update Targets**: Add/remove targets based on changing interests
3. **Use Entity Tracking**: Track specific people, companies, or brands
4. **Avoid Over-Monitoring**: Don't add too many targets to avoid noise

### Alert Configuration
1. **Set Appropriate Thresholds**: Configure thresholds based on your monitoring goals
2. **Use Cooldown Periods**: Prevent alert spam with reasonable cooldown periods
3. **Monitor Alert Performance**: Track alert effectiveness and adjust thresholds
4. **Test Alert System**: Regularly test alert functionality

### Performance Optimization
1. **Batch Operations**: Group related operations to save gas
2. **Use Appropriate Data Types**: Choose efficient data types for storage
3. **Regular Cleanup**: Remove old or irrelevant data periodically
4. **Monitor Metrics**: Track performance metrics and optimize accordingly

### Security Considerations
1. **Verify Ownership**: Always verify token ownership before operations
2. **Validate Inputs**: Ensure all inputs are properly validated
3. **Use Secure Oracles**: Only use trusted oracle contracts
4. **Regular Updates**: Keep the contract updated with latest security patches

## Integration with BEP-007 Ecosystem

### Agent Creation
```solidity
// Create NFA agent with StrategicAgent logic
uint256 agentId = bep007.createAgent(
    owner,
    address(strategicAgent), // logic contract
    "Strategic Monitor Agent",
    metadata
);
```

### Learning Module Integration
```solidity
// Register with learning module
learningModule.registerAgent(
    agentId,
    "strategic_monitoring",
    learningConfig
);
```

### Experience Module Integration
```solidity
// Register with experience module registry
experienceRegistry.registerModule(
    agentId,
    "StrategicAgent",
    "1.0.0",
    moduleAddress,
    signature
);
```

## Conclusion

The StrategicAgent template provides a comprehensive solution for intelligent monitoring and analysis across multiple platforms. With its robust architecture, extensive configuration options, and seamless integration with the BEP-007 ecosystem, it enables the creation of sophisticated monitoring agents that can adapt and learn over time.

For more information about the BEP-007 standard and other agent templates, refer to the main project documentation.
