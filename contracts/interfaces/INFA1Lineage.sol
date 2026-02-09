// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

/// @title INFA1Lineage - NFA-1 Lineage and Fusion Extension
/// @notice Optional extension for agent breeding, lineage tracking, and fusion mechanics
/// @dev Implementations that support fusion SHOULD use a commit-reveal pattern
///      to prevent frontrunning of trait outcomes.
interface INFA1Lineage {

    struct Lineage {
        uint256 parent1;      // Token ID of first parent (0 for genesis)
        uint256 parent2;      // Token ID of second parent (0 for genesis)
        uint256 generation;   // Generation number (0 for genesis)
        bool isSealed;        // Whether this agent has been used in fusion
    }

    /// @notice Emitted when an offspring is created from fusion
    event OffspringCreated(
        uint256 indexed offspringId,
        uint256 indexed parent1,
        uint256 indexed parent2,
        uint256 generation
    );

    /// @notice Emitted when an agent is sealed (used in fusion)
    event AgentSealed(uint256 indexed tokenId);

    /// @notice Emitted when an agent is burned via fusion
    event AgentBurned(uint256 indexed tokenId);

    /// @notice Get the lineage information for an agent
    function getLineage(uint256 tokenId) external view returns (Lineage memory);

    /// @notice Get the generation number of an agent
    function getGeneration(uint256 tokenId) external view returns (uint256);

    /// @notice Check if an agent has been sealed
    function isSealed(uint256 tokenId) external view returns (bool);
}
