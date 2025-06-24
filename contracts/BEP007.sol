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
import "./interfaces/ICircuitBreaker.sol";

/**
 * @title BEP007 - Non-Fungible Agent (NFA) Token Standard
 * @dev Implementation of the BEP-007 standard for autonomous agent tokens
 */
contract BEP007 is
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
    mapping(uint256 => State) private _agentStates;

    // Mapping from token ID to agent metadata URI
    mapping(uint256 => string) private _agentMetadataURIs;

    // Mapping from token ID to extended agent metadata
    mapping(uint256 => AgentMetadata) private _agentExtendedMetadata;

    // Circuit breaker for emergency pause
    bool public globalPause;

    ICircuitBreaker public circuitBreaker;

    // Gas limit for delegatecall to prevent out-of-gas attacks
    uint256 public constant MAX_GAS_FOR_DELEGATECALL = 3_000_000;

    /**
     * @dev Modifier to check if the caller is the governance contract
     */
    modifier onlyGovernance() {
        require(msg.sender == governance, "BEP007: caller is not governance");
        _;
    }

    /**
     * @dev Modifier to check if the caller is the owner of the token
     */
    modifier onlyAgentOwner(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender, "BEP007: caller is not agent owner");
        _;
    }

    /**
     * @dev Modifier to check if the agent is active
     */
    modifier whenAgentActive(uint256 tokenId) {
        require(!globalPause, "BEP007: global pause active");
        require(_agentStates[tokenId].status == Status.Active, "BEP007: agent not active");
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
    ) public initializer {
        require(governanceAddress != address(0), "BEP007: governance address is zero");

        __ERC721_init(name, symbol);
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();
        __ReentrancyGuard_init();
        __Ownable_init();
        __UUPSUpgradeable_init();

        governance = governanceAddress;
        circuitBreaker = ICircuitBreaker(governanceAddress);
        globalPause = false;

        // Transfer ownership to governance for additional security
        _transferOwnership(governanceAddress);
    }

    /**
     * @dev Creates a new agent token with extended metadata
     * @param to The address that will own the agent
     * @param logicAddress The address of the logic contract
     * @param metadataURI The URI for the agent's metadata
     * @param extendedMetadata The extended metadata for the agent
     * @return tokenId The ID of the new agent token
     */
    function createAgent(
        address to,
        address logicAddress,
        string memory metadataURI,
        AgentMetadata memory extendedMetadata
    ) external returns (uint256 tokenId) {
        require(logicAddress != address(0), "BEP007: logic address is zero");

        _tokenIdCounter.increment();
        tokenId = _tokenIdCounter.current();

        _safeMint(to, tokenId);
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

        return tokenId;
    }

    /**
     * @dev Creates a new agent token with basic metadata
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
        // Create empty extended metadata
        AgentMetadata memory emptyMetadata = AgentMetadata({
            persona: "",
            experience: "",
            voiceHash: "",
            animationURI: "",
            vaultURI: "",
            vaultHash: bytes32(0)
        });

        return this.createAgent(to, logicAddress, metadataURI, emptyMetadata);
    }

    /**
     * @dev Executes an action using the agent's logic
     * @param tokenId The ID of the agent token
     * @param data The encoded function call to execute
     */
    function executeAction(
        uint256 tokenId,
        bytes calldata data
    ) external nonReentrant whenAgentActive(tokenId) {
        State storage agentState = _agentStates[tokenId];

        require(circuitBreaker.globalPause() == false, "CircuitBreaker: globally paused");

        // Only the owner or the logic contract itself can execute actions
        require(
            msg.sender == ownerOf(tokenId) || msg.sender == agentState.logicAddress,
            "BEP007: unauthorized caller"
        );

        // Ensure the agent has enough balance for gas
        require(agentState.balance > 0, "BEP007: insufficient balance for gas");

        // Update the last action timestamp
        agentState.lastActionTimestamp = block.timestamp;

        // Execute the action via delegatecall with gas limit
        (bool success, bytes memory result) = agentState.logicAddress.call{
            gas: MAX_GAS_FOR_DELEGATECALL
        }(data);

        require(success, "BEP007: action execution failed");

        emit ActionExecuted(address(this), result);
    }

    /**
     * @dev Updates the logic address for the agent
     * @param tokenId The ID of the agent token
     * @param newLogic The address of the new logic contract
     */
    function setLogicAddress(uint256 tokenId, address newLogic) external onlyAgentOwner(tokenId) {
        require(newLogic != address(0), "BEP007: new logic address is zero");

        address oldLogic = _agentStates[tokenId].logicAddress;
        _agentStates[tokenId].logicAddress = newLogic;

        emit LogicUpgraded(address(this), oldLogic, newLogic);
    }

    /**
     * @dev Funds the agent with BNB for gas fees
     * @param tokenId The ID of the agent token
     */
    function fundAgent(uint256 tokenId) external payable {
        require(_exists(tokenId), "BEP007: agent does not exist");

        _agentStates[tokenId].balance += msg.value;

        emit AgentFunded(address(this), msg.sender, msg.value);
    }

    /**
     * @dev Returns the current state of the agent
     * @param tokenId The ID of the agent token
     * @return The agent's state
     */
    function getState(uint256 tokenId) external view returns (State memory) {
        require(_exists(tokenId), "BEP007: agent does not exist");
        return _agentStates[tokenId];
    }

    /**
     * @dev Gets the agent's extended metadata
     * @param tokenId The ID of the agent token
     * @return The agent's extended metadata
     */
    function getAgentMetadata(uint256 tokenId) external view returns (AgentMetadata memory) {
        require(_exists(tokenId), "BEP007: agent does not exist");
        return _agentExtendedMetadata[tokenId];
    }

    /**
     * @dev Updates the agent's extended metadata
     * @param tokenId The ID of the agent token
     * @param metadata The new metadata
     */
    function updateAgentMetadata(
        uint256 tokenId,
        AgentMetadata memory metadata
    ) external onlyAgentOwner(tokenId) {
        _agentExtendedMetadata[tokenId] = metadata;

        emit MetadataUpdated(tokenId, _agentMetadataURIs[tokenId]);
    }

    /**
     * @dev Registers a experience module for the agent
     * @param tokenId The ID of the agent token
     * @param moduleAddress The address of the experience module
     */
    function registerExperienceModule(
        uint256 tokenId,
        address moduleAddress
    ) external onlyAgentOwner(tokenId) {
        require(
            experienceModuleRegistry != address(0),
            "BEP007: experience module registry not set"
        );

        emit ExperienceModuleRegistered(tokenId, moduleAddress);
    }

    /**
     * @dev Pauses the agent
     * @param tokenId The ID of the agent token
     */
    function pause(uint256 tokenId) external onlyAgentOwner(tokenId) {
        require(_agentStates[tokenId].status == Status.Active, "BEP007: agent not active");

        _agentStates[tokenId].status = Status.Paused;

        emit StatusChanged(address(this), Status.Paused);
    }

    /**
     * @dev Resumes the agent
     * @param tokenId The ID of the agent token
     */
    function unpause(uint256 tokenId) external onlyAgentOwner(tokenId) {
        require(_agentStates[tokenId].status == Status.Paused, "BEP007: agent not paused");

        _agentStates[tokenId].status = Status.Active;

        emit StatusChanged(address(this), Status.Active);
    }

    /**
     * @dev Terminates the agent permanently
     * @param tokenId The ID of the agent token
     */
    function terminate(uint256 tokenId) external onlyAgentOwner(tokenId) {
        require(
            _agentStates[tokenId].status != Status.Terminated,
            "BEP007: agent already terminated"
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
     * @dev Sets the global pause state (emergency circuit breaker)
     * @param paused The new pause state
     */
    function setGlobalPause(bool paused) external onlyGovernance {
        globalPause = paused;
    }

    /**
     * @dev Updates the governance address
     * @param newGovernance The address of the new governance contract
     */
    function setGovernance(address newGovernance) external onlyGovernance {
        require(newGovernance != address(0), "BEP007: new governance address is zero");
        governance = newGovernance;
    }

    /**
     * @dev Sets the experience module registry address
     * @param registry The address of the experience module registry
     */
    function setExperienceModuleRegistry(address registry) external onlyGovernance {
        require(registry != address(0), "BEP007: registry is zero address");
        experienceModuleRegistry = registry;
    }

    /**
     * @dev Withdraws BNB from the agent
     * @param tokenId The ID of the agent token
     * @param amount The amount to withdraw
     */
    function withdrawFromAgent(uint256 tokenId, uint256 amount) external onlyAgentOwner(tokenId) {
        require(amount <= _agentStates[tokenId].balance, "BEP007: insufficient balance");

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
    ) external onlyAgentOwner(tokenId) {
        _agentMetadataURIs[tokenId] = newMetadataURI;
        _setTokenURI(tokenId, newMetadataURI);

        emit MetadataUpdated(tokenId, newMetadataURI);
    }

    /**
     * @dev See {IERC165-supportsInterface}
     */
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
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
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
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
    ) internal override(ERC721Upgradeable, ERC721URIStorageUpgradeable) {
        super._burn(tokenId);
    }

    /**
     * @dev See {ERC721URIStorage-tokenURI}
     */
    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721Upgradeable, ERC721URIStorageUpgradeable) returns (string memory) {
        return super.tokenURI(tokenId);
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

    receive() external payable {}
}
