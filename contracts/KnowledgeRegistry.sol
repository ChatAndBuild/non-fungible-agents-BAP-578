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

    /// @dev Reference to the AgentFactory contract for validation
    address public agentFactory;

    /// @dev Counter for knowledge source IDs
    CountersUpgradeable.Counter private _sourceIdCounter;

    /// @dev Mapping from agent contract -> token ID -> source ID -> KnowledgeSource
    mapping(address => mapping(uint256 => mapping(uint256 => KnowledgeSource)))
        public knowledgeSources;

    /// @dev Mapping from agent contract -> token ID -> array of source IDs
    mapping(address => mapping(uint256 => uint256[])) public agentSourceIds;

    /// @dev Mapping from agent contract -> token ID -> knowledge configuration
    mapping(address => mapping(uint256 => KnowledgeConfig)) public agentConfigs;

    /// @dev Mapping to track URI usage across agents (for deduplication)
    /// Maps URI hash to array of (agentContract, tokenId) packed as bytes32
    mapping(bytes32 => bytes32[]) public uriToAgents;

    /// @dev Default maximum sources per agent
    uint256 public defaultMaxSources;

    // ============ EVENTS ============

    event KnowledgeSourceAdded(
        address indexed agentContract,
        uint256 indexed tokenId,
        uint256 sourceId,
        string uri,
        KnowledgeType sourceType,
        uint256 priority
    );

    event KnowledgeSourceUpdated(
        address indexed agentContract,
        uint256 indexed tokenId,
        uint256 sourceId,
        string oldUri,
        string newUri
    );

    event KnowledgeSourceToggled(
        address indexed agentContract,
        uint256 indexed tokenId,
        uint256 sourceId,
        bool active
    );

    event KnowledgeSourceRemoved(
        address indexed agentContract,
        uint256 indexed tokenId,
        uint256 sourceId
    );

    event KnowledgeConfigUpdated(
        address indexed agentContract,
        uint256 indexed tokenId,
        uint256 maxSources,
        bool allowDynamicSources
    );

    event KnowledgePriorityChanged(
        address indexed agentContract,
        uint256 indexed tokenId,
        uint256 sourceId,
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
    modifier onlyTokenOwner(address agentContract, uint256 tokenId) {
        require(agentContract != address(0), "KnowledgeRegistry: invalid agent contract");
        IBAP578 agent = IBAP578(agentContract);
        IBAP578.State memory agentState = agent.getState(tokenId);
        require(agentState.owner == msg.sender, "KnowledgeRegistry: caller is not token owner");
        _;
    }

    /**
     * @dev Modifier to check if a source exists
     */
    modifier sourceExists(address agentContract, uint256 tokenId, uint256 sourceId) {
        require(
            knowledgeSources[agentContract][tokenId][sourceId].id == sourceId && sourceId != 0,
            "KnowledgeRegistry: source does not exist"
        );
        _;
    }

    /**
     * @dev Initializes the contract
     * @param agentFactoryAddress Address of the AgentFactory contract
     * @param defaultMaxSourcesValue Default maximum sources per agent
     */
    function initialize(
        address agentFactoryAddress,
        uint256 defaultMaxSourcesValue
    ) public initializer {
        require(
            agentFactoryAddress != address(0),
            "KnowledgeRegistry: invalid AgentFactory address"
        );
        require(defaultMaxSourcesValue > 0, "KnowledgeRegistry: invalid max sources");

        __Ownable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        agentFactory = agentFactoryAddress;
        defaultMaxSources = defaultMaxSourcesValue;
    }

    // ============ CORE FUNCTIONS ============

    /**
     * @dev Adds a new knowledge source for an agent
     * @param agentContract The address of the agent contract
     * @param tokenId The ID of the agent token
     * @param uri The URI of the knowledge source
     * @param sourceType The type of knowledge source
     * @param priority Priority of the source (higher = more important)
     * @param description Human-readable description
     * @param contentHash Hash of the content for verification
     */
    function addKnowledgeSource(
        address agentContract,
        uint256 tokenId,
        string memory uri,
        KnowledgeType sourceType,
        uint256 priority,
        string memory description,
        bytes32 contentHash
    ) external onlyTokenOwner(agentContract, tokenId) nonReentrant returns (uint256 sourceId) {
        require(bytes(uri).length > 0, "KnowledgeRegistry: empty URI");

        // Initialize config if needed
        if (agentConfigs[agentContract][tokenId].maxSources == 0) {
            agentConfigs[agentContract][tokenId].maxSources = defaultMaxSources;
            agentConfigs[agentContract][tokenId].allowDynamicSources = true;
        }

        KnowledgeConfig storage config = agentConfigs[agentContract][tokenId];
        require(config.totalSources < config.maxSources, "KnowledgeRegistry: max sources reached");

        // Check if dynamic sources are allowed for this type
        if (sourceType == KnowledgeType.DYNAMIC) {
            require(config.allowDynamicSources, "KnowledgeRegistry: dynamic sources not allowed");
        }

        _sourceIdCounter.increment();
        sourceId = _sourceIdCounter.current();

        // Store knowledge source
        _storeKnowledgeSource(
            agentContract,
            tokenId,
            sourceId,
            uri,
            sourceType,
            priority,
            description,
            contentHash
        );

        agentSourceIds[agentContract][tokenId].push(sourceId);
        config.totalSources++;
        config.activeSources++;

        // Track URI usage (simplified to avoid stack too deep)
        _trackUriUsage(uri, agentContract, tokenId);

        emit KnowledgeSourceAdded(agentContract, tokenId, sourceId, uri, sourceType, priority);

        return sourceId;
    }

    /**
     * @dev Internal function to store knowledge source (helps avoid stack too deep)
     */
    function _storeKnowledgeSource(
        address agentContract,
        uint256 tokenId,
        uint256 sourceId,
        string memory uri,
        KnowledgeType sourceType,
        uint256 priority,
        string memory description,
        bytes32 contentHash
    ) internal {
        knowledgeSources[agentContract][tokenId][sourceId] = KnowledgeSource({
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
    }

    /**
     * @dev Internal function to track URI usage (helps avoid stack too deep)
     */
    function _trackUriUsage(string memory uri, address agentContract, uint256 tokenId) internal {
        bytes32 uriHash = keccak256(abi.encodePacked(uri));
        bytes32 agentId = keccak256(abi.encodePacked(agentContract, tokenId));
        uriToAgents[uriHash].push(agentId);
    }

    /**
     * @dev Updates an existing knowledge source
     * @param agentContract The address of the agent contract
     * @param tokenId The ID of the agent token
     * @param sourceId The ID of the knowledge source
     * @param newUri The new URI
     * @param newContentHash New content hash
     */
    function updateKnowledgeSource(
        address agentContract,
        uint256 tokenId,
        uint256 sourceId,
        string memory newUri,
        bytes32 newContentHash
    )
        external
        onlyTokenOwner(agentContract, tokenId)
        sourceExists(agentContract, tokenId, sourceId)
        nonReentrant
    {
        require(bytes(newUri).length > 0, "KnowledgeRegistry: empty URI");

        // Store the old URI before updating
        string memory oldUri = knowledgeSources[agentContract][tokenId][sourceId].uri;

        // Update source fields
        _updateSourceFields(agentContract, tokenId, sourceId, newUri, newContentHash);

        // Handle URI tracking update if URI changed
        if (keccak256(abi.encodePacked(oldUri)) != keccak256(abi.encodePacked(newUri))) {
            _handleUriChange(oldUri, newUri, agentContract, tokenId);
        }

        emit KnowledgeSourceUpdated(agentContract, tokenId, sourceId, oldUri, newUri);
    }

    /**
     * @dev Internal function to update source fields (helps avoid stack too deep)
     */
    function _updateSourceFields(
        address agentContract,
        uint256 tokenId,
        uint256 sourceId,
        string memory newUri,
        bytes32 newContentHash
    ) internal {
        KnowledgeSource storage source = knowledgeSources[agentContract][tokenId][sourceId];
        source.uri = newUri;
        source.contentHash = newContentHash;
        source.version++;
        source.lastUpdated = block.timestamp;
    }

    /**
     * @dev Internal function to handle URI change in tracking
     */
    function _handleUriChange(
        string memory oldUri,
        string memory newUri,
        address agentContract,
        uint256 tokenId
    ) internal {
        bytes32 agentId = keccak256(abi.encodePacked(agentContract, tokenId));
        bytes32 oldUriHash = keccak256(abi.encodePacked(oldUri));
        bytes32 newUriHash = keccak256(abi.encodePacked(newUri));

        _removeFromUriTracking(oldUriHash, agentId);
        uriToAgents[newUriHash].push(agentId);
    }

    /**
     * @dev Toggles the active status of a knowledge source
     * @param agentContract The address of the agent contract
     * @param tokenId The ID of the agent token
     * @param sourceId The ID of the knowledge source
     */
    function toggleKnowledgeSource(
        address agentContract,
        uint256 tokenId,
        uint256 sourceId
    )
        external
        onlyTokenOwner(agentContract, tokenId)
        sourceExists(agentContract, tokenId, sourceId)
    {
        KnowledgeSource storage source = knowledgeSources[agentContract][tokenId][sourceId];
        source.active = !source.active;

        KnowledgeConfig storage config = agentConfigs[agentContract][tokenId];
        if (source.active) {
            config.activeSources++;
        } else {
            config.activeSources--;
        }

        emit KnowledgeSourceToggled(agentContract, tokenId, sourceId, source.active);
    }

    /**
     * @dev Changes the priority of a knowledge source
     * @param agentContract The address of the agent contract
     * @param tokenId The ID of the agent token
     * @param sourceId The ID of the knowledge source
     * @param newPriority The new priority
     */
    function changeKnowledgePriority(
        address agentContract,
        uint256 tokenId,
        uint256 sourceId,
        uint256 newPriority
    )
        external
        onlyTokenOwner(agentContract, tokenId)
        sourceExists(agentContract, tokenId, sourceId)
    {
        KnowledgeSource storage source = knowledgeSources[agentContract][tokenId][sourceId];
        uint256 oldPriority = source.priority;
        source.priority = newPriority;
        source.lastUpdated = block.timestamp;

        emit KnowledgePriorityChanged(agentContract, tokenId, sourceId, oldPriority, newPriority);
    }

    /**
     * @dev Removes a knowledge source
     * @param agentContract The address of the agent contract
     * @param tokenId The ID of the agent token
     * @param sourceId The ID of the knowledge source
     */
    function removeKnowledgeSource(
        address agentContract,
        uint256 tokenId,
        uint256 sourceId
    )
        external
        onlyTokenOwner(agentContract, tokenId)
        sourceExists(agentContract, tokenId, sourceId)
        nonReentrant
    {
        KnowledgeSource storage source = knowledgeSources[agentContract][tokenId][sourceId];

        // Update URI tracking (separated to avoid stack too deep)
        _removeSourceUriTracking(source.uri, agentContract, tokenId);

        // Update config
        KnowledgeConfig storage config = agentConfigs[agentContract][tokenId];
        config.totalSources--;
        if (source.active) {
            config.activeSources--;
        }

        // Remove from agent's source IDs array
        uint256[] storage sourceIds = agentSourceIds[agentContract][tokenId];
        for (uint256 i = 0; i < sourceIds.length; i++) {
            if (sourceIds[i] == sourceId) {
                sourceIds[i] = sourceIds[sourceIds.length - 1];
                sourceIds.pop();
                break;
            }
        }

        // Delete the source
        delete knowledgeSources[agentContract][tokenId][sourceId];

        emit KnowledgeSourceRemoved(agentContract, tokenId, sourceId);
    }

    /**
     * @dev Internal function to remove source URI tracking (helps avoid stack too deep)
     */
    function _removeSourceUriTracking(
        string memory uri,
        address agentContract,
        uint256 tokenId
    ) internal {
        bytes32 uriHash = keccak256(abi.encodePacked(uri));
        bytes32 agentId = keccak256(abi.encodePacked(agentContract, tokenId));
        _removeFromUriTracking(uriHash, agentId);
    }

    /**
     * @dev Updates the knowledge configuration for an agent
     * @param agentContract The address of the agent contract
     * @param tokenId The ID of the agent token
     * @param maxSources Maximum number of sources allowed
     * @param allowDynamicSources Whether dynamic sources are allowed
     */
    function updateKnowledgeConfig(
        address agentContract,
        uint256 tokenId,
        uint256 maxSources,
        bool allowDynamicSources
    ) external onlyTokenOwner(agentContract, tokenId) {
        require(maxSources > 0, "KnowledgeRegistry: invalid max sources");

        KnowledgeConfig storage config = agentConfigs[agentContract][tokenId];
        require(
            maxSources >= config.totalSources,
            "KnowledgeRegistry: max sources less than current total"
        );

        config.maxSources = maxSources;
        config.allowDynamicSources = allowDynamicSources;

        emit KnowledgeConfigUpdated(agentContract, tokenId, maxSources, allowDynamicSources);
    }

    // ============ VIEW FUNCTIONS ============

    /**
     * @dev Returns all knowledge sources for an agent
     * @param agentContract The address of the agent contract
     * @param tokenId The ID of the agent token
     * @return sources Array of knowledge sources
     */
    function getKnowledgeSources(
        address agentContract,
        uint256 tokenId
    ) external view returns (KnowledgeSource[] memory sources) {
        uint256[] memory sourceIds = agentSourceIds[agentContract][tokenId];
        sources = new KnowledgeSource[](sourceIds.length);

        for (uint256 i = 0; i < sourceIds.length; i++) {
            sources[i] = knowledgeSources[agentContract][tokenId][sourceIds[i]];
        }

        return sources;
    }

    /**
     * @dev Returns only active knowledge sources for an agent
     * @param agentContract The address of the agent contract
     * @param tokenId The ID of the agent token
     * @return sources Array of active knowledge sources
     */
    function getActiveKnowledgeSources(
        address agentContract,
        uint256 tokenId
    ) external view returns (KnowledgeSource[] memory sources) {
        uint256[] memory sourceIds = agentSourceIds[agentContract][tokenId];
        uint256 activeCount = 0;

        // Count active sources
        for (uint256 i = 0; i < sourceIds.length; i++) {
            if (knowledgeSources[agentContract][tokenId][sourceIds[i]].active) {
                activeCount++;
            }
        }

        // Populate active sources
        sources = new KnowledgeSource[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < sourceIds.length; i++) {
            KnowledgeSource memory source = knowledgeSources[agentContract][tokenId][sourceIds[i]];
            if (source.active) {
                sources[index++] = source;
            }
        }

        return sources;
    }

    /**
     * @dev Returns knowledge sources sorted by priority
     * @param agentContract The address of the agent contract
     * @param tokenId The ID of the agent token
     * @return sources Array of knowledge sources sorted by priority
     */
    function getKnowledgeSourcesByPriority(
        address agentContract,
        uint256 tokenId
    ) external view returns (KnowledgeSource[] memory sources) {
        sources = this.getActiveKnowledgeSources(agentContract, tokenId);

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
     * @param agentContract The address of the agent contract
     * @param tokenId The ID of the agent token
     * @param sourceType The type of knowledge sources to return
     * @return sources Array of knowledge sources of the specified type
     */
    function getKnowledgeSourcesByType(
        address agentContract,
        uint256 tokenId,
        KnowledgeType sourceType
    ) external view returns (KnowledgeSource[] memory sources) {
        uint256[] memory sourceIds = agentSourceIds[agentContract][tokenId];
        uint256 typeCount = 0;

        // Count sources of this type
        for (uint256 i = 0; i < sourceIds.length; i++) {
            if (knowledgeSources[agentContract][tokenId][sourceIds[i]].sourceType == sourceType) {
                typeCount++;
            }
        }

        // Populate sources of this type
        sources = new KnowledgeSource[](typeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < sourceIds.length; i++) {
            KnowledgeSource memory source = knowledgeSources[agentContract][tokenId][sourceIds[i]];
            if (source.sourceType == sourceType) {
                sources[index++] = source;
            }
        }

        return sources;
    }

    /**
     * @dev Returns the knowledge configuration for an agent
     * @param agentContract The address of the agent contract
     * @param tokenId The ID of the agent token
     * @return config The knowledge configuration
     */
    function getKnowledgeConfig(
        address agentContract,
        uint256 tokenId
    ) external view returns (KnowledgeConfig memory config) {
        config = agentConfigs[agentContract][tokenId];

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
     * @return agents Array of agent identifiers (packed agentContract+tokenId)
     */
    function getAgentsUsingUri(string memory uri) external view returns (bytes32[] memory agents) {
        bytes32 uriHash = keccak256(abi.encodePacked(uri));
        return uriToAgents[uriHash];
    }

    // ============ ADMIN FUNCTIONS ============

    /**
     * @dev Updates the default maximum sources per agent
     * @param newDefaultMaxSources New default maximum
     */
    function setDefaultMaxSources(uint256 newDefaultMaxSources) external onlyOwner {
        require(newDefaultMaxSources > 0, "KnowledgeRegistry: invalid max sources");
        defaultMaxSources = newDefaultMaxSources;
    }

    /**
     * @dev Updates the AgentFactory contract address
     * @param newAgentFactory New AgentFactory contract address
     */
    function updateAgentFactory(address newAgentFactory) external onlyOwner {
        require(newAgentFactory != address(0), "KnowledgeRegistry: invalid AgentFactory address");
        agentFactory = newAgentFactory;
    }

    // ============ INTERNAL FUNCTIONS ============

    /**
     * @dev Removes an agent ID from URI tracking
     * @param uriHash Hash of the URI
     * @param agentId Packed agent identifier (agentContract + tokenId)
     */
    function _removeFromUriTracking(bytes32 uriHash, bytes32 agentId) internal {
        bytes32[] storage agents = uriToAgents[uriHash];
        for (uint256 i = 0; i < agents.length; i++) {
            if (agents[i] == agentId) {
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
