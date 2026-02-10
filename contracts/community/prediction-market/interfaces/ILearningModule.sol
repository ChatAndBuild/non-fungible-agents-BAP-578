// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ILearningModule {
    struct LearningMetrics {
        uint256 totalInteractions;
        uint256 successfulOutcomes;
        bytes32 learningRoot;       // Merkle root of learning data
        uint256 lastUpdated;
    }

    event LearningUpdated(uint256 indexed tokenId, bytes32 newRoot);
    event InteractionRecorded(uint256 indexed tokenId, uint256 totalInteractions);

    function updateLearning(uint256 tokenId, bytes32 newRoot, bytes calldata proof) external;
    function verifyLearning(uint256 tokenId, bytes32 claim, bytes32[] calldata proof) external view returns (bool);
    function getLearningMetrics(uint256 tokenId) external view returns (LearningMetrics memory);
    function recordInteraction(uint256 tokenId, bool success) external;
}
