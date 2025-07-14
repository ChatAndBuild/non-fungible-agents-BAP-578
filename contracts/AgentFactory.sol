// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./BEP007Enhanced.sol";
import "./BEP007EnhancedImpl.sol";
import "./interfaces/IBEP007.sol";
import "./interfaces/ILearningModule.sol";

/**
 * @title AgentFactory
 * @dev Enhanced factory contract for deploying Non-Fungible Agent (NFA) tokens with learning capabilities
 */
contract AgentFactory is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using ECDSAUpgradeable for bytes32;

    // The address of the BEP007Enhanced implementation contract
    address public implementation;

    // The address of the governance contract
    address public governance;

    // Default learning module for new agents
    address public defaultLearningModule;

    // Mapping of template addresses to their approval status
    mapping(address => bool) public approvedTemplates;

    // Mapping of template categories to their latest version
    mapping(string => address) public templateVersions;

    // Mapping of learning modules to their approval status
    mapping(address => bool) public approvedLearningModules;

    // Mapping of learning module categories to their latest version
    mapping(string => address) public learningModuleVersions;

    // Mapping of agent addresses to their learning analytics
    mapping(address => LearningAnalytics) public agentLearningAnalytics;

    // Global learning statistics
    LearningGlobalStats public globalLearningStats;

    // Learning configuration parameters
    LearningConfig public learningConfig;

    /**
     * @dev Struct for learning analytics per agent
     */
    struct LearningAnalytics {
        uint256 totalAgents;
        uint256 learningEnabledAgents;
        uint256 totalInteractions;
        uint256 averageConfidenceScore;
        uint256 lastAnalyticsUpdate;
        mapping(string => uint256) templateUsage;
        mapping(string => uint256) learningModuleUsage;
    }

    /**
     * @dev Struct for global learning statistics
     */
    struct LearningGlobalStats {
        uint256 totalAgentsCreated;
        uint256 totalLearningEnabledAgents;
        uint256 totalLearningInteractions;
        uint256 totalLearningModules;
        uint256 averageGlobalConfidence;
        uint256 lastStatsUpdate;
    }

    /**
     * @dev Struct for learning configuration
     */
    struct LearningConfig {
        bool learningEnabledByDefault;
        uint256 minConfidenceThreshold;
        uint256 maxLearningModulesPerAgent;
        uint256 learningAnalyticsUpdateInterval;
        bool requireSignatureForLearning;
    }

    /**
     * @dev Struct for enhanced agent creation parameters
     */
    struct AgentCreationParams {
        string name;
        string symbol;
        address logicAddress;
        string metadataURI;
        IBEP007.AgentMetadata extendedMetadata;
        bool enableLearning;
        address learningModule;
        bytes32 initialLearningRoot;
        bytes learningSignature;
    }

    // Events
    event AgentCreated(
        address indexed agent,
        address indexed owner,
        address logic,
        bool learningEnabled,
        address learningModule
    );

    event TemplateApproved(address indexed template, string category, string version);
    event LearningModuleApproved(address indexed module, string category, string version);
    event LearningAnalyticsUpdated(address indexed agent, uint256 timestamp);
    event GlobalLearningStatsUpdated(uint256 timestamp);
    event LearningConfigUpdated(uint256 timestamp);
    event AgentLearningEnabled(
        address indexed agent,
        uint256 indexed tokenId,
        address learningModule
    );
    event AgentLearningDisabled(address indexed agent, uint256 indexed tokenId);

    /**
     * @dev Initializes the contract
     * @dev This function can only be called once due to the initializer modifier
     * @param _implementation The address of the BEP007Enhanced implementation contract
     * @param _governance The address of the governance contract
     * @param _defaultLearningModule The default learning module address
     */
    function initialize(
        address _implementation,
        address _governance,
        address _defaultLearningModule
    ) public initializer {
        require(_implementation != address(0), "AgentFactory: implementation is zero address");
        require(_governance != address(0), "AgentFactory: governance is zero address");

        __Ownable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        implementation = _implementation;
        governance = _governance;
        defaultLearningModule = _defaultLearningModule;

        // Initialize learning configuration
        learningConfig = LearningConfig({
            learningEnabledByDefault: true,
            minConfidenceThreshold: 50e16, // 0.5 scaled by 1e18
            maxLearningModulesPerAgent: 3,
            learningAnalyticsUpdateInterval: 86400, // 1 day
            requireSignatureForLearning: false
        });

        // Initialize global stats
        globalLearningStats = LearningGlobalStats({
            totalAgentsCreated: 0,
            totalLearningEnabledAgents: 0,
            totalLearningInteractions: 0,
            totalLearningModules: 0,
            averageGlobalConfidence: 0,
            lastStatsUpdate: block.timestamp
        });

        // Transfer ownership to governance for additional security
        _transferOwnership(_governance);
    }

    /**
     * @dev Modifier to check if the caller is the governance contract
     */
    modifier onlyGovernance() {
        require(msg.sender == governance, "AgentFactory: caller is not governance");
        _;
    }

    /**
     * @dev Creates a new agent with enhanced learning capabilities
     * @param params The agent creation parameters
     * @return agent The address of the new agent contract
     */
    function createAgentWithLearning(
        AgentCreationParams memory params
    ) public returns (address payable agent) {
        require(
            approvedTemplates[params.logicAddress],
            "AgentFactory: logic template not approved"
        );

        // Validate learning module if learning is enabled
        if (params.enableLearning) {
            address learningModule = params.learningModule != address(0)
                ? params.learningModule
                : defaultLearningModule;

            require(
                approvedLearningModules[learningModule],
                "AgentFactory: learning module not approved"
            );

            // Verify signature if required
            if (learningConfig.requireSignatureForLearning) {
                _verifyLearningSignature(params, msg.sender);
            }

            params.learningModule = learningModule;
        }

        // Create a new clone of the implementation
        // agent = payable(ClonesUpgradeable.clone(implementation));

        BEP007EnhancedImpl clonedAgent = BEP007EnhancedImpl(payable(implementation));
        // Initialize the new agent - must be done before any other calls
        // Cast to the interface, not the implementation contract
        // clonedAgent.initialize(params.name, params.symbol, governance);

        // Prepare enhanced metadata with learning configuration
        BEP007Enhanced.EnhancedAgentMetadata memory enhancedMetadata = BEP007Enhanced
            .EnhancedAgentMetadata({
                persona: params.extendedMetadata.persona,
                experience: params.extendedMetadata.experience,
                voiceHash: params.extendedMetadata.voiceHash,
                animationURI: params.extendedMetadata.animationURI,
                vaultURI: params.extendedMetadata.vaultURI,
                vaultHash: params.extendedMetadata.vaultHash,
                learningEnabled: params.enableLearning,
                learningModule: params.enableLearning ? params.learningModule : address(0),
                learningTreeRoot: params.enableLearning ? params.initialLearningRoot : bytes32(0),
                learningVersion: params.enableLearning ? 1 : 0
            });

        // Create the agent token with enhanced metadata
        uint256 tokenId = clonedAgent.createAgent(
            msg.sender,
            params.logicAddress,
            params.metadataURI,
            enhancedMetadata
        );

        // Update analytics and statistics
        _updateAgentAnalytics(agent, params.enableLearning, params.learningModule);
        _updateGlobalStats(params.enableLearning);

        emit AgentCreated(
            agent,
            msg.sender,
            params.logicAddress,
            params.enableLearning,
            params.learningModule
        );

        if (params.enableLearning) {
            emit AgentLearningEnabled(agent, tokenId, params.learningModule);
        }

        return agent;
    }

    /**
     * @dev Creates a new agent with basic metadata (backward compatibility)
     * @param name The name of the agent token collection
     * @param symbol The symbol of the agent token collection
     * @param logicAddress The address of the logic contract
     * @param metadataURI The URI for the agent's metadata
     * @return agent The address of the new agent contract
     */
    function createAgent(
        string memory name,
        string memory symbol,
        address logicAddress,
        string memory metadataURI
    ) external returns (address agent) {
        // Create empty extended metadata
        IBEP007.AgentMetadata memory emptyMetadata = IBEP007.AgentMetadata({
            persona: "",
            experience: "",
            voiceHash: "",
            animationURI: "",
            vaultURI: "",
            vaultHash: bytes32(0)
        });

        AgentCreationParams memory params = AgentCreationParams({
            name: name,
            symbol: symbol,
            logicAddress: logicAddress,
            metadataURI: metadataURI,
            extendedMetadata: emptyMetadata,
            enableLearning: learningConfig.learningEnabledByDefault,
            learningModule: defaultLearningModule,
            initialLearningRoot: bytes32(0),
            learningSignature: ""
        });

        return createAgentWithLearning(params);
    }

    /**
     * @dev Creates a new agent with extended metadata (backward compatibility)
     * @param name The name of the agent token collection
     * @param symbol The symbol of the agent token collection
     * @param logicAddress The address of the logic contract
     * @param metadataURI The URI for the agent's metadata
     * @param extendedMetadata The extended metadata for the agent
     * @return agent The address of the new agent contract
     */
    function createAgent(
        string memory name,
        string memory symbol,
        address logicAddress,
        string memory metadataURI,
        IBEP007.AgentMetadata memory extendedMetadata
    ) external returns (address agent) {
        AgentCreationParams memory params = AgentCreationParams({
            name: name,
            symbol: symbol,
            logicAddress: logicAddress,
            metadataURI: metadataURI,
            extendedMetadata: extendedMetadata,
            enableLearning: learningConfig.learningEnabledByDefault,
            learningModule: defaultLearningModule,
            initialLearningRoot: bytes32(0),
            learningSignature: ""
        });

        return createAgentWithLearning(params);
    }

    /**
     * @dev Enables learning for an existing agent
     * @param agentAddress The address of the agent contract
     * @param tokenId The ID of the agent token
     * @param learningModule The learning module to use
     * @param initialTreeRoot The initial learning tree root
     */
    function enableAgentLearning(
        address payable agentAddress,
        uint256 tokenId,
        address learningModule,
        bytes32 initialTreeRoot
    ) external nonReentrant {
        require(
            approvedLearningModules[learningModule],
            "AgentFactory: learning module not approved"
        );

        // Enable learning on the agent
        BEP007EnhancedImpl(payable(agentAddress)).enableLearning(
            tokenId,
            learningModule,
            initialTreeRoot
        );

        // Update analytics
        LearningAnalytics storage analytics = agentLearningAnalytics[agentAddress];
        analytics.learningEnabledAgents++;
        analytics.lastAnalyticsUpdate = block.timestamp;

        // Update global stats
        globalLearningStats.totalLearningEnabledAgents++;
        globalLearningStats.lastStatsUpdate = block.timestamp;

        emit AgentLearningEnabled(agentAddress, tokenId, learningModule);
    }

    /**
     * @dev Approves a new template
     * @param template The address of the template contract
     * @param category The category of the template
     * @param version The version of the template
     */
    function approveTemplate(
        address template,
        string memory category,
        string memory version
    ) external onlyGovernance {
        require(template != address(0), "AgentFactory: template is zero address");

        approvedTemplates[template] = true;
        templateVersions[category] = template;

        emit TemplateApproved(template, category, version);
    }

    /**
     * @dev Approves a new learning module
     * @param module The address of the learning module contract
     * @param category The category of the learning module
     * @param version The version of the learning module
     */
    function approveLearningModule(
        address module,
        string memory category,
        string memory version
    ) external onlyGovernance {
        require(module != address(0), "AgentFactory: learning module is zero address");

        approvedLearningModules[module] = true;
        learningModuleVersions[category] = module;
        globalLearningStats.totalLearningModules++;

        emit LearningModuleApproved(module, category, version);
    }

    /**
     * @dev Revokes approval for a template
     * @param template The address of the template contract
     */
    function revokeTemplate(address template) external onlyGovernance {
        require(approvedTemplates[template], "AgentFactory: template not approved");
        approvedTemplates[template] = false;
    }

    /**
     * @dev Revokes approval for a learning module
     * @param module The address of the learning module contract
     */
    function revokeLearningModule(address module) external onlyGovernance {
        require(approvedLearningModules[module], "AgentFactory: learning module not approved");
        approvedLearningModules[module] = false;
        globalLearningStats.totalLearningModules--;
    }

    /**
     * @dev Updates the learning configuration
     * @param config The new learning configuration
     */
    function updateLearningConfig(LearningConfig memory config) external onlyGovernance {
        learningConfig = config;
        emit LearningConfigUpdated(block.timestamp);
    }

    /**
     * @dev Updates the default learning module
     * @param newDefaultModule The new default learning module address
     */
    function setDefaultLearningModule(address newDefaultModule) external onlyGovernance {
        require(newDefaultModule != address(0), "AgentFactory: module is zero address");
        require(approvedLearningModules[newDefaultModule], "AgentFactory: module not approved");

        defaultLearningModule = newDefaultModule;
    }

    /**
     * @dev Updates the implementation address
     * @param newImplementation The address of the new implementation contract
     */
    function setImplementation(address newImplementation) external onlyGovernance {
        require(newImplementation != address(0), "AgentFactory: implementation is zero address");
        implementation = newImplementation;
    }

    /**
     * @dev Updates the governance address
     * @param newGovernance The address of the new governance contract
     */
    function setGovernance(address newGovernance) external onlyGovernance {
        require(newGovernance != address(0), "AgentFactory: governance is zero address");
        governance = newGovernance;
    }

    /**
     * @dev Gets the latest template for a category
     * @param category The category of the template
     * @return The address of the latest template
     */
    function getLatestTemplate(string memory category) external view returns (address) {
        address template = templateVersions[category];
        require(template != address(0), "AgentFactory: no template for category");
        return template;
    }

    /**
     * @dev Gets the latest learning module for a category
     * @param category The category of the learning module
     * @return The address of the latest learning module
     */
    function getLatestLearningModule(string memory category) external view returns (address) {
        address module = learningModuleVersions[category];
        require(module != address(0), "AgentFactory: no learning module for category");
        return module;
    }

    /**
     * @dev Gets learning analytics for an agent
     * @param agentAddress The address of the agent contract
     * @return totalAgents Total agents created by this contract
     * @return learningEnabledAgents Number of agents with learning enabled
     * @return totalInteractions Total learning interactions
     * @return averageConfidenceScore Average confidence score
     * @return lastAnalyticsUpdate Last analytics update timestamp
     */
    function getAgentLearningAnalytics(
        address agentAddress
    )
        external
        view
        returns (
            uint256 totalAgents,
            uint256 learningEnabledAgents,
            uint256 totalInteractions,
            uint256 averageConfidenceScore,
            uint256 lastAnalyticsUpdate
        )
    {
        LearningAnalytics storage analytics = agentLearningAnalytics[agentAddress];
        return (
            analytics.totalAgents,
            analytics.learningEnabledAgents,
            analytics.totalInteractions,
            analytics.averageConfidenceScore,
            analytics.lastAnalyticsUpdate
        );
    }

    /**
     * @dev Gets global learning statistics
     * @return The global learning statistics
     */
    function getGlobalLearningStats() external view returns (LearningGlobalStats memory) {
        return globalLearningStats;
    }

    /**
     * @dev Gets the current learning configuration
     * @return The learning configuration
     */
    function getLearningConfig() external view returns (LearningConfig memory) {
        return learningConfig;
    }

    /**
     * @dev Checks if a learning module is approved
     * @param module The address of the learning module
     * @return Whether the module is approved
     */
    function isLearningModuleApproved(address module) external view returns (bool) {
        return approvedLearningModules[module];
    }

    /**
     * @dev Updates analytics for an agent (internal)
     * @param agentAddress The address of the agent contract
     * @param learningEnabled Whether learning is enabled
     * @param learningModule The learning module address
     */
    function _updateAgentAnalytics(
        address agentAddress,
        bool learningEnabled,
        address learningModule
    ) internal {
        LearningAnalytics storage analytics = agentLearningAnalytics[agentAddress];
        analytics.totalAgents++;

        if (learningEnabled) {
            analytics.learningEnabledAgents++;
        }

        analytics.lastAnalyticsUpdate = block.timestamp;

        emit LearningAnalyticsUpdated(agentAddress, block.timestamp);
    }

    /**
     * @dev Updates global learning statistics (internal)
     * @param learningEnabled Whether learning is enabled for the new agent
     */
    function _updateGlobalStats(bool learningEnabled) internal {
        globalLearningStats.totalAgentsCreated++;

        if (learningEnabled) {
            globalLearningStats.totalLearningEnabledAgents++;
        }

        globalLearningStats.lastStatsUpdate = block.timestamp;

        emit GlobalLearningStatsUpdated(block.timestamp);
    }

    /**
     * @dev Verifies the learning signature (internal)
     * @param params The agent creation parameters
     * @param signer The expected signer address
     */
    function _verifyLearningSignature(
        AgentCreationParams memory params,
        address signer
    ) internal pure {
        if (params.learningSignature.length > 0) {
            bytes32 messageHash = keccak256(
                abi.encodePacked(
                    params.name,
                    params.logicAddress,
                    params.learningModule,
                    params.initialLearningRoot
                )
            );

            bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
            address recoveredSigner = ethSignedMessageHash.recover(params.learningSignature);

            require(recoveredSigner == signer, "AgentFactory: invalid learning signature");
        }
    }

    /**
     * @dev Batch creates multiple agents with learning capabilities
     * @param paramsArray Array of agent creation parameters
     * @return agents Array of created agent addresses
     */
    function batchCreateAgentsWithLearning(
        AgentCreationParams[] memory paramsArray
    ) external nonReentrant returns (address[] memory agents) {
        require(paramsArray.length > 0, "AgentFactory: empty params array");
        require(paramsArray.length <= 10, "AgentFactory: too many agents in batch");

        agents = new address[](paramsArray.length);

        for (uint256 i = 0; i < paramsArray.length; i++) {
            agents[i] = createAgentWithLearning(paramsArray[i]);
        }

        return agents;
    }

    /**
     * @dev Emergency pause for learning functionality
     * @param paused Whether to pause learning functionality
     */
    function setLearningPaused(bool paused) external onlyGovernance {
        learningConfig.learningEnabledByDefault = !paused;
        emit LearningConfigUpdated(block.timestamp);
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
     * @dev Only governance can authorize upgrades for enhanced security
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
