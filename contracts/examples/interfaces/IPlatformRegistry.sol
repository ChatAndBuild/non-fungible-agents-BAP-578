// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
 * @title IPlatformRegistry
 * @dev Interface for the Multi-Platform Integration Hub registry.
 *      Tracks which BORT agents are connected to which external platforms
 *      (Discord, Telegram, Twitter/X, Web APIs) and manages connection lifecycle.
 */
interface IPlatformRegistry {
    // ──────────────────────────────────────────────
    // Enums
    // ──────────────────────────────────────────────

    enum PlatformType {
        DISCORD,
        TELEGRAM,
        TWITTER,
        WEBAPI
    }

    enum ConnectionStatus {
        INACTIVE,
        ACTIVE,
        SUSPENDED
    }

    // ──────────────────────────────────────────────
    // Structs
    // ──────────────────────────────────────────────

    struct PlatformConnection {
        uint256 id;
        uint256 agentId;
        PlatformType platform;
        ConnectionStatus status;
        string platformIdentifier;   // e.g. Discord guild ID, Telegram chat ID, Twitter handle, webhook URL
        string configURI;            // IPFS/vault URI to non-sensitive config
        bytes32 configHash;          // Hash of config for verification
        string credentialVaultId;    // Vault ID in VaultPermissionManager for encrypted credentials
        uint256 connectedAt;
        uint256 lastActivityAt;
    }

    struct AgentPlatformConfig {
        uint256 maxConnections;      // Max platform connections per agent (default 10)
        bool autoReportLearning;     // Auto-report interactions to MerkleTreeLearning
        uint256 totalConnections;
        uint256 activeConnections;
    }

    struct ConnectParams {
        uint256 agentId;
        PlatformType platform;
        string platformIdentifier;
        string configURI;
        bytes32 configHash;
        string credentialVaultId;
    }

    // ──────────────────────────────────────────────
    // Events
    // ──────────────────────────────────────────────

    event PlatformConnected(
        uint256 indexed connectionId,
        uint256 indexed agentId,
        PlatformType platform,
        string platformIdentifier,
        uint256 timestamp
    );

    event PlatformDisconnected(
        uint256 indexed connectionId,
        uint256 indexed agentId,
        PlatformType platform,
        uint256 timestamp
    );

    event PlatformStatusChanged(
        uint256 indexed connectionId,
        ConnectionStatus oldStatus,
        ConnectionStatus newStatus
    );

    event PlatformActivityRecorded(
        uint256 indexed connectionId,
        uint256 indexed agentId,
        PlatformType platform,
        uint256 timestamp
    );

    event AgentPlatformConfigUpdated(
        uint256 indexed agentId,
        uint256 maxConnections,
        bool autoReportLearning
    );

    event MessageRelayed(
        uint256 indexed connectionId,
        uint256 indexed agentId,
        PlatformType platform,
        bytes32 messageHash,
        uint256 timestamp
    );

    // ──────────────────────────────────────────────
    // Connection Management
    // ──────────────────────────────────────────────

    function connectPlatform(
        ConnectParams calldata params
    ) external returns (uint256 connectionId);

    function disconnectPlatform(uint256 connectionId) external;

    function suspendPlatform(uint256 connectionId) external;

    function resumePlatform(uint256 connectionId) external;

    // ──────────────────────────────────────────────
    // Runtime Operations
    // ──────────────────────────────────────────────

    function recordActivity(uint256 connectionId) external;

    function relayMessage(uint256 connectionId, bytes32 messageHash) external;

    // ──────────────────────────────────────────────
    // Configuration
    // ──────────────────────────────────────────────

    function updateAgentPlatformConfig(
        uint256 agentId,
        uint256 maxConnections,
        bool autoReportLearning
    ) external;

    function setRuntimeOperator(address operator, bool authorized) external;

    // ──────────────────────────────────────────────
    // View Functions
    // ──────────────────────────────────────────────

    function getConnection(uint256 connectionId) external view returns (PlatformConnection memory);

    function getAgentConnections(uint256 agentId) external view returns (PlatformConnection[] memory);

    function getAgentConnectionsByPlatform(
        uint256 agentId,
        PlatformType platform
    ) external view returns (PlatformConnection[] memory);

    function getActiveConnections(uint256 agentId) external view returns (PlatformConnection[] memory);

    function getAgentPlatformConfig(uint256 agentId) external view returns (AgentPlatformConfig memory);
}
