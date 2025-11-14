// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
    // STATE VARIABLES
    // ============================================

    // Token counter
    uint256 private _tokenIdCounter;

    // Agent data
    mapping(uint256 => AgentState) public agentStates;
    mapping(uint256 => AgentMetadata) public agentMetadata;

    // Minting fee
    uint256 public constant MINT_FEE = 0.01 ether;

    // Free mints tracking (everyone gets 3 free mints)
    mapping(address => uint256) public freeMintsClaimed;
    uint256 public constant FREE_MINTS_PER_USER = 3;

    // Treasury address for fee distribution
    address public treasuryAddress;

    // Pause state for emergency
    bool public paused;

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

    function initialize(
        string memory name,
        string memory symbol,
        address _treasury
    ) public initializer {
        require(_treasury != address(0), "Invalid treasury");

        __ERC721_init(name, symbol);
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();
        __ReentrancyGuard_init();
        __Ownable_init();
        __UUPSUpgradeable_init();

        treasuryAddress = _treasury;
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
        // Check if user has free mints remaining
        uint256 freeMintsRemaining = FREE_MINTS_PER_USER - freeMintsClaimed[msg.sender];

        if (freeMintsRemaining > 0) {
            // Use free mint
            freeMintsClaimed[msg.sender]++;
        } else {
            // Require payment
            require(msg.value == MINT_FEE, "Incorrect fee");
            // Send fee to treasury
            if (treasuryAddress != address(0)) {
                payable(treasuryAddress).transfer(msg.value);
            }
        }

        // Mint NFT
        uint256 tokenId = ++_tokenIdCounter;
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
    function fundAgent(uint256 tokenId) external payable {
        require(_exists(tokenId), "Token does not exist");
        agentStates[tokenId].balance += msg.value;
        emit AgentFunded(tokenId, msg.value);
    }

    /**
     * @dev Withdraw funds from agent (owner only)
     */
    function withdrawFromAgent(
        uint256 tokenId,
        uint256 amount
    ) external onlyTokenOwner(tokenId) nonReentrant {
        require(agentStates[tokenId].balance >= amount, "Insufficient balance");
        agentStates[tokenId].balance -= amount;
        payable(msg.sender).transfer(amount);
        emit AgentWithdraw(tokenId, amount);
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
     */
    function setLogicAddress(
        uint256 tokenId,
        address newLogicAddress
    ) external onlyTokenOwner(tokenId) {
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
        // This allows owner to grant mints beyond the default 3
        // Setting to 0 resets to default behavior
        if (freeMintsClaimed[user] > additionalAmount) {
            freeMintsClaimed[user] = 0; // Reset if giving more than claimed
        }
    }

    /**
     * @dev Update treasury address
     */
    function setTreasury(address _treasury) external onlyOwner {
        treasuryAddress = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    /**
     * @dev Pause/unpause contract
     */
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit ContractPaused(_paused);
    }

    /**
     * @dev Emergency withdraw (owner only)
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance");
        payable(owner()).transfer(balance);
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
     */
    function tokensOfOwner(address owner) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(owner);
        uint256[] memory tokens = new uint256[](tokenCount);

        for (uint256 i = 0; i < tokenCount; i++) {
            tokens[i] = tokenOfOwnerByIndex(owner, i);
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
        uint256 claimed = freeMintsClaimed[user];
        if (claimed >= FREE_MINTS_PER_USER) {
            return 0;
        }
        return FREE_MINTS_PER_USER - claimed;
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
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(
        uint256 tokenId
    ) internal override(ERC721Upgradeable, ERC721URIStorageUpgradeable) {
        super._burn(tokenId);
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

    // Allow contract to receive ETH
    receive() external payable {}
}
