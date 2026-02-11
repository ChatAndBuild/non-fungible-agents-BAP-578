// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title BAP578
 * @dev NFT contract for Non-Fungible Agents with structured metadata
 */
contract BAP578 is
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    // ============================================
    // STRUCTS
    // ============================================

    struct AgentMetadata {
        string persona; // JSON-encoded string for character traits, style, tone
        string experience; // Short summary string for agent's role/purpose
        string voiceHash; // Reference ID to stored audio profile
        string animationURI; // URI to video or animation file
        string vaultURI; // URI to the agent's vault (extended data storage)
        bytes32 vaultHash; // Hash of the vault contents for verification
    }

    struct AgentState {
        uint256 balance;
        bool active;
        address logicAddress;
        uint256 createdAt;
    }

    // ============================================
    // CONSTANTS
    // ============================================

    uint256 public constant MINT_FEE = 0.01 ether;
    uint256 public constant MAX_METADATA_URI_LENGTH = 512;
    uint256 public constant MAX_PERSONA_LENGTH = 2048;
    uint256 public constant MAX_STRING_LENGTH = 1024;

    // ============================================
    // STATE VARIABLES
    // ============================================

    // Token counter
    uint256 private _tokenIdCounter;

    // Agent data
    mapping(uint256 => AgentState) public agentStates;
    mapping(uint256 => AgentMetadata) public agentMetadata;

    // Free mints tracking
    uint256 public freeMintsPerUser;
    mapping(address => uint256) public freeMintsClaimed;
    mapping(uint256 tokenId => bool) public isFreeMint;
    mapping(address => uint256) public bonusFreeMints;

    // Treasury address for fee distribution
    address public treasuryAddress;

    // Pause state for emergency
    bool public paused;

    // Total ETH deposited across all agents (for safe emergency withdraw)
    uint256 public totalAgentBalances;

    // ============================================
    // EVENTS
    // ============================================

    event AgentCreated(
        uint256 indexed tokenId,
        address indexed owner,
        address logicAddress,
        string metadataURI
    );
    event AgentFunded(uint256 indexed tokenId, uint256 amount);
    event AgentWithdraw(uint256 indexed tokenId, uint256 amount);
    event AgentStatusChanged(uint256 indexed tokenId, bool active);
    event LogicAddressUpdated(uint256 indexed tokenId, address newLogicAddress);
    event MetadataUpdated(uint256 indexed tokenId);
    event TreasuryUpdated(address newTreasury);
    event ContractPaused(bool paused);
    event FreeMintGranted(address indexed user, uint256 amount);
    event FreeMintsPerUserUpdated(uint256 oldAmount, uint256 newAmount);
    event AgentBurned(uint256 indexed tokenId, address indexed owner);

    // ============================================
    // MODIFIERS
    // ============================================

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    modifier onlyTokenOwner(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        _;
    }

    // ============================================
    // INITIALIZATION
    // ============================================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name,
        string memory symbol,
        address treasury
    ) public initializer {
        require(treasury != address(0), "Invalid treasury");

        __ERC721_init(name, symbol);
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();
        __ReentrancyGuard_init();
        __Ownable_init();
        __UUPSUpgradeable_init();

        treasuryAddress = treasury;
        freeMintsPerUser = 3;
    }

    // ============================================
    // MAIN FUNCTIONS
    // ============================================

    /**
     * @dev Create a new agent NFT
     */
    function createAgent(
        address to,
        address logicAddress,
        string memory metadataURI,
        AgentMetadata memory extendedMetadata
    ) external payable whenNotPaused nonReentrant returns (uint256) {
        require(to != address(0), "Cannot mint to zero address");
        require(
            logicAddress == address(0) || logicAddress.code.length > 0,
            "Invalid logic address"
        );

        // Validate metadata string lengths
        require(bytes(metadataURI).length <= MAX_METADATA_URI_LENGTH, "URI too long");
        require(bytes(extendedMetadata.persona).length <= MAX_PERSONA_LENGTH, "Persona too long");
        require(
            bytes(extendedMetadata.experience).length <= MAX_STRING_LENGTH,
            "Experience too long"
        );
        require(
            bytes(extendedMetadata.voiceHash).length <= MAX_STRING_LENGTH,
            "VoiceHash too long"
        );
        require(
            bytes(extendedMetadata.animationURI).length <= MAX_STRING_LENGTH,
            "AnimationURI too long"
        );
        require(bytes(extendedMetadata.vaultURI).length <= MAX_STRING_LENGTH, "VaultURI too long");

        // Check if user has free mints remaining (base + bonus)
        uint256 totalFreeMints = freeMintsPerUser + bonusFreeMints[msg.sender];
        uint256 freeMintsRemaining = totalFreeMints > freeMintsClaimed[msg.sender]
            ? totalFreeMints - freeMintsClaimed[msg.sender]
            : 0;

        bool isFree = freeMintsRemaining > 0;

        if (isFree) {
            require(msg.value == 0, "Free mint does not require payment");
            require(to == msg.sender, "Free mints can only be minted to self");
            freeMintsClaimed[msg.sender]++;
        } else {
            // Require payment
            require(msg.value == MINT_FEE, "Incorrect fee");
            // Validate and send fee to treasury
            require(treasuryAddress != address(0), "Treasury not set");
            (bool success, ) = payable(treasuryAddress).call{ value: msg.value }("");
            require(success, "Treasury transfer failed");
        }

        // Mint NFT — increment first, then use tokenId consistently
        uint256 tokenId = ++_tokenIdCounter;

        if (isFree) {
            isFreeMint[tokenId] = true;
        }

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, metadataURI);

        // Initialize agent state
        agentStates[tokenId] = AgentState({
            balance: 0,
            active: true,
            logicAddress: logicAddress,
            createdAt: block.timestamp
        });

        // Store extended metadata
        agentMetadata[tokenId] = extendedMetadata;

        emit AgentCreated(tokenId, to, logicAddress, metadataURI);
        return tokenId;
    }

    /**
     * @dev Fund an agent with ETH
     */
    function fundAgent(uint256 tokenId) external payable whenNotPaused nonReentrant {
        require(_exists(tokenId), "Token does not exist");
        require(msg.value > 0, "Must send ETH");
        agentStates[tokenId].balance += msg.value;
        totalAgentBalances += msg.value;
        emit AgentFunded(tokenId, msg.value);
    }

    /**
     * @dev Withdraw funds from agent (owner only)
     */
    function withdrawFromAgent(
        uint256 tokenId,
        uint256 amount
    ) external onlyTokenOwner(tokenId) nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(agentStates[tokenId].balance >= amount, "Insufficient balance");

        // Update state first
        agentStates[tokenId].balance -= amount;
        totalAgentBalances -= amount;

        // Emit event before external call
        emit AgentWithdraw(tokenId, amount);

        // External call last (Checks-Effects-Interactions pattern)
        (bool success, ) = payable(msg.sender).call{ value: amount }("");
        require(success, "Withdrawal failed");
    }

    /**
     * @dev Burn an agent NFT (token owner only, balance must be 0)
     */
    function burn(uint256 tokenId) external onlyTokenOwner(tokenId) {
        emit AgentBurned(tokenId, msg.sender);
        _burn(tokenId);
    }

    /**
     * @dev Toggle agent active status
     */
    function setAgentStatus(uint256 tokenId, bool active) external onlyTokenOwner(tokenId) {
        agentStates[tokenId].active = active;
        emit AgentStatusChanged(tokenId, active);
    }

    /**
     * @dev Update logic address for an agent
     * @dev Logic address must be either zero address or a contract address
     */
    function setLogicAddress(
        uint256 tokenId,
        address newLogicAddress
    ) external onlyTokenOwner(tokenId) {
        require(
            newLogicAddress == address(0) || newLogicAddress.code.length > 0,
            "Invalid logic address"
        );
        agentStates[tokenId].logicAddress = newLogicAddress;
        emit LogicAddressUpdated(tokenId, newLogicAddress);
    }

    /**
     * @dev Update agent metadata
     */
    function updateAgentMetadata(
        uint256 tokenId,
        string memory newMetadataURI,
        AgentMetadata memory newExtendedMetadata
    ) external onlyTokenOwner(tokenId) {
        require(bytes(newMetadataURI).length <= MAX_METADATA_URI_LENGTH, "URI too long");
        require(
            bytes(newExtendedMetadata.persona).length <= MAX_PERSONA_LENGTH,
            "Persona too long"
        );
        require(
            bytes(newExtendedMetadata.experience).length <= MAX_STRING_LENGTH,
            "Experience too long"
        );
        require(
            bytes(newExtendedMetadata.voiceHash).length <= MAX_STRING_LENGTH,
            "VoiceHash too long"
        );
        require(
            bytes(newExtendedMetadata.animationURI).length <= MAX_STRING_LENGTH,
            "AnimationURI too long"
        );
        require(
            bytes(newExtendedMetadata.vaultURI).length <= MAX_STRING_LENGTH,
            "VaultURI too long"
        );

        _setTokenURI(tokenId, newMetadataURI);
        agentMetadata[tokenId] = newExtendedMetadata;
        emit MetadataUpdated(tokenId);
    }

    // ============================================
    // ADMIN FUNCTIONS
    // ============================================

    /**
     * @dev Grant additional free mints to an address (admin override)
     */
    function grantAdditionalFreeMints(address user, uint256 additionalAmount) external onlyOwner {
        bonusFreeMints[user] += additionalAmount;
        emit FreeMintGranted(user, additionalAmount);
    }

    /**
     * @dev Update treasury address
     */
    function setTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Treasury cannot be zero address");
        treasuryAddress = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }

    /**
     * @dev Update free mints per user
     */
    function setFreeMintsPerUser(uint256 amount) external onlyOwner {
        uint256 oldAmount = freeMintsPerUser;
        freeMintsPerUser = amount;
        emit FreeMintsPerUserUpdated(oldAmount, amount);
    }

    /**
     * @dev Pause/unpause contract
     */
    function setPaused(bool pausedState) external onlyOwner {
        paused = pausedState;
        emit ContractPaused(pausedState);
    }

    /**
     * @dev Emergency withdraw — only unallocated funds (not agent balances)
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 unallocated = address(this).balance - totalAgentBalances;
        require(unallocated > 0, "No unallocated balance");
        (bool success, ) = payable(owner()).call{ value: unallocated }("");
        require(success, "Emergency withdraw failed");
    }

    // ============================================
    // VIEW FUNCTIONS
    // ============================================

    /**
     * @dev Get agent state information
     */
    function getAgentState(
        uint256 tokenId
    )
        external
        view
        returns (
            uint256 balance,
            bool active,
            address logicAddress,
            uint256 createdAt,
            address owner
        )
    {
        require(_exists(tokenId), "Token does not exist");
        AgentState memory state = agentStates[tokenId];
        return (state.balance, state.active, state.logicAddress, state.createdAt, ownerOf(tokenId));
    }

    /**
     * @dev Get agent metadata
     */
    function getAgentMetadata(
        uint256 tokenId
    ) external view returns (AgentMetadata memory metadata, string memory metadataURI) {
        require(_exists(tokenId), "Token does not exist");
        return (agentMetadata[tokenId], tokenURI(tokenId));
    }

    /**
     * @dev Get all tokens owned by an address
     * @dev Warning: Unbounded loop - might get expensive with large token counts
     */
    function tokensOfOwner(address account) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(account);
        uint256[] memory tokens = new uint256[](tokenCount);

        for (uint256 i = 0; i < tokenCount; i++) {
            tokens[i] = tokenOfOwnerByIndex(account, i);
        }

        return tokens;
    }

    /**
     * @dev Get tokens owned by an address with pagination
     */
    function tokensOfOwnerPaginated(
        address account,
        uint256 offset,
        uint256 limit
    ) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(account);
        if (offset >= tokenCount) return new uint256[](0);
        uint256 end = offset + limit > tokenCount ? tokenCount : offset + limit;
        uint256[] memory tokens = new uint256[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            tokens[i - offset] = tokenOfOwnerByIndex(account, i);
        }
        return tokens;
    }

    /**
     * @dev Get total supply
     */
    function getTotalSupply() external view returns (uint256) {
        return totalSupply();
    }

    /**
     * @dev Get remaining free mints for an address
     */
    function getFreeMints(address user) external view returns (uint256) {
        uint256 totalFreeMints = freeMintsPerUser + bonusFreeMints[user];
        uint256 claimed = freeMintsClaimed[user];
        return claimed >= totalFreeMints ? 0 : totalFreeMints - claimed;
    }

    // ============================================
    // OVERRIDES
    // ============================================

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        if (isFreeMint[tokenId]) {
            require(
                from == address(0) || to == address(0),
                "Free minted tokens are non-transferable"
            );
        }
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(
        uint256 tokenId
    ) internal override(ERC721Upgradeable, ERC721URIStorageUpgradeable) {
        require(agentStates[tokenId].balance == 0, "Agent balance must be 0");
        super._burn(tokenId);
        delete agentStates[tokenId];
        delete agentMetadata[tokenId];
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721Upgradeable, ERC721URIStorageUpgradeable) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721URIStorageUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    receive() external payable {
        revert("Use fundAgent() instead");
    }

    fallback() external payable {
        revert("Use fundAgent() to send ETH");
    }

    // ============================================
    // STORAGE GAP (for upgrade safety)
    // ============================================

    uint256[39] private __gap;
}
