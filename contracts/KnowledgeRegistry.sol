// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "./interfaces/IBAP578.sol";

/**
 * @title KnowledgeRegistry
 * @dev Registry for managing multiple knowledge sources per agent with versioning and priority
 * @notice This contract allows NFA agents to register and manage multiple knowledge URLs/sources
 */
contract KnowledgeRegistry is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    // ============ STRUCTS ============

    /**
     * @dev Represents a knowledge source with its metadata
     */
    struct KnowledgeSource {
        uint256 id;
        string uri; // Knowledge source URI (IPFS, HTTP, etc.)
        KnowledgeType sourceType; // Type of knowledge
        uint256 version; // Version number
        uint256 priority; // Priority (higher = more important)
        bool active; // Whether this source is active
        uint256 addedAt; // Timestamp when added
        uint256 lastUpdated; // Last update timestamp
        string description; // Human-readable description
        bytes32 contentHash; // Hash of the content for verification
    }

    /**
     * @dev Types of knowledge sources
     */
    enum KnowledgeType {
        BASE, // Base training data
        CONTEXT, // Contextual information
        MEMORY, // Agent memories
        INSTRUCTION, // Instructions/prompts
        REFERENCE, // Reference documentation
        DYNAMIC // Dynamic/live data
    }

    /**
     * @dev Configuration for agent's knowledge management
     */
    struct KnowledgeConfig {
        uint256 maxSources; // Maximum number of sources
        bool allowDynamicSources; // Whether dynamic sources are allowed
        uint256 totalSources; // Total sources registered
        uint256 activeSources; // Number of active sources
    }

    // ============ STATE VARIABLES ============

    /// @dev Reference to the BAP578 token contract
    IBAP578 public bap578Token;

    /// @dev Counter for knowledge source IDs
    CountersUpgradeable.Counter private _sourceIdCounter;

    /// @dev Mapping from token ID to knowledge sources
    mapping(uint256 => mapping(uint256 => KnowledgeSource)) public knowledgeSources;

    /// @dev Mapping from token ID to array of source IDs
    mapping(uint256 => uint256[]) public agentSourceIds;

    /// @dev Mapping from token ID to knowledge configuration
    mapping(uint256 => KnowledgeConfig) public agentConfigs;

    /// @dev Mapping to track URI usage across agents (for deduplication)
    mapping(bytes32 => uint256[]) public uriToAgents;

    /// @dev Default maximum sources per agent
    uint256 public defaultMaxSources;

    // ============ EVENTS ============

    event KnowledgeSourceAdded(
        uint256 indexed tokenId,
        uint256 indexed sourceId,
        string uri,
        KnowledgeType sourceType,
        uint256 priority
    );

    event KnowledgeSourceUpdated(
        uint256 indexed tokenId,
        uint256 indexed sourceId,
        string oldUri,
        string newUri
    );

    event KnowledgeSourceToggled(uint256 indexed tokenId, uint256 indexed sourceId, bool active);

    event KnowledgeSourceRemoved(uint256 indexed tokenId, uint256 indexed sourceId);

    event KnowledgeConfigUpdated(
        uint256 indexed tokenId,
        uint256 maxSources,
        bool allowDynamicSources
    );

    event KnowledgePriorityChanged(
        uint256 indexed tokenId,
        uint256 indexed sourceId,
        uint256 oldPriority,
        uint256 newPriority
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Modifier to check if the caller is the owner of the specified token
     */
    modifier onlyTokenOwner(uint256 tokenId) {
        IBAP578.State memory agentState = bap578Token.getState(tokenId);
        require(agentState.owner == msg.sender, "KnowledgeRegistry: caller is not token owner");
        _;
    }

    /**
     * @dev Modifier to check if a source exists
     */
    modifier sourceExists(uint256 tokenId, uint256 sourceId) {
        require(
            knowledgeSources[tokenId][sourceId].id == sourceId && sourceId != 0,
            "KnowledgeRegistry: source does not exist"
        );
        _;
    }

    /**
     * @dev Initializes the contract
     * @param bap578TokenAddress Address of the BAP578 token contract
     * @param _defaultMaxSources Default maximum sources per agent
     */
    function initialize(address bap578TokenAddress, uint256 _defaultMaxSources) public initializer {
        require(bap578TokenAddress != address(0), "KnowledgeRegistry: invalid BAP578 address");
        require(_defaultMaxSources > 0, "KnowledgeRegistry: invalid max sources");

        __Ownable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        bap578Token = IBAP578(bap578TokenAddress);
        defaultMaxSources = _defaultMaxSources;
    }

    // ============ CORE FUNCTIONS ============

    /**
     * @dev Adds a new knowledge source for an agent
     * @param tokenId The ID of the agent token
     * @param uri The URI of the knowledge source
     * @param sourceType The type of knowledge source
     * @param priority Priority of the source (higher = more important)
     * @param description Human-readable description
     * @param contentHash Hash of the content for verification
     */
    function addKnowledgeSource(
        uint256 tokenId,
        string memory uri,
        KnowledgeType sourceType,
        uint256 priority,
        string memory description,
        bytes32 contentHash
    ) external onlyTokenOwner(tokenId) nonReentrant returns (uint256 sourceId) {
        require(bytes(uri).length > 0, "KnowledgeRegistry: empty URI");

        // Initialize config if needed
        if (agentConfigs[tokenId].maxSources == 0) {
            agentConfigs[tokenId].maxSources = defaultMaxSources;
            agentConfigs[tokenId].allowDynamicSources = true;
        }

        KnowledgeConfig storage config = agentConfigs[tokenId];
        require(config.totalSources < config.maxSources, "KnowledgeRegistry: max sources reached");

        // Check if dynamic sources are allowed for this type
        if (sourceType == KnowledgeType.DYNAMIC) {
            require(config.allowDynamicSources, "KnowledgeRegistry: dynamic sources not allowed");
        }

        _sourceIdCounter.increment();
        sourceId = _sourceIdCounter.current();

        knowledgeSources[tokenId][sourceId] = KnowledgeSource({
            id: sourceId,
            uri: uri,
            sourceType: sourceType,
            version: 1,
            priority: priority,
            active: true,
            addedAt: block.timestamp,
            lastUpdated: block.timestamp,
            description: description,
            contentHash: contentHash
        });

        agentSourceIds[tokenId].push(sourceId);
        config.totalSources++;
        config.activeSources++;

        // Track URI usage
        bytes32 uriHash = keccak256(abi.encodePacked(uri));
        uriToAgents[uriHash].push(tokenId);

        emit KnowledgeSourceAdded(tokenId, sourceId, uri, sourceType, priority);

        return sourceId;
    }

    /**
     * @dev Updates an existing knowledge source
     * @param tokenId The ID of the agent token
     * @param sourceId The ID of the knowledge source
     * @param newUri The new URI
     * @param newContentHash New content hash
     */
    function updateKnowledgeSource(
        uint256 tokenId,
        uint256 sourceId,
        string memory newUri,
        bytes32 newContentHash
    ) external onlyTokenOwner(tokenId) sourceExists(tokenId, sourceId) nonReentrant {
        require(bytes(newUri).length > 0, "KnowledgeRegistry: empty URI");

        KnowledgeSource storage source = knowledgeSources[tokenId][sourceId];
        string memory oldUri = source.uri;

        source.uri = newUri;
        source.contentHash = newContentHash;
        source.version++;
        source.lastUpdated = block.timestamp;

        // Update URI tracking
        bytes32 oldUriHash = keccak256(abi.encodePacked(oldUri));
        bytes32 newUriHash = keccak256(abi.encodePacked(newUri));

        // Remove old URI tracking if different
        if (oldUriHash != newUriHash) {
            _removeFromUriTracking(oldUriHash, tokenId);
            uriToAgents[newUriHash].push(tokenId);
        }

        emit KnowledgeSourceUpdated(tokenId, sourceId, oldUri, newUri);
    }

    /**
     * @dev Toggles the active status of a knowledge source
     * @param tokenId The ID of the agent token
     * @param sourceId The ID of the knowledge source
     */
    function toggleKnowledgeSource(
        uint256 tokenId,
        uint256 sourceId
    ) external onlyTokenOwner(tokenId) sourceExists(tokenId, sourceId) {
        KnowledgeSource storage source = knowledgeSources[tokenId][sourceId];
        source.active = !source.active;

        KnowledgeConfig storage config = agentConfigs[tokenId];
        if (source.active) {
            config.activeSources++;
        } else {
            config.activeSources--;
        }

        emit KnowledgeSourceToggled(tokenId, sourceId, source.active);
    }

    /**
     * @dev Changes the priority of a knowledge source
     * @param tokenId The ID of the agent token
     * @param sourceId The ID of the knowledge source
     * @param newPriority The new priority
     */
    function changeKnowledgePriority(
        uint256 tokenId,
        uint256 sourceId,
        uint256 newPriority
    ) external onlyTokenOwner(tokenId) sourceExists(tokenId, sourceId) {
        KnowledgeSource storage source = knowledgeSources[tokenId][sourceId];
        uint256 oldPriority = source.priority;
        source.priority = newPriority;
        source.lastUpdated = block.timestamp;

        emit KnowledgePriorityChanged(tokenId, sourceId, oldPriority, newPriority);
    }

    /**
     * @dev Removes a knowledge source
     * @param tokenId The ID of the agent token
     * @param sourceId The ID of the knowledge source
     */
    function removeKnowledgeSource(
        uint256 tokenId,
        uint256 sourceId
    ) external onlyTokenOwner(tokenId) sourceExists(tokenId, sourceId) nonReentrant {
        KnowledgeSource storage source = knowledgeSources[tokenId][sourceId];

        // Update URI tracking
        bytes32 uriHash = keccak256(abi.encodePacked(source.uri));
        _removeFromUriTracking(uriHash, tokenId);

        // Update config
        KnowledgeConfig storage config = agentConfigs[tokenId];
        config.totalSources--;
        if (source.active) {
            config.activeSources--;
        }

        // Remove from agent's source IDs array
        uint256[] storage sourceIds = agentSourceIds[tokenId];
        for (uint256 i = 0; i < sourceIds.length; i++) {
            if (sourceIds[i] == sourceId) {
                sourceIds[i] = sourceIds[sourceIds.length - 1];
                sourceIds.pop();
                break;
            }
        }

        // Delete the source
        delete knowledgeSources[tokenId][sourceId];

        emit KnowledgeSourceRemoved(tokenId, sourceId);
    }

    /**
     * @dev Updates the knowledge configuration for an agent
     * @param tokenId The ID of the agent token
     * @param maxSources Maximum number of sources allowed
     * @param allowDynamicSources Whether dynamic sources are allowed
     */
    function updateKnowledgeConfig(
        uint256 tokenId,
        uint256 maxSources,
        bool allowDynamicSources
    ) external onlyTokenOwner(tokenId) {
        require(maxSources > 0, "KnowledgeRegistry: invalid max sources");

        KnowledgeConfig storage config = agentConfigs[tokenId];
        require(
            maxSources >= config.totalSources,
            "KnowledgeRegistry: max sources less than current total"
        );

        config.maxSources = maxSources;
        config.allowDynamicSources = allowDynamicSources;

        emit KnowledgeConfigUpdated(tokenId, maxSources, allowDynamicSources);
    }

    // ============ VIEW FUNCTIONS ============

    /**
     * @dev Returns all knowledge sources for an agent
     * @param tokenId The ID of the agent token
     * @return sources Array of knowledge sources
     */
    function getKnowledgeSources(
        uint256 tokenId
    ) external view returns (KnowledgeSource[] memory sources) {
        uint256[] memory sourceIds = agentSourceIds[tokenId];
        sources = new KnowledgeSource[](sourceIds.length);

        for (uint256 i = 0; i < sourceIds.length; i++) {
            sources[i] = knowledgeSources[tokenId][sourceIds[i]];
        }

        return sources;
    }

    /**
     * @dev Returns only active knowledge sources for an agent
     * @param tokenId The ID of the agent token
     * @return sources Array of active knowledge sources
     */
    function getActiveKnowledgeSources(
        uint256 tokenId
    ) external view returns (KnowledgeSource[] memory sources) {
        uint256[] memory sourceIds = agentSourceIds[tokenId];
        uint256 activeCount = 0;

        // Count active sources
        for (uint256 i = 0; i < sourceIds.length; i++) {
            if (knowledgeSources[tokenId][sourceIds[i]].active) {
                activeCount++;
            }
        }

        // Populate active sources
        sources = new KnowledgeSource[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < sourceIds.length; i++) {
            KnowledgeSource memory source = knowledgeSources[tokenId][sourceIds[i]];
            if (source.active) {
                sources[index++] = source;
            }
        }

        return sources;
    }

    /**
     * @dev Returns knowledge sources sorted by priority
     * @param tokenId The ID of the agent token
     * @return sources Array of knowledge sources sorted by priority
     */
    function getKnowledgeSourcesByPriority(
        uint256 tokenId
    ) external view returns (KnowledgeSource[] memory sources) {
        sources = this.getActiveKnowledgeSources(tokenId);

        // Simple bubble sort for priority (descending)
        for (uint256 i = 0; i < sources.length; i++) {
            for (uint256 j = 0; j < sources.length - i - 1; j++) {
                if (sources[j].priority < sources[j + 1].priority) {
                    KnowledgeSource memory temp = sources[j];
                    sources[j] = sources[j + 1];
                    sources[j + 1] = temp;
                }
            }
        }

        return sources;
    }

    /**
     * @dev Returns knowledge sources of a specific type
     * @param tokenId The ID of the agent token
     * @param sourceType The type of knowledge sources to return
     * @return sources Array of knowledge sources of the specified type
     */
    function getKnowledgeSourcesByType(
        uint256 tokenId,
        KnowledgeType sourceType
    ) external view returns (KnowledgeSource[] memory sources) {
        uint256[] memory sourceIds = agentSourceIds[tokenId];
        uint256 typeCount = 0;

        // Count sources of this type
        for (uint256 i = 0; i < sourceIds.length; i++) {
            if (knowledgeSources[tokenId][sourceIds[i]].sourceType == sourceType) {
                typeCount++;
            }
        }

        // Populate sources of this type
        sources = new KnowledgeSource[](typeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < sourceIds.length; i++) {
            KnowledgeSource memory source = knowledgeSources[tokenId][sourceIds[i]];
            if (source.sourceType == sourceType) {
                sources[index++] = source;
            }
        }

        return sources;
    }

    /**
     * @dev Returns the knowledge configuration for an agent
     * @param tokenId The ID of the agent token
     * @return config The knowledge configuration
     */
    function getKnowledgeConfig(
        uint256 tokenId
    ) external view returns (KnowledgeConfig memory config) {
        config = agentConfigs[tokenId];

        // Return default config if not initialized
        if (config.maxSources == 0) {
            config.maxSources = defaultMaxSources;
            config.allowDynamicSources = true;
        }

        return config;
    }

    /**
     * @dev Returns all agents using a specific URI
     * @param uri The URI to check
     * @return agents Array of token IDs using this URI
     */
    function getAgentsUsingUri(string memory uri) external view returns (uint256[] memory agents) {
        bytes32 uriHash = keccak256(abi.encodePacked(uri));
        return uriToAgents[uriHash];
    }

    // ============ ADMIN FUNCTIONS ============

    /**
     * @dev Updates the default maximum sources per agent
     * @param _defaultMaxSources New default maximum
     */
    function setDefaultMaxSources(uint256 _defaultMaxSources) external onlyOwner {
        require(_defaultMaxSources > 0, "KnowledgeRegistry: invalid max sources");
        defaultMaxSources = _defaultMaxSources;
    }

    /**
     * @dev Updates the BAP578 token contract address
     * @param newBAP578Token New BAP578 token contract address
     */
    function updateBAP578Token(address newBAP578Token) external onlyOwner {
        require(newBAP578Token != address(0), "KnowledgeRegistry: invalid BAP578 address");
        bap578Token = IBAP578(newBAP578Token);
    }

    // ============ INTERNAL FUNCTIONS ============

    /**
     * @dev Removes a token ID from URI tracking
     * @param uriHash Hash of the URI
     * @param tokenId Token ID to remove
     */
    function _removeFromUriTracking(bytes32 uriHash, uint256 tokenId) internal {
        uint256[] storage agents = uriToAgents[uriHash];
        for (uint256 i = 0; i < agents.length; i++) {
            if (agents[i] == tokenId) {
                agents[i] = agents[agents.length - 1];
                agents.pop();
                break;
            }
        }
    }

    /**
     * @dev Authorizes an upgrade (UUPS pattern)
     * @param newImplementation Address of the new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
