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
        uint256 expiry;       // 0 = no expiry
        address ownerAtGrant; // ownerOf(tokenId) at the time the grant was created
        bool exists;
    }

    address public bap578;

    // tokenId => vaultIdHash => exists
    mapping(uint256 => mapping(bytes32 => bool)) private _vaults;

    // tokenId => vaultIdHash => grantee => Grant
    mapping(uint256 => mapping(bytes32 => mapping(address => Grant))) private _grants;

    // Reserved storage for future upgrades.
    uint256[50] private __gap;

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

    // ---- Modifiers --------------------------------------------------------

    modifier onlyTokenOwnerOrAdmin(uint256 tokenId, bytes32 vid) {
        if (IBAP578(bap578).ownerOf(tokenId) != msg.sender) {
            (bool ok, ) = _check(tokenId, vid, msg.sender, PermissionLevel.ADMIN);
            require(ok, "VPM: not owner or admin");
        }
        _;
    }

    // ---- IVaultPermissionManager writes -----------------------------------

    function createVault(
        uint256 tokenId,
        string calldata vaultId,
        string calldata /*description*/
    ) external {
        require(IBAP578(bap578).ownerOf(tokenId) == msg.sender, "VPM: only NFT owner");
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
        require(level != PermissionLevel.NONE, "VPM: NONE; use revoke");
        require(expiry == 0 || expiry > block.timestamp, "VPM: expiry in past");
        bytes32 vid = _vid(vaultId);
        require(_vaults[tokenId][vid], "VPM: no such vault");
        _authorizeGrantor(tokenId, vid);

        _grants[tokenId][vid][grantee] = Grant({
            level: level,
            expiry: expiry,
            ownerAtGrant: IBAP578(bap578).ownerOf(tokenId),
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

        (bool ok, ) = _check(tokenId, vid, msg.sender, PermissionLevel.WRITE);
        require(ok, "VPM: caller lacks WRITE");

        (, , address logic, ) = IBAP578(bap578).agentStates(tokenId);
        require(logic != address(0), "VPM: no logic bound");

        emit ActionForwarded(tokenId, vid, msg.sender, action);
        result = ILogicModuleForwardable(logic).handleAction(tokenId, action, data);
    }

    // ---- IVaultPermissionManager reads ------------------------------------

    function checkPermission(
        uint256 tokenId,
        string calldata vaultId,
        address accessor,
        PermissionLevel minLevel
    ) external view returns (bool ok, uint256 expiry) {
        return _check(tokenId, _vid(vaultId), accessor, minLevel);
    }

    function canForward(
        uint256 tokenId,
        string calldata vaultId,
        address accessor
    ) external view returns (bool) {
        (bool ok, ) = _check(tokenId, _vid(vaultId), accessor, PermissionLevel.WRITE);
        return ok;
    }

    function vaultExists(uint256 tokenId, string calldata vaultId) external view returns (bool) {
        return _vaults[tokenId][_vid(vaultId)];
    }

    // ---- Internal ---------------------------------------------------------

    function _check(
        uint256 tokenId,
        bytes32 vid,
        address accessor,
        PermissionLevel minLevel
    ) internal view returns (bool ok, uint256 expiry) {
        Grant storage g = _grants[tokenId][vid][accessor];
        if (!g.exists) return (false, 0);
        if (uint8(g.level) < uint8(minLevel)) return (false, g.expiry);
        if (g.expiry != 0 && block.timestamp > g.expiry) return (false, g.expiry);
        // Auto-revoke: if the NFT changed hands since the grant, the grant is dead.
        if (IBAP578(bap578).ownerOf(tokenId) != g.ownerAtGrant) return (false, g.expiry);
        return (true, g.expiry);
    }

    function _authorizeGrantor(uint256 tokenId, bytes32 vid) internal view {
        if (IBAP578(bap578).ownerOf(tokenId) == msg.sender) return;
        (bool isAdmin, ) = _check(tokenId, vid, msg.sender, PermissionLevel.ADMIN);
        require(isAdmin, "VPM: not owner or admin");
    }

    function _vid(string calldata vaultId) internal pure returns (bytes32) {
        return keccak256(bytes(vaultId));
    }
}
