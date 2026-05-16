// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IVaultPermissionManager: actor-authorization layer for BAP-578 agents
/// @notice Lets a BAP-578 NFT owner grant a third-party operator the right to
///         drive their agent's `handleAction` entry point, within a time-bounded
///         permission tier. The operator never holds the NFT and cannot transfer
///         it, list it, or change its logic.
///
///         Complementary to the IPolicyGuard framework already in this repo:
///           - IPolicyGuard answers "is this action ALLOWED?" (per-call validation,
///             typically of the logic's outbound calls to external contracts).
///           - IVaultPermissionManager answers "is this ACTOR authorized to drive
///             handleAction at all?" (per-actor authorization at the outer boundary).
///
///         A full agent stack uses both: the operator passes through the VPM
///         forwarder, the logic module's outbound calls are validated by
///         IPolicyGuard. See EXTENSION-README.md for the composition pattern.
interface IVaultPermissionManager {
    /// @notice Permission tiers. Higher tiers strictly include lower tiers.
    enum PermissionLevel { NONE, READ, WRITE, ADMIN }

    // ---- Events -----------------------------------------------------------

    event VaultCreated(uint256 indexed tokenId, bytes32 indexed vaultIdHash, string vaultId, address creator);

    event PermissionGranted(
        uint256 indexed tokenId,
        bytes32 indexed vaultIdHash,
        address indexed grantee,
        PermissionLevel level,
        uint256 expiry,
        string description
    );

    event PermissionRevoked(uint256 indexed tokenId, bytes32 indexed vaultIdHash, address indexed grantee);

    event ActionForwarded(
        uint256 indexed tokenId,
        bytes32 indexed vaultIdHash,
        address indexed accessor,
        string action
    );

    // ---- Writes -----------------------------------------------------------

    /// @notice Create a new permission namespace for an agent.
    /// @dev Callable by the NFT owner only. An agent may have multiple vaults
    ///      (e.g. separate scopes for trading vs. social vs. memory writes).
    function createVault(
        uint256 tokenId,
        string calldata vaultId,
        string calldata description
    ) external;

    /// @notice Grant a permission tier to a grantee on a vault.
    /// @param expiry Unix timestamp; 0 means no expiry. Past timestamps revert.
    /// @dev Callable by the NFT owner or an address that already holds ADMIN
    ///      on the same (tokenId, vaultId).
    function grantPermission(
        uint256 tokenId,
        string calldata vaultId,
        address grantee,
        PermissionLevel level,
        uint256 expiry,
        string calldata description
    ) external;

    /// @notice Revoke an existing grant.
    /// @dev Callable by the NFT owner or an ADMIN on the same vault.
    function revokePermission(
        uint256 tokenId,
        string calldata vaultId,
        address grantee
    ) external;

    /// @notice Forward an action to the agent's bound logic module.
    /// @dev msg.sender must have at least WRITE on (tokenId, vaultId). Reverts
    ///      with the logic module's revert reason if the inner call reverts.
    /// @return result Whatever bytes the logic module returns (often empty).
    function forwardHandleAction(
        uint256 tokenId,
        string calldata vaultId,
        string calldata action,
        bytes calldata data
    ) external returns (bytes memory result);

    // ---- Reads ------------------------------------------------------------

    /// @notice Whether `accessor` currently holds at least `minLevel`.
    /// @return ok      True iff the grant exists, is at or above `minLevel`, and
    ///                 has not expired (or has no expiry).
    /// @return expiry  The grant's expiry timestamp (0 = no expiry), or 0 if no grant.
    function checkPermission(
        uint256 tokenId,
        string calldata vaultId,
        address accessor,
        PermissionLevel minLevel
    ) external view returns (bool ok, uint256 expiry);

    /// @notice Convenience helper used by forwarders before dispatching.
    /// @dev Equivalent to checkPermission(..., WRITE).ok.
    function canForward(
        uint256 tokenId,
        string calldata vaultId,
        address accessor
    ) external view returns (bool);

    /// @notice Whether the named vault exists on the agent.
    function vaultExists(uint256 tokenId, string calldata vaultId) external view returns (bool);
}
