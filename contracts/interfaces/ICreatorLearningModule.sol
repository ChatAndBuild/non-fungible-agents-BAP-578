// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ILearningModule.sol";
import "../libraries/CreatorInteractionTypes.sol";

/**
 * @title ILearningModule
 * @dev Interface for learning modules in the BEP007 ecosystem
 */
interface ICreatorLearningModule is ILearningModule {
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
    ) external;

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
    ) external;

    /**
     * @dev Records an interaction for learning metrics (enum-based)
     * @param tokenId The ID of the agent token
     * @param interactionType The type of interaction (enum)
     * @param success Whether the interaction was successful
     * @param metadata Additional metadata about the interaction
     */
    function recordInteraction(
        uint256 tokenId,
        CreatorInteractionTypes.InteractionType interactionType,
        bool success,
        bytes32 metadata
    ) external;
}
