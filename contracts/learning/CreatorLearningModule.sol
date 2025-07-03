// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import "../interfaces/ICreatorLearningModule.sol";
import "../libraries/CreatorInteractionTypes.sol";
import "../BEP007.sol";

/**
 * @title CreatorLearningModule
 * @dev Specialized learning module for CreatorAgent templates
 *      Focuses on content performance, audience engagement, and creative optimization
 */
contract CreatorLearningModule is
    ICreatorLearningModule,
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using MerkleProofUpgradeable for bytes32[];

    // BEP007 token contract
    BEP007 public bep007Token;

    // Creator-specific learning data structures
    struct CreatorLearningMetrics {
        uint256 totalInteractions;
        uint256 learningEvents;
        uint256 lastUpdateTimestamp;
        uint256 learningVelocity;
        uint256 confidenceScore;
        // Creator-specific metrics
        uint256 contentCreationCount;
        uint256 averageEngagementRate;
        uint256 audienceGrowthRate;
        uint256 creativityScore;
        uint256 trendAdaptationScore;
        uint256 lastContentTimestamp;
    }

    struct Interaction {
        CreatorInteractionTypes.InteractionType interactionType;
        bool success;
        bytes32 metadata;
    }

    struct ContentLearningData {
        string contentType;
        uint256 engagementRate;
        uint256 timestamp;
        string[] tags;
        uint256 performanceScore;
        bool viral; // Content that exceeded expected performance
    }

    struct AudienceLearningData {
        uint256 segmentId;
        uint256 engagementRate;
        uint256 growthRate;
        string[] preferredContentTypes;
        uint256[] optimalPostingTimes;
        uint256 lastUpdated;
    }

    struct CreativePattern {
        string patternType; // "high_engagement", "viral_content", "audience_growth"
        bytes32 patternHash;
        uint256 successRate;
        uint256 occurrenceCount;
        uint256 lastSeen;
    }

    // Mapping from token ID to learning tree root
    mapping(uint256 => bytes32) private _learningRoots;

    mapping(uint256 => mapping(uint256 => Interaction)) public interactions;

    // Mapping from token ID to creator learning metrics
    mapping(uint256 => CreatorLearningMetrics) private _creatorMetrics;

    // Mapping from token ID to learning enabled status
    mapping(uint256 => bool) private _learningEnabled;

    // Mapping from token ID to authorized updaters
    mapping(uint256 => mapping(address => bool)) private _authorizedUpdaters;

    // Creator-specific learning data
    mapping(uint256 => mapping(uint256 => ContentLearningData)) private _contentLearningData;
    mapping(uint256 => uint256) private _contentLearningCount;

    mapping(uint256 => mapping(uint256 => AudienceLearningData)) private _audienceLearningData;
    mapping(uint256 => uint256) private _audienceLearningCount;

    mapping(uint256 => mapping(bytes32 => CreativePattern)) private _creativePatterns;
    mapping(uint256 => bytes32[]) private _patternHashes;

    // Learning thresholds and constants
    uint256 public constant VIRAL_THRESHOLD = 500; // 5x average engagement
    uint256 public constant HIGH_ENGAGEMENT_THRESHOLD = 150; // 1.5x average
    uint256 public constant CREATIVITY_BOOST_THRESHOLD = 80; // 80% creativity score
    uint256 public constant TREND_ADAPTATION_THRESHOLD = 70; // 70% trend adaptation

    // Milestones specific to creators
    uint256 public constant MILESTONE_CONTENT_10 = 10;
    uint256 public constant MILESTONE_CONTENT_100 = 100;
    uint256 public constant MILESTONE_VIRAL_CONTENT = 1;
    uint256 public constant MILESTONE_HIGH_CREATIVITY = 80;
    uint256 public constant MILESTONE_TREND_MASTER = 90;

    // Maximum learning updates per day
    uint256 public constant MAX_UPDATES_PER_DAY = 100; // Higher for creators
    mapping(uint256 => mapping(uint256 => uint256)) private _dailyUpdateCounts;

    // Events specific to creator learning
    event ContentLearningRecorded(
        uint256 indexed tokenId,
        uint256 indexed contentId,
        string contentType,
        uint256 engagementRate,
        bool viral
    );

    event AudienceLearningUpdated(
        uint256 indexed tokenId,
        uint256 indexed segmentId,
        uint256 engagementRate,
        uint256 growthRate
    );

    event CreativePatternDetected(
        uint256 indexed tokenId,
        string patternType,
        bytes32 patternHash,
        uint256 successRate
    );

    event CreatorMilestoneAchieved(
        uint256 indexed tokenId,
        string milestone,
        uint256 value,
        uint256 timestamp
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
            "CreatorLearningModule: not authorized"
        );
        _;
    }

    /**
     * @dev Modifier to check if learning is enabled for the agent
     */
    modifier whenLearningEnabled(uint256 tokenId) {
        require(_learningEnabled[tokenId], "CreatorLearningModule: learning not enabled");
        _;
    }

    /**
     * @dev Initializes the contract
     * @param _bep007Token The address of the BEP007 token contract
     */
    function initialize(address payable _bep007Token) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();

        require(_bep007Token != address(0), "CreatorLearningModule: token is zero address");
        bep007Token = BEP007(_bep007Token);
    }

    /**
     * @dev Enables learning for a creator agent
     * @param tokenId The ID of the agent token
     * @param initialRoot The initial learning tree root
     */
    function enableCreatorLearning(uint256 tokenId, bytes32 initialRoot) external {
        address owner = bep007Token.ownerOf(tokenId);
        require(msg.sender == owner, "CreatorLearningModule: not token owner");
        require(!_learningEnabled[tokenId], "CreatorLearningModule: already enabled");

        _learningEnabled[tokenId] = true;
        _learningRoots[tokenId] = initialRoot;

        // Initialize creator-specific learning metrics
        _creatorMetrics[tokenId] = CreatorLearningMetrics({
            totalInteractions: 0,
            learningEvents: 0,
            lastUpdateTimestamp: block.timestamp,
            learningVelocity: 0,
            confidenceScore: 0,
            contentCreationCount: 0,
            averageEngagementRate: 0,
            audienceGrowthRate: 0,
            creativityScore: 50, // Start with medium creativity
            trendAdaptationScore: 50, // Start with medium trend adaptation
            lastContentTimestamp: 0
        });

        emit LearningUpdated(tokenId, bytes32(0), initialRoot, block.timestamp);
    }

    /**
     * @dev Records content creation and performance learning
     * @param tokenId The ID of the agent token
     * @param contentId The ID of the content
     * @param contentType The type of content
     * @param engagementRate The engagement rate achieved
     * @param tags Content tags for pattern recognition
     */
    function recordContentLearning(
        uint256 tokenId,
        uint256 contentId,
        string calldata contentType,
        uint256 engagementRate,
        string[] calldata tags
    ) external onlyAuthorized(tokenId) whenLearningEnabled(tokenId) {
        CreatorLearningMetrics storage metrics = _creatorMetrics[tokenId];

        // Update content creation count
        if (engagementRate == 0) {
            metrics.contentCreationCount++;
        }
        metrics.lastContentTimestamp = block.timestamp;

        // Calculate if content is viral or high-performing
        bool isViral = engagementRate >= (metrics.averageEngagementRate * VIRAL_THRESHOLD) / 100;
        bool isHighEngagement = engagementRate >=
            (metrics.averageEngagementRate * HIGH_ENGAGEMENT_THRESHOLD) / 100;

        // Update average engagement rate
        if (metrics.contentCreationCount == 1) {
            metrics.averageEngagementRate = engagementRate;
        } else {
            metrics.averageEngagementRate =
                (metrics.averageEngagementRate *
                    (metrics.contentCreationCount - 1) +
                    engagementRate) /
                metrics.contentCreationCount;
        }

        // Store content learning data
        uint256 learningId = _contentLearningCount[tokenId]++;
        _contentLearningData[tokenId][learningId] = ContentLearningData({
            contentType: contentType,
            engagementRate: engagementRate,
            timestamp: block.timestamp,
            tags: tags,
            performanceScore: _calculatePerformanceScore(
                engagementRate,
                metrics.averageEngagementRate
            ),
            viral: isViral
        });

        // Update creativity score based on content variety and performance
        _updateCreativityScore(tokenId, engagementRate);

        // Detect and record creative patterns
        _detectCreativePatterns(tokenId, contentType, tags, isHighEngagement);

        // Check for content milestones
        _checkContentMilestones(tokenId, metrics, isViral);

        emit ContentLearningRecorded(tokenId, contentId, contentType, engagementRate, isViral);

        // Record as general interaction
        _recordGeneralInteraction(
            tokenId,
            CreatorInteractionTypes.InteractionType.CONTENT_CREATION,
            true,
            bytes32(contentId)
        );
    }

    /**
     * @dev Records audience segment learning data
     * @param tokenId The ID of the agent token
     * @param segmentId The ID of the audience segment
     * @param engagementRate Current engagement rate for the segment
     * @param growthRate Growth rate of the segment
     * @param preferredContentTypes Preferred content types
     * @param optimalPostingTimes Optimal posting times
     */
    function recordAudienceLearning(
        uint256 tokenId,
        uint256 segmentId,
        uint256 engagementRate,
        uint256 growthRate,
        string[] calldata preferredContentTypes,
        uint256[] calldata optimalPostingTimes
    ) external onlyAuthorized(tokenId) whenLearningEnabled(tokenId) {
        CreatorLearningMetrics storage metrics = _creatorMetrics[tokenId];

        // Update audience growth rate
        if (metrics.audienceGrowthRate == 0) {
            metrics.audienceGrowthRate = growthRate;
        } else {
            metrics.audienceGrowthRate = (metrics.audienceGrowthRate + growthRate) / 2;
        }

        // Store audience learning data
        uint256 learningId = _audienceLearningCount[tokenId]++;
        _audienceLearningData[tokenId][learningId] = AudienceLearningData({
            segmentId: segmentId,
            engagementRate: engagementRate,
            growthRate: growthRate,
            preferredContentTypes: preferredContentTypes,
            optimalPostingTimes: optimalPostingTimes,
            lastUpdated: block.timestamp
        });

        // Update trend adaptation score based on audience response
        _updateTrendAdaptationScore(tokenId, engagementRate, growthRate);

        emit AudienceLearningUpdated(tokenId, segmentId, engagementRate, growthRate);

        // Record as general interaction
        _recordGeneralInteraction(
            tokenId,
            CreatorInteractionTypes.InteractionType.AUDIENCE_ANALYSIS,
            true,
            bytes32(segmentId)
        );
    }

    /**
     * @dev Records an interaction for learning metrics (base interface implementation)
     * @param tokenId The ID of the agent token
     * @param interactionType The type of interaction (string)
     * @param success Whether the interaction was successful
     * @param metadata Additional metadata about the interaction
     */
    function recordInteraction(
        uint256 tokenId,
        CreatorInteractionTypes.InteractionType interactionType,
        bool success,
        bytes32 metadata
    ) external onlyAuthorized(tokenId) whenLearningEnabled(tokenId) {
        _recordGeneralInteraction(tokenId, interactionType, success, metadata);
    }

    /**
     * @dev Records an interaction for learning metrics (string-based, backward compatibility)
     * @param tokenId The ID of the agent token
     * @param interactionType The type of interaction (string)
     * @param success Whether the interaction was successful
     */
    function recordInteraction(
        uint256 tokenId,
        string calldata interactionType,
        bool success
    ) external onlyAuthorized(tokenId) whenLearningEnabled(tokenId) {
        _recordGeneralInteraction(
            tokenId,
            CreatorInteractionTypes.fromString(interactionType),
            success,
            bytes32(0)
        );
    }

    /**
     * @dev Gets creator-specific learning metrics
     * @param tokenId The ID of the agent token
     * @return The creator learning metrics
     */
    function getCreatorLearningMetrics(
        uint256 tokenId
    ) external view returns (CreatorLearningMetrics memory) {
        return _creatorMetrics[tokenId];
    }

    /**
     * @dev Gets content learning insights
     * @param tokenId The ID of the agent token
     * @param limit Maximum number of insights to return
     * @return Array of content learning data
     */
    function getContentLearningInsights(
        uint256 tokenId,
        uint256 limit
    ) external view returns (ContentLearningData[] memory) {
        uint256 count = _contentLearningCount[tokenId];
        uint256 returnCount = count > limit ? limit : count;

        ContentLearningData[] memory insights = new ContentLearningData[](returnCount);

        for (uint256 i = 0; i < returnCount; i++) {
            insights[i] = _contentLearningData[tokenId][count - 1 - i]; // Most recent first
        }

        return insights;
    }

    /**
     * @dev Gets detected creative patterns
     * @param tokenId The ID of the agent token
     * @return hashes Array of pattern hashes
     * @return patterns Array of creative pattern data
     */
    function getCreativePatterns(
        uint256 tokenId
    ) external view returns (bytes32[] memory hashes, CreativePattern[] memory patterns) {
        bytes32[] memory tokenPatterns = _patternHashes[tokenId];
        patterns = new CreativePattern[](tokenPatterns.length);

        for (uint256 i = 0; i < tokenPatterns.length; i++) {
            patterns[i] = _creativePatterns[tokenId][tokenPatterns[i]];
        }

        return (tokenPatterns, patterns);
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
     * @dev Gets the current learning metrics for an agent (ICreatorLearningModule interface)
     * @param tokenId The ID of the agent token
     * @return The learning metrics
     */
    function getLearningMetrics(
        uint256 tokenId
    ) external view override returns (LearningMetrics memory) {
        CreatorLearningMetrics memory creatorMetrics = _creatorMetrics[tokenId];

        return
            LearningMetrics({
                totalInteractions: creatorMetrics.totalInteractions,
                learningEvents: creatorMetrics.learningEvents,
                lastUpdateTimestamp: creatorMetrics.lastUpdateTimestamp,
                learningVelocity: creatorMetrics.learningVelocity,
                confidenceScore: creatorMetrics.confidenceScore
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
        return "1.0.0-creator";
    }

    /**
     * @dev Authorizes an address to update learning for an agent
     * @param tokenId The ID of the agent token
     * @param updater The address to authorize
     * @param authorized Whether to authorize or revoke
     */
    function setAuthorizedUpdater(uint256 tokenId, address updater, bool authorized) external {
        address owner = bep007Token.ownerOf(tokenId);
        require(msg.sender == owner, "CreatorLearningModule: not token owner");

        _authorizedUpdaters[tokenId][updater] = authorized;
    }

    /**
     * @dev Internal function to record general interactions
     */
    function _recordGeneralInteraction(
        uint256 tokenId,
        CreatorInteractionTypes.InteractionType interactionType,
        bool success,
        bytes32 metadata
    ) internal {
        CreatorLearningMetrics storage metrics = _creatorMetrics[tokenId];
        metrics.totalInteractions++;

        interactions[tokenId][metrics.totalInteractions] = Interaction({
            interactionType: interactionType,
            success: success,
            metadata: metadata
        });

        // Enhanced processing based on interaction type
        if (CreatorInteractionTypes.isContentRelated(interactionType)) {
            _processContentInteraction(tokenId, interactionType, success);
        } else if (CreatorInteractionTypes.isAudienceRelated(interactionType)) {
            _processAudienceInteraction(tokenId, interactionType, success);
        } else if (CreatorInteractionTypes.isLearningRelated(interactionType)) {
            _processLearningInteraction(tokenId, interactionType, success);
        }

        // Update confidence score based on success rate and interaction weight
        uint8 weight = CreatorInteractionTypes.getGasCostWeight(interactionType);
        if (success) {
            uint256 boost = (weight * 1e16) / 5; // Scale weight to confidence boost
            metrics.confidenceScore = _updateConfidence(metrics.confidenceScore + boost, true);
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
     * @dev Internal function to update creativity score
     */
    function _updateCreativityScore(uint256 tokenId, uint256 engagementRate) internal {
        CreatorLearningMetrics storage metrics = _creatorMetrics[tokenId];

        // Boost creativity for high-performing content
        if (engagementRate > metrics.averageEngagementRate) {
            uint256 boost = ((engagementRate - metrics.averageEngagementRate) * 10) /
                metrics.averageEngagementRate;
            metrics.creativityScore = _capScore(metrics.creativityScore + boost, 100);
        }

        // TODO: Add content type variety bonus
        // This would require tracking content type history
    }

    /**
     * @dev Internal function to update trend adaptation score
     */
    function _updateTrendAdaptationScore(
        uint256 tokenId,
        uint256 engagementRate,
        uint256 growthRate
    ) internal {
        CreatorLearningMetrics storage metrics = _creatorMetrics[tokenId];

        // Boost trend adaptation for growing engagement and audience
        if (engagementRate > metrics.averageEngagementRate && growthRate > 0) {
            uint256 boost = (growthRate * 5) / 100; // 5% of growth rate
            metrics.trendAdaptationScore = _capScore(metrics.trendAdaptationScore + boost, 100);
        }
    }

    /**
     * @dev Internal function to detect creative patterns
     */
    function _detectCreativePatterns(
        uint256 tokenId,
        string calldata contentType,
        string[] calldata tags,
        bool isHighEngagement
    ) internal {
        if (isHighEngagement) {
            // Create pattern hash from content type and concatenated tags
            bytes memory tagsBytes = "";
            for (uint256 i = 0; i < tags.length; i++) {
                tagsBytes = abi.encodePacked(tagsBytes, tags[i]);
            }
            bytes32 patternHash = keccak256(abi.encodePacked(contentType, tagsBytes));

            CreativePattern storage pattern = _creativePatterns[tokenId][patternHash];

            if (pattern.occurrenceCount == 0) {
                // New pattern
                pattern.patternType = "high_engagement";
                pattern.patternHash = patternHash;
                pattern.successRate = 100;
                pattern.occurrenceCount = 1;
                pattern.lastSeen = block.timestamp;

                _patternHashes[tokenId].push(patternHash);

                emit CreativePatternDetected(tokenId, "high_engagement", patternHash, 100);
            } else {
                // Update existing pattern
                pattern.occurrenceCount++;
                pattern.lastSeen = block.timestamp;
                // Success rate remains high since we only record successful patterns here
            }
        }
    }

    /**
     * @dev Internal function to check content milestones
     */
    function _checkContentMilestones(
        uint256 tokenId,
        CreatorLearningMetrics memory metrics,
        bool isViral
    ) internal {
        if (metrics.contentCreationCount == MILESTONE_CONTENT_10) {
            emit CreatorMilestoneAchieved(tokenId, "content_creator_10", 10, block.timestamp);
        } else if (metrics.contentCreationCount == MILESTONE_CONTENT_100) {
            emit CreatorMilestoneAchieved(tokenId, "content_creator_100", 100, block.timestamp);
        }

        if (isViral) {
            emit CreatorMilestoneAchieved(tokenId, "viral_content", 1, block.timestamp);
        }

        if (metrics.creativityScore >= MILESTONE_HIGH_CREATIVITY) {
            emit CreatorMilestoneAchieved(
                tokenId,
                "high_creativity",
                metrics.creativityScore,
                block.timestamp
            );
        }

        if (metrics.trendAdaptationScore >= MILESTONE_TREND_MASTER) {
            emit CreatorMilestoneAchieved(
                tokenId,
                "trend_master",
                metrics.trendAdaptationScore,
                block.timestamp
            );
        }
    }

    /**
     * @dev Internal function to calculate performance score
     */
    function _calculatePerformanceScore(
        uint256 engagementRate,
        uint256 averageEngagementRate
    ) internal pure returns (uint256) {
        if (averageEngagementRate == 0) return 50; // Default score

        uint256 ratio = (engagementRate * 100) / averageEngagementRate;

        if (ratio >= 500) return 100; // 5x average = perfect score
        if (ratio >= 200) return 90; // 2x average = excellent
        if (ratio >= 150) return 80; // 1.5x average = very good
        if (ratio >= 100) return 70; // Average = good
        if (ratio >= 75) return 60; // 0.75x average = fair
        if (ratio >= 50) return 40; // 0.5x average = poor
        return 20; // Below 0.5x average = very poor
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
     * @dev Internal function to process content-related interactions
     */
    function _processContentInteraction(
        uint256 tokenId,
        CreatorInteractionTypes.InteractionType interactionType,
        bool success
    ) internal {
        CreatorLearningMetrics storage metrics = _creatorMetrics[tokenId];

        if (interactionType == CreatorInteractionTypes.InteractionType.CONTENT_CREATION) {
            if (success) {
                metrics.creativityScore = _capScore(metrics.creativityScore + 1, 100);
            }
        } else if (
            interactionType == CreatorInteractionTypes.InteractionType.VIRAL_CONTENT_DETECTED
        ) {
            if (success) {
                metrics.creativityScore = _capScore(metrics.creativityScore + 5, 100);
                metrics.trendAdaptationScore = _capScore(metrics.trendAdaptationScore + 3, 100);
            }
        }
    }

    /**
     * @dev Internal function to process audience-related interactions
     */
    function _processAudienceInteraction(
        uint256 tokenId,
        CreatorInteractionTypes.InteractionType interactionType,
        bool success
    ) internal {
        CreatorLearningMetrics storage metrics = _creatorMetrics[tokenId];

        if (interactionType == CreatorInteractionTypes.InteractionType.AUDIENCE_ANALYSIS) {
            if (success) {
                metrics.trendAdaptationScore = _capScore(metrics.trendAdaptationScore + 2, 100);
            }
        } else if (
            interactionType == CreatorInteractionTypes.InteractionType.ENGAGEMENT_OPTIMIZATION
        ) {
            if (success) {
                metrics.trendAdaptationScore = _capScore(metrics.trendAdaptationScore + 3, 100);
            }
        }
    }

    /**
     * @dev Internal function to process learning-related interactions
     */
    function _processLearningInteraction(
        uint256 tokenId,
        CreatorInteractionTypes.InteractionType interactionType,
        bool success
    ) internal {
        CreatorLearningMetrics storage metrics = _creatorMetrics[tokenId];

        if (interactionType == CreatorInteractionTypes.InteractionType.LEARNING_MILESTONE) {
            if (success) {
                metrics.confidenceScore = _capScore(metrics.confidenceScore + 5e16, 1e18); // 5% boost
            }
        } else if (interactionType == CreatorInteractionTypes.InteractionType.PATTERN_RECOGNITION) {
            if (success) {
                metrics.creativityScore = _capScore(metrics.creativityScore + 2, 100);
                metrics.trendAdaptationScore = _capScore(metrics.trendAdaptationScore + 2, 100);
            }
        }
    }

    /**
     * @dev Internal function to cap scores at maximum value
     */
    function _capScore(uint256 score, uint256 max) internal pure returns (uint256) {
        return score > max ? max : score;
    }

    /**
     * @dev Disables learning for an agent (emergency function)
     * @param tokenId The ID of the agent token
     */
    function disableLearning(uint256 tokenId) external {
        address owner = bep007Token.ownerOf(tokenId);
        require(msg.sender == owner, "CreatorLearningModule: not token owner");

        _learningEnabled[tokenId] = false;
    }
}
