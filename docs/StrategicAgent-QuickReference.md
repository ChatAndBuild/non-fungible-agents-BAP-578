# StrategicAgent Quick Reference

## Quick Start

### 1. Deploy and Initialize
```solidity
StrategicAgent strategicAgent = new StrategicAgent();
strategicAgent.initialize(
    bep007TokenAddress,
    "My Monitor",
    "Crypto Analysis",
    75
);
```

### 2. Configure Platforms
```solidity
strategicAgent.configurePlatform(
    "Twitter",
    twitterOracleAddress,
    true,  // active
    8,     // priority (1-10)
    300    // 5-min updates
);
```

### 3. Add Monitoring Targets
```solidity
strategicAgent.addTargetKeyword("Bitcoin");
strategicAgent.addTargetEntity("Vitalik Buterin");
```

### 4. Set Up Alerts
```solidity
strategicAgent.configureAlerts(
    100,  // trend threshold
    50,   // mention threshold
    80,   // sentiment threshold
    300,  // 5-min cooldown
    true  // enabled
);
```

## Key Functions

### Profile Management
```solidity
updateProfile(name, specialization, intensity, depth, realTime, crossPlatform)
```

### Target Management
```solidity
addTargetKeyword(keyword)
removeTargetKeyword(keyword)
addTargetEntity(entity)
removeTargetEntity(entity)
```

### Data Operations
```solidity
detectTrend(keyword, mentions, sentiment, confidence, platforms, posts)
recordMention(entity, content, platform, sentiment, reach, hashtags)
analyzeSentiment(content, sentiment, confidence, emotions, scores, platform)
```

### View Functions
```solidity
getProfile() → StrategicProfile
getTrend(trendId) → TrendData
getMention(mentionId) → MentionData
getSentimentAnalysis(analysisId) → SentimentData
getMetrics() → MonitoringMetrics
```

## Data Structures

### StrategicProfile
- `name`: Agent name
- `specialization`: Area of expertise
- `targetKeywords[]`: Keywords to monitor
- `targetEntities[]`: Entities to track
- `monitoringIntensity`: 1-100
- `analysisDepth`: 1-100
- `realTimeMonitoring`: bool
- `crossPlatformAnalysis`: bool

### TrendData
- `keyword`: Trending keyword
- `mentions`: Number of mentions
- `sentimentScore`: 0-100
- `confidence`: 0-100
- `timestamp`: Detection time
- `platforms[]`: Source platforms
- `topPosts[]`: Top related posts

### MentionData
- `entity`: Mentioned entity
- `content`: Content with mention
- `platform`: Source platform
- `sentiment`: 0-100
- `reach`: Estimated reach
- `timestamp`: Detection time
- `hashtags[]`: Associated hashtags

### SentimentData
- `content`: Analyzed content
- `overallSentiment`: 0-100
- `confidence`: 0-100
- `emotions[]`: Detected emotions
- `emotionScores[]`: Emotion intensities
- `timestamp`: Analysis time
- `platform`: Source platform

## Events

### Core Events
```solidity
ProfileUpdated(name, specialization, intensity, depth)
TargetKeywordAdded(keyword)
TargetEntityAdded(entity)
PlatformConfigured(platformName, oracleAddress, isActive, priority)
```

### Data Events
```solidity
TrendDetected(trendId, keyword, mentions, sentimentScore)
MentionRecorded(mentionId, entity, platform, sentiment)
SentimentAnalyzed(analysisId, content, overallSentiment, confidence)
```

### Alert Events
```solidity
AlertTriggered(alertType, message, severity, timestamp)
AlertsConfigured(trendThreshold, mentionThreshold, sentimentThreshold)
```

## Common Patterns

### Basic Monitoring Setup
```solidity
// 1. Initialize agent
strategicAgent.initialize(bep007Token, "Crypto Monitor", "DeFi", 80);

// 2. Configure platforms
strategicAgent.configurePlatform("Twitter", twitterOracle, true, 9, 60);
strategicAgent.configurePlatform("Reddit", redditOracle, true, 7, 300);

// 3. Add targets
strategicAgent.addTargetKeyword("DeFi");
strategicAgent.addTargetKeyword("Yield Farming");
strategicAgent.addTargetEntity("Uniswap");

// 4. Configure alerts
strategicAgent.configureAlerts(100, 50, 80, 300, true);
```

### Trend Detection Workflow
```solidity
// Detect trend
uint256 trendId = strategicAgent.detectTrend(
    "DeFi",
    150,  // mentions
    75,   // sentiment
    85,   // confidence
    ["Twitter", "Reddit"],
    ["DeFi is booming!", "New yield opportunities"]
);

// Get trend data
TrendData memory trend = strategicAgent.getTrend(trendId);
```

### Sentiment Analysis Workflow
```solidity
// Analyze sentiment
uint256 analysisId = strategicAgent.analyzeSentiment(
    "This DeFi protocol is revolutionary!",
    95,  // very positive
    90,  // high confidence
    ["joy", "excitement"],
    [90, 85],
    "Twitter"
);

// Get analysis
SentimentData memory analysis = strategicAgent.getSentimentAnalysis(analysisId);
```

## Error Codes

### Access Control
- `"StrategicAgent: caller is not token owner"`

### Input Validation
- `"StrategicAgent: invalid monitoring intensity (1-100)"`
- `"StrategicAgent: invalid analysis depth (1-100)"`
- `"StrategicAgent: invalid priority level (1-10)"`
- `"StrategicAgent: keyword cannot be empty"`
- `"StrategicAgent: entity cannot be empty"`

### Data Validation
- `"StrategicAgent: invalid sentiment score (0-100)"`
- `"StrategicAgent: invalid confidence level (0-100)"`
- `"StrategicAgent: emotions and scores arrays must have same length"`

### Alert System
- `"StrategicAgent: alert cooldown not expired"`
- `"StrategicAgent: alerts are disabled"`

## Gas Optimization Tips

1. **Batch Operations**: Group related function calls
2. **Use Appropriate Data Types**: Choose efficient storage types
3. **Limit Array Sizes**: Keep arrays reasonably sized
4. **Regular Cleanup**: Remove old data periodically
5. **Optimize Update Frequencies**: Balance real-time vs gas costs

## Integration Examples

### With BEP-007
```solidity
// Create NFA agent
uint256 agentId = bep007.createAgent(
    owner,
    address(strategicAgent),
    "Strategic Monitor",
    metadata
);
```

### With Learning Modules
```solidity
// Register for learning
learningModule.registerAgent(
    agentId,
    "strategic_monitoring",
    learningConfig
);
```

### With Experience Modules
```solidity
// Register experience module
experienceRegistry.registerModule(
    agentId,
    "StrategicAgent",
    "1.0.0",
    moduleAddress,
    signature
);
```

## Testing

### Basic Test Structure
```javascript
describe('StrategicAgent', function() {
  beforeEach(async function() {
    strategicAgent = await StrategicAgent.deploy();
    await strategicAgent.initialize(bep007Token.address, "Test Agent", "Testing", 50);
  });

  it('Should initialize correctly', async function() {
    const profile = await strategicAgent.getProfile();
    expect(profile.name).to.equal("Test Agent");
  });
});
```

### Common Test Patterns
```javascript
// Test profile update
await strategicAgent.updateProfile("New Name", "New Spec", 80, 90, true, true);

// Test target management
await strategicAgent.addTargetKeyword("Bitcoin");
expect(await strategicAgent.isTargetKeyword("Bitcoin")).to.be.true;

// Test trend detection
const tx = await strategicAgent.detectTrend("Bitcoin", 100, 75, 85, ["Twitter"], ["Post"]);
await expect(tx).to.emit(strategicAgent, 'TrendDetected');
```

## Troubleshooting

### Common Issues

1. **"caller is not token owner"**
   - Ensure you're calling from the correct account
   - Verify token ownership in BEP-007 contract

2. **"invalid monitoring intensity"**
   - Use values between 1-100
   - Check for integer overflow

3. **"keyword already exists"**
   - Check if keyword is already added
   - Use `isTargetKeyword()` to verify

4. **Alert not triggering**
   - Check if alerts are enabled
   - Verify cooldown period has expired
   - Ensure thresholds are met

### Debug Tips

1. **Check Contract State**: Use view functions to inspect current state
2. **Monitor Events**: Listen for events to track operations
3. **Verify Inputs**: Ensure all inputs are within valid ranges
4. **Test Incrementally**: Test functions one at a time

## Resources

- **Full Documentation**: [StrategicAgent.md](./StrategicAgent.md)
- **Test Suite**: [StrategicAgent.test.js](../test/StrategicAgent.test.js)
- **Contract Source**: [StrategicAgent.sol](../contracts/templates/StrategicAgent.sol)
- **BEP-007 Standard**: [BEP-007.md](./BEP-007.md)
