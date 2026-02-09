// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

/// @title INFA1LearningModules - NFA-1 Learning Module Registry Extension
/// @notice Optional extension for pluggable learning strategies and on-chain verification
/// @dev Allows implementations to support multiple learning approaches:
///      - RAG (Retrieval-Augmented Generation)
///      - Fine-tuning
///      - Reinforcement Learning
///      - Hybrid approaches
///
///      This extension adds three capabilities beyond core learning (INFA1Core.updateLearning):
///      1. Module Registry: Track which learning modules are active for an agent
///      2. Learning Verification: On-chain Merkle proof verification of learning claims
///      3. Learning Metrics: Quantitative tracking of learning progress
///
///      Designed for: Merkle proof-based learning verification (BAP-578 ILearningModule)
interface INFA1LearningModules {

    // ======================== STRUCTS ========================

    /// @notice A registered learning module
    struct LearningModule {
        address moduleAddress;    // Address of the learning module contract
        string moduleType;        // "rag", "finetune", "rl", "hybrid"
        bytes32 configHash;       // Hash of module configuration
        bool isActive;            // Whether this module is currently active
    }

    /// @notice Quantitative learning progress metrics
    /// @dev Stored on-chain. Updated by the learning module or updater role.
    struct LearningMetrics {
        uint256 totalInteractions;    // Total number of interactions processed
        uint256 learningEvents;       // Number of learning-relevant events
        uint256 lastUpdateTimestamp;  // Timestamp of last metrics update
        uint256 confidenceScore;      // Learning confidence (0-10000 basis points)
    }

    // ======================== EVENTS ========================

    event LearningModuleRegistered(
        uint256 indexed tokenId,
        address indexed moduleAddress,
        string moduleType
    );

    event LearningModuleDeactivated(
        uint256 indexed tokenId,
        address indexed moduleAddress
    );

    /// @notice Emitted when a learning milestone is reached
    /// @dev Milestones are implementation-defined (e.g., "100_interactions",
    ///      "confidence_90", "first_finetune")
    event LearningMilestone(
        uint256 indexed tokenId,
        string milestone,
        uint256 value
    );

    // ======================== MODULE REGISTRY ========================

    /// @notice Register a learning module for an agent
    /// @dev MUST only be callable by token owner or approved
    function registerLearningModule(
        uint256 tokenId,
        LearningModule calldata module
    ) external;

    /// @notice Deactivate a learning module
    /// @dev MUST only be callable by token owner or approved
    function deactivateLearningModule(
        uint256 tokenId,
        address moduleAddress
    ) external;

    /// @notice Get all registered learning modules for an agent
    function getLearningModules(uint256 tokenId)
        external view returns (LearningModule[] memory);

    // ======================== LEARNING VERIFICATION ========================

    /// @notice Verify a learning claim using Merkle proof against the agent's learning root
    /// @dev Enables on-chain verification that a specific piece of learning data
    ///      is included in the agent's learning tree. The learning root is stored
    ///      in INFA1Core.LearningState.learningRoot.
    /// @param tokenId The agent token ID
    /// @param claim The leaf hash of the learning claim to verify
    /// @param proof The Merkle proof (array of sibling hashes)
    /// @return valid True if the claim is verified against the current learning root
    function verifyLearning(
        uint256 tokenId,
        bytes32 claim,
        bytes32[] calldata proof
    ) external view returns (bool valid);

    // ======================== LEARNING METRICS ========================

    /// @notice Get the learning metrics for an agent
    function getLearningMetrics(uint256 tokenId)
        external view returns (LearningMetrics memory);
}
