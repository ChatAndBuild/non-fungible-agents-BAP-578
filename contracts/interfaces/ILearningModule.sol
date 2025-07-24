// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ILearningModule
 * @dev Interface for learning modules in the BEP007 ecosystem
 */
interface ILearningModule {
    /**
     * @dev Struct representing learning metrics
     */
    struct LearningMetrics {
        uint256 totalInteractions;
        uint256 learningEvents;
        uint256 lastUpdateTimestamp;
        uint256 learningVelocity;
        uint256 confidenceScore;
    }

    /**
     * @dev Struct representing a learning update
     */
    struct LearningUpdate {
        bytes32 previousRoot;
        bytes32 newRoot;
        bytes proof;
        uint256 timestamp;
    }

    /**
     * @dev Emitted when learning is updated
     */
    event LearningUpdated(
        uint256 indexed tokenId,
        bytes32 previousRoot,
        bytes32 newRoot,
        uint256 timestamp
    );

    /**
     * @dev Emitted when a learning milestone is reached
     */
    event LearningMilestone(
        uint256 indexed tokenId,
        string milestone,
        uint256 value,
        uint256 timestamp
    );

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
    ) external view returns (bool);

    /**
     * @dev Gets the current learning metrics for an agent
     * @param tokenId The ID of the agent token
     * @return The learning metrics
     */
    function getLearningMetrics(uint256 tokenId) external view returns (LearningMetrics memory);

    /**
     * @dev Gets the current learning tree root for an agent
     * @param tokenId The ID of the agent token
     * @return The Merkle root of the learning tree
     */
    function getLearningRoot(uint256 tokenId) external view returns (bytes32);
}
