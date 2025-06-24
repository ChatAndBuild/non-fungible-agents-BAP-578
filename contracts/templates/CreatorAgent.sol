// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/ILearningModule.sol";

/**
 * @title CreatorAgent
 * @dev Enhanced template for creator agents with learning capabilities
 *      that serve as personalized brand assistants or digital twins
 */
contract CreatorAgent is Ownable, ReentrancyGuard {
    // The address of the BEP007 token that owns this logic
    address public agentToken;

    // Learning module integration
    address public learningModule;
    bool public learningEnabled;

    // The creator's profile
    struct CreatorProfile {
        string name;
        string bio;
        string niche;
        string[] socialHandles;
        string contentStyle;
        string voiceStyle;
        // Enhanced learning fields
        string[] preferredTopics;
        string[] learningGoals;
        uint256 creativityLevel; // 0-100 scale
    }

    // The creator's profile
    CreatorProfile public profile;

    // The creator's content library
    struct ContentItem {
        uint256 id;
        string contentType; // "post", "article", "video", "audio", etc.
        string title;
        string summary;
        string contentURI;
        uint256 timestamp;
        bool featured;
        // Learning enhancements
        uint256 engagementScore; // Learned from interactions
        string[] tags;
        uint256 performanceRating; // 0-100 based on learning
    }

    // The creator's content library
    mapping(uint256 => ContentItem) public contentLibrary;
    uint256 public contentCount;

    // The creator's audience segments
    struct AudienceSegment {
        uint256 id;
        string name;
        string description;
        string[] interests;
        string communicationStyle;
        // Learning enhancements
        uint256 engagementRate; // Learned metric
        uint256 preferredContentTypes; // Bitmask for content preferences
        uint256 optimalPostingTime; // Learned optimal timing
    }

    // The creator's audience segments
    mapping(uint256 => AudienceSegment) public audienceSegments;
    uint256 public segmentCount;

    // The creator's scheduled content
    struct ScheduledContent {
        uint256 id;
        string contentType;
        string title;
        string summary;
        string contentURI;
        uint256 scheduledTime;
        bool published;
        uint256[] targetSegments;
        // Learning enhancements
        uint256 predictedEngagement; // AI-predicted engagement
        bool optimizedTiming; // Whether timing was AI-optimized
    }

    // The creator's scheduled content
    mapping(uint256 => ScheduledContent) public scheduledContent;
    uint256 public scheduledCount;

    // Learning-specific data structures
    struct ContentPerformance {
        uint256 contentId;
        uint256 views;
        uint256 likes;
        uint256 shares;
        uint256 comments;
        uint256 engagementRate;
        uint256 timestamp;
    }

    mapping(uint256 => ContentPerformance) public contentPerformance;

    // Audience insights from learning
    struct AudienceInsights {
        string[] trendingTopics;
        uint256[] optimalPostingTimes;
        string[] preferredContentFormats;
        uint256 averageEngagementRate;
        uint256 lastUpdated;
    }

    AudienceInsights public audienceInsights;

    // Event emitted when content is published
    event ContentPublished(uint256 indexed contentId, string contentType, string title);

    // Event emitted when a new audience segment is created
    event AudienceSegmentCreated(uint256 indexed segmentId, string name);

    // Event emitted when content is scheduled
    event ContentScheduled(uint256 indexed contentId, uint256 scheduledTime);

    // Learning-specific events
    event LearningInsightGenerated(string insightType, bytes data, uint256 timestamp);
    event ContentPerformanceRecorded(uint256 indexed contentId, uint256 engagementRate);
    event AudienceInsightsUpdated(uint256 timestamp);

    /**
     * @dev Initializes the contract
     * @param _agentToken The address of the BEP007 token
     * @param _name The creator's name
     * @param _bio The creator's bio
     * @param _niche The creator's niche
     * @param _socialHandles The creator's social media handles
     * @param _contentStyle The creator's content style
     * @param _voiceStyle The creator's voice style
     */
    constructor(
        address _agentToken,
        string memory _name,
        string memory _bio,
        string memory _niche,
        string[] memory _socialHandles,
        string memory _contentStyle,
        string memory _voiceStyle
    ) {
        require(_agentToken != address(0), "CreatorAgent: agent token is zero address");

        agentToken = _agentToken;

        profile = CreatorProfile({
            name: _name,
            bio: _bio,
            niche: _niche,
            socialHandles: _socialHandles,
            contentStyle: _contentStyle,
            voiceStyle: _voiceStyle,
            preferredTopics: new string[](0),
            learningGoals: new string[](0),
            creativityLevel: 50 // Default medium creativity
        });

        // Initialize audience insights
        audienceInsights = AudienceInsights({
            trendingTopics: new string[](0),
            optimalPostingTimes: new uint256[](0),
            preferredContentFormats: new string[](0),
            averageEngagementRate: 0,
            lastUpdated: block.timestamp
        });
    }

    /**
     * @dev Modifier to check if the caller is the agent token
     */
    modifier onlyAgentToken() {
        require(msg.sender == agentToken, "CreatorAgent: caller is not agent token");
        _;
    }

    /**
     * @dev Modifier to check if learning is enabled
     */
    modifier whenLearningEnabled() {
        require(
            learningEnabled && learningModule != address(0),
            "CreatorAgent: learning not enabled"
        );
        _;
    }

    /**
     * @dev Enables learning for this agent
     * @param _learningModule The address of the learning module
     */
    function enableLearning(address _learningModule) external onlyOwner {
        require(_learningModule != address(0), "CreatorAgent: learning module is zero address");
        require(!learningEnabled, "CreatorAgent: learning already enabled");

        learningModule = _learningModule;
        learningEnabled = true;
    }

    /**
     * @dev Records an interaction for learning purposes
     * @param interactionType The type of interaction
     * @param success Whether the interaction was successful
     * @param metadata Additional metadata about the interaction
     */
    function recordInteraction(
        string memory interactionType,
        bool success,
        bytes memory metadata
    ) external onlyAgentToken whenLearningEnabled {
        try
            ILearningModule(learningModule).recordInteraction(
                uint256(uint160(address(this))), // Use contract address as token ID
                interactionType,
                success
            )
        {
            emit LearningInsightGenerated(interactionType, metadata, block.timestamp);
        } catch {
            // Silently fail to not break agent functionality
        }
    }

    /**
     * @dev Updates the creator's profile with learning enhancements
     * @param _name The creator's name
     * @param _bio The creator's bio
     * @param _niche The creator's niche
     * @param _socialHandles The creator's social media handles
     * @param _contentStyle The creator's content style
     * @param _voiceStyle The creator's voice style
     * @param _preferredTopics The creator's preferred topics
     * @param _learningGoals The creator's learning goals
     * @param _creativityLevel The creator's creativity level (0-100)
     */
    function updateProfile(
        string memory _name,
        string memory _bio,
        string memory _niche,
        string[] memory _socialHandles,
        string memory _contentStyle,
        string memory _voiceStyle,
        string[] memory _preferredTopics,
        string[] memory _learningGoals,
        uint256 _creativityLevel
    ) external onlyOwner {
        require(_creativityLevel <= 100, "CreatorAgent: creativity level must be 0-100");

        profile = CreatorProfile({
            name: _name,
            bio: _bio,
            niche: _niche,
            socialHandles: _socialHandles,
            contentStyle: _contentStyle,
            voiceStyle: _voiceStyle,
            preferredTopics: _preferredTopics,
            learningGoals: _learningGoals,
            creativityLevel: _creativityLevel
        });

        // Record learning interaction
        if (learningEnabled) {
            this.recordInteraction(
                "profile_update",
                true,
                abi.encode(_preferredTopics, _learningGoals)
            );
        }
    }

    /**
     * @dev Adds a content item to the library with learning enhancements
     * @param _contentType The type of content
     * @param _title The title of the content
     * @param _summary The summary of the content
     * @param _contentURI The URI of the content
     * @param _featured Whether the content is featured
     * @param _tags Tags for the content
     * @return contentId The ID of the new content item
     */
    function addContent(
        string memory _contentType,
        string memory _title,
        string memory _summary,
        string memory _contentURI,
        bool _featured,
        string[] memory _tags
    ) external onlyOwner returns (uint256 contentId) {
        contentCount += 1;
        contentId = contentCount;

        contentLibrary[contentId] = ContentItem({
            id: contentId,
            contentType: _contentType,
            title: _title,
            summary: _summary,
            contentURI: _contentURI,
            timestamp: block.timestamp,
            featured: _featured,
            engagementScore: 0,
            tags: _tags,
            performanceRating: 50 // Default medium performance
        });

        emit ContentPublished(contentId, _contentType, _title);

        // Record learning interaction
        if (learningEnabled) {
            this.recordInteraction("content_creation", true, abi.encode(_contentType, _tags));
        }

        return contentId;
    }

    /**
     * @dev Records content performance for learning
     * @param _contentId The ID of the content
     * @param _views Number of views
     * @param _likes Number of likes
     * @param _shares Number of shares
     * @param _comments Number of comments
     */
    function recordContentPerformance(
        uint256 _contentId,
        uint256 _views,
        uint256 _likes,
        uint256 _shares,
        uint256 _comments
    ) external onlyOwner {
        require(
            _contentId <= contentCount && _contentId > 0,
            "CreatorAgent: content does not exist"
        );

        uint256 engagementRate = 0;
        if (_views > 0) {
            engagementRate = ((_likes + _shares + _comments) * 100) / _views;
        }

        contentPerformance[_contentId] = ContentPerformance({
            contentId: _contentId,
            views: _views,
            likes: _likes,
            shares: _shares,
            comments: _comments,
            engagementRate: engagementRate,
            timestamp: block.timestamp
        });

        // Update content item with learned performance rating
        contentLibrary[_contentId].engagementScore = engagementRate;
        contentLibrary[_contentId].performanceRating = _calculatePerformanceRating(engagementRate);

        emit ContentPerformanceRecorded(_contentId, engagementRate);

        // Record learning interaction
        if (learningEnabled) {
            this.recordInteraction(
                "performance_analysis",
                true,
                abi.encode(_contentId, engagementRate)
            );
        }
    }

    /**
     * @dev Creates an audience segment with learning enhancements
     * @param _name The name of the segment
     * @param _description The description of the segment
     * @param _interests The interests of the segment
     * @param _communicationStyle The communication style for the segment
     * @return segmentId The ID of the new segment
     */
    function createAudienceSegment(
        string memory _name,
        string memory _description,
        string[] memory _interests,
        string memory _communicationStyle
    ) external onlyOwner returns (uint256 segmentId) {
        segmentCount += 1;
        segmentId = segmentCount;

        audienceSegments[segmentId] = AudienceSegment({
            id: segmentId,
            name: _name,
            description: _description,
            interests: _interests,
            communicationStyle: _communicationStyle,
            engagementRate: 0,
            preferredContentTypes: 0,
            optimalPostingTime: 12 * 3600 // Default to noon
        });

        emit AudienceSegmentCreated(segmentId, _name);

        // Record learning interaction
        if (learningEnabled) {
            this.recordInteraction("segment_creation", true, abi.encode(_interests));
        }

        return segmentId;
    }

    /**
     * @dev Updates audience insights based on learning
     * @param _trendingTopics Current trending topics
     * @param _optimalPostingTimes Optimal posting times
     * @param _preferredContentFormats Preferred content formats
     * @param _averageEngagementRate Average engagement rate
     */
    function updateAudienceInsights(
        string[] memory _trendingTopics,
        uint256[] memory _optimalPostingTimes,
        string[] memory _preferredContentFormats,
        uint256 _averageEngagementRate
    ) external onlyOwner {
        audienceInsights = AudienceInsights({
            trendingTopics: _trendingTopics,
            optimalPostingTimes: _optimalPostingTimes,
            preferredContentFormats: _preferredContentFormats,
            averageEngagementRate: _averageEngagementRate,
            lastUpdated: block.timestamp
        });

        emit AudienceInsightsUpdated(block.timestamp);

        // Record learning interaction
        if (learningEnabled) {
            this.recordInteraction("insights_update", true, abi.encode(_averageEngagementRate));
        }
    }

    /**
     * @dev Schedules content with AI optimization
     * @param _contentType The type of content
     * @param _title The title of the content
     * @param _summary The summary of the content
     * @param _contentURI The URI of the content
     * @param _scheduledTime The time to publish the content
     * @param _targetSegments The target audience segments
     * @param _useAIOptimization Whether to use AI optimization
     * @return scheduleId The ID of the scheduled content
     */
    function scheduleContent(
        string memory _contentType,
        string memory _title,
        string memory _summary,
        string memory _contentURI,
        uint256 _scheduledTime,
        uint256[] memory _targetSegments,
        bool _useAIOptimization
    ) external onlyOwner returns (uint256 scheduleId) {
        require(
            _scheduledTime > block.timestamp,
            "CreatorAgent: scheduled time must be in the future"
        );

        scheduledCount += 1;
        scheduleId = scheduledCount;

        uint256 predictedEngagement = _useAIOptimization
            ? _predictEngagement(_contentType, _targetSegments)
            : 0;

        scheduledContent[scheduleId] = ScheduledContent({
            id: scheduleId,
            contentType: _contentType,
            title: _title,
            summary: _summary,
            contentURI: _contentURI,
            scheduledTime: _scheduledTime,
            published: false,
            targetSegments: _targetSegments,
            predictedEngagement: predictedEngagement,
            optimizedTiming: _useAIOptimization
        });

        emit ContentScheduled(scheduleId, _scheduledTime);

        // Record learning interaction
        if (learningEnabled) {
            this.recordInteraction(
                "content_scheduling",
                true,
                abi.encode(_useAIOptimization, predictedEngagement)
            );
        }

        return scheduleId;
    }

    /**
     * @dev Gets learning-enhanced content recommendations
     * @param _segmentId The target audience segment
     * @param _contentType The desired content type
     * @return recommendations Array of recommended content IDs
     */
    function getContentRecommendations(
        uint256 _segmentId,
        string memory _contentType
    ) external view returns (uint256[] memory recommendations) {
        require(
            _segmentId <= segmentCount && _segmentId > 0,
            "CreatorAgent: segment does not exist"
        );

        // Simple recommendation logic based on performance ratings
        uint256[] memory tempRecommendations = new uint256[](contentCount);
        uint256 recommendationCount = 0;

        for (uint256 i = 1; i <= contentCount; i++) {
            ContentItem storage content = contentLibrary[i];
            if (
                keccak256(bytes(content.contentType)) == keccak256(bytes(_contentType)) &&
                content.performanceRating >= 70
            ) {
                tempRecommendations[recommendationCount] = i;
                recommendationCount++;
            }
        }

        // Create properly sized array
        recommendations = new uint256[](recommendationCount);
        for (uint256 i = 0; i < recommendationCount; i++) {
            recommendations[i] = tempRecommendations[i];
        }

        return recommendations;
    }

    /**
     * @dev Gets the creator's learning progress
     * @return metrics The learning metrics if available
     */
    function getLearningProgress()
        external
        view
        returns (ILearningModule.LearningMetrics memory metrics)
    {
        if (learningEnabled && learningModule != address(0)) {
            try
                ILearningModule(learningModule).getLearningMetrics(uint256(uint160(address(this))))
            returns (ILearningModule.LearningMetrics memory _metrics) {
                return _metrics;
            } catch {
                // Return empty metrics if call fails
            }
        }
    }

    /**
     * @dev Internal function to calculate performance rating
     * @param engagementRate The engagement rate
     * @return rating The performance rating (0-100)
     */
    function _calculatePerformanceRating(
        uint256 engagementRate
    ) internal pure returns (uint256 rating) {
        if (engagementRate >= 20) return 100;
        if (engagementRate >= 15) return 90;
        if (engagementRate >= 10) return 80;
        if (engagementRate >= 7) return 70;
        if (engagementRate >= 5) return 60;
        if (engagementRate >= 3) return 50;
        if (engagementRate >= 2) return 40;
        if (engagementRate >= 1) return 30;
        return 20;
    }

    /**
     * @dev Internal function to predict engagement
     * @param contentType The type of content
     * @param targetSegments The target segments
     * @return predicted The predicted engagement rate
     */
    function _predictEngagement(
        string memory contentType,
        uint256[] memory targetSegments
    ) internal view returns (uint256 predicted) {
        // Simple prediction based on historical data
        uint256 totalEngagement = 0;
        uint256 segmentCount = 0;

        for (uint256 i = 0; i < targetSegments.length; i++) {
            if (targetSegments[i] <= segmentCount && targetSegments[i] > 0) {
                totalEngagement += audienceSegments[targetSegments[i]].engagementRate;
                segmentCount++;
            }
        }

        if (segmentCount > 0) {
            predicted = totalEngagement / segmentCount;
        } else {
            predicted = audienceInsights.averageEngagementRate;
        }

        return predicted;
    }

    // Include all original functions with learning enhancements...

    /**
     * @dev Publishes scheduled content with performance tracking
     * @param _scheduleId The ID of the scheduled content
     */
    function publishScheduledContent(uint256 _scheduleId) external onlyAgentToken {
        require(
            _scheduleId <= scheduledCount && _scheduleId > 0,
            "CreatorAgent: scheduled content does not exist"
        );

        ScheduledContent storage content = scheduledContent[_scheduleId];
        require(!content.published, "CreatorAgent: content already published");
        require(
            block.timestamp >= content.scheduledTime,
            "CreatorAgent: scheduled time not reached"
        );

        content.published = true;

        // Add to content library with predicted performance
        contentCount += 1;
        uint256 contentId = contentCount;

        contentLibrary[contentId] = ContentItem({
            id: contentId,
            contentType: content.contentType,
            title: content.title,
            summary: content.summary,
            contentURI: content.contentURI,
            timestamp: block.timestamp,
            featured: false,
            engagementScore: content.predictedEngagement,
            tags: new string[](0),
            performanceRating: _calculatePerformanceRating(content.predictedEngagement)
        });

        emit ContentPublished(contentId, content.contentType, content.title);

        // Record learning interaction
        if (learningEnabled) {
            this.recordInteraction(
                "scheduled_publish",
                true,
                abi.encode(contentId, content.predictedEngagement)
            );
        }
    }

    /**
     * @dev Gets the creator's profile with learning data
     * @return The creator's enhanced profile
     */
    function getProfile() external view returns (CreatorProfile memory) {
        return profile;
    }

    /**
     * @dev Gets audience insights
     * @return The current audience insights
     */
    function getAudienceInsights() external view returns (AudienceInsights memory) {
        return audienceInsights;
    }

    /**
     * @dev Gets content performance data
     * @param _contentId The ID of the content
     * @return The content performance data
     */
    function getContentPerformance(
        uint256 _contentId
    ) external view returns (ContentPerformance memory) {
        require(
            _contentId <= contentCount && _contentId > 0,
            "CreatorAgent: content does not exist"
        );
        return contentPerformance[_contentId];
    }
}
