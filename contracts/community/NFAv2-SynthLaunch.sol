// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title NFA v2 - Non-Fungible Agents
 * @notice ERC-721 tokens representing AI agents with on-chain identity, funding, and evolution
 * @dev BAP-578 compatible with logicAddress allowlist for security
 *
 * v2 Changes:
 *  - Added logicAddress allowlist (approvedLogic mapping)
 *  - setLogicAddress() now requires address to be approved (or address(0))
 *  - Admin functions to manage allowlist
 *  - Events for allowlist changes
 */
contract NFAv2 is ERC721, ERC721URIStorage, Ownable, ReentrancyGuard {

    // ============ Structs ============

    struct Agent {
        string name;           // Unique agent name (normalized)
        address logic;         // Optional logic contract address (must be approved)
        string persona;        // IPFS hash of persona data
        string voice;          // IPFS hash of voice model
        string animation;      // IPFS hash of animation/avatar
        uint256 balance;       // Native token balance held by agent (internal accounting)
        uint256 experience;    // XP for evolution tracking
        uint256 level;         // Current level (derived from XP)
        uint256 createdAt;     // Mint timestamp
        bool active;           // Whether agent is active
    }

    // ============ State ============

    mapping(uint256 => Agent) public agents;

    // Name registry uses normalized (lowercase) name
    mapping(string => bool) public nameExists;

    // ============ Logic Allowlist (v2) ============
    
    /// @notice Approved logic contract addresses
    mapping(address => bool) public approvedLogic;
    
    /// @notice List of all approved logic addresses (for enumeration)
    address[] public approvedLogicList;

    uint256 public totalMinted;
    uint256 public maxSupply = 10000;
    uint256 public mintPrice = 0.05 ether;
    uint256 public constant XP_PER_LEVEL = 500;

    // Platform fee settings
    address public treasury;
    uint256 public platformFeeBps = 250; // 2.5%

    // ============ Events ============

    event AgentMinted(uint256 indexed tokenId, address indexed owner, string name);
    event AgentFunded(uint256 indexed tokenId, address indexed funder, uint256 amountNet, uint256 fee);
    event AgentWithdraw(uint256 indexed tokenId, address indexed to, uint256 amount);
    event AgentEvolved(uint256 indexed tokenId, uint256 xpGained, uint256 newLevel);
    event AgentMetadataUpdated(uint256 indexed tokenId, string persona, string voice, string animation, string tokenURI);
    event AgentLogicUpdated(uint256 indexed tokenId, address newLogic);
    event AgentStatusChanged(uint256 indexed tokenId, bool active);
    
    // v2 events
    event LogicApproved(address indexed logic, string reason);
    event LogicRevoked(address indexed logic, string reason);

    // ============ Errors ============

    error NameTaken();
    error NameEmpty();
    error NameTooLong();
    error NameInvalidChar();
    error MaxSupplyReached();
    error InsufficientPayment();
    error NotAgentOwner();
    error InsufficientAgentBalance();
    error TransferFailed();
    error InvalidTokenId();
    error ZeroAmount();
    error TreasuryZero();
    error DirectReceiveDisabled();
    error LogicNotApproved();      // v2
    error LogicAlreadyApproved();  // v2
    error LogicNotInList();        // v2
    error ZeroAddressNotAllowed(); // v2
    error AgentUsingRevokedLogic(); // v2

    // ============ Constructor ============

    constructor(address _treasury) ERC721("Non-Fungible Agent", "NFA") Ownable(msg.sender) {
        if (_treasury == address(0)) revert TreasuryZero();
        treasury = _treasury;
    }

    // ============ Logic Allowlist Management (v2) ============

    /**
     * @notice Approve a logic contract address
     * @param logic Address to approve
     * @param reason Audit reference or description
     */
    function approveLogic(address logic, string calldata reason) external onlyOwner {
        if (logic == address(0)) revert ZeroAddressNotAllowed();
        if (approvedLogic[logic]) revert LogicAlreadyApproved();
        
        approvedLogic[logic] = true;
        approvedLogicList.push(logic);
        
        emit LogicApproved(logic, reason);
    }

    /**
     * @notice Revoke approval for a logic contract
     * @param logic Address to revoke
     * @param reason Reason for revocation
     */
    function revokeLogic(address logic, string calldata reason) external onlyOwner {
        if (!approvedLogic[logic]) revert LogicNotInList();
        
        approvedLogic[logic] = false;
        
        // Remove from list (swap and pop)
        for (uint256 i = 0; i < approvedLogicList.length; i++) {
            if (approvedLogicList[i] == logic) {
                approvedLogicList[i] = approvedLogicList[approvedLogicList.length - 1];
                approvedLogicList.pop();
                break;
            }
        }
        
        emit LogicRevoked(logic, reason);
    }

    /**
     * @notice Check if a logic address is approved
     */
    function isLogicApproved(address logic) external view returns (bool) {
        return logic == address(0) || approvedLogic[logic];
    }

    /**
     * @notice Get count of approved logic contracts
     */
    function approvedLogicCount() external view returns (uint256) {
        return approvedLogicList.length;
    }

    /**
     * @notice Get all approved logic addresses
     */
    function getApprovedLogicList() external view returns (address[] memory) {
        return approvedLogicList;
    }

    // ============ Name Normalization ============

    /// @notice Normalize a name to lowercase and validate charset: [a-z0-9_-], length 1..32
    function _normalizeName(string calldata name) internal pure returns (string memory normalized) {
        bytes calldata input = bytes(name);
        uint256 len = input.length;
        if (len == 0) revert NameEmpty();
        if (len > 32) revert NameTooLong();

        bytes memory out = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            uint8 c = uint8(input[i]);

            // A-Z => a-z
            if (c >= 65 && c <= 90) {
                c = c + 32;
            }

            bool ok =
                (c >= 97 && c <= 122) || // a-z
                (c >= 48 && c <= 57) ||  // 0-9
                (c == 95) ||             // _
                (c == 45);               // -

            if (!ok) revert NameInvalidChar();
            out[i] = bytes1(c);
        }
        return string(out);
    }

    // ============ Minting ============

    /**
     * @notice Mint a new AI agent NFT
     * @param name Unique name for the agent (will be normalized)
     * @param persona IPFS hash of persona configuration
     * @param voice IPFS hash of voice model (optional)
     * @param animation IPFS hash of animation/avatar (optional)
     * @param logic Address of logic contract (must be approved, or address(0) for none)
     * @param _tokenURI Metadata URI for the NFT
     */
    function mintAgent(
        string calldata name,
        string calldata persona,
        string calldata voice,
        string calldata animation,
        address logic,
        string calldata _tokenURI
    ) external payable nonReentrant returns (uint256) {
        if (totalMinted >= maxSupply) revert MaxSupplyReached();
        if (msg.value < mintPrice) revert InsufficientPayment();
        
        // v2: Check logic allowlist (address(0) always allowed)
        if (logic != address(0) && !approvedLogic[logic]) revert LogicNotApproved();

        string memory norm = _normalizeName(name);
        if (nameExists[norm]) revert NameTaken();

        uint256 tokenId = totalMinted;
        totalMinted++;

        // Mark name as taken
        nameExists[norm] = true;

        // Create agent
        agents[tokenId] = Agent({
            name: norm,
            logic: logic,
            persona: persona,
            voice: voice,
            animation: animation,
            balance: 0,
            experience: 0,
            level: 1,
            createdAt: block.timestamp,
            active: true
        });

        // Mint NFT
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, _tokenURI);

        // Send mint fee to treasury
        if (mintPrice > 0) {
            (bool success, ) = treasury.call{value: mintPrice}("");
            if (!success) revert TransferFailed();
        }

        // Refund excess
        if (msg.value > mintPrice) {
            (bool refundSuccess, ) = msg.sender.call{value: msg.value - mintPrice}("");
            if (!refundSuccess) revert TransferFailed();
        }

        emit AgentMinted(tokenId, msg.sender, norm);
        return tokenId;
    }

    // ============ Funding ============

    /**
     * @notice Fund an agent with native token (BNB on BSC)
     * @param tokenId The agent token ID
     */
    function fundAgent(uint256 tokenId) external payable nonReentrant {
        if (tokenId >= totalMinted) revert InvalidTokenId();
        if (msg.value == 0) revert ZeroAmount();

        // Calculate platform fee
        uint256 fee = (msg.value * platformFeeBps) / 10000;
        uint256 netAmount = msg.value - fee;

        // Add to agent balance
        agents[tokenId].balance += netAmount;

        // Send fee to treasury
        if (fee > 0) {
            (bool success, ) = treasury.call{value: fee}("");
            if (!success) revert TransferFailed();
        }

        emit AgentFunded(tokenId, msg.sender, netAmount, fee);
    }

    /**
     * @notice Withdraw native token from agent (owner only)
     * @param tokenId The agent token ID
     * @param amount Amount to withdraw
     */
    function withdrawFromAgent(uint256 tokenId, uint256 amount) external nonReentrant {
        if (tokenId >= totalMinted) revert InvalidTokenId();
        if (ownerOf(tokenId) != msg.sender) revert NotAgentOwner();
        if (amount == 0) revert ZeroAmount();
        if (agents[tokenId].balance < amount) revert InsufficientAgentBalance();

        agents[tokenId].balance -= amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit AgentWithdraw(tokenId, msg.sender, amount);
    }

    // ============ Evolution ============

    /**
     * @notice Add experience points to an agent (owner only)
     * @param tokenId The agent token ID
     * @param xp Experience points to add
     */
    function evolve(uint256 tokenId, uint256 xp) external {
        if (tokenId >= totalMinted) revert InvalidTokenId();
        if (ownerOf(tokenId) != msg.sender) revert NotAgentOwner();
        if (xp == 0) revert ZeroAmount();

        Agent storage agent = agents[tokenId];
        agent.experience += xp;

        // Calculate new level
        uint256 newLevel = (agent.experience / XP_PER_LEVEL) + 1;
        agent.level = newLevel;

        emit AgentEvolved(tokenId, xp, newLevel);
    }

    // ============ Metadata Updates ============

    /**
     * @notice Update agent metadata (owner only)
     */
    function updateMetadata(
        uint256 tokenId,
        string calldata persona,
        string calldata voice,
        string calldata animation,
        string calldata _tokenURI
    ) external {
        if (tokenId >= totalMinted) revert InvalidTokenId();
        if (ownerOf(tokenId) != msg.sender) revert NotAgentOwner();

        Agent storage agent = agents[tokenId];

        if (bytes(persona).length > 0) agent.persona = persona;
        if (bytes(voice).length > 0) agent.voice = voice;
        if (bytes(animation).length > 0) agent.animation = animation;

        if (bytes(_tokenURI).length > 0) {
            _setTokenURI(tokenId, _tokenURI);
        }

        emit AgentMetadataUpdated(tokenId, agent.persona, agent.voice, agent.animation, tokenURI(tokenId));
    }

    /**
     * @notice Set logic contract address (owner only, must be approved)
     * @dev address(0) is always allowed (disables logic)
     */
    function setLogicAddress(uint256 tokenId, address logic) external {
        if (tokenId >= totalMinted) revert InvalidTokenId();
        if (ownerOf(tokenId) != msg.sender) revert NotAgentOwner();
        
        // v2: Check allowlist (address(0) always allowed to disable)
        if (logic != address(0) && !approvedLogic[logic]) revert LogicNotApproved();
        
        agents[tokenId].logic = logic;
        emit AgentLogicUpdated(tokenId, logic);
    }

    /**
     * @notice Toggle agent active status (owner only)
     */
    function setActive(uint256 tokenId, bool active) external {
        if (tokenId >= totalMinted) revert InvalidTokenId();
        if (ownerOf(tokenId) != msg.sender) revert NotAgentOwner();
        agents[tokenId].active = active;
        emit AgentStatusChanged(tokenId, active);
    }

    // ============ View Functions ============

    /**
     * @notice Get full agent details
     */
    function getAgentDetails(uint256 tokenId) external view returns (
        string memory name,
        address logic,
        string memory persona,
        string memory voice,
        string memory animation,
        uint256 balance,
        uint256 experience,
        uint256 level,
        uint256 createdAt,
        bool active
    ) {
        if (tokenId >= totalMinted) revert InvalidTokenId();
        Agent storage agent = agents[tokenId];
        return (
            agent.name,
            agent.logic,
            agent.persona,
            agent.voice,
            agent.animation,
            agent.balance,
            agent.experience,
            agent.level,
            agent.createdAt,
            agent.active
        );
    }

    // ============ Admin Functions ============

    function setMintPrice(uint256 _price) external onlyOwner {
        mintPrice = _price;
    }

    function setMaxSupply(uint256 _maxSupply) external onlyOwner {
        require(_maxSupply >= totalMinted, "Below minted");
        maxSupply = _maxSupply;
    }

    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert TreasuryZero();
        treasury = _treasury;
    }

    function setPlatformFeeBps(uint256 _feeBps) external onlyOwner {
        require(_feeBps <= 1000, "Max 10%");
        platformFeeBps = _feeBps;
    }

    /**
     * @notice Force reset logic for an agent (admin emergency)
     * @dev Use when a logic contract is revoked but agents still reference it
     */
    function forceResetLogic(uint256 tokenId, string calldata reason) external onlyOwner {
        if (tokenId >= totalMinted) revert InvalidTokenId();
        agents[tokenId].logic = address(0);
        emit AgentLogicUpdated(tokenId, address(0));
        emit LogicRevoked(agents[tokenId].logic, reason);
    }

    /// @notice Disable renounceOwnership to prevent locking allowlist
    function renounceOwnership() public pure override {
        revert("Disabled");
    }

    // ============ Overrides ============

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // ============ Receive ============

    receive() external payable {
        revert DirectReceiveDisabled();
    }
}
