// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title CreatorInteractionTypes
 * @dev Library defining interaction types as enums for gas efficiency and type safety
 *      Used by CreatorAgent and CreatorLearningModule contracts
 */
library CreatorInteractionTypes {
    /**
     * @dev Enum defining all possible interaction types for creator agents
     *      Using uint8 values for gas efficiency (1 byte storage vs 32+ bytes for strings)
     */
    enum InteractionType {
        // Content-related interactions (0-9)
        CONTENT_CREATION, // 0 - When new content is created
        CONTENT_PERFORMANCE_UPDATE, // 1 - When content performance metrics are updated
        CONTENT_SCHEDULING, // 2 - When content is scheduled for future publication
        SCHEDULED_PUBLISH, // 3 - When scheduled content is published
        CONTENT_RECOMMENDATION, // 4 - When content recommendations are generated
        VIRAL_CONTENT_DETECTED, // 5 - When content goes viral (exceeds thresholds)
        // Profile & Identity interactions (10-15)
        PROFILE_UPDATE, // 6 - When creator profile is updated
        CREATIVITY_BOOST, // 7 - When creativity score increases significantly
        LEARNING_GOAL_SET, // 8 - When new learning goals are established
        NICHE_OPTIMIZATION, // 9 - When niche-specific optimizations are applied
        BRAND_CONSISTENCY_CHECK, // 10 - When brand consistency is validated
        // Audience-related interactions (16-25)
        AUDIENCE_ANALYSIS, // 11 - When audience behavior is analyzed
        AUDIENCE_SEGMENT_CREATION, // 12 - When new audience segments are created
        AUDIENCE_INSIGHTS_UPDATE, // 13 - When audience insights are updated
        ENGAGEMENT_OPTIMIZATION, // 14 - When engagement strategies are optimized
        TREND_ADAPTATION, // 15 - When content adapts to trending topics
        COMMUNITY_ENGAGEMENT, // 16 - When community interactions occur
        // Strategy & Optimization interactions (26-35)
        STRATEGY_ADAPTATION, // 17 - When content strategy is adapted
        PERFORMANCE_ANALYSIS, // 18 - When performance metrics are analyzed
        PATTERN_RECOGNITION, // 19 - When creative patterns are detected
        TIMING_OPTIMIZATION, // 20 - When posting timing is optimized
        FORMAT_OPTIMIZATION, // 21 - When content format is optimized
        MONETIZATION_OPTIMIZATION, // 22 - When monetization strategies are optimized
        // Analytics & Learning interactions (36-45)
        LEARNING_MILESTONE, // 23 - When learning milestones are achieved
        CONFIDENCE_UPDATE, // 24 - When confidence scores are updated
        VELOCITY_CALCULATION, // 25 - When learning velocity is calculated
        INSIGHTS_GENERATION, // 26 - When AI insights are generated
        FEEDBACK_PROCESSING, // 27 - When feedback is processed and learned from
        // Advanced Creator interactions (46-55)
        COLLABORATION_TRACKING, // 28 - When collaborations are tracked
        CROSS_PLATFORM_SYNC, // 29 - When cross-platform data is synchronized
        // Reserved for future use (56-63)
        RESERVED_1, // 30 - Reserved for future interaction types
        RESERVED_2, // 31 - Reserved for future interaction types
        RESERVED_3, // 32 - Reserved for future interaction types
        RESERVED_4, // 33 - Reserved for future interaction types
        RESERVED_5, // 34 - Reserved for future interaction types
        RESERVED_6 // 35 - Reserved for future interaction types
    }

    /**
     * @dev Categories for grouping interaction types
     */
    enum InteractionCategory {
        CONTENT, // Content-related interactions
        PROFILE, // Profile and identity interactions
        AUDIENCE, // Audience-related interactions
        STRATEGY, // Strategy and optimization interactions
        ANALYTICS, // Analytics and learning interactions
        ADVANCED // Advanced creator interactions
    }

    /**
     * @dev Returns the category for a given interaction type
     * @param interactionType The interaction type to categorize
     * @return The category of the interaction type
     */
    function getCategory(
        InteractionType interactionType
    ) internal pure returns (InteractionCategory) {
        uint8 typeValue = uint8(interactionType);

        if (typeValue <= 5) return InteractionCategory.CONTENT;
        if (typeValue <= 10) return InteractionCategory.PROFILE;
        if (typeValue <= 16) return InteractionCategory.AUDIENCE;
        if (typeValue <= 22) return InteractionCategory.STRATEGY;
        if (typeValue <= 27) return InteractionCategory.ANALYTICS;
        return InteractionCategory.ADVANCED;
    }

    /**
     * @dev Converts interaction type enum to string (for debugging/logging)
     * @param interactionType The interaction type to convert
     * @return The string representation of the interaction type
     */
    function toString(InteractionType interactionType) internal pure returns (string memory) {
        if (interactionType == InteractionType.CONTENT_CREATION) return "content_creation";
        if (interactionType == InteractionType.CONTENT_PERFORMANCE_UPDATE)
            return "content_performance_update";
        if (interactionType == InteractionType.CONTENT_SCHEDULING) return "content_scheduling";
        if (interactionType == InteractionType.SCHEDULED_PUBLISH) return "scheduled_publish";
        if (interactionType == InteractionType.CONTENT_RECOMMENDATION)
            return "content_recommendation";
        if (interactionType == InteractionType.VIRAL_CONTENT_DETECTED)
            return "viral_content_detected";

        if (interactionType == InteractionType.PROFILE_UPDATE) return "profile_update";
        if (interactionType == InteractionType.CREATIVITY_BOOST) return "creativity_boost";
        if (interactionType == InteractionType.LEARNING_GOAL_SET) return "learning_goal_set";
        if (interactionType == InteractionType.NICHE_OPTIMIZATION) return "niche_optimization";
        if (interactionType == InteractionType.BRAND_CONSISTENCY_CHECK)
            return "brand_consistency_check";

        if (interactionType == InteractionType.AUDIENCE_ANALYSIS) return "audience_analysis";
        if (interactionType == InteractionType.AUDIENCE_SEGMENT_CREATION)
            return "audience_segment_creation";
        if (interactionType == InteractionType.AUDIENCE_INSIGHTS_UPDATE)
            return "audience_insights_update";
        if (interactionType == InteractionType.ENGAGEMENT_OPTIMIZATION)
            return "engagement_optimization";
        if (interactionType == InteractionType.TREND_ADAPTATION) return "trend_adaptation";
        if (interactionType == InteractionType.COMMUNITY_ENGAGEMENT) return "community_engagement";

        if (interactionType == InteractionType.STRATEGY_ADAPTATION) return "strategy_adaptation";
        if (interactionType == InteractionType.PERFORMANCE_ANALYSIS) return "performance_analysis";
        if (interactionType == InteractionType.PATTERN_RECOGNITION) return "pattern_recognition";
        if (interactionType == InteractionType.TIMING_OPTIMIZATION) return "timing_optimization";
        if (interactionType == InteractionType.FORMAT_OPTIMIZATION) return "format_optimization";
        if (interactionType == InteractionType.MONETIZATION_OPTIMIZATION)
            return "monetization_optimization";

        if (interactionType == InteractionType.LEARNING_MILESTONE) return "learning_milestone";
        if (interactionType == InteractionType.CONFIDENCE_UPDATE) return "confidence_update";
        if (interactionType == InteractionType.VELOCITY_CALCULATION) return "velocity_calculation";
        if (interactionType == InteractionType.INSIGHTS_GENERATION) return "insights_generation";
        if (interactionType == InteractionType.FEEDBACK_PROCESSING) return "feedback_processing";

        if (interactionType == InteractionType.COLLABORATION_TRACKING)
            return "collaboration_tracking";
        if (interactionType == InteractionType.CROSS_PLATFORM_SYNC) return "cross_platform_sync";

        return "unknown";
    }

    /**
     * @dev Converts string to interaction type enum (for backward compatibility)
     * @param interactionString The string representation of the interaction type
     * @return The corresponding interaction type enum
     */
    function fromString(string memory interactionString) internal pure returns (InteractionType) {
        bytes32 stringHash = keccak256(abi.encodePacked(interactionString));

        if (stringHash == keccak256("content_creation")) return InteractionType.CONTENT_CREATION;
        if (stringHash == keccak256("content_performance_update"))
            return InteractionType.CONTENT_PERFORMANCE_UPDATE;
        if (stringHash == keccak256("content_scheduling"))
            return InteractionType.CONTENT_SCHEDULING;
        if (stringHash == keccak256("scheduled_publish")) return InteractionType.SCHEDULED_PUBLISH;
        if (stringHash == keccak256("content_recommendation"))
            return InteractionType.CONTENT_RECOMMENDATION;
        if (stringHash == keccak256("viral_content_detected"))
            return InteractionType.VIRAL_CONTENT_DETECTED;

        if (stringHash == keccak256("profile_update")) return InteractionType.PROFILE_UPDATE;
        if (stringHash == keccak256("creativity_boost")) return InteractionType.CREATIVITY_BOOST;
        if (stringHash == keccak256("learning_goal_set")) return InteractionType.LEARNING_GOAL_SET;
        if (stringHash == keccak256("niche_optimization"))
            return InteractionType.NICHE_OPTIMIZATION;
        if (stringHash == keccak256("brand_consistency_check"))
            return InteractionType.BRAND_CONSISTENCY_CHECK;

        if (stringHash == keccak256("audience_analysis")) return InteractionType.AUDIENCE_ANALYSIS;
        if (stringHash == keccak256("audience_segment_creation"))
            return InteractionType.AUDIENCE_SEGMENT_CREATION;
        if (stringHash == keccak256("audience_insights_update"))
            return InteractionType.AUDIENCE_INSIGHTS_UPDATE;
        if (stringHash == keccak256("engagement_optimization"))
            return InteractionType.ENGAGEMENT_OPTIMIZATION;
        if (stringHash == keccak256("trend_adaptation")) return InteractionType.TREND_ADAPTATION;
        if (stringHash == keccak256("community_engagement"))
            return InteractionType.COMMUNITY_ENGAGEMENT;

        if (stringHash == keccak256("strategy_adaptation"))
            return InteractionType.STRATEGY_ADAPTATION;
        if (stringHash == keccak256("performance_analysis"))
            return InteractionType.PERFORMANCE_ANALYSIS;
        if (stringHash == keccak256("pattern_recognition"))
            return InteractionType.PATTERN_RECOGNITION;
        if (stringHash == keccak256("timing_optimization"))
            return InteractionType.TIMING_OPTIMIZATION;
        if (stringHash == keccak256("format_optimization"))
            return InteractionType.FORMAT_OPTIMIZATION;
        if (stringHash == keccak256("monetization_optimization"))
            return InteractionType.MONETIZATION_OPTIMIZATION;

        if (stringHash == keccak256("learning_milestone"))
            return InteractionType.LEARNING_MILESTONE;
        if (stringHash == keccak256("confidence_update")) return InteractionType.CONFIDENCE_UPDATE;
        if (stringHash == keccak256("velocity_calculation"))
            return InteractionType.VELOCITY_CALCULATION;
        if (stringHash == keccak256("insights_generation"))
            return InteractionType.INSIGHTS_GENERATION;
        if (stringHash == keccak256("feedback_processing"))
            return InteractionType.FEEDBACK_PROCESSING;

        if (stringHash == keccak256("collaboration_tracking"))
            return InteractionType.COLLABORATION_TRACKING;
        if (stringHash == keccak256("cross_platform_sync"))
            return InteractionType.CROSS_PLATFORM_SYNC;

        // For backward compatibility with existing string-based interactions
        if (stringHash == keccak256("insights_update"))
            return InteractionType.AUDIENCE_INSIGHTS_UPDATE;

        revert("CreatorInteractionTypes: unknown interaction type");
    }

    /**
     * @dev Checks if an interaction type is content-related
     * @param interactionType The interaction type to check
     * @return True if the interaction type is content-related
     */
    function isContentRelated(InteractionType interactionType) internal pure returns (bool) {
        return getCategory(interactionType) == InteractionCategory.CONTENT;
    }

    /**
     * @dev Checks if an interaction type is audience-related
     * @param interactionType The interaction type to check
     * @return True if the interaction type is audience-related
     */
    function isAudienceRelated(InteractionType interactionType) internal pure returns (bool) {
        return getCategory(interactionType) == InteractionCategory.AUDIENCE;
    }

    /**
     * @dev Checks if an interaction type is learning-related
     * @param interactionType The interaction type to check
     * @return True if the interaction type is learning-related
     */
    function isLearningRelated(InteractionType interactionType) internal pure returns (bool) {
        InteractionCategory category = getCategory(interactionType);
        return
            category == InteractionCategory.ANALYTICS || category == InteractionCategory.STRATEGY;
    }

    /**
     * @dev Gets the gas cost weight for different interaction types
     * @param interactionType The interaction type
     * @return The relative gas cost weight (1-5 scale)
     */
    function getGasCostWeight(InteractionType interactionType) internal pure returns (uint8) {
        InteractionCategory category = getCategory(interactionType);

        if (category == InteractionCategory.CONTENT) return 3; // Medium cost
        if (category == InteractionCategory.PROFILE) return 2; // Low cost
        if (category == InteractionCategory.AUDIENCE) return 4; // High cost
        if (category == InteractionCategory.STRATEGY) return 5; // Very high cost
        if (category == InteractionCategory.ANALYTICS) return 3; // Medium cost
        if (category == InteractionCategory.ADVANCED) return 4; // High cost

        return 1; // Default low cost
    }
}
