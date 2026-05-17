// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./IVaultPermissionManager.sol";

/// @dev Minimal surface the VPM needs from BAP-578: owner-of and bound logic address.
///      Matches `contracts/BAP578.sol` (agentStates returns a public tuple).
interface IBAP578 {
    function ownerOf(uint256 tokenId) external view returns (address);

    function agentStates(uint256 tokenId)
        external
        view
        returns (uint256 balance, bool active, address logicAddress, uint256 createdAt);
}

/// @dev The downstream-callable shape that VPM forwards into. Logic modules
///      that want to be drivable through VPM implement this single function.
interface ILogicModuleForwardable {
    function handleAction(
        uint256 tokenId,
        string calldata action,
        bytes calldata data
    ) external returns (bytes memory);
}

/// @title VaultPermissionManagerReference
/// @notice Reference UUPS implementation of IVaultPermissionManager.
///
///         Storage model: tokenId -> vaultIdHash -> grantee -> Grant.
///         Vault IDs are user-supplied strings (kept for human readability in
///         events), hashed to bytes32 for storage lookups.
///
///         Auto-revoke on NFT transfer is enforced through a per-token owner
///         epoch (see `_syncEpoch` / `_currentEpoch`): every grant stamps the
///         epoch live at creation, and a grant is invalid once the epoch moves.
///         The epoch advances whenever the contract observes a new owner, so a
///         grant from a previous owner cannot reactivate on an NFT round-trip
///         that the contract observed.
///
///         Production deployments should add: pause guard, per-action policy
///         hooks (see EXTENSION-README.md for the IPolicyGuard composition
///         pattern), and indexer-friendly events.
contract VaultPermissionManagerReference is
    IVaultPermissionManager,
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    // ---- Storage ----------------------------------------------------------

    struct Grant {
        PermissionLevel level;
        uint256 expiry; // 0 = no expiry
        uint256 epoch;  // owner epoch of the token when this grant was created
        bool exists;
    }

    address public bap578;

    // tokenId => vaultIdHash => exists
    mapping(uint256 => mapping(bytes32 => bool)) private _vaults;

    // tokenId => vaultIdHash => grantee => Grant
    mapping(uint256 => mapping(bytes32 => mapping(address => Grant))) private _grants;

    // tokenId => owner epoch. Advances every time the contract observes a new owner.
    mapping(uint256 => uint256) private _ownerEpoch;

    // tokenId => the owner address the contract last observed.
    mapping(uint256 => address) private _lastSeenOwner;

    // Reserved storage for future upgrades.
    uint256[48] private __gap;

    // ---- Initializer ------------------------------------------------------

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address bap578_) public initializer {
        require(bap578_ != address(0), "VPM: bap578 is zero");
        __Ownable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        bap578 = bap578_;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    // ---- IVaultPermissionManager writes -----------------------------------

    function createVault(
        uint256 tokenId,
        string calldata vaultId,
        string calldata /*description*/
    ) external {
        require(IBAP578(bap578).ownerOf(tokenId) == msg.sender, "VPM: only NFT owner");
        _syncEpoch(tokenId);
        bytes32 vid = _vid(vaultId);
        require(!_vaults[tokenId][vid], "VPM: vault exists");
        _vaults[tokenId][vid] = true;
        emit VaultCreated(tokenId, vid, vaultId, msg.sender);
    }

    function grantPermission(
        uint256 tokenId,
        string calldata vaultId,
        address grantee,
        PermissionLevel level,
        uint256 expiry,
        string calldata description
    ) external {
        require(grantee != address(0), "VPM: grantee zero");
        require(grantee != msg.sender, "VPM: cannot grant to self");
        require(level != PermissionLevel.NONE, "VPM: NONE; use revoke");
        require(expiry == 0 || expiry > block.timestamp, "VPM: expiry in past");
        bytes32 vid = _vid(vaultId);
        require(_vaults[tokenId][vid], "VPM: no such vault");

        // Only the NFT owner may mint or renew the ADMIN tier. Admins can grant
        // READ / WRITE but cannot create further admins or renew themselves.
        bool isOwner = IBAP578(bap578).ownerOf(tokenId) == msg.sender;
        if (level == PermissionLevel.ADMIN) {
            require(isOwner, "VPM: only owner grants ADMIN");
        }
        if (!isOwner) {
            uint256 epoch = _currentEpoch(tokenId);
            (bool isAdmin, ) = _check(tokenId, vid, msg.sender, PermissionLevel.ADMIN, epoch);
            require(isAdmin, "VPM: not owner or admin");
        }

        uint256 currentEpoch = _syncEpoch(tokenId);
        _grants[tokenId][vid][grantee] = Grant({
            level: level,
            expiry: expiry,
            epoch: currentEpoch,
            exists: true
        });
        emit PermissionGranted(tokenId, vid, grantee, level, expiry, description);
    }

    function revokePermission(
        uint256 tokenId,
        string calldata vaultId,
        address grantee
    ) external {
        bytes32 vid = _vid(vaultId);
        require(_grants[tokenId][vid][grantee].exists, "VPM: no such grant");
        _authorizeGrantor(tokenId, vid);

        delete _grants[tokenId][vid][grantee];
        emit PermissionRevoked(tokenId, vid, grantee);
    }

    function forwardHandleAction(
        uint256 tokenId,
        string calldata vaultId,
        string calldata action,
        bytes calldata data
    ) external nonReentrant returns (bytes memory result) {
        bytes32 vid = _vid(vaultId);
        require(_vaults[tokenId][vid], "VPM: no such vault");

        uint256 currentEpoch = _syncEpoch(tokenId);
        (bool ok, ) = _check(tokenId, vid, msg.sender, PermissionLevel.WRITE, currentEpoch);
        require(ok, "VPM: caller lacks WRITE");

        (, , address logic, ) = IBAP578(bap578).agentStates(tokenId);
        require(logic != address(0), "VPM: no logic bound");

        emit ActionForwarded(tokenId, vid, msg.sender, action);
        result = ILogicModuleForwardable(logic).handleAction(tokenId, action, data);
    }

    /// @notice Commit the current owner of `tokenId` into contract state.
    /// @dev Anyone may call this. It advances the owner epoch if the token has
    ///      changed hands since the contract last observed it, which permanently
    ///      invalidates every grant issued under the previous owner. Off-chain
    ///      indexers watching BAP-578 Transfer events can call this to close the
    ///      window where a dormant token round-trips without any other VPM call.
    function syncOwner(uint256 tokenId) external {
        _syncEpoch(tokenId);
    }

    // ---- IVaultPermissionManager reads ------------------------------------

    function checkPermission(
        uint256 tokenId,
        string calldata vaultId,
        address accessor,
        PermissionLevel minLevel
    ) external view returns (bool ok, uint256 expiry) {
        return _check(tokenId, _vid(vaultId), accessor, minLevel, _currentEpoch(tokenId));
    }

    function canForward(
        uint256 tokenId,
        string calldata vaultId,
        address accessor
    ) external view returns (bool) {
        (bool ok, ) = _check(
            tokenId, _vid(vaultId), accessor, PermissionLevel.WRITE, _currentEpoch(tokenId)
        );
        return ok;
    }

    function vaultExists(uint256 tokenId, string calldata vaultId) external view returns (bool) {
        return _vaults[tokenId][_vid(vaultId)];
    }

    /// @notice Current owner epoch for a token, accounting for an owner change
    ///         the contract has not yet committed to storage.
    function ownerEpoch(uint256 tokenId) external view returns (uint256) {
        return _currentEpoch(tokenId);
    }

    // ---- Internal ---------------------------------------------------------

    function _check(
        uint256 tokenId,
        bytes32 vid,
        address accessor,
        PermissionLevel minLevel,
        uint256 currentEpoch
    ) internal view returns (bool ok, uint256 expiry) {
        Grant storage g = _grants[tokenId][vid][accessor];
        if (!g.exists) return (false, 0);
        if (uint8(g.level) < uint8(minLevel)) return (false, g.expiry);
        if (g.expiry != 0 && block.timestamp > g.expiry) return (false, g.expiry);
        // Auto-revoke: a grant is dead once the token's owner epoch has moved.
        if (g.epoch != currentEpoch) return (false, g.expiry);
        return (true, g.expiry);
    }

    function _authorizeGrantor(uint256 tokenId, bytes32 vid) internal view {
        if (IBAP578(bap578).ownerOf(tokenId) == msg.sender) return;
        (bool isAdmin, ) = _check(
            tokenId, vid, msg.sender, PermissionLevel.ADMIN, _currentEpoch(tokenId)
        );
        require(isAdmin, "VPM: not owner or admin");
    }

    /// @dev Observe the current owner and advance the epoch if it changed.
    ///      Returns the up-to-date epoch.
    function _syncEpoch(uint256 tokenId) internal returns (uint256) {
        address current = IBAP578(bap578).ownerOf(tokenId);
        address lastSeen = _lastSeenOwner[tokenId];
        if (lastSeen == address(0)) {
            _lastSeenOwner[tokenId] = current;
        } else if (lastSeen != current) {
            uint256 next = _ownerEpoch[tokenId] + 1;
            _ownerEpoch[tokenId] = next;
            _lastSeenOwner[tokenId] = current;
            emit OwnerEpochAdvanced(tokenId, lastSeen, current, next);
        }
        return _ownerEpoch[tokenId];
    }

    /// @dev View-only epoch: if the owner has changed since the last committed
    ///      observation, the effective epoch is one ahead of stored state.
    function _currentEpoch(uint256 tokenId) internal view returns (uint256) {
        address lastSeen = _lastSeenOwner[tokenId];
        if (lastSeen != address(0) && lastSeen != IBAP578(bap578).ownerOf(tokenId)) {
            return _ownerEpoch[tokenId] + 1;
        }
        return _ownerEpoch[tokenId];
    }

    function _vid(string calldata vaultId) internal pure returns (bytes32) {
        return keccak256(bytes(vaultId));
    }
}
