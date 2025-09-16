// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../interfaces/ILearningModule.sol";

/**
 * @title StrategicAgent
 * @dev Enhanced template for strategic agents with learning capabilities
 *      that monitor trends, detect mentions, and analyze sentiment across various platforms
 *
 * This agent serves as an intelligent monitoring and analysis system that can:
 * - Track trending topics and keywords across multiple platforms
 * - Detect mentions of specific entities, brands, or topics
 * - Analyze sentiment and emotional tone of content
 * - Learn from patterns and adapt monitoring strategies
 * - Provide actionable insights and alerts
 */
contract StrategicAgent is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    // The address of the BAP-578 token that owns this logic
    address public agentToken;

    // Learning module integration
    address public learningModule;
    bool public learningEnabled;

    // Strategic agent profile
    struct StrategicProfile {
        string name; // Agent name
        string specialization; // Area of expertise (e.g., "Crypto", "Tech", "Finance")
        string[] targetKeywords; // Keywords to monitor
        string[] targetEntities; // Entities to track (brands, people, companies)
        uint256 monitoringIntensity; // 0-100 scale (0 = passive, 100 = aggressive)
        uint256 analysisDepth; // 0-100 scale (0 = surface, 100 = deep analysis)
        bool realTimeMonitoring; // Whether to monitor in real-time
        bool crossPlatformAnalysis; // Whether to analyze across multiple platforms
    }

    // Platform configuration
    struct PlatformConfig {
        string name; // Platform name (Twitter, Reddit, Discord, etc.)
        address oracleAddress; // Oracle contract for platform data
        bool enabled; // Whether platform is enabled
        uint256 priority; // Priority level (1-10, 10 = highest)
        uint256 updateFrequency; // Update frequency in seconds
        uint256 lastUpdate; // Last update timestamp
    }

    // Trend data structure
    struct TrendData {
        string keyword; // Trending keyword or topic
        uint256 mentions; // Number of mentions
        uint256 sentimentScore; // Sentiment score (-100 to +100)
        uint256 confidence; // Confidence level (0-100)
        uint256 timestamp; // When trend was detected
        string[] platforms; // Platforms where trend was detected
        string[] topPosts; // Top posts mentioning the trend
    }

    // Mention data structure
    struct MentionData {
        string entity; // Mentioned entity
        string content; // Content containing the mention
        string platform; // Platform where mention occurred
        uint256 sentimentScore; // Sentiment score (-100 to +100)
        uint256 reach; // Estimated reach/impressions
        uint256 engagement; // Likes, shares, comments
        uint256 timestamp; // When mention occurred
        address author; // Content author (if available)
    }

    // Sentiment analysis result
    struct SentimentAnalysis {
        string content; // Analyzed content
        uint256 overallSentiment; // Overall sentiment (-100 to +100)
        uint256 confidence; // Analysis confidence (0-100)
        string[] emotions; // Detected emotions
        uint256[] emotionScores; // Emotion intensity scores
        uint256 timestamp; // Analysis timestamp
    }

    // Alert configuration
    struct AlertConfig {
        string alertType; // Type of alert (trend, mention, sentiment)
        uint256 threshold; // Threshold for triggering alert
        bool enabled; // Whether alert is enabled
        string[] recipients; // Alert recipients
        uint256 cooldownPeriod; // Cooldown between alerts (seconds)
        uint256 lastAlert; // Last alert timestamp
    }

    // Agent's strategic profile
    StrategicProfile public profile;

    // Platform configurations
    mapping(string => PlatformConfig) public platforms;
    string[] public platformList;

    // Alert configurations
    mapping(string => AlertConfig) public alerts;
    string[] public alertTypes;

    // Trend tracking
    mapping(string => TrendData) public trends;
    string[] public trendKeywords;

    // Mention tracking
    mapping(bytes32 => MentionData) public mentions;
    bytes32[] public mentionIds;

    // Sentiment analysis history
    mapping(bytes32 => SentimentAnalysis) public sentimentHistory;
    bytes32[] public sentimentIds;

    // Performance metrics
    struct PerformanceMetrics {
        uint256 totalTrendsDetected; // Total trends detected
        uint256 totalMentionsTracked; // Total mentions tracked
        uint256 totalAnalysesPerformed; // Total sentiment analyses
        uint256 accuracyScore; // Overall accuracy score (0-100)
        uint256 responseTime; // Average response time in seconds
        uint256 lastActivity; // Last activity timestamp
    }

    // Counters for ID generation
    Counters.Counter private _mentionIdCounter;
    Counters.Counter private _analysisIdCounter;

    PerformanceMetrics public metrics;

    // Events
    event TrendDetected(
        string indexed keyword,
        uint256 mentions,
        uint256 sentimentScore,
        uint256 confidence,
        string[] platforms
    );

    event MentionDetected(
        string indexed entity,
        string platform,
        uint256 sentimentScore,
        uint256 reach,
        uint256 engagement
    );

    event SentimentAnalyzed(
        bytes32 indexed analysisId,
        uint256 sentimentScore,
        uint256 confidence,
        string[] emotions
    );

    event AlertTriggered(
        string indexed alertType,
        string description,
        uint256 severity,
        uint256 timestamp
    );

    event PlatformUpdated(
        string indexed platformName,
        bool enabled,
        uint256 priority,
        uint256 updateFrequency
    );

    event LearningUpdate(string updateType, bytes32 dataHash, uint256 timestamp);
    event ETHWithdrawn(address indexed to, uint256 amount);

    /**
     * @dev Initializes the Strategic Agent contract
     * @param _agentToken The address of the BAP-578 token
     * @param _name The agent's name
     * @param _specialization The agent's area of expertise
     * @param _monitoringIntensity Monitoring intensity level (0-100)
     */
    constructor(
        address _agentToken,
        string memory _name,
        string memory _specialization,
        uint256 _monitoringIntensity
    ) {
        require(_agentToken != address(0), "StrategicAgent: agent token is zero address");
        require(_monitoringIntensity <= 100, "StrategicAgent: monitoring intensity must be 0-100");

        agentToken = _agentToken;

        // Initialize strategic profile
        profile = StrategicProfile({
            name: _name,
            specialization: _specialization,
            targetKeywords: new string[](0),
            targetEntities: new string[](0),
            monitoringIntensity: _monitoringIntensity,
            analysisDepth: 50, // Default medium analysis depth
            realTimeMonitoring: true,
            crossPlatformAnalysis: true
        });

        // Initialize performance metrics
        metrics = PerformanceMetrics({
            totalTrendsDetected: 0,
            totalMentionsTracked: 0,
            totalAnalysesPerformed: 0,
            accuracyScore: 0,
            responseTime: 0,
            lastActivity: block.timestamp
        });
    }

    /**
     * @dev Modifier to check if the caller is the agent token
     */
    modifier onlyAgentToken() {
        require(msg.sender == agentToken, "StrategicAgent: caller is not agent token");
        _;
    }

    /**
     * @dev Modifier to check if learning is enabled
     */
    modifier whenLearningEnabled() {
        require(
            learningEnabled && learningModule != address(0),
            "StrategicAgent: learning not enabled"
        );
        _;
    }

    /**
     * @dev Enables learning for this agent
     * @param _learningModule The address of the learning module
     */
    function enableLearning(address _learningModule) external onlyOwner {
        require(_learningModule != address(0), "StrategicAgent: learning module is zero address");
        require(!learningEnabled, "StrategicAgent: learning already enabled");

        learningModule = _learningModule;
        learningEnabled = true;
    }

    /**
     * @dev Updates the strategic agent's profile
     * @param _name The agent's name
     * @param _specialization The agent's specialization
     * @param _monitoringIntensity Monitoring intensity (0-100)
     * @param _analysisDepth Analysis depth (0-100)
     * @param _realTimeMonitoring Whether real-time monitoring is enabled
     * @param _crossPlatformAnalysis Whether cross-platform analysis is enabled
     */
    function updateProfile(
        string memory _name,
        string memory _specialization,
        uint256 _monitoringIntensity,
        uint256 _analysisDepth,
        bool _realTimeMonitoring,
        bool _crossPlatformAnalysis
    ) external onlyOwner {
        require(_monitoringIntensity <= 100, "StrategicAgent: monitoring intensity must be 0-100");
        require(_analysisDepth <= 100, "StrategicAgent: analysis depth must be 0-100");

        profile.name = _name;
        profile.specialization = _specialization;
        profile.monitoringIntensity = _monitoringIntensity;
        profile.analysisDepth = _analysisDepth;
        profile.realTimeMonitoring = _realTimeMonitoring;
        profile.crossPlatformAnalysis = _crossPlatformAnalysis;
    }

    /**
     * @dev Adds a target keyword to monitor
     * @param _keyword The keyword to monitor
     */
    function addTargetKeyword(string memory _keyword) external onlyOwner {
        require(bytes(_keyword).length > 0, "StrategicAgent: keyword cannot be empty");

        // Check if keyword already exists
        for (uint256 i = 0; i < profile.targetKeywords.length; i++) {
            require(
                keccak256(bytes(profile.targetKeywords[i])) != keccak256(bytes(_keyword)),
                "StrategicAgent: keyword already exists"
            );
        }

        profile.targetKeywords.push(_keyword);
    }

    /**
     * @dev Adds a target entity to monitor
     * @param _entity The entity to monitor (brand, person, company)
     */
    function addTargetEntity(string memory _entity) external onlyOwner {
        require(bytes(_entity).length > 0, "StrategicAgent: entity cannot be empty");

        // Check if entity already exists
        for (uint256 i = 0; i < profile.targetEntities.length; i++) {
            require(
                keccak256(bytes(profile.targetEntities[i])) != keccak256(bytes(_entity)),
                "StrategicAgent: entity already exists"
            );
        }

        profile.targetEntities.push(_entity);
    }

    /**
     * @dev Configures a monitoring platform
     * @param _platformName The name of the platform
     * @param _oracleAddress The oracle contract address for platform data
     * @param _enabled Whether the platform is enabled
     * @param _priority Priority level (1-10)
     * @param _updateFrequency Update frequency in seconds
     */
    function configurePlatform(
        string memory _platformName,
        address _oracleAddress,
        bool _enabled,
        uint256 _priority,
        uint256 _updateFrequency
    ) external onlyOwner {
        require(bytes(_platformName).length > 0, "StrategicAgent: platform name cannot be empty");
        require(_priority >= 1 && _priority <= 10, "StrategicAgent: priority must be 1-10");
        require(_updateFrequency > 0, "StrategicAgent: update frequency must be greater than 0");

        // Add to platform list if new
        if (platforms[_platformName].oracleAddress == address(0)) {
            platformList.push(_platformName);
        }

        platforms[_platformName] = PlatformConfig({
            name: _platformName,
            oracleAddress: _oracleAddress,
            enabled: _enabled,
            priority: _priority,
            updateFrequency: _updateFrequency,
            lastUpdate: 0
        });

        emit PlatformUpdated(_platformName, _enabled, _priority, _updateFrequency);
    }

    /**
     * @dev Configures an alert system
     * @param _alertType The type of alert (trend, mention, sentiment)
     * @param _threshold The threshold for triggering the alert
     * @param _enabled Whether the alert is enabled
     * @param _cooldownPeriod Cooldown period between alerts in seconds
     */
    function configureAlert(
        string memory _alertType,
        uint256 _threshold,
        bool _enabled,
        uint256 _cooldownPeriod
    ) external onlyOwner {
        require(bytes(_alertType).length > 0, "StrategicAgent: alert type cannot be empty");

        // Add to alert types list if new
        if (alerts[_alertType].threshold <= 0) {
            alertTypes.push(_alertType);
        }

        alerts[_alertType] = AlertConfig({
            alertType: _alertType,
            threshold: _threshold,
            enabled: _enabled,
            recipients: new string[](0),
            cooldownPeriod: _cooldownPeriod,
            lastAlert: 0
        });
    }

    /**
     * @dev Detects and records a new trend
     * @param _keyword The trending keyword
     * @param _mentions Number of mentions
     * @param _sentimentScore Sentiment score (-100 to +100)
     * @param _confidence Confidence level (0-100)
     * @param _platforms Platforms where trend was detected
     * @param _topPosts Top posts mentioning the trend
     */
    function detectTrend(
        string memory _keyword,
        uint256 _mentions,
        int256 _sentimentScore,
        uint256 _confidence,
        string[] memory _platforms,
        string[] memory _topPosts
    ) external onlyOwner nonReentrant {
        require(bytes(_keyword).length > 0, "StrategicAgent: keyword cannot be empty");
        require(_confidence <= 100, "StrategicAgent: confidence must be 0-100");
        require(
            _sentimentScore >= -100 && _sentimentScore <= 100,
            "StrategicAgent: sentiment score must be -100 to +100"
        );

        // Convert sentiment score to uint256 for storage
        uint256 sentimentScore = _sentimentScore >= 0
            ? uint256(_sentimentScore)
            : uint256(-_sentimentScore);

        trends[_keyword] = TrendData({
            keyword: _keyword,
            mentions: _mentions,
            sentimentScore: sentimentScore,
            confidence: _confidence,
            timestamp: block.timestamp,
            platforms: _platforms,
            topPosts: _topPosts
        });

        // Add to trend keywords list if new
        bool exists = false;
        for (uint256 i = 0; i < trendKeywords.length; i++) {
            if (keccak256(bytes(trendKeywords[i])) == keccak256(bytes(_keyword))) {
                exists = true;
                break;
            }
        }
        if (!exists) {
            trendKeywords.push(_keyword);
        }

        // Update metrics
        metrics.totalTrendsDetected++;
        metrics.lastActivity = block.timestamp;

        // Check for alerts
        _checkTrendAlerts(_keyword, _mentions, sentimentScore, _confidence);

        // Record for learning if enabled
        if (learningEnabled) {
            _recordTrendForLearning(_keyword, _mentions, sentimentScore, _confidence);
        }

        emit TrendDetected(_keyword, _mentions, sentimentScore, _confidence, _platforms);
    }

    /**
     * @dev Records a mention detection
     * @param _entity The mentioned entity
     * @param _content The content containing the mention
     * @param _platform The platform where mention occurred
     * @param _sentimentScore Sentiment score (-100 to +100)
     * @param _reach Estimated reach/impressions
     * @param _engagement Engagement metrics
     * @param _author Content author address
     */
    function recordMention(
        string memory _entity,
        string memory _content,
        string memory _platform,
        int256 _sentimentScore,
        uint256 _reach,
        uint256 _engagement,
        address _author
    ) external onlyOwner nonReentrant {
        require(bytes(_entity).length > 0, "StrategicAgent: entity cannot be empty");
        require(bytes(_content).length > 0, "StrategicAgent: content cannot be empty");
        require(
            _sentimentScore >= -100 && _sentimentScore <= 100,
            "StrategicAgent: sentiment score must be -100 to +100"
        );

        // Create mention ID using nonce-based generation for better security
        _mentionIdCounter.increment();
        bytes32 mentionId = keccak256(
            abi.encode(_entity, _content, _platform, _mentionIdCounter.current())
        );

        // Convert sentiment score to uint256 for storage
        uint256 sentimentScore = _sentimentScore >= 0
            ? uint256(_sentimentScore)
            : uint256(-_sentimentScore);

        mentions[mentionId] = MentionData({
            entity: _entity,
            content: _content,
            platform: _platform,
            sentimentScore: sentimentScore,
            reach: _reach,
            engagement: _engagement,
            timestamp: block.timestamp,
            author: _author
        });

        mentionIds.push(mentionId);

        // Update metrics
        metrics.totalMentionsTracked++;
        metrics.lastActivity = block.timestamp;

        // Check for alerts
        _checkMentionAlerts(_entity, sentimentScore, _reach, _engagement);

        // Record for learning if enabled
        if (learningEnabled) {
            _recordMentionForLearning(_entity, _content, _platform, sentimentScore);
        }

        emit MentionDetected(_entity, _platform, sentimentScore, _reach, _engagement);
    }

    /**
     * @dev Performs sentiment analysis on content
     * @param _content The content to analyze
     * @param _sentimentScore Overall sentiment score (-100 to +100)
     * @param _confidence Analysis confidence (0-100)
     * @param _emotions Detected emotions
     * @param _emotionScores Emotion intensity scores
     */
    function analyzeSentiment(
        string memory _content,
        int256 _sentimentScore,
        uint256 _confidence,
        string[] memory _emotions,
        uint256[] memory _emotionScores
    ) external onlyOwner nonReentrant {
        require(bytes(_content).length > 0, "StrategicAgent: content cannot be empty");
        require(_confidence <= 100, "StrategicAgent: confidence must be 0-100");
        require(
            _sentimentScore >= -100 && _sentimentScore <= 100,
            "StrategicAgent: sentiment score must be -100 to +100"
        );
        require(
            _emotions.length == _emotionScores.length,
            "StrategicAgent: emotions and scores arrays must match"
        );

        // Create analysis ID using nonce-based generation for better security
        _analysisIdCounter.increment();
        bytes32 analysisId = keccak256(abi.encodePacked(_content, _analysisIdCounter.current()));

        // Convert sentiment score to uint256 for storage
        uint256 sentimentScore = _sentimentScore >= 0
            ? uint256(_sentimentScore)
            : uint256(-_sentimentScore);

        sentimentHistory[analysisId] = SentimentAnalysis({
            content: _content,
            overallSentiment: sentimentScore,
            confidence: _confidence,
            emotions: _emotions,
            emotionScores: _emotionScores,
            timestamp: block.timestamp
        });

        sentimentIds.push(analysisId);

        // Update metrics
        metrics.totalAnalysesPerformed++;
        metrics.lastActivity = block.timestamp;

        // Check for alerts
        _checkSentimentAlerts(sentimentScore, _confidence);

        // Record for learning if enabled
        if (learningEnabled) {
            _recordSentimentForLearning(_content, sentimentScore, _confidence, _emotions);
        }

        emit SentimentAnalyzed(analysisId, sentimentScore, _confidence, _emotions);
    }

    /**
     * @dev Triggers an alert
     * @param _alertType The type of alert
     * @param _description Alert description
     * @param _severity Alert severity (1-10)
     */
    function triggerAlert(
        string memory _alertType,
        string memory _description,
        uint256 _severity
    ) external onlyOwner {
        require(bytes(_alertType).length > 0, "StrategicAgent: alert type cannot be empty");
        require(_severity >= 1 && _severity <= 10, "StrategicAgent: severity must be 1-10");

        // Check cooldown period
        AlertConfig storage alert = alerts[_alertType];
        if (alert.cooldownPeriod > 0) {
            require(
                block.timestamp >= alert.lastAlert.add(alert.cooldownPeriod),
                "StrategicAgent: alert cooldown period not met"
            );
        }

        alert.lastAlert = block.timestamp;

        emit AlertTriggered(_alertType, _description, _severity, block.timestamp);
    }

    /**
     * @dev Updates performance metrics
     * @param _accuracyScore New accuracy score (0-100)
     * @param _responseTime New average response time in seconds
     */
    function updateMetrics(uint256 _accuracyScore, uint256 _responseTime) external onlyOwner {
        require(_accuracyScore <= 100, "StrategicAgent: accuracy score must be 0-100");

        metrics.accuracyScore = _accuracyScore;
        metrics.responseTime = _responseTime;
        metrics.lastActivity = block.timestamp;
    }

    // View functions

    /**
     * @dev Gets the strategic profile
     * @return The agent's strategic profile
     */
    function getProfile() external view returns (StrategicProfile memory) {
        return profile;
    }

    /**
     * @dev Gets target keywords
     * @return Array of target keywords
     */
    function getTargetKeywords() external view returns (string[] memory) {
        return profile.targetKeywords;
    }

    /**
     * @dev Gets target entities
     * @return Array of target entities
     */
    function getTargetEntities() external view returns (string[] memory) {
        return profile.targetEntities;
    }

    /**
     * @dev Gets platform configurations
     * @return Array of platform names
     */
    function getPlatforms() external view returns (string[] memory) {
        return platformList;
    }

    /**
     * @dev Gets platform configuration
     * @param _platformName The platform name
     * @return The platform configuration
     */
    function getPlatformConfig(
        string memory _platformName
    ) external view returns (PlatformConfig memory) {
        return platforms[_platformName];
    }

    /**
     * @dev Gets trend data
     * @param _keyword The trend keyword
     * @return The trend data
     */
    function getTrend(string memory _keyword) external view returns (TrendData memory) {
        return trends[_keyword];
    }

    /**
     * @dev Gets all trend keywords
     * @return Array of trend keywords
     */
    function getTrendKeywords() external view returns (string[] memory) {
        return trendKeywords;
    }

    /**
     * @dev Gets mention data
     * @param _mentionId The mention ID
     * @return The mention data
     */
    function getMention(bytes32 _mentionId) external view returns (MentionData memory) {
        return mentions[_mentionId];
    }

    /**
     * @dev Gets all mention IDs
     * @return Array of mention IDs
     */
    function getMentionIds() external view returns (bytes32[] memory) {
        return mentionIds;
    }

    /**
     * @dev Gets sentiment analysis
     * @param _analysisId The analysis ID
     * @return The sentiment analysis
     */
    function getSentimentAnalysis(
        bytes32 _analysisId
    ) external view returns (SentimentAnalysis memory) {
        return sentimentHistory[_analysisId];
    }

    /**
     * @dev Gets all sentiment analysis IDs
     * @return Array of sentiment analysis IDs
     */
    function getSentimentIds() external view returns (bytes32[] memory) {
        return sentimentIds;
    }

    /**
     * @dev Gets performance metrics
     * @return The performance metrics
     */
    function getMetrics() external view returns (PerformanceMetrics memory) {
        return metrics;
    }

    /**
     * @dev Gets alert configuration
     * @param _alertType The alert type
     * @return The alert configuration
     */
    function getAlertConfig(string memory _alertType) external view returns (AlertConfig memory) {
        return alerts[_alertType];
    }

    /**
     * @dev Gets all alert types
     * @return Array of alert types
     */
    function getAlertTypes() external view returns (string[] memory) {
        return alertTypes;
    }

    // Internal functions

    /**
     * @dev Checks for trend alerts
     */
    function _checkTrendAlerts(
        string memory _keyword,
        uint256 _mentions,
        uint256 /* _sentimentScore */,
        uint256 _confidence
    ) internal {
        AlertConfig storage alert = alerts["trend"];
        if (!alert.enabled) return;

        // Check if threshold is met and cooldown period has passed
        if (
            _mentions >= alert.threshold &&
            block.timestamp >= alert.lastAlert.add(alert.cooldownPeriod)
        ) {
            string memory description = string(
                abi.encodePacked("Trend detected: ", _keyword, " with high mentions")
            );

            uint256 severity = _confidence > 80 ? 8 : (_confidence > 60 ? 6 : 4);

            emit AlertTriggered("trend", description, severity, block.timestamp);
            alert.lastAlert = block.timestamp;
        }
    }

    /**
     * @dev Checks for mention alerts
     */
    function _checkMentionAlerts(
        string memory _entity,
        uint256 /* _sentimentScore */,
        uint256 _reach,
        uint256 /* _engagement */
    ) internal {
        AlertConfig storage alert = alerts["mention"];
        if (!alert.enabled) return;

        // Check if threshold is met and cooldown period has passed
        if (
            _reach >= alert.threshold &&
            block.timestamp >= alert.lastAlert.add(alert.cooldownPeriod)
        ) {
            string memory description = string(
                abi.encodePacked("High-reach mention of ", _entity, " detected")
            );

            uint256 severity = _reach > 10000 ? 9 : (_reach > 1000 ? 7 : 5);

            emit AlertTriggered("mention", description, severity, block.timestamp);
            alert.lastAlert = block.timestamp;
        }
    }

    /**
     * @dev Checks for sentiment alerts
     */
    function _checkSentimentAlerts(uint256 _sentimentScore, uint256 _confidence) internal {
        AlertConfig storage alert = alerts["sentiment"];
        if (!alert.enabled) return;

        // Check for extreme sentiment (very positive or very negative)
        if (
            (_sentimentScore >= 90 || _sentimentScore <= 10) &&
            _confidence >= alert.threshold &&
            block.timestamp >= alert.lastAlert.add(alert.cooldownPeriod)
        ) {
            string memory description = string(
                abi.encodePacked(
                    "Extreme sentiment detected: ",
                    _sentimentScore >= 90 ? "Very Positive" : "Very Negative"
                )
            );

            uint256 severity = _confidence > 90 ? 9 : 7;

            emit AlertTriggered("sentiment", description, severity, block.timestamp);
            alert.lastAlert = block.timestamp;
        }
    }

    /**
     * @dev Records trend data for learning
     */
    function _recordTrendForLearning(
        string memory _keyword,
        uint256 _mentions,
        uint256 _sentimentScore,
        uint256 _confidence
    ) internal whenLearningEnabled {
        bytes32 dataHash = keccak256(
            abi.encodePacked(_keyword, _mentions, _sentimentScore, _confidence, block.timestamp)
        );

        emit LearningUpdate("trend_detection", dataHash, block.timestamp);
    }

    /**
     * @dev Records mention data for learning
     */
    function _recordMentionForLearning(
        string memory _entity,
        string memory _content,
        string memory _platform,
        uint256 _sentimentScore
    ) internal whenLearningEnabled {
        bytes32 dataHash = keccak256(
            abi.encode(_entity, _content, _platform, _sentimentScore, block.timestamp)
        );

        emit LearningUpdate("mention_detection", dataHash, block.timestamp);
    }

    /**
     * @dev Records sentiment analysis for learning
     */
    function _recordSentimentForLearning(
        string memory _content,
        uint256 _sentimentScore,
        uint256 _confidence,
        string[] memory /* _emotions */
    ) internal whenLearningEnabled {
        bytes32 dataHash = keccak256(
            abi.encodePacked(_content, _sentimentScore, _confidence, block.timestamp)
        );

        emit LearningUpdate("sentiment_analysis", dataHash, block.timestamp);
    }

    /**
     * @dev Withdraws ETH from the contract (only owner)
     * @param amount Amount of ETH to withdraw
     */
    function withdrawETH(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "StrategicAgent: insufficient balance");
        payable(owner()).transfer(amount);
        emit ETHWithdrawn(owner(), amount);
    }

    /**
     * @dev Withdraws all ETH from the contract (only owner)
     */
    function withdrawAllETH() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "StrategicAgent: no ETH to withdraw");
        payable(owner()).transfer(balance);
        emit ETHWithdrawn(owner(), balance);
    }

    /**
     * @dev Allows contract to receive BNB
     */
    receive() external payable {}
}
