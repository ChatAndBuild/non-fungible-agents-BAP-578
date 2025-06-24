// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "./interfaces/IBEP007.sol";
import "./interfaces/ILearningModule.sol";
/**
 * @title BEP007Enhanced - Enhanced Non-Fungible Agent (NFA) Token Standard with Learning
 * @dev Implementation of the enhanced BEP-007 standard with optional learning capabilities
 */
abstract contract BEP007Enhanced is
    IBEP007,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    // Token ID counter
    CountersUpgradeable.Counter private _tokenIdCounter;

    // Governance contract address
    address public governance;

    // Experience module registry address
    address public experienceModuleRegistry;

    // Mapping from token ID to agent state
    mapping(uint256 => State) internal _agentStates;

    // Mapping from token ID to agent metadata URI
    mapping(uint256 => string) internal _agentMetadataURIs;

    // Mapping from token ID to extended agent metadata
    mapping(uint256 => EnhancedAgentMetadata) internal _agentExtendedMetadata;

    // Mapping from token ID to learning module address
    mapping(uint256 => address) private _learningModules;

    // Circuit breaker for emergency pause
    bool public globalPause;

    // Gas limit for delegatecall to prevent out-of-gas attacks
    uint256 public constant MAX_GAS_FOR_DELEGATECALL = 3_000_000;

    /**
     * @dev Enhanced AgentMetadata structure with learning capabilities
     */
    struct EnhancedAgentMetadata {
        string persona; // JSON-encoded string for character traits, style, tone
        string experience; // Short summary string for agent's role/purpose
        string voiceHash; // Reference ID to stored audio profile
        string animationURI; // URI to video or animation file
        string vaultURI; // URI to the agent's vault (extended data storage)
        bytes32 vaultHash; // Hash of the vault contents for verification
        // Learning enhancements
        bool learningEnabled; // Whether learning is enabled for this agent
        address learningModule; // Address of the learning module contract
        bytes32 learningTreeRoot; // Merkle root of the learning tree
        uint256 learningVersion; // Version of the learning implementation
    }

    /**
     * @dev Event emitted when learning is enabled for an agent
     */
    event LearningEnabled(uint256 indexed tokenId, address indexed learningModule);

    /**
     * @dev Event emitted when learning module is updated
     */
    event LearningModuleUpdated(
        uint256 indexed tokenId,
        address indexed oldModule,
        address indexed newModule
    );

    /**
     * @dev Modifier to check if the caller is the governance contract
     */
    modifier onlyGovernance() {
        require(msg.sender == governance, "BEP007Enhanced: caller is not governance");
        _;
    }

    /**
     * @dev Modifier to check if the caller is the owner of the token
     */
    modifier onlyAgentOwner(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender, "BEP007Enhanced: caller is not agent owner");
        _;
    }

    /**
     * @dev Modifier to check if the agent is active
     */
    modifier whenAgentActive(uint256 tokenId) {
        require(!globalPause, "BEP007Enhanced: global pause active");
        require(_agentStates[tokenId].status == Status.Active, "BEP007Enhanced: agent not active");
        _;
    }

    /**
     * @dev Initializes the contract
     * @dev This function can only be called once due to the initializer modifier
     */
    function initialize(
        string memory name,
        string memory symbol,
        address governanceAddress
    ) public virtual initializer {
        require(governanceAddress != address(0), "BEP007Enhanced: governance address is zero");

        __ERC721_init(name, symbol);
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();
        __ReentrancyGuard_init();
        __Ownable_init();
        __UUPSUpgradeable_init();

        governance = governanceAddress;
        globalPause = false;

        // Transfer ownership to governance for additional security
        _transferOwnership(governanceAddress);
    }

    /**
     * @dev Creates a new agent token with enhanced metadata and optional learning
     * @param to The address that will own the agent
     * @param logicAddress The address of the logic contract
     * @param metadataURI The URI for the agent's metadata
     * @param extendedMetadata The enhanced metadata for the agent
     * @return tokenId The ID of the new agent token
     */
    function createAgent(
        address to,
        address logicAddress,
        string memory metadataURI,
        EnhancedAgentMetadata memory extendedMetadata
    ) external returns (uint256 tokenId) {
        return _createAgentInternal(to, logicAddress, metadataURI, extendedMetadata);
    }

    /**
     * @dev Creates a new agent token with basic metadata (backward compatibility)
     * @param to The address that will own the agent
     * @param logicAddress The address of the logic contract
     * @param metadataURI The URI for the agent's metadata
     * @return tokenId The ID of the new agent token
     */
    function createAgent(
        address to,
        address logicAddress,
        string memory metadataURI
    ) external returns (uint256 tokenId) {
        // Create empty enhanced metadata (learning disabled by default)
        EnhancedAgentMetadata memory basicMetadata = EnhancedAgentMetadata({
            persona: "",
            experience: "",
            voiceHash: "",
            animationURI: "",
            vaultURI: "",
            vaultHash: bytes32(0),
            learningEnabled: false,
            learningModule: address(0),
            learningTreeRoot: bytes32(0),
            learningVersion: 0
        });

        return _createAgentInternal(to, logicAddress, metadataURI, basicMetadata);
    }

    /**
     * @dev Internal function to create agent with enhanced metadata
     */
    function _createAgentInternal(
        address to,
        address logicAddress,
        string memory metadataURI,
        EnhancedAgentMetadata memory extendedMetadata
    ) internal returns (uint256 tokenId) {
        require(logicAddress != address(0), "BEP007Enhanced: logic address is zero");

        _tokenIdCounter.increment();
        tokenId = _tokenIdCounter.current();

        _mint(to, tokenId);
        _setTokenURI(tokenId, metadataURI);

        _agentStates[tokenId] = State({
            balance: 0,
            status: Status.Active,
            owner: to,
            logicAddress: logicAddress,
            lastActionTimestamp: block.timestamp
        });

        _agentMetadataURIs[tokenId] = metadataURI;
        _agentExtendedMetadata[tokenId] = extendedMetadata;

        // Set up learning module if enabled
        if (extendedMetadata.learningEnabled && extendedMetadata.learningModule != address(0)) {
            _learningModules[tokenId] = extendedMetadata.learningModule;
            emit LearningEnabled(tokenId, extendedMetadata.learningModule);
        }

        return tokenId;
    }

    /**
     * @dev Enables learning for an existing agent
     * @param tokenId The ID of the agent token
     * @param learningModule The address of the learning module
     * @param initialTreeRoot The initial learning tree root
     */
    function enableLearning(
        uint256 tokenId,
        address learningModule,
        bytes32 initialTreeRoot
    ) external onlyAgentOwner(tokenId) {
        require(learningModule != address(0), "BEP007Enhanced: learning module is zero address");
        require(
            !_agentExtendedMetadata[tokenId].learningEnabled,
            "BEP007Enhanced: learning already enabled"
        );

        EnhancedAgentMetadata storage metadata = _agentExtendedMetadata[tokenId];
        metadata.learningEnabled = true;
        metadata.learningModule = learningModule;
        metadata.learningTreeRoot = initialTreeRoot;
        metadata.learningVersion = 1;

        _learningModules[tokenId] = learningModule;

        emit LearningEnabled(tokenId, learningModule);
    }

    /**
     * @dev Updates the learning module for an agent
     * @param tokenId The ID of the agent token
     * @param newLearningModule The address of the new learning module
     */
    function updateLearningModule(
        uint256 tokenId,
        address newLearningModule
    ) external onlyAgentOwner(tokenId) {
        require(newLearningModule != address(0), "BEP007Enhanced: learning module is zero address");
        require(
            _agentExtendedMetadata[tokenId].learningEnabled,
            "BEP007Enhanced: learning not enabled"
        );

        address oldModule = _agentExtendedMetadata[tokenId].learningModule;
        _agentExtendedMetadata[tokenId].learningModule = newLearningModule;
        _agentExtendedMetadata[tokenId].learningVersion++;
        _learningModules[tokenId] = newLearningModule;

        emit LearningModuleUpdated(tokenId, oldModule, newLearningModule);
    }

    /**
     * @dev Records an interaction for learning purposes
     * @param tokenId The ID of the agent token
     * @param interactionType The type of interaction
     * @param success Whether the interaction was successful
     */
    function recordInteraction(
        uint256 tokenId,
        string calldata interactionType,
        bool success
    ) external onlyAgentOwner(tokenId) {
        EnhancedAgentMetadata storage metadata = _agentExtendedMetadata[tokenId];
        if (metadata.learningEnabled && metadata.learningModule != address(0)) {
            try
                ILearningModule(metadata.learningModule).recordInteraction(
                    tokenId,
                    interactionType,
                    success
                )
            {
                // Successfully recorded interaction
            } catch {
                // Silently fail to not break agent functionality
            }
        }
    }

    /**
     * @dev Gets the learning status and metrics for an agent
     * @param tokenId The ID of the agent token
     * @return enabled Whether learning is enabled
     * @return moduleAddress The address of the learning module
     * @return metrics The learning metrics (if available)
     */
    function getLearningInfo(
        uint256 tokenId
    )
        external
        view
        returns (
            bool enabled,
            address moduleAddress,
            ILearningModule.LearningMetrics memory metrics
        )
    {
        EnhancedAgentMetadata storage metadata = _agentExtendedMetadata[tokenId];
        enabled = metadata.learningEnabled;
        moduleAddress = metadata.learningModule;

        if (enabled && moduleAddress != address(0)) {
            try ILearningModule(moduleAddress).getLearningMetrics(tokenId) returns (
                ILearningModule.LearningMetrics memory _metrics
            ) {
                metrics = _metrics;
            } catch {
                // Return empty metrics if call fails
            }
        }
    }

    /**
     * @dev Verifies a learning claim for an agent
     * @param tokenId The ID of the agent token
     * @param claim The claim to verify
     * @param proof The Merkle proof
     * @return Whether the claim is valid
     */
    function verifyLearningClaim(
        uint256 tokenId,
        bytes32 claim,
        bytes32[] calldata proof
    ) external view returns (bool) {
        EnhancedAgentMetadata storage metadata = _agentExtendedMetadata[tokenId];
        if (!metadata.learningEnabled || metadata.learningModule == address(0)) {
            return false;
        }

        try ILearningModule(metadata.learningModule).verifyLearning(tokenId, claim, proof) returns (
            bool result
        ) {
            return result;
        } catch {
            return false;
        }
    }

    // ... (Include all other functions from the original BEP007.sol)

    /**
     * @dev Executes an action using the agent's logic
     * @param tokenId The ID of the agent token
     * @param data The encoded function call to execute
     */
    function executeAction(
        uint256 tokenId,
        bytes calldata data
    ) external virtual nonReentrant whenAgentActive(tokenId) {
        State storage agentState = _agentStates[tokenId];

        // Only the owner or the logic contract itself can execute actions
        require(
            msg.sender == ownerOf(tokenId) || msg.sender == agentState.logicAddress,
            "BEP007Enhanced: unauthorized caller"
        );

        // Ensure the agent has enough balance for gas
        require(agentState.balance > 0, "BEP007Enhanced: insufficient balance for gas");

        // Update the last action timestamp
        agentState.lastActionTimestamp = block.timestamp;

        // Execute the action via call with gas limit (upgrade-safe)
        (bool success, bytes memory result) = agentState.logicAddress.call{
            gas: MAX_GAS_FOR_DELEGATECALL
        }(data);

        require(success, "BEP007Enhanced: action execution failed");

        emit ActionExecuted(address(this), result);

        // Record interaction for learning if enabled
        EnhancedAgentMetadata storage metadata = _agentExtendedMetadata[tokenId];
        if (metadata.learningEnabled && metadata.learningModule != address(0)) {
            try
                ILearningModule(metadata.learningModule).recordInteraction(
                    tokenId,
                    "action_executed",
                    success
                )
            {
                // Successfully recorded interaction
            } catch {
                // Silently fail to not break agent functionality
            }
        }
    }

    /**
     * @dev Gets the agent's metadata (IBEP007 interface implementation)
     * @param tokenId The ID of the agent token
     * @return The agent's base metadata
     */
    function getAgentMetadata(
        uint256 tokenId
    ) external view virtual override returns (IBEP007.AgentMetadata memory) {
        require(_exists(tokenId), "BEP007Enhanced: agent does not exist");
        EnhancedAgentMetadata storage enhanced = _agentExtendedMetadata[tokenId];
        return
            IBEP007.AgentMetadata({
                persona: enhanced.persona,
                experience: enhanced.experience,
                voiceHash: enhanced.voiceHash,
                animationURI: enhanced.animationURI,
                vaultURI: enhanced.vaultURI,
                vaultHash: enhanced.vaultHash
            });
    }

    /**
     * @dev Gets the agent's enhanced metadata
     * @param tokenId The ID of the agent token
     * @return The agent's enhanced metadata
     */
    function getAgentEnhancedMetadata(
        uint256 tokenId
    ) external view virtual returns (EnhancedAgentMetadata memory) {
        require(_exists(tokenId), "BEP007Enhanced: agent does not exist");
        return _agentExtendedMetadata[tokenId];
    }

    /**
     * @dev Updates the agent's metadata (IBEP007 interface implementation)
     * @param tokenId The ID of the agent token
     * @param metadata The new base metadata
     */
    function updateAgentMetadata(
        uint256 tokenId,
        IBEP007.AgentMetadata memory metadata
    ) external virtual override onlyAgentOwner(tokenId) {
        // Update only the base metadata fields
        EnhancedAgentMetadata storage enhanced = _agentExtendedMetadata[tokenId];
        enhanced.persona = metadata.persona;
        enhanced.experience = metadata.experience;
        enhanced.voiceHash = metadata.voiceHash;
        enhanced.animationURI = metadata.animationURI;
        enhanced.vaultURI = metadata.vaultURI;
        enhanced.vaultHash = metadata.vaultHash;

        emit MetadataUpdated(tokenId, _agentMetadataURIs[tokenId]);
    }

    /**
     * @dev Updates the agent's enhanced metadata including learning fields
     * @param tokenId The ID of the agent token
     * @param metadata The new enhanced metadata
     */
    function updateAgentEnhancedMetadata(
        uint256 tokenId,
        EnhancedAgentMetadata memory metadata
    ) external virtual onlyAgentOwner(tokenId) {
        // Preserve learning settings if not explicitly changing them
        EnhancedAgentMetadata storage currentMetadata = _agentExtendedMetadata[tokenId];
        if (metadata.learningEnabled != currentMetadata.learningEnabled) {
            require(
                !currentMetadata.learningEnabled || metadata.learningModule != address(0),
                "BEP007Enhanced: cannot disable learning without migration"
            );
        }

        _agentExtendedMetadata[tokenId] = metadata;

        emit MetadataUpdated(tokenId, _agentMetadataURIs[tokenId]);
    }

    /**
     * @dev Updates the logic address for the agent
     * @param tokenId The ID of the agent token
     * @param newLogic The address of the new logic contract
     */
    function setLogicAddress(
        uint256 tokenId,
        address newLogic
    ) external virtual onlyAgentOwner(tokenId) {
        require(newLogic != address(0), "BEP007Enhanced: new logic address is zero");

        address oldLogic = _agentStates[tokenId].logicAddress;
        _agentStates[tokenId].logicAddress = newLogic;

        emit LogicUpgraded(address(this), oldLogic, newLogic);
    }

    /**
     * @dev Funds the agent with BNB for gas fees
     * @param tokenId The ID of the agent token
     */
    function fundAgent(uint256 tokenId) external payable virtual {
        require(_exists(tokenId), "BEP007Enhanced: agent does not exist");

        _agentStates[tokenId].balance += msg.value;

        emit AgentFunded(address(this), msg.sender, msg.value);
    }

    /**
     * @dev Returns the current state of the agent
     * @param tokenId The ID of the agent token
     * @return The agent's state
     */
    function getState(uint256 tokenId) external view virtual returns (State memory) {
        require(_exists(tokenId), "BEP007Enhanced: agent does not exist");
        return _agentStates[tokenId];
    }

    /**
     * @dev Pauses the agent
     * @param tokenId The ID of the agent token
     */
    function pause(uint256 tokenId) external virtual onlyAgentOwner(tokenId) {
        require(_agentStates[tokenId].status == Status.Active, "BEP007Enhanced: agent not active");

        _agentStates[tokenId].status = Status.Paused;

        emit StatusChanged(address(this), Status.Paused);
    }

    /**
     * @dev Resumes the agent
     * @param tokenId The ID of the agent token
     */
    function unpause(uint256 tokenId) external virtual onlyAgentOwner(tokenId) {
        require(_agentStates[tokenId].status == Status.Paused, "BEP007Enhanced: agent not paused");

        _agentStates[tokenId].status = Status.Active;

        emit StatusChanged(address(this), Status.Active);
    }

    /**
     * @dev Terminates the agent permanently
     * @param tokenId The ID of the agent token
     */
    function terminate(uint256 tokenId) external virtual onlyAgentOwner(tokenId) {
        require(
            _agentStates[tokenId].status != Status.Terminated,
            "BEP007Enhanced: agent already terminated"
        );

        _agentStates[tokenId].status = Status.Terminated;

        // Return any remaining balance to the owner
        uint256 remainingBalance = _agentStates[tokenId].balance;
        if (remainingBalance > 0) {
            _agentStates[tokenId].balance = 0;
            payable(ownerOf(tokenId)).transfer(remainingBalance);
        }

        emit StatusChanged(address(this), Status.Terminated);
    }

    /**
     * @dev Registers a experience module for the agent
     * @param tokenId The ID of the agent token
     * @param moduleAddress The address of the experience module
     */
    function registerExperienceModule(
        uint256 tokenId,
        address moduleAddress
    ) external virtual onlyAgentOwner(tokenId) {
        require(
            experienceModuleRegistry != address(0),
            "BEP007Enhanced: experience module registry not set"
        );

        emit ExperienceModuleRegistered(tokenId, moduleAddress);
    }

    /**
     * @dev Withdraws BNB from the agent
     * @param tokenId The ID of the agent token
     * @param amount The amount to withdraw
     */
    function withdrawFromAgent(
        uint256 tokenId,
        uint256 amount
    ) external virtual onlyAgentOwner(tokenId) {
        require(amount <= _agentStates[tokenId].balance, "BEP007Enhanced: insufficient balance");

        _agentStates[tokenId].balance -= amount;
        payable(msg.sender).transfer(amount);
    }

    /**
     * @dev Updates the agent's metadata URI
     * @param tokenId The ID of the agent token
     * @param newMetadataURI The new metadata URI
     */
    function setAgentMetadataURI(
        uint256 tokenId,
        string memory newMetadataURI
    ) external virtual onlyAgentOwner(tokenId) {
        _agentMetadataURIs[tokenId] = newMetadataURI;
        _setTokenURI(tokenId, newMetadataURI);

        emit MetadataUpdated(tokenId, newMetadataURI);
    }

    /**
     * @dev Sets the global pause state (emergency circuit breaker)
     * @param paused The new pause state
     */
    function setGlobalPause(bool paused) external virtual onlyGovernance {
        globalPause = paused;
    }

    /**
     * @dev Updates the governance address
     * @param newGovernance The address of the new governance contract
     */
    function setGovernance(address newGovernance) external virtual onlyGovernance {
        require(newGovernance != address(0), "BEP007Enhanced: new governance address is zero");
        governance = newGovernance;
    }

    /**
     * @dev Sets the experience module registry address
     * @param registry The address of the experience module registry
     */
    function setExperienceModuleRegistry(address registry) external virtual onlyGovernance {
        require(registry != address(0), "BEP007Enhanced: registry is zero address");
        experienceModuleRegistry = registry;
    }

    /**
     * @dev See {IERC165-supportsInterface}
     */
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721URIStorageUpgradeable)
        returns (bool)
    {
        return interfaceId == type(IBEP007).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {ERC721-_beforeTokenTransfer}
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal virtual override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);

        // Update owner in agent state when transferred
        if (from != address(0) && to != address(0)) {
            _agentStates[tokenId].owner = to;
        }
    }

    /**
     * @dev See {ERC721URIStorage-_burn}
     */
    function _burn(
        uint256 tokenId
    ) internal virtual override(ERC721Upgradeable, ERC721URIStorageUpgradeable) {
        super._burn(tokenId);
    }

    /**
     * @dev See {ERC721URIStorage-tokenURI}
     */
    function tokenURI(
        uint256 tokenId
    )
        public
        view
        virtual
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract.
     * Called by {upgradeTo} and {upgradeToAndCall}.
     */
    function _authorizeUpgrade(address) internal virtual override onlyOwner {}

    receive() external payable {}
}
