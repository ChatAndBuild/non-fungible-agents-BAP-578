// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "./interfaces/ICircuitBreaker.sol";

/**
 * @title VaultPermissionManager
 * @dev Manages secure access to off-chain data vaults with time-based delegation
 * Provides granular permission control for accessing agent data vaults
 */
contract VaultPermissionManager is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    // Circuit breaker for emergency controls
    ICircuitBreaker public circuitBreaker;

    // Permission tracking
    CountersUpgradeable.Counter private _permissionIdCounter;

    /**
     * @dev Permission levels for vault access
     */
    enum PermissionLevel {
        NONE, // No access
        READ, // Read-only access
        WRITE, // Read and write access
        ADMIN // Full administrative access
    }

    /**
     * @dev Permission structure for vault access
     */
    struct VaultPermission {
        uint256 id;
        address vaultOwner; // Owner of the vault
        address delegate; // Address being granted permission
        string vaultId; // Unique identifier for the vault
        PermissionLevel level; // Permission level granted
        uint256 startTime; // When permission becomes active
        uint256 endTime; // When permission expires
        bool isActive; // Whether permission is currently active
        string metadata; // Additional metadata about the permission
        uint256 createdAt; // When permission was created
    }

    /**
     * @dev Vault information structure
     */
    struct VaultInfo {
        address owner;
        string vaultId;
        string description;
        bool isActive;
        uint256 createdAt;
        uint256 lastAccessed;
    }

    // Mappings for permission management
    mapping(uint256 => VaultPermission) public permissions;
    mapping(address => mapping(string => VaultInfo)) public vaults; // owner => vaultId => VaultInfo
    mapping(address => uint256[]) public userPermissions; // user => permission IDs
    mapping(address => mapping(string => uint256[])) public vaultPermissions; // owner => vaultId => permission IDs
    mapping(address => bool) public authorizedAgents; // BAP578 agent contracts that can request permissions

    // Statistics
    uint256 public totalPermissions;
    uint256 public totalVaults;
    uint256 public activePermissions;

    // Events
    event VaultCreated(
        address indexed owner,
        string indexed vaultId,
        string description,
        uint256 timestamp
    );

    event PermissionGranted(
        uint256 indexed permissionId,
        address indexed vaultOwner,
        address indexed delegate,
        string vaultId,
        PermissionLevel level,
        uint256 startTime,
        uint256 endTime
    );

    event PermissionRevoked(
        uint256 indexed permissionId,
        address indexed vaultOwner,
        address indexed delegate,
        string vaultId
    );

    event PermissionExpired(
        uint256 indexed permissionId,
        address indexed vaultOwner,
        address indexed delegate,
        string vaultId
    );

    event VaultAccessed(
        address indexed vaultOwner,
        string indexed vaultId,
        address indexed accessor,
        PermissionLevel level,
        uint256 timestamp
    );

    event AgentAuthorized(address indexed agent, bool authorized);
    event VaultDeactivated(address indexed owner, string indexed vaultId);

    /**
     * @dev Modifier to check if the system is not paused
     */
    modifier whenNotPaused() {
        require(
            !ICircuitBreaker(circuitBreaker).globalPause(),
            "VaultPermissionManager: system is paused"
        );
        _;
    }

    /**
     * @dev Modifier to check if caller is vault owner or authorized agent
     */
    modifier onlyVaultOwnerOrAgent(string memory vaultId) {
        require(
            vaults[msg.sender][vaultId].owner == msg.sender || authorizedAgents[msg.sender],
            "VaultPermissionManager: not vault owner or authorized agent"
        );
        _;
    }

    /**
     * @dev Initializes the contract
     * @param circuitBreakerAddr The address of the circuit breaker contract
     * @param ownerAddr The address of the contract owner
     */
    function initialize(address circuitBreakerAddr, address ownerAddr) public initializer {
        require(
            circuitBreakerAddr != address(0),
            "VaultPermissionManager: circuit breaker is zero address"
        );
        require(ownerAddr != address(0), "VaultPermissionManager: owner is zero address");

        __Ownable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        circuitBreaker = ICircuitBreaker(circuitBreakerAddr);
        transferOwnership(ownerAddr);
    }

    /**
     * @dev Creates a new vault
     * @param vaultId Unique identifier for the vault
     * @param description Description of the vault contents
     */
    function createVault(
        string memory vaultId,
        string memory description
    ) external whenNotPaused nonReentrant {
        require(bytes(vaultId).length > 0, "VaultPermissionManager: vault ID cannot be empty");
        require(
            vaults[msg.sender][vaultId].owner == address(0),
            "VaultPermissionManager: vault already exists"
        );

        vaults[msg.sender][vaultId] = VaultInfo({
            owner: msg.sender,
            vaultId: vaultId,
            description: description,
            isActive: true,
            createdAt: block.timestamp,
            lastAccessed: 0
        });

        totalVaults++;

        emit VaultCreated(msg.sender, vaultId, description, block.timestamp);
    }

    /**
     * @dev Grants permission to access a vault
     * @param delegate Address to grant permission to
     * @param vaultId Vault identifier
     * @param level Permission level to grant
     * @param duration Duration of permission in seconds
     * @param metadata Additional metadata about the permission
     */
    function grantPermission(
        address delegate,
        string memory vaultId,
        PermissionLevel level,
        uint256 duration,
        string memory metadata
    ) external whenNotPaused nonReentrant {
        require(delegate != address(0), "VaultPermissionManager: delegate is zero address");
        require(delegate != msg.sender, "VaultPermissionManager: cannot grant permission to self");
        require(bytes(vaultId).length > 0, "VaultPermissionManager: vault ID cannot be empty");
        require(
            vaults[msg.sender][vaultId].owner == msg.sender,
            "VaultPermissionManager: vault not found or not owner"
        );
        require(
            vaults[msg.sender][vaultId].isActive,
            "VaultPermissionManager: vault is not active"
        );
        require(
            level != PermissionLevel.NONE,
            "VaultPermissionManager: cannot grant NONE permission"
        );
        require(duration > 0, "VaultPermissionManager: duration must be greater than 0");

        _permissionIdCounter.increment();
        uint256 permissionId = _permissionIdCounter.current();

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + duration;

        permissions[permissionId] = VaultPermission({
            id: permissionId,
            vaultOwner: msg.sender,
            delegate: delegate,
            vaultId: vaultId,
            level: level,
            startTime: startTime,
            endTime: endTime,
            isActive: true,
            metadata: metadata,
            createdAt: block.timestamp
        });

        userPermissions[delegate].push(permissionId);
        vaultPermissions[msg.sender][vaultId].push(permissionId);

        totalPermissions++;
        activePermissions++;

        emit PermissionGranted(
            permissionId,
            msg.sender,
            delegate,
            vaultId,
            level,
            startTime,
            endTime
        );
    }

    /**
     * @dev Revokes a permission before it expires
     * @param permissionId ID of the permission to revoke
     */
    function revokePermission(uint256 permissionId) external whenNotPaused nonReentrant {
        VaultPermission storage permission = permissions[permissionId];
        require(
            permission.vaultOwner == msg.sender,
            "VaultPermissionManager: not permission owner"
        );
        require(permission.isActive, "VaultPermissionManager: permission not active");

        permission.isActive = false;
        activePermissions--;

        emit PermissionRevoked(
            permissionId,
            permission.vaultOwner,
            permission.delegate,
            permission.vaultId
        );
    }

    /**
     * @dev Checks if an address has permission to access a vault
     * @param vaultOwner Owner of the vault
     * @param vaultId Vault identifier
     * @param accessor Address requesting access
     * @param requiredLevel Required permission level
     * @return hasPermission Whether accessor has required permission
     * @return permissionLevel Actual permission level granted
     */
    function checkPermission(
        address vaultOwner,
        string memory vaultId,
        address accessor,
        PermissionLevel requiredLevel
    ) external view returns (bool hasPermission, PermissionLevel permissionLevel) {
        // Vault owner always has full access
        if (accessor == vaultOwner) {
            return (true, PermissionLevel.ADMIN);
        }

        // Check if accessor has an active permission
        uint256[] memory vaultPerms = vaultPermissions[vaultOwner][vaultId];
        PermissionLevel highestLevel = PermissionLevel.NONE;
        bool hasActivePermission = false;

        for (uint256 i = 0; i < vaultPerms.length; i++) {
            VaultPermission memory perm = permissions[vaultPerms[i]];

            if (
                perm.delegate == accessor &&
                perm.isActive &&
                block.timestamp >= perm.startTime &&
                block.timestamp <= perm.endTime
            ) {
                hasActivePermission = true;

                // Track the highest permission level found
                if (uint256(perm.level) > uint256(highestLevel)) {
                    highestLevel = perm.level;
                }

                // Check if permission level is sufficient
                if (uint256(perm.level) >= uint256(requiredLevel)) {
                    return (true, perm.level);
                }
            }
        }

        // Return the highest permission level found, or NONE if no active permissions
        return (false, hasActivePermission ? highestLevel : PermissionLevel.NONE);
    }

    /**
     * @dev Records vault access for audit purposes
     * @param vaultOwner Owner of the vault
     * @param vaultId Vault identifier
     * @param accessor Address accessing the vault
     * @param level Permission level used for access
     */
    function recordVaultAccess(
        address vaultOwner,
        string memory vaultId,
        address accessor,
        PermissionLevel level
    ) external whenNotPaused {
        require(
            authorizedAgents[msg.sender] || msg.sender == vaultOwner,
            "VaultPermissionManager: not authorized to record access"
        );

        // Update last accessed time
        vaults[vaultOwner][vaultId].lastAccessed = block.timestamp;

        emit VaultAccessed(vaultOwner, vaultId, accessor, level, block.timestamp);
    }

    /**
     * @dev Deactivates a vault (owner only)
     * @param vaultId Vault identifier to deactivate
     */
    function deactivateVault(string memory vaultId) external whenNotPaused nonReentrant {
        require(
            vaults[msg.sender][vaultId].owner == msg.sender,
            "VaultPermissionManager: vault not found or not owner"
        );
        require(
            vaults[msg.sender][vaultId].isActive,
            "VaultPermissionManager: vault already inactive"
        );

        vaults[msg.sender][vaultId].isActive = false;

        // Revoke all active permissions for this vault
        uint256[] memory vaultPerms = vaultPermissions[msg.sender][vaultId];
        uint256 vaultPermsLength = vaultPerms.length;
        for (uint256 i = 0; i < vaultPermsLength; i++) {
            if (permissions[vaultPerms[i]].isActive) {
                permissions[vaultPerms[i]].isActive = false;
                activePermissions--;
            }
        }

        emit VaultDeactivated(msg.sender, vaultId);
    }

    /**
     * @dev Authorizes or deauthorizes a BAP578 agent contract
     * @param agent Address of the agent contract
     * @param authorized Whether to authorize or deauthorize
     */
    function setAgentAuthorization(address agent, bool authorized) external onlyOwner {
        require(agent != address(0), "VaultPermissionManager: agent is zero address");

        authorizedAgents[agent] = authorized;
        emit AgentAuthorized(agent, authorized);
    }

    /**
     * @dev Cleans up expired permissions with pagination (anyone can call this)
     * @param startIndex Starting index for cleanup (1-based)
     * @param maxIterations Maximum number of permissions to check in this call
     * @return cleaned Number of permissions cleaned up
     * @return nextIndex Next index to continue from (0 if complete)
     */
    function cleanupExpiredPermissions(
        uint256 startIndex,
        uint256 maxIterations
    ) external whenNotPaused returns (uint256 cleaned, uint256 nextIndex) {
        require(maxIterations > 0, "VaultPermissionManager: maxIterations must be greater than 0");
        require(maxIterations <= 1000, "VaultPermissionManager: maxIterations too high");

        uint256 currentIndex = startIndex;
        uint256 totalPerms = _permissionIdCounter.current();
        uint256 iterations = 0;

        while (currentIndex <= totalPerms && iterations < maxIterations) {
            VaultPermission storage perm = permissions[currentIndex];

            if (perm.isActive && block.timestamp > perm.endTime) {
                perm.isActive = false;
                activePermissions--;
                cleaned++;

                emit PermissionExpired(perm.id, perm.vaultOwner, perm.delegate, perm.vaultId);
            }

            currentIndex++;
            iterations++;
        }

        // Return next index to continue from, or 0 if we've reached the end
        nextIndex = currentIndex <= totalPerms ? currentIndex : 0;

        return (cleaned, nextIndex);
    }

    /**
     * @dev Cleans up expired permissions for a specific vault
     * @param vaultOwner Owner of the vault
     * @param vaultId Vault identifier
     * @param maxIterations Maximum number of permissions to check
     * @return cleaned Number of permissions cleaned up
     */
    function cleanupExpiredVaultPermissions(
        address vaultOwner,
        string memory vaultId,
        uint256 maxIterations
    ) external whenNotPaused returns (uint256 cleaned) {
        require(maxIterations > 0, "VaultPermissionManager: maxIterations must be greater than 0");
        require(maxIterations <= 1000, "VaultPermissionManager: maxIterations too high");

        uint256[] memory vaultPerms = vaultPermissions[vaultOwner][vaultId];
        uint256 vaultPermsLength = vaultPerms.length;
        uint256 iterations = 0;

        for (uint256 i = 0; i < vaultPermsLength && iterations < maxIterations; i++) {
            VaultPermission storage perm = permissions[vaultPerms[i]];

            if (perm.isActive && block.timestamp > perm.endTime) {
                perm.isActive = false;
                activePermissions--;
                cleaned++;

                emit PermissionExpired(perm.id, perm.vaultOwner, perm.delegate, perm.vaultId);
            }

            iterations++;
        }

        return cleaned;
    }

    /**
     * @dev Cleans up expired permissions for a specific user
     * @param user Address of the user
     * @param maxIterations Maximum number of permissions to check
     * @return cleaned Number of permissions cleaned up
     */
    function cleanupExpiredUserPermissions(
        address user,
        uint256 maxIterations
    ) external whenNotPaused returns (uint256 cleaned) {
        require(maxIterations > 0, "VaultPermissionManager: maxIterations must be greater than 0");
        require(maxIterations <= 1000, "VaultPermissionManager: maxIterations too high");

        uint256[] memory userPerms = userPermissions[user];
        uint256 iterations = 0;

        for (uint256 i = 0; i < userPerms.length && iterations < maxIterations; i++) {
            VaultPermission storage perm = permissions[userPerms[i]];

            if (perm.isActive && block.timestamp > perm.endTime) {
                perm.isActive = false;
                activePermissions--;
                cleaned++;

                emit PermissionExpired(perm.id, perm.vaultOwner, perm.delegate, perm.vaultId);
            }

            iterations++;
        }

        return cleaned;
    }

    /**
     * @dev Gets the next cleanup index and count of expired permissions
     * @param startIndex Starting index for checking
     * @param maxIterations Maximum number of permissions to check
     * @return nextIndex Next index to continue from (0 if complete)
     * @return expiredCount Number of expired permissions found
     */
    function getNextCleanupIndex(
        uint256 startIndex,
        uint256 maxIterations
    ) external view returns (uint256 nextIndex, uint256 expiredCount) {
        require(maxIterations > 0, "VaultPermissionManager: maxIterations must be greater than 0");
        require(maxIterations <= 1000, "VaultPermissionManager: maxIterations too high");

        uint256 currentIndex = startIndex;
        uint256 totalPerms = _permissionIdCounter.current();
        uint256 iterations = 0;

        while (currentIndex <= totalPerms && iterations < maxIterations) {
            VaultPermission storage perm = permissions[currentIndex];

            if (perm.isActive && block.timestamp > perm.endTime) {
                expiredCount++;
            }

            currentIndex++;
            iterations++;
        }

        // Return next index to continue from, or 0 if we've reached the end
        nextIndex = currentIndex <= totalPerms ? currentIndex : 0;

        return (nextIndex, expiredCount);
    }

    /**
     * @dev Simple cleanup function for backward compatibility
     * @return cleaned Number of permissions cleaned up
     */
    function cleanupAllExpiredPermissions() external whenNotPaused returns (uint256 cleaned) {
        (cleaned, ) = this.cleanupExpiredPermissions(1, 1000);
        return cleaned;
    }

    /**
     * @dev Gets all permissions for a user
     * @param user Address of the user
     * @return Array of permission IDs
     */
    function getUserPermissions(address user) external view returns (uint256[] memory) {
        return userPermissions[user];
    }

    /**
     * @dev Views vault contents if user has appropriate permissions
     * @param vaultOwner Owner of the vault
     * @param vaultId Vault identifier
     * @return vaultInfo The vault information
     * @return hasAccess Whether the caller has access to view the vault
     */
    function viewVaultContents(
        address vaultOwner,
        string memory vaultId
    ) external view returns (VaultInfo memory vaultInfo, bool hasAccess) {
        // Check if vault exists and is active
        require(
            vaults[vaultOwner][vaultId].owner == vaultOwner,
            "VaultPermissionManager: vault not found"
        );
        require(
            vaults[vaultOwner][vaultId].isActive,
            "VaultPermissionManager: vault is not active"
        );

        // Check if caller has access
        hasAccess = _checkViewAccess(vaultOwner, vaultId, msg.sender);
        require(hasAccess, "VaultPermissionManager: insufficient permissions to view vault");

        vaultInfo = vaults[vaultOwner][vaultId];

        return (vaultInfo, hasAccess);
    }

    /**
     * @dev Internal function to check if user has view access to a vault
     * @param vaultOwner Owner of the vault
     * @param vaultId Vault identifier
     * @param accessor Address requesting access
     * @return Whether the accessor has view permissions
     */
    function _checkViewAccess(
        address vaultOwner,
        string memory vaultId,
        address accessor
    ) internal view returns (bool) {
        // Vault owner always has access
        if (accessor == vaultOwner) {
            return true;
        }

        // Check if accessor has an active permission with at least READ level
        uint256[] memory vaultPerms = vaultPermissions[vaultOwner][vaultId];

        for (uint256 i = 0; i < vaultPerms.length; i++) {
            VaultPermission memory perm = permissions[vaultPerms[i]];

            if (
                perm.delegate == accessor &&
                perm.isActive &&
                block.timestamp >= perm.startTime &&
                block.timestamp <= perm.endTime &&
                uint256(perm.level) >= uint256(PermissionLevel.READ)
            ) {
                return true;
            }
        }

        return false;
    }

    /**
     * @dev Gets all permissions for a vault
     * @param vaultOwner Owner of the vault
     * @param vaultId Vault identifier
     * @return Array of permission IDs
     */
    function getVaultPermissions(
        address vaultOwner,
        string memory vaultId
    ) external view returns (uint256[] memory) {
        return vaultPermissions[vaultOwner][vaultId];
    }

    /**
     * @dev Gets vault information
     * @param vaultOwner Owner of the vault
     * @param vaultId Vault identifier
     * @return Vault information
     */
    function getVaultInfo(
        address vaultOwner,
        string memory vaultId
    ) external view returns (VaultInfo memory) {
        return vaults[vaultOwner][vaultId];
    }

    /**
     * @dev Gets contract statistics
     * @return totalPermissionsCount Total number of permissions created
     * @return totalVaultsCount Total number of vaults created
     * @return activePermissionsCount Number of currently active permissions
     */
    function getStats()
        external
        view
        returns (
            uint256 totalPermissionsCount,
            uint256 totalVaultsCount,
            uint256 activePermissionsCount
        )
    {
        return (totalPermissions, totalVaults, activePermissions);
    }

    /**
     * @dev Upgrades the contract to a new implementation and calls a function on the new implementation.
     * This function is part of the UUPS (Universal Upgradeable Proxy Standard) pattern.
     * @param newImplementation The address of the new implementation contract
     * @param data The calldata to execute on the new implementation after upgrade
     * @notice Only the contract owner can perform upgrades for security
     * @notice This function is payable to support implementations that require ETH
     */
    function upgradeToAndCall(
        address newImplementation,
        bytes memory data
    ) public payable override onlyOwner {}

    /**
     * @dev Upgrades the contract to a new implementation.
     * This function is part of the UUPS (Universal Upgradeable Proxy Standard) pattern.
     * @param newImplementation The address of the new implementation contract
     * @notice Only the contract owner can perform upgrades for security
     * @notice Use upgradeToAndCall if you need to call initialization functions on the new implementation
     */
    function upgradeTo(address newImplementation) public override onlyOwner {}

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract.
     * Called by {upgradeTo} and {upgradeToAndCall}.
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
