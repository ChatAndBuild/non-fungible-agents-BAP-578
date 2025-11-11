// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./BAP578.sol";
import "./interfaces/IBAP578.sol";
import "./BAP578Treasury.sol";

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

    // The address of the BAP578Enhanced implementation contract
    address public implementation;

    // Default learning module for new agents
    address public defaultLearningModule;

    // Treasury contract for fee collection
    BAP578Treasury public treasury;

    // Circuit breaker for new agents
    address public circuitBreaker;

    // Agent creation fee (0.01 BNB as specified in documentation)
    uint256 public constant AGENT_CREATION_FEE = 0.01 ether;

    // Mapping of template addresses to their approval status
    mapping(address => bool) public approvedTemplates;

    // Mapping of template categories to their latest version
    mapping(string => mapping(string => address)) public templateVersions;

    // Mapping of learning modules to their approval status
    mapping(address => bool) public approvedLearningModules;

    // Mapping of learning module categories to their latest version
    mapping(string => address) public learningModuleVersions;

    // Global learning statistics
    LearningGlobalStats public globalLearningStats;
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
     * @dev Struct for enhanced agent creation parameters
     */
    struct AgentCreationParams {
        string name;
        string symbol;
        address logicAddress;
        string metadataURI;
        IBAP578.AgentMetadata extendedMetadata;
    }

    // Events
    event AgentCreated(
        address indexed agent,
        address indexed owner,
        uint256 tokenId,
        address logic
    );

    event TemplateApproved(address indexed template, string category, string version);
    event LearningModuleApproved(address indexed module, string category, string version);
    event GlobalLearningStatsUpdated(uint256 timestamp);
    event LearningConfigUpdated(uint256 timestamp);
    event AgentLearningEnabled(
        address indexed agent,
        uint256 indexed tokenId,
        address learningModule
    );
    event AgentLearningDisabled(address indexed agent, uint256 indexed tokenId);
    event AgentCreationFeeCollected(address indexed creator, uint256 amount);
    event FreeMintUsed(address indexed creator, address indexed agent);

    /**
     * @dev Initializes the contract
     * @dev This function can only be called once due to the initializer modifier
     * @param implementationAddr The address of the BAP578Enhanced implementation contract
     * @param ownerAddr The address of contract
     * @param defaultLearningModuleAddr The default learning module address
     */
    function initialize(
        address implementationAddr,
        address ownerAddr,
        address defaultLearningModuleAddr,
        address payable treasuryAddr,
        address circuitBreakerAddr
    ) public initializer {
        require(implementationAddr != address(0), "AgentFactory: implementation is zero address");
        require(ownerAddr != address(0), "AgentFactory: owner is zero address");
        require(
            defaultLearningModuleAddr != address(0),
            "AgentFactory: default learning module is zero address"
        );
        require(treasuryAddr != address(0), "AgentFactory: treasury is zero address");
        require(circuitBreakerAddr != address(0), "AgentFactory: circuit breaker is zero address");

        __Ownable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        implementation = implementationAddr;
        defaultLearningModule = defaultLearningModuleAddr;
        treasury = BAP578Treasury(treasuryAddr);
        circuitBreaker = circuitBreakerAddr;

        // Initialize global stats
        globalLearningStats = LearningGlobalStats({
            totalAgentsCreated: 0,
            totalLearningEnabledAgents: 0,
            totalLearningInteractions: 0,
            totalLearningModules: 0,
            averageGlobalConfidence: 0,
            lastStatsUpdate: block.timestamp
        });

        // Transfer ownership to owner
        _transferOwnership(ownerAddr);
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
        string calldata name,
        string calldata symbol,
        address logicAddress,
        string calldata metadataURI
    ) external payable returns (address agent) {
        // Create empty extended metadata
        IBAP578.AgentMetadata memory emptyMetadata = IBAP578.AgentMetadata({
            persona: "",
            experience: "",
            voiceHash: "",
            animationURI: "",
            vaultURI: "",
            vaultHash: bytes32(0)
        });

        // Call internal function with empty metadata
        return _createAgentInternal(name, symbol, logicAddress, metadataURI, emptyMetadata);
    }

    /**
     * @dev Creates a new agent with FREE MINTING (no fee required)
     * NOTE: Tracking of free mint usage should be done off-chain
     * @param name The name of the agent token collection
     * @param symbol The symbol of the agent token collection
     * @param logicAddress The address of the logic contract
     * @param metadataURI The URI for the agent's metadata
     * @return agent The address of the new agent contract
     */
    function createAgentFreeMint(
        string calldata name,
        string calldata symbol,
        address logicAddress,
        string calldata metadataURI
    ) external returns (address agent) {
        // Create empty extended metadata
        IBAP578.AgentMetadata memory emptyMetadata = IBAP578.AgentMetadata({
            persona: "",
            experience: "",
            voiceHash: "",
            animationURI: "",
            vaultURI: "",
            vaultHash: bytes32(0)
        });

        // Call internal function with free mint flag
        return _createAgentInternalFree(name, symbol, logicAddress, metadataURI, emptyMetadata);
    }

    /**
     * @dev Creates a new agent with extended metadata with FREE MINTING (no fee required)
     * NOTE: Tracking of free mint usage should be done off-chain
     * @param name The name of the agent token collection
     * @param symbol The symbol of the agent token collection
     * @param logicAddress The address of the logic contract
     * @param metadataURI The URI for the agent's metadata
     * @param extendedMetadata The extended metadata including vault information
     * @return agent The address of the new agent contract
     */
    function createAgentWithExtendedMetadataFreeMint(
        string calldata name,
        string calldata symbol,
        address logicAddress,
        string calldata metadataURI,
        IBAP578.AgentMetadata calldata extendedMetadata
    ) external returns (address agent) {
        return _createAgentInternalFree(name, symbol, logicAddress, metadataURI, extendedMetadata);
    }

    /**
     * @dev Creates a new agent with extended metadata including vault information
     * @param name The name of the agent token collection
     * @param symbol The symbol of the agent token collection
     * @param logicAddress The address of the logic contract
     * @param metadataURI The URI for the agent's metadata
     * @param extendedMetadata The extended metadata including vault information
     * @return agent The address of the new agent contract
     */
    function createAgentWithExtendedMetadata(
        string calldata name,
        string calldata symbol,
        address logicAddress,
        string calldata metadataURI,
        IBAP578.AgentMetadata calldata extendedMetadata
    ) external payable returns (address agent) {
        return _createAgentInternal(name, symbol, logicAddress, metadataURI, extendedMetadata);
    }

    /**
     * @dev Internal function to create a new agent with FREE MINTING (no fee)
     * @param name The name of the agent token collection
     * @param symbol The symbol of the agent token collection
     * @param logicAddress The address of the logic contract
     * @param metadataURI The URI for the agent's metadata
     * @param extendedMetadata The extended metadata for the agent
     * @return agent The address of the new agent contract
     */
    function _createAgentInternalFree(
        string calldata name,
        string calldata symbol,
        address logicAddress,
        string calldata metadataURI,
        IBAP578.AgentMetadata memory extendedMetadata
    ) internal returns (address agent) {
        // No fee verification needed for free mint
        // Refund any ETH accidentally sent
        if (msg.value > 0) {
            (bool refundSuccess, ) = msg.sender.call{ value: msg.value }("");
            require(refundSuccess, "AgentFactory: refund failed");
        }

        AgentCreationParams memory params = AgentCreationParams({
            name: name,
            symbol: symbol,
            logicAddress: logicAddress,
            metadataURI: metadataURI,
            extendedMetadata: extendedMetadata
        });

        agent = address(
            new ERC1967Proxy(
                implementation,
                abi.encodeWithSelector(
                    BAP578(payable(implementation)).initialize.selector,
                    params.name,
                    params.symbol,
                    circuitBreaker
                )
            )
        );

        // Prepare enhanced metadata
        IBAP578.AgentMetadata memory enhancedMetadata = IBAP578.AgentMetadata({
            persona: params.extendedMetadata.persona,
            experience: params.extendedMetadata.experience,
            voiceHash: params.extendedMetadata.voiceHash,
            animationURI: params.extendedMetadata.animationURI,
            vaultURI: params.extendedMetadata.vaultURI,
            vaultHash: params.extendedMetadata.vaultHash
        });

        uint256 tokenId = BAP578(payable(agent)).createAgent(
            msg.sender,
            params.logicAddress,
            params.metadataURI,
            enhancedMetadata
        );

        // Update global stats
        _updateGlobalStats(false);

        // Emit free mint event
        emit FreeMintUsed(msg.sender, agent);
        emit AgentCreated(agent, msg.sender, tokenId, params.logicAddress);

        return agent;
    }

    /**
     * @dev Internal function to create a new agent with extended metadata
     * @param name The name of the agent token collection
     * @param symbol The symbol of the agent token collection
     * @param logicAddress The address of the logic contract
     * @param metadataURI The URI for the agent's metadata
     * @param extendedMetadata The extended metadata for the agent
     * @return agent The address of the new agent contract
     */
    function _createAgentInternal(
        string calldata name,
        string calldata symbol,
        address logicAddress,
        string calldata metadataURI,
        IBAP578.AgentMetadata memory extendedMetadata
    ) internal returns (address agent) {
        // Verify fee payment
        require(msg.value == AGENT_CREATION_FEE, "AgentFactory: incorrect fee amount");

        // Collect fee and donate to treasury (this will trigger the 60/25/15 distribution)
        BAP578Treasury(treasury).donate{ value: AGENT_CREATION_FEE }("Agent creation fee");

        emit AgentCreationFeeCollected(msg.sender, AGENT_CREATION_FEE);

        AgentCreationParams memory params = AgentCreationParams({
            name: name,
            symbol: symbol,
            logicAddress: logicAddress,
            metadataURI: metadataURI,
            extendedMetadata: extendedMetadata
        });

        agent = address(
            new ERC1967Proxy(
                implementation,
                abi.encodeWithSelector(
                    BAP578(payable(implementation)).initialize.selector,
                    params.name,
                    params.symbol,
                    circuitBreaker // Use the stored circuit breaker address
                )
            )
        );

        // Prepare enhanced metadata with learning configuration
        IBAP578.AgentMetadata memory enhancedMetadata = IBAP578.AgentMetadata({
            persona: params.extendedMetadata.persona,
            experience: params.extendedMetadata.experience,
            voiceHash: params.extendedMetadata.voiceHash,
            animationURI: params.extendedMetadata.animationURI,
            vaultURI: params.extendedMetadata.vaultURI,
            vaultHash: params.extendedMetadata.vaultHash
        });

        uint256 tokenId = BAP578(payable(agent)).createAgent(
            msg.sender,
            params.logicAddress,
            params.metadataURI,
            enhancedMetadata
        );

        // Update global stats
        _updateGlobalStats(false);

        emit AgentCreated(agent, msg.sender, tokenId, params.logicAddress);

        return agent;
    }

    /**
     * @dev Sets the treasury contract address
     * @param newTreasury The new treasury contract address
     */
    function setTreasury(address payable newTreasury) external onlyOwner {
        require(newTreasury != address(0), "AgentFactory: treasury is zero address");
        treasury = BAP578Treasury(newTreasury);
    }

    /**
     * @dev Approves a new template
     * @param template The address of the template contract
     * @param category The category of the template
     * @param version The version of the template
     */
    function approveTemplate(
        address template,
        string calldata category,
        string calldata version
    ) external onlyOwner {
        require(template != address(0), "AgentFactory: template is zero address");

        approvedTemplates[template] = true;
        templateVersions[category][version] = template;

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
        string calldata category,
        string calldata version
    ) external onlyOwner {
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
    function revokeTemplate(address template) external onlyOwner {
        require(approvedTemplates[template], "AgentFactory: template not approved");
        approvedTemplates[template] = false;
    }

    /**
     * @dev Revokes approval for a learning module
     * @param module The address of the learning module contract
     */
    function revokeLearningModule(address module) external onlyOwner {
        require(approvedLearningModules[module], "AgentFactory: learning module not approved");
        approvedLearningModules[module] = false;
        globalLearningStats.totalLearningModules--;
    }

    /**
     * @dev Updates the default learning module
     * @param newDefaultModule The new default learning module address
     */
    function setDefaultLearningModule(address newDefaultModule) external onlyOwner {
        require(newDefaultModule != address(0), "AgentFactory: module is zero address");
        require(approvedLearningModules[newDefaultModule], "AgentFactory: module not approved");

        defaultLearningModule = newDefaultModule;
    }

    /**
     * @dev Updates the implementation address
     * @param newImplementation The address of the new implementation contract
     */
    function setImplementation(address newImplementation) external onlyOwner {
        require(newImplementation != address(0), "AgentFactory: implementation is zero address");
        implementation = newImplementation;
    }

    /**
     * @dev Gets the latest template for a category
     * @param category The category of the template
     * @return The address of the latest template
     */
    function getTemplateVersion(
        string calldata category,
        string calldata version
    ) external view returns (address) {
        address template = templateVersions[category][version];
        require(template != address(0), "AgentFactory: no template for category");
        return template;
    }

    /**
     * @dev Gets the latest learning module for a category
     * @param category The category of the learning module
     * @return The address of the latest learning module
     */
    function getLatestLearningModule(string calldata category) external view returns (address) {
        address module = learningModuleVersions[category];
        require(module != address(0), "AgentFactory: no learning module for category");
        return module;
    }

    /**
     * @dev Gets global learning statistics
     * @return The global learning statistics
     */
    function getGlobalLearningStats() external view returns (LearningGlobalStats memory) {
        return globalLearningStats;
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
     * @dev Upgrades the contract to a new implementation and calls a function on the new implementation.
     * Inherits the implementation from UUPSUpgradeable parent contract.
     * The _authorizeUpgrade function below controls access to this function.
     */
    // Function is inherited from UUPSUpgradeable and doesn't need to be re-implemented

    /**
     * @dev Upgrades the contract to a new implementation.
     * Inherits the implementation from UUPSUpgradeable parent contract.
     * The _authorizeUpgrade function below controls access to this function.
     */
    // Function is inherited from UUPSUpgradeable and doesn't need to be re-implemented

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract.
     * Called by {upgradeTo} and {upgradeToAndCall}.
     * @dev Only owner can authorize upgrades for enhanced security
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
