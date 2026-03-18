// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

/// @title INFA1Identity - NFA-1 Identity Registry Bridge Extension
/// @notice Optional extension for bridging NFAs to ERC-8004 Trustless Agents ecosystem
/// @dev Enables NFAs to participate in cross-organizational agent discovery and reputation.
///
///      ERC-8004 Agent Card Mapping:
///      - The NFA vault metadata SHOULD include an Agent Card-compatible JSON
///      - This creates a bidirectional bridge: NFA tokens discoverable via ERC-8004,
///        and ERC-8004 agents can prove they are backed by verifiable NFA assets.
interface INFA1Identity {

    /// @notice Emitted when an NFA is linked to an external identity registry
    event IdentityLinked(
        uint256 indexed tokenId,
        address indexed registry,
        uint256 indexed externalAgentId
    );

    /// @notice Emitted when an identity link is removed
    event IdentityUnlinked(
        uint256 indexed tokenId,
        address indexed registry
    );

    /// @notice Link this NFA to an ERC-8004 or compatible Identity Registry entry
    /// @dev MUST only be callable by token owner
    /// @param tokenId The agent token ID
    /// @param registry Address of the identity registry contract
    /// @param externalAgentId Agent ID in the external registry
    function linkIdentity(
        uint256 tokenId,
        address registry,
        uint256 externalAgentId
    ) external;

    /// @notice Remove a linked identity
    /// @dev MUST only be callable by token owner
    function unlinkIdentity(uint256 tokenId, address registry) external;

    /// @notice Get the linked identity for this NFA in a specific registry
    /// @param tokenId The agent token ID
    /// @param registry Address of the identity registry to query
    /// @return externalAgentId Agent ID in the external registry (0 if not linked)
    function getLinkedIdentity(uint256 tokenId, address registry)
        external view returns (uint256 externalAgentId);
}
