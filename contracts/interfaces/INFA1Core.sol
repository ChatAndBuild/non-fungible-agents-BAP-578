// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

/// @title INFA1Core - Non-Fungible Agent Standard Core Interface
/// @notice Core interface for NFA-1 compliant Non-Fungible Agents
/// @dev Extends ERC-721. Implementations MUST also implement ERC-165.
///      Based on: BAP-578 BEP Draft (https://github.com/bnb-chain/BEPs/blob/master/BAPs/BAP-578.md)
///      Spec: https://github.com/KinForgeLab/nfa-standard
interface INFA1Core /* is IERC721 */ {

    // ======================== ENUMS ========================

    /// @notice Agent lifecycle states
    /// @dev State transitions:
    ///   Active <-> Paused  (reversible)
    ///   Active  -> Terminated (irreversible)
    ///   Paused  -> Terminated (irreversible)
    ///   Terminated -> * (PROHIBITED)
    enum Status {
        Active,      // Normal operation; all functions available
        Paused,      // Actions blocked; transfers MUST remain allowed
        Terminated   // Permanent; MUST NOT be reversible
    }

    // ======================== STRUCTS ========================

    /// @notice On-chain runtime state of an agent
    /// @dev All fields are On-Chain (directly readable via contract calls)
    struct State {
        uint256 balance;              // Internal funding balance (native currency)
        Status status;                // Current lifecycle status
        address owner;                // Current owner (derived from ERC-721)
        address logicAddress;         // Delegated logic contract (address(0) = none)
        uint256 lastActionTimestamp;  // Timestamp of last executeAction call
    }

    /// @notice Agent identity and metadata
    /// @dev `vaultHash` bridges On-Chain and Verifiably On-Chain data:
    ///      the hash is stored on-chain, the vault contents live off-chain
    ///      but can be verified by recomputing the hash.
    struct AgentMetadata {
        string persona;        // JSON-encoded personality/character traits
        string experience;     // Role/purpose summary
        string voiceHash;      // Hash reference for voice identity (MAY be empty)
        string animationURI;   // URI for animation/avatar (MAY be empty)
        string vaultURI;       // URI pointing to off-chain vault data
        bytes32 vaultHash;     // keccak256 of vault contents (integrity anchor)
    }

    /// @notice Learning progression state
    /// @dev `learningRoot` is the on-chain commitment for off-chain learning data.
    ///      The full learning tree is Verifiably On-Chain: stored off-chain,
    ///      verified via Merkle proof against learningRoot.
    struct LearningState {
        bytes32 learningRoot;        // Merkle root or hash of learning data
        uint256 learningVersion;     // Monotonically increasing version counter
        uint256 lastLearningUpdate;  // Block timestamp of last update
        bool learningEnabled;        // Whether learning updates are accepted
    }

    // ======================== EVENTS ========================

    /// @notice MUST be emitted when executeAction is called
    event ActionExecuted(uint256 indexed tokenId, bytes result);

    /// @notice MUST be emitted when the logic address changes
    event LogicUpgraded(
        uint256 indexed tokenId,
        address indexed oldLogic,
        address indexed newLogic
    );

    /// @notice MUST be emitted when an agent receives funding
    event AgentFunded(
        uint256 indexed tokenId,
        address indexed funder,
        uint256 amount
    );

    /// @notice MUST be emitted on any status transition
    event StatusChanged(uint256 indexed tokenId, Status newStatus);

    /// @notice MUST be emitted when metadata is updated
    event MetadataUpdated(uint256 indexed tokenId, string metadataURI);

    /// @notice MUST be emitted when learning state is updated
    event LearningUpdated(
        uint256 indexed tokenId,
        bytes32 indexed oldRoot,
        bytes32 indexed newRoot,
        uint256 newVersion
    );

    // ======================== ACTION EXECUTION ========================

    /// @notice Execute an action via the agent's delegated logic contract
    /// @dev MUST revert if status != Active
    /// @dev MUST revert if logicAddress == address(0)
    /// @dev MUST update lastActionTimestamp to block.timestamp
    /// @dev MUST emit ActionExecuted
    /// @dev Implementations SHOULD enforce a gas limit on the delegated call
    /// @param tokenId The agent token ID
    /// @param data Calldata to forward to the logic contract
    /// @return result Return data from the logic contract
    function executeAction(uint256 tokenId, bytes calldata data)
        external returns (bytes memory result);

    /// @notice Set or update the delegated logic contract address
    /// @dev MUST only be callable by token owner or approved
    /// @dev MUST NOT revert if newLogic == address(0) (disabling logic)
    /// @dev MUST emit LogicUpgraded
    /// @param tokenId The agent token ID
    /// @param newLogic Address of the new logic contract (or address(0) to disable)
    function setLogicAddress(uint256 tokenId, address newLogic) external;

    // ======================== FUNDING ========================

    /// @notice Fund an agent's internal balance with native currency
    /// @dev MUST be callable by anyone (permissionless)
    /// @dev MUST emit AgentFunded
    /// @param tokenId The agent token ID
    function fundAgent(uint256 tokenId) external payable;

    // ======================== LIFECYCLE ========================

    /// @notice Pause an agent (blocks action execution, allows transfers)
    /// @dev MUST revert if current status is not Active
    /// @dev MUST only be callable by token owner or approved
    /// @dev MUST emit StatusChanged
    function pause(uint256 tokenId) external;

    /// @notice Unpause an agent (restores to Active)
    /// @dev MUST revert if current status is not Paused
    /// @dev MUST only be callable by token owner or approved
    /// @dev MUST emit StatusChanged
    function unpause(uint256 tokenId) external;

    /// @notice Permanently terminate an agent (IRREVERSIBLE)
    /// @dev MUST revert if already Terminated
    /// @dev MUST only be callable by token owner or approved
    /// @dev MUST emit StatusChanged
    /// @dev MUST NOT be reversible under any circumstance
    function terminate(uint256 tokenId) external;

    // ======================== STATE QUERIES ========================

    /// @notice Get the complete runtime state of an agent
    function getState(uint256 tokenId) external view returns (State memory);

    /// @notice Get the agent's metadata
    function getAgentMetadata(uint256 tokenId)
        external view returns (AgentMetadata memory);

    /// @notice Get the agent's learning state
    function getLearningState(uint256 tokenId)
        external view returns (LearningState memory);

    // ======================== METADATA ========================

    /// @notice Update the agent's metadata
    /// @dev MUST revert if Terminated
    /// @dev MUST only be callable by owner, approved, or designated updater role
    /// @dev MUST emit MetadataUpdated
    function updateAgentMetadata(
        uint256 tokenId,
        AgentMetadata calldata metadata
    ) external;

    // ======================== LEARNING ========================

    /// @notice Update the agent's learning state with new off-chain data commitment
    /// @dev MUST revert if learningEnabled == false
    /// @dev MUST revert if newVersion <= current version (monotonic enforcement)
    /// @dev MUST revert if Terminated
    /// @dev MUST emit LearningUpdated
    /// @param tokenId The agent token ID
    /// @param newVaultURI Updated vault URI
    /// @param newVaultHash Updated vault integrity hash
    /// @param newLearningRoot New Merkle root of learning data
    /// @param newVersion New version number (MUST be > current)
    function updateLearning(
        uint256 tokenId,
        string calldata newVaultURI,
        bytes32 newVaultHash,
        bytes32 newLearningRoot,
        uint256 newVersion
    ) external;

    // ======================== LEARNING QUERIES ========================

    /// @notice Get the current learning root hash
    function getLearningRoot(uint256 tokenId) external view returns (bytes32);

    /// @notice Check if learning is enabled for this agent
    function isLearningEnabled(uint256 tokenId) external view returns (bool);

    /// @notice Get the current learning version
    function getLearningVersion(uint256 tokenId) external view returns (uint256);

    /// @notice Get the timestamp of the last learning update
    function getLastLearningUpdate(uint256 tokenId) external view returns (uint256);
}
