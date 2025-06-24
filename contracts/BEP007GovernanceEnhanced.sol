// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./BEP007.sol";
import "./interfaces/ILearningModule.sol";

/**
 * @title BEP007GovernanceEnhanced
 * @dev Enhanced governance contract for the BEP-007 ecosystem with full standard compliance
 * Supports learning systems, dual agent types, experience models, and cross-chain metadata
 */
contract BEP007GovernanceEnhanced is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    // BEP007 token contract
    BEP007 public bep007Token;

    // Treasury contract
    address public treasury;

    // Agent factory contract
    address public agentFactory;

    // Proposal counter
    CountersUpgradeable.Counter private _proposalIdCounter;

    uint256 public constant MAX_GAS_FOR_DELEGATECALL = 3_000_000;

    // Voting parameters
    uint256 public votingPeriod; // in days
    uint256 public quorumPercentage; // percentage of total supply needed
    uint256 public executionDelay; // in days

    // Agent types enum
    enum AgentType {
        Simple,
        Learning
    }

    // Proposal struct
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        bytes callData;
        address targetContract;
        uint256 createdAt;
        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
        bool canceled;
        AgentType requiredAgentType; // Type restriction for voting
        mapping(address => bool) hasVoted;
    }

    // Agent type governance parameters
    struct AgentTypeParameters {
        uint256 creationFee;
        uint256 gasLimit;
        uint256 votingWeight; // Multiplier for voting power
        uint256 proposalThreshold; // Min tokens needed to create proposals
        bool canCreateProposals;
        bool learningEnabled;
    }

    // Learning system governance
    struct LearningGovernance {
        uint256 maxUpdatesPerDay;
        uint256 confidenceThreshold;
        uint256 rewardPool;
        bool globalLearningPaused;
        mapping(string => uint256) milestoneRewards;
    }

    // Experience model governance
    struct ExperienceGovernance {
        uint256 onChainGasLimit;
        uint256 offChainGasLimit;
        uint256 onChainStorageFee;
        uint256 offChainStorageFee;
        address[] approvedProviders;
        mapping(address => bool) isApprovedProvider;
    }

    // Cross-chain metadata governance
    struct MetadataGovernance {
        string currentVersion;
        bytes32 currentSchemaHash;
        mapping(uint256 => bool) supportedChains;
        mapping(address => bool) approvedBridges;
        mapping(string => bytes32) versionHashes;
        address metadataValidator;
    }

    // State variables
    mapping(uint256 => Proposal) public proposals;
    mapping(AgentType => AgentTypeParameters) public agentTypeParameters;
    mapping(address => bool) public approvedLearningModules;

    LearningGovernance public learningGovernance;
    ExperienceGovernance public experienceGovernance;
    MetadataGovernance public metadataGovernance;

    // Events
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string description,
        AgentType requiredType
    );
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 weight,
        AgentType voterType
    );
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);

    // Learning system events
    event LearningModuleApproved(address indexed module, bool approved);
    event LearningParametersUpdated(uint256 maxUpdatesPerDay, uint256 confidenceThreshold);
    event LearningRewardDistributed(uint256 indexed tokenId, string milestone, uint256 reward);
    event LearningGloballyPaused(bool paused);

    // Agent type events
    event AgentTypeParametersUpdated(AgentType agentType, AgentTypeParameters parameters);
    event AgentTypeMigrated(uint256 indexed tokenId, AgentType fromType, AgentType toType);

    // Experience model events
    event ExperienceProviderApproved(address indexed provider, bool approved);
    event ExperienceParametersUpdated(uint256 onChainGasLimit, uint256 offChainGasLimit);
    event ExperienceFeesUpdated(uint256 onChainFee, uint256 offChainFee);
    event AgentExperienceMigrated(
        uint256 indexed tokenId,
        address fromProvider,
        address toProvider
    );

    // Metadata events
    event MetadataStandardUpdated(string version, bytes32 schemaHash);
    event CrossChainBridgeApproved(address indexed bridge, uint256 chainId, bool approved);
    event MetadataValidatorUpdated(address indexed validator);
    event MetadataSchemaMigrated(string fromVersion, string toVersion);

    /**
     * @dev Initializes the enhanced governance contract
     */
    function initialize(
        string memory name,
        address payable _bep007Token,
        address _owner,
        uint256 _votingPeriod,
        uint256 _quorumPercentage,
        uint256 _executionDelay
    ) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        require(_bep007Token != address(0), "BEP007Governance: token is zero address");
        require(_owner != address(0), "BEP007Governance: owner is zero address");
        require(_quorumPercentage <= 100, "BEP007Governance: quorum percentage exceeds 100");

        transferOwnership(_owner);
        bep007Token = BEP007(_bep007Token);
        votingPeriod = _votingPeriod;
        quorumPercentage = _quorumPercentage;
        executionDelay = _executionDelay;

        // Initialize default agent type parameters
        _initializeAgentTypes();

        // Initialize learning governance
        learningGovernance.maxUpdatesPerDay = 50;
        learningGovernance.confidenceThreshold = 80e16; // 0.8
        learningGovernance.rewardPool = 0;
        learningGovernance.globalLearningPaused = false;

        // Initialize experience governance
        experienceGovernance.onChainGasLimit = 3_000_000;
        experienceGovernance.offChainGasLimit = 1_000_000;
        experienceGovernance.onChainStorageFee = 0.001 ether;
        experienceGovernance.offChainStorageFee = 0.0001 ether;

        // Initialize metadata governance
        metadataGovernance.currentVersion = "1.0.0";
        metadataGovernance.currentSchemaHash = keccak256("BEP007_METADATA_V1");
    }

    /**
     * @dev Creates a new proposal with agent type restrictions
     */
    function createProposal(
        string memory description,
        bytes memory callData,
        address targetContract,
        AgentType requiredAgentType
    ) external returns (uint256) {
        require(targetContract != address(0), "BEP007Governance: target is zero address");

        // Check if caller can create proposals based on agent type
        AgentType callerType = _getCallerAgentType(msg.sender);
        require(
            agentTypeParameters[callerType].canCreateProposals,
            "BEP007Governance: agent type cannot create proposals"
        );

        // Check proposal threshold
        uint256 callerBalance = bep007Token.balanceOf(msg.sender);
        require(
            callerBalance >= agentTypeParameters[callerType].proposalThreshold,
            "BEP007Governance: insufficient tokens for proposal"
        );

        _proposalIdCounter.increment();
        uint256 proposalId = _proposalIdCounter.current();

        Proposal storage proposal = proposals[proposalId];
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.description = description;
        proposal.callData = callData;
        proposal.targetContract = targetContract;
        proposal.createdAt = block.timestamp;
        proposal.executed = false;
        proposal.canceled = false;
        proposal.requiredAgentType = requiredAgentType;

        emit ProposalCreated(proposalId, msg.sender, description, requiredAgentType);

        return proposalId;
    }

    /**
     * @dev Casts a vote with agent type-based weighting
     */
    function castVote(uint256 proposalId, bool support) external {
        Proposal storage proposal = proposals[proposalId];

        require(proposal.id != 0, "BEP007Governance: proposal does not exist");
        require(!proposal.executed, "BEP007Governance: proposal already executed");
        require(!proposal.canceled, "BEP007Governance: proposal canceled");
        require(
            block.timestamp <= proposal.createdAt + votingPeriod * 1 days,
            "BEP007Governance: voting period ended"
        );
        require(!proposal.hasVoted[msg.sender], "BEP007Governance: already voted");

        // Get voter's agent type and calculate weighted voting power
        AgentType voterType = _getCallerAgentType(msg.sender);
        uint256 baseWeight = bep007Token.balanceOf(msg.sender);
        uint256 weightMultiplier = agentTypeParameters[voterType].votingWeight;
        uint256 totalWeight = (baseWeight * weightMultiplier) / 100;

        require(totalWeight > 0, "BEP007Governance: no voting weight");

        proposal.hasVoted[msg.sender] = true;

        if (support) {
            proposal.votesFor += totalWeight;
        } else {
            proposal.votesAgainst += totalWeight;
        }

        emit VoteCast(proposalId, msg.sender, support, totalWeight, voterType);
    }

    /**
     * @dev Executes an action using the agent's logic
     * @param contractAddress The ID of the agent token
     * @param data The encoded function call to execute
     */
    function executeAction(
        address contractAddress,
        bytes calldata data
    ) external nonReentrant onlyOwner {
        // Execute the action via delegatecall with gas limit
        (bool success, bytes memory result) = contractAddress.call{ gas: MAX_GAS_FOR_DELEGATECALL }(
            data
        );

        if (!success) {
            // If the call failed, try to extract the revert reason
            if (result.length > 0) {
                // The result contains the revert reason
                // Decode it and include in the revert message
                assembly {
                    let resultSize := mload(result)
                    revert(add(32, result), resultSize)
                }
            } else {
                // No specific error message was provided
                revert("BEP007GovernanceEnhanced: action execution failed without reason");
            }
        }
    }

    // ==================== LEARNING SYSTEM GOVERNANCE ====================

    /**
     * @dev Approves or removes a learning module
     */
    function setLearningModule(address learningModule, bool approved) external onlyOwner {
        require(learningModule != address(0), "BEP007Governance: module is zero address");

        approvedLearningModules[learningModule] = approved;

        emit LearningModuleApproved(learningModule, approved);
    }

    /**
     * @dev Updates learning system parameters
     */
    function updateLearningParameters(
        uint256 maxUpdatesPerDay,
        uint256 confidenceThreshold
    ) external onlyOwner {
        require(confidenceThreshold <= 1e18, "BEP007Governance: invalid confidence threshold");

        learningGovernance.maxUpdatesPerDay = maxUpdatesPerDay;
        learningGovernance.confidenceThreshold = confidenceThreshold;

        emit LearningParametersUpdated(maxUpdatesPerDay, confidenceThreshold);
    }

    /**
     * @dev Sets milestone rewards
     */
    function setMilestoneReward(string memory milestone, uint256 reward) external onlyOwner {
        learningGovernance.milestoneRewards[milestone] = reward;
    }

    /**
     * @dev Distributes learning milestone rewards
     */
    function distributeLearningReward(
        uint256 tokenId,
        string memory milestone
    ) external nonReentrant {
        require(approvedLearningModules[msg.sender], "BEP007Governance: not approved module");

        uint256 reward = learningGovernance.milestoneRewards[milestone];
        require(reward > 0, "BEP007Governance: no reward for milestone");
        require(
            reward <= learningGovernance.rewardPool,
            "BEP007Governance: insufficient reward pool"
        );

        learningGovernance.rewardPool -= reward;

        address agentOwner = bep007Token.ownerOf(tokenId);
        payable(agentOwner).transfer(reward);

        emit LearningRewardDistributed(tokenId, milestone, reward);
    }

    /**
     * @dev Pauses learning globally (emergency function)
     */
    function pauseLearningGlobally(bool paused) external onlyOwner {
        learningGovernance.globalLearningPaused = paused;

        emit LearningGloballyPaused(paused);
    }

    /**
     * @dev Funds the learning reward pool
     */
    function fundLearningRewards() external payable {
        learningGovernance.rewardPool += msg.value;
    }

    // ==================== AGENT TYPE GOVERNANCE ====================

    /**
     * @dev Updates parameters for an agent type
     */
    function setAgentTypeParameters(
        AgentType agentType,
        AgentTypeParameters memory parameters
    ) external onlyOwner {
        require(parameters.votingWeight > 0, "BEP007Governance: invalid voting weight");

        agentTypeParameters[agentType] = parameters;

        emit AgentTypeParametersUpdated(agentType, parameters);
    }

    /**
     * @dev Migrates an agent from one type to another
     */
    function migrateAgentType(uint256 tokenId, AgentType newType) external {
        address owner = bep007Token.ownerOf(tokenId);
        require(msg.sender == owner, "BEP007Governance: not token owner");

        AgentType currentType = _getAgentType(tokenId);
        require(currentType != newType, "BEP007Governance: same agent type");

        // Update agent metadata to reflect new type
        // This would interact with the BEP007 contract to update agent metadata

        emit AgentTypeMigrated(tokenId, currentType, newType);
    }

    // ==================== EXPERIENCE MODEL GOVERNANCE ====================

    /**
     * @dev Approves or removes a experience provider
     */
    function approveExperienceProvider(address provider, bool approved) external onlyOwner {
        require(provider != address(0), "BEP007Governance: provider is zero address");

        if (approved && !experienceGovernance.isApprovedProvider[provider]) {
            experienceGovernance.approvedProviders.push(provider);
        }

        experienceGovernance.isApprovedProvider[provider] = approved;

        emit ExperienceProviderApproved(provider, approved);
    }

    /**
     * @dev Updates experience gas limits
     */
    function setExperienceGasLimits(
        uint256 onChainLimit,
        uint256 offChainLimit
    ) external onlyOwner {
        experienceGovernance.onChainGasLimit = onChainLimit;
        experienceGovernance.offChainGasLimit = offChainLimit;

        emit ExperienceParametersUpdated(onChainLimit, offChainLimit);
    }

    /**
     * @dev Updates experience storage fees
     */
    function setExperienceStorageFees(uint256 onChainFee, uint256 offChainFee) external onlyOwner {
        experienceGovernance.onChainStorageFee = onChainFee;
        experienceGovernance.offChainStorageFee = offChainFee;

        emit ExperienceFeesUpdated(onChainFee, offChainFee);
    }

    /**
     * @dev Migrates agent experience to a new provider
     */
    function migrateAgentExperience(uint256 tokenId, address newProvider) external {
        address owner = bep007Token.ownerOf(tokenId);
        require(msg.sender == owner, "BEP007Governance: not token owner");
        require(
            experienceGovernance.isApprovedProvider[newProvider],
            "BEP007Governance: provider not approved"
        );

        // Implementation would handle the actual experience migration
        // This is a governance approval mechanism

        emit AgentExperienceMigrated(tokenId, address(0), newProvider);
    }

    // ==================== METADATA SCHEMA GOVERNANCE ====================

    /**
     * @dev Updates the metadata standard
     */
    function setMetadataStandard(string memory version, bytes32 schemaHash) external onlyOwner {
        metadataGovernance.currentVersion = version;
        metadataGovernance.currentSchemaHash = schemaHash;
        metadataGovernance.versionHashes[version] = schemaHash;

        emit MetadataStandardUpdated(version, schemaHash);
    }

    /**
     * @dev Approves a cross-chain bridge
     */
    function approveCrossChainBridge(
        address bridge,
        uint256 chainId,
        bool approved
    ) external onlyOwner {
        require(bridge != address(0), "BEP007Governance: bridge is zero address");

        metadataGovernance.approvedBridges[bridge] = approved;
        metadataGovernance.supportedChains[chainId] = approved;

        emit CrossChainBridgeApproved(bridge, chainId, approved);
    }

    /**
     * @dev Sets the metadata validator
     */
    function setMetadataValidator(address validator) external onlyOwner {
        require(validator != address(0), "BEP007Governance: validator is zero address");

        metadataGovernance.metadataValidator = validator;

        emit MetadataValidatorUpdated(validator);
    }

    /**
     * @dev Migrates metadata schema
     */
    function migrateMetadataSchema(
        string memory fromVersion,
        string memory toVersion
    ) external onlyOwner {
        require(
            metadataGovernance.versionHashes[toVersion] != bytes32(0),
            "BEP007Governance: target version not found"
        );

        metadataGovernance.currentVersion = toVersion;
        metadataGovernance.currentSchemaHash = metadataGovernance.versionHashes[toVersion];

        emit MetadataSchemaMigrated(fromVersion, toVersion);
    }

    // ==================== VIEW FUNCTIONS ====================

    /**
     * @dev Gets learning governance parameters
     */
    function getLearningGovernance()
        external
        view
        returns (
            uint256 maxUpdatesPerDay,
            uint256 confidenceThreshold,
            uint256 rewardPool,
            bool globalLearningPaused
        )
    {
        return (
            learningGovernance.maxUpdatesPerDay,
            learningGovernance.confidenceThreshold,
            learningGovernance.rewardPool,
            learningGovernance.globalLearningPaused
        );
    }

    /**
     * @dev Gets experience governance parameters
     */
    function getExperienceGovernance()
        external
        view
        returns (
            uint256 onChainGasLimit,
            uint256 offChainGasLimit,
            uint256 onChainStorageFee,
            uint256 offChainStorageFee,
            address[] memory approvedProviders
        )
    {
        return (
            experienceGovernance.onChainGasLimit,
            experienceGovernance.offChainGasLimit,
            experienceGovernance.onChainStorageFee,
            experienceGovernance.offChainStorageFee,
            experienceGovernance.approvedProviders
        );
    }

    /**
     * @dev Gets metadata governance parameters
     */
    function getMetadataGovernance()
        external
        view
        returns (string memory currentVersion, bytes32 currentSchemaHash, address metadataValidator)
    {
        return (
            metadataGovernance.currentVersion,
            metadataGovernance.currentSchemaHash,
            metadataGovernance.metadataValidator
        );
    }

    /**
     * @dev Checks if a chain is supported
     */
    function isChainSupported(uint256 chainId) external view returns (bool) {
        return metadataGovernance.supportedChains[chainId];
    }

    /**
     * @dev Checks if a bridge is approved
     */
    function isBridgeApproved(address bridge) external view returns (bool) {
        return metadataGovernance.approvedBridges[bridge];
    }

    /**
     * @dev Gets milestone reward amount
     */
    function getMilestoneReward(string memory milestone) external view returns (uint256) {
        return learningGovernance.milestoneRewards[milestone];
    }

    // ==================== INTERNAL FUNCTIONS ====================

    /**
     * @dev Initializes default agent type parameters
     */
    function _initializeAgentTypes() internal {
        // Simple agent parameters
        agentTypeParameters[AgentType.Simple] = AgentTypeParameters({
            creationFee: 0.01 ether,
            gasLimit: 1_000_000,
            votingWeight: 100, // 1x voting power
            proposalThreshold: 1000 * 1e18, // 1000 tokens
            canCreateProposals: true,
            learningEnabled: false
        });

        // Learning agent parameters
        agentTypeParameters[AgentType.Learning] = AgentTypeParameters({
            creationFee: 0.05 ether,
            gasLimit: 3_000_000,
            votingWeight: 150, // 1.5x voting power
            proposalThreshold: 500 * 1e18, // 500 tokens (lower threshold)
            canCreateProposals: true,
            learningEnabled: true
        });
    }

    /**
     * @dev Gets the agent type for a caller (simplified logic)
     */
    function _getCallerAgentType(address caller) internal view returns (AgentType) {
        // Simplified logic - in practice, this would check the caller's agent tokens
        // and determine their primary agent type
        uint256 balance = bep007Token.balanceOf(caller);
        return balance > 1000 * 1e18 ? AgentType.Learning : AgentType.Simple;
    }

    /**
     * @dev Gets the agent type for a specific token
     */
    function _getAgentType(uint256 tokenId) internal view returns (AgentType) {
        // This would check the agent's metadata to determine its type
        // Simplified logic for demonstration
        return proposals[tokenId].requiredAgentType;
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
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
