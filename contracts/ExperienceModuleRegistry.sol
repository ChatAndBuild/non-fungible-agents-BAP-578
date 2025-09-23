// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IBAP578.sol";

/**
 * @title ExperienceModuleRegistry
 * @dev Registry for managing external experience modules with cryptographic verification
 * @notice This contract allows NFA agents to register and manage external experience sources
 * that enable learning, adaptation, and enhanced capabilities without modifying core contracts.
 */
contract ExperienceModuleRegistry is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using ECDSAUpgradeable for bytes32;

    // ============ STRUCTS ============

    /**
     * @dev Represents an experience module with its configuration and metadata
     */
    struct ExperienceModule {
        address moduleAddress; // Address of the experience module contract
        bytes32 moduleHash; // Hash of the module's code/configuration
        string specification; // JSON specification of the module's capabilities
        ExperienceType experienceType; // Type of experience this module provides
        SecurityLevel securityLevel; // Security classification of the module
        bool active; // Whether the module is currently active
        uint256 registrationTime; // Timestamp when module was registered
        address creator; // Address of the module creator
        uint256 version; // Version number of the module
    }

    /**
     * @dev Experience module types based on BAP-578 standard
     */
    enum ExperienceType {
        STATIC, // Traditional static experience (no learning)
        ADAPTIVE, // Basic adaptive experience (simple learning)
        LEARNING, // Full learning capabilities (advanced AI)
        FEDERATED // Cross-agent learning support (collaborative)
    }

    /**
     * @dev Security levels for experience modules
     */
    enum SecurityLevel {
        EXPERIMENTAL, // For development and testing
        COMMUNITY, // Community-validated modules
        PROFESSIONAL, // Professionally audited
        ENTERPRISE // Enterprise-grade security
    }

    /**
     * @dev Represents an agent's experience configuration
     */
    struct AgentExperienceConfig {
        bool learningEnabled; // Whether learning is enabled for this agent
        ExperienceType preferredType; // Preferred experience type
        uint256 maxModules; // Maximum number of modules allowed
        uint256 lastUpdate; // Last time configuration was updated
    }

    // ============ STATE VARIABLES ============

    /// @dev Reference to the BAP578 token contract
    IBAP578 public bap578Token;

    /// @dev Mapping from token ID to registered experience modules
    mapping(uint256 => address[]) private _registeredModules;

    /// @dev Mapping from token ID to module address to approval status
    mapping(uint256 => mapping(address => bool)) private _approvedModules;

    /// @dev Mapping from token ID to module address to module metadata
    mapping(uint256 => mapping(address => string)) private _moduleMetadata;

    /// @dev Mapping from module address to ExperienceModule struct
    mapping(address => ExperienceModule) private _moduleRegistry;

    /// @dev Mapping from token ID to agent experience configuration
    mapping(uint256 => AgentExperienceConfig) private _agentConfigs;

    /// @dev Mapping from module address to usage count across all agents
    mapping(address => uint256) private _moduleUsageCount;

    /// @dev Array of all registered modules (for enumeration)
    address[] private _allModules;

    /// @dev Mapping from module address to index in _allModules
    mapping(address => uint256) private _moduleIndex;

    // ============ EVENTS ============

    event ModuleRegistered(
        uint256 indexed tokenId,
        address indexed moduleAddress,
        address indexed creator,
        ExperienceType experienceType,
        SecurityLevel securityLevel,
        string specification
    );

    event ModuleApproved(uint256 indexed tokenId, address indexed moduleAddress, bool approved);

    event ModuleMetadataUpdated(
        uint256 indexed tokenId,
        address indexed moduleAddress,
        string metadata
    );

    event AgentExperienceConfigUpdated(
        uint256 indexed tokenId,
        bool learningEnabled,
        ExperienceType preferredType,
        uint256 maxModules
    );

    event ModuleDeactivated(address indexed moduleAddress, string reason);

    event ModuleUsageUpdated(address indexed moduleAddress, uint256 newUsageCount);

    event ContractInitialized(address indexed bap578Token, uint256 timestamp);

    // ============ MODIFIERS ============

    /**
     * @dev Modifier to check if the caller is the owner of the specified token
     */
    modifier onlyTokenOwner(uint256 tokenId) {
        IBAP578.State memory agentState = bap578Token.getState(tokenId);
        require(
            agentState.owner == msg.sender,
            "ExperienceModuleRegistry: caller is not token owner"
        );
        _;
    }

    /**
     * @dev Modifier to check if a module exists in the registry
     */
    modifier moduleExists(address moduleAddress) {
        require(
            _moduleRegistry[moduleAddress].moduleAddress != address(0),
            "ExperienceModuleRegistry: module does not exist"
        );
        _;
    }

    /**
     * @dev Modifier to check if a module is active
     */
    modifier moduleActive(address moduleAddress) {
        require(
            _moduleRegistry[moduleAddress].active,
            "ExperienceModuleRegistry: module is not active"
        );
        _;
    }

    // ============ INITIALIZATION ============

    /**
     * @dev Constructor disables initializers to prevent implementation contract from being initialized
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract
     * @param bap578TokenAddress Address of the BAP578 token contract
     */
    function initialize(address bap578TokenAddress) public initializer {
        require(
            bap578TokenAddress != address(0),
            "ExperienceModuleRegistry: invalid BAP578 address"
        );

        __Ownable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        bap578Token = IBAP578(bap578TokenAddress);

        // Initialize state variables explicitly for security
        // Note: Mappings are automatically initialized in Solidity, but we document this for clarity
        // _registeredModules, _approvedModules, and _moduleMetadata are automatically initialized as empty mappings

        // Emit event to confirm successful initialization
        emit ContractInitialized(bap578TokenAddress, block.timestamp);
    }

    // ============ CORE FUNCTIONS ============

    /**
     * @dev Registers a new experience module for an agent with cryptographic verification
     * @param tokenId The ID of the agent token
     * @param moduleAddress Address of the experience module contract
     * @param moduleHash Hash of the module's code/configuration
     * @param specification JSON specification of the module's capabilities
     * @param experienceType Type of experience this module provides
     * @param securityLevel Security classification of the module
     * @param metadata Additional metadata for the module
     * @param signature Cryptographic signature from the token owner
     */
    function registerModule(
        uint256 tokenId,
        address moduleAddress,
        bytes32 moduleHash,
        string memory specification,
        ExperienceType experienceType,
        SecurityLevel securityLevel,
        string memory metadata,
        bytes memory signature
    ) external nonReentrant {
        require(moduleAddress != address(0), "ExperienceModuleRegistry: invalid module address");
        require(bytes(specification).length > 0, "ExperienceModuleRegistry: empty specification");

        // Verify signature and get signer
        address signer = _verifySignature(
            tokenId,
            moduleAddress,
            moduleHash,
            specification,
            experienceType,
            securityLevel,
            metadata,
            signature
        );

        // Register module in global registry if new
        _registerGlobalModule(
            moduleAddress,
            moduleHash,
            specification,
            experienceType,
            securityLevel,
            signer,
            tokenId
        );

        // Add module to agent's registry if not already present
        _addModuleToAgent(tokenId, moduleAddress, metadata);
    }

    /**
     * @dev Verifies the signature and returns the signer address
     */
    function _verifySignature(
        uint256 tokenId,
        address moduleAddress,
        bytes32 moduleHash,
        string memory specification,
        ExperienceType experienceType,
        SecurityLevel securityLevel,
        string memory metadata,
        bytes memory signature
    ) private view returns (address) {
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                tokenId,
                moduleAddress,
                moduleHash,
                specification,
                uint256(experienceType),
                uint256(securityLevel),
                metadata
            )
        );
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        address signer = ethSignedMessageHash.recover(signature);

        IBAP578.State memory agentState = bap578Token.getState(tokenId);
        require(signer == agentState.owner, "ExperienceModuleRegistry: invalid signature");

        return signer;
    }

    /**
     * @dev Registers a module in the global registry if it doesn't exist
     */
    function _registerGlobalModule(
        address moduleAddress,
        bytes32 moduleHash,
        string memory specification,
        ExperienceType experienceType,
        SecurityLevel securityLevel,
        address signer,
        uint256 tokenId
    ) private {
        if (_moduleRegistry[moduleAddress].moduleAddress == address(0)) {
            _moduleRegistry[moduleAddress] = ExperienceModule({
                moduleAddress: moduleAddress,
                moduleHash: moduleHash,
                specification: specification,
                experienceType: experienceType,
                securityLevel: securityLevel,
                active: true,
                registrationTime: block.timestamp,
                creator: signer,
                version: 1
            });

            _allModules.push(moduleAddress);
            _moduleIndex[moduleAddress] = _allModules.length - 1;

            emit ModuleRegistered(
                tokenId,
                moduleAddress,
                signer,
                experienceType,
                securityLevel,
                specification
            );
        }
    }

    /**
     * @dev Adds a module to an agent's registry if not already present
     */
    function _addModuleToAgent(
        uint256 tokenId,
        address moduleAddress,
        string memory metadata
    ) private {
        address[] storage agentModules = _registeredModules[tokenId];
        bool alreadyRegistered = false;

        for (uint256 i = 0; i < agentModules.length; i++) {
            if (agentModules[i] == moduleAddress) {
                alreadyRegistered = true;
                break;
            }
        }

        if (!alreadyRegistered) {
            agentModules.push(moduleAddress);
            _moduleMetadata[tokenId][moduleAddress] = metadata;
            _moduleUsageCount[moduleAddress]++;
            emit ModuleUsageUpdated(moduleAddress, _moduleUsageCount[moduleAddress]);
        }
    }

    /**
     * @dev Sets the approval status for a module for a specific agent
     * @param tokenId The ID of the agent token
     * @param moduleAddress Address of the experience module
     * @param approved Whether the module is approved for use
     */
    function setModuleApproval(
        uint256 tokenId,
        address moduleAddress,
        bool approved
    ) external onlyTokenOwner(tokenId) moduleExists(moduleAddress) {
        _approvedModules[tokenId][moduleAddress] = approved;
        emit ModuleApproved(tokenId, moduleAddress, approved);
    }

    /**
     * @dev Updates the metadata for a module for a specific agent
     * @param tokenId The ID of the agent token
     * @param moduleAddress Address of the experience module
     * @param metadata New metadata for the module
     */
    function updateModuleMetadata(
        uint256 tokenId,
        address moduleAddress,
        string memory metadata
    ) external onlyTokenOwner(tokenId) moduleExists(moduleAddress) {
        require(
            _approvedModules[tokenId][moduleAddress],
            "ExperienceModuleRegistry: module not approved"
        );

        _moduleMetadata[tokenId][moduleAddress] = metadata;
        emit ModuleMetadataUpdated(tokenId, moduleAddress, metadata);
    }

    /**
     * @dev Updates the experience configuration for an agent
     * @param tokenId The ID of the agent token
     * @param learningEnabled Whether learning is enabled
     * @param preferredType Preferred experience type
     * @param maxModules Maximum number of modules allowed
     */
    function updateAgentExperienceConfig(
        uint256 tokenId,
        bool learningEnabled,
        ExperienceType preferredType,
        uint256 maxModules
    ) external onlyTokenOwner(tokenId) {
        require(maxModules > 0, "ExperienceModuleRegistry: maxModules must be greater than 0");

        _agentConfigs[tokenId] = AgentExperienceConfig({
            learningEnabled: learningEnabled,
            preferredType: preferredType,
            maxModules: maxModules,
            lastUpdate: block.timestamp
        });

        emit AgentExperienceConfigUpdated(tokenId, learningEnabled, preferredType, maxModules);
    }

    /**
     * @dev Deactivates a module (only by module creator or contract owner)
     * @param moduleAddress Address of the module to deactivate
     * @param reason Reason for deactivation
     */
    function deactivateModule(
        address moduleAddress,
        string memory reason
    ) external moduleExists(moduleAddress) {
        require(
            msg.sender == _moduleRegistry[moduleAddress].creator || msg.sender == owner(),
            "ExperienceModuleRegistry: not authorized to deactivate"
        );

        _moduleRegistry[moduleAddress].active = false;
        emit ModuleDeactivated(moduleAddress, reason);
    }

    // ============ VIEW FUNCTIONS ============

    /**
     * @dev Returns all registered modules for a specific agent
     * @param tokenId The ID of the agent token
     * @return Array of module addresses
     */
    function getRegisteredModules(uint256 tokenId) external view returns (address[] memory) {
        return _registeredModules[tokenId];
    }

    /**
     * @dev Returns all approved modules for a specific agent
     * @param tokenId The ID of the agent token
     * @return Array of approved module addresses
     */
    function getApprovedModules(uint256 tokenId) external view returns (address[] memory) {
        address[] memory registered = _registeredModules[tokenId];
        address[] memory approved = new address[](registered.length);
        uint256 approvedCount = 0;

        uint256 registeredLength = registered.length;
        for (uint256 i = 0; i < registeredLength; i++) {
            if (_approvedModules[tokenId][registered[i]]) {
                approved[approvedCount] = registered[i];
                approvedCount++;
            }
        }

        // Resize array to actual approved count
        address[] memory result = new address[](approvedCount);
        for (uint256 i = 0; i < approvedCount; i++) {
            result[i] = approved[i];
        }

        return result;
    }

    /**
     * @dev Checks if a module is approved for a specific agent
     * @param tokenId The ID of the agent token
     * @param moduleAddress Address of the experience module
     * @return True if the module is approved
     */
    function isModuleApproved(uint256 tokenId, address moduleAddress) external view returns (bool) {
        return _approvedModules[tokenId][moduleAddress];
    }

    /**
     * @dev Returns the metadata for a module for a specific agent
     * @param tokenId The ID of the agent token
     * @param moduleAddress Address of the experience module
     * @return Metadata string
     */
    function getModuleMetadata(
        uint256 tokenId,
        address moduleAddress
    ) external view returns (string memory) {
        return _moduleMetadata[tokenId][moduleAddress];
    }

    /**
     * @dev Returns the full module information from the global registry
     * @param moduleAddress Address of the experience module
     * @return ExperienceModule struct
     */
    function getModuleInfo(
        address moduleAddress
    ) external view moduleExists(moduleAddress) returns (ExperienceModule memory) {
        return _moduleRegistry[moduleAddress];
    }

    /**
     * @dev Returns the experience configuration for an agent
     * @param tokenId The ID of the agent token
     * @return AgentExperienceConfig struct
     */
    function getAgentExperienceConfig(
        uint256 tokenId
    ) external view returns (AgentExperienceConfig memory) {
        return _agentConfigs[tokenId];
    }

    /**
     * @dev Returns the usage count for a module across all agents
     * @param moduleAddress Address of the experience module
     * @return Usage count
     */
    function getModuleUsageCount(address moduleAddress) external view returns (uint256) {
        return _moduleUsageCount[moduleAddress];
    }

    /**
     * @dev Returns all modules in the global registry
     * @return Array of all module addresses
     */
    function getAllModules() external view returns (address[] memory) {
        return _allModules;
    }

    /**
     * @dev Returns modules by experience type
     * @param experienceType The experience type to filter by
     * @return Array of module addresses matching the type
     */
    function getModulesByType(
        ExperienceType experienceType
    ) external view returns (address[] memory) {
        uint256 modulesLength = _allModules.length;
        address[] memory result = new address[](modulesLength);
        uint256 count = 0;

        for (uint256 i = 0; i < modulesLength; i++) {
            ExperienceModule storage module = _moduleRegistry[_allModules[i]];
            if (module.active && module.experienceType == experienceType) {
                result[count] = _allModules[i];
                count++;
            }
        }

        // Resize array to actual count
        address[] memory finalResult = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            finalResult[i] = result[i];
        }

        return finalResult;
    }

    /**
     * @dev Returns modules by security level
     * @param securityLevel The security level to filter by
     * @return Array of module addresses matching the security level
     */
    function getModulesBySecurityLevel(
        SecurityLevel securityLevel
    ) external view returns (address[] memory) {
        uint256 modulesLength = _allModules.length;
        address[] memory result = new address[](modulesLength);
        uint256 count = 0;

        for (uint256 i = 0; i < modulesLength; i++) {
            ExperienceModule storage module = _moduleRegistry[_allModules[i]];
            if (module.active && module.securityLevel == securityLevel) {
                result[count] = _allModules[i];
                count++;
            }
        }

        // Resize array to actual count
        address[] memory finalResult = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            finalResult[i] = result[i];
        }

        return finalResult;
    }

    /**
     * @dev Returns the total number of registered modules
     * @return Total count of modules
     */
    function getTotalModuleCount() external view returns (uint256) {
        return _allModules.length;
    }

    // ============ ADMIN FUNCTIONS ============

    /**
     * @dev Updates the BAP578 token contract address (only owner)
     * @param newBAP578Token New BAP578 token contract address
     */
    function updateBAP578Token(address newBAP578Token) external onlyOwner {
        require(newBAP578Token != address(0), "ExperienceModuleRegistry: invalid BAP578 address");
        bap578Token = IBAP578(newBAP578Token);
    }

    /**
     * @dev Authorizes an upgrade (UUPS pattern)
     * @param newImplementation Address of the new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ============ UTILITY FUNCTIONS ============

    /**
     * @dev Validates that a module specification is properly formatted
     * @param specification The JSON specification to validate
     * @return True if the specification is valid
     */
    function validateModuleSpecification(string memory specification) external pure returns (bool) {
        bytes memory specBytes = bytes(specification);
        if (specBytes.length == 0) return false;

        // Basic JSON validation - check for required fields
        string memory spec = string(specBytes);
        return
            bytes(spec).length > 0 &&
            _containsString(spec, "context_id") &&
            _containsString(spec, "persona") &&
            _containsString(spec, "experience_slots");
    }

    /**
     * @dev Helper function to check if a string contains a substring
     * @param str The string to search in
     * @param substr The substring to search for
     * @return True if the substring is found
     */
    function _containsString(string memory str, string memory substr) private pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory substrBytes = bytes(substr);

        if (substrBytes.length > strBytes.length) return false;

        for (uint256 i = 0; i <= strBytes.length - substrBytes.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < substrBytes.length; j++) {
                if (strBytes[i + j] != substrBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return true;
        }
        return false;
    }
}
