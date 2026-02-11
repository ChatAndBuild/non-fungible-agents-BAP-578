// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/IBAP578.sol";
import "./interfaces/ILearningModule.sol";
import "./interfaces/IMemoryModuleRegistry.sol";
import "./interfaces/IVaultPermissionManager.sol";

/**
 * @title NFAPredictionAgent
 * @dev BAP-578 compliant NFA implementation for AI-powered prediction market agents.
 *
 * Each NFA represents an autonomous prediction agent with:
 * - Full BAP-578 lifecycle (ACTIVE / PAUSED / TERMINATED)
 * - Prediction profile with reputation scoring
 * - Auto-trade authorization with daily limits and expiry
 * - On-chain learning module (Merkle-proof verified)
 * - Memory module registry for off-chain knowledge stores
 * - Vault permission manager with tiered delegation
 *
 * Designed to integrate with PredictionMarket.sol for agent-driven trading.
 * All agent funding, trading, and settlements are denominated in BNB.
 */
contract NFAPredictionAgent is ERC721Enumerable, ReentrancyGuard, Pausable, Ownable, IBAP578, ILearningModule, IMemoryModuleRegistry, IVaultPermissionManager {

    // ─── Constants ──────────────────────────────────────────────
    uint256 public constant MINT_PRICE = 0.01 ether;

    // ─── Prediction Profile ─────────────────────────────────────
    struct PredictionProfile {
        uint256 totalPredictions;
        uint256 correctPredictions;
        bytes32 styleRoot;
        uint256 reputationScore;
    }

    // ─── Auto Trade Auth ────────────────────────────────────────
    struct AutoTradeAuth {
        bool authorized;
        address authorizedCaller;
        uint256 maxAmountPerTrade;
        uint256 maxDailyAmount;
        uint256 dailyUsed;
        uint256 lastResetDay;
        uint256 expiresAt;
    }

    // ─── State ──────────────────────────────────────────────────
    uint256 private _nextTokenId;
    address public predictionMarket;
    string private _baseTokenURI;

    // BAP-578 state
    mapping(uint256 => AgentState) private _agentStates;
    mapping(uint256 => AgentMetadata) private _agentMetadata;
    mapping(uint256 => address) private _logicAddresses;
    mapping(uint256 => uint256) private _agentBalances;

    // Prediction profile
    mapping(uint256 => PredictionProfile) private _profiles;

    // Auto trade
    mapping(uint256 => AutoTradeAuth) private _autoTradeAuth;

    // Learning module
    mapping(uint256 => LearningMetrics) private _learningMetrics;

    // Memory modules
    mapping(uint256 => mapping(address => MemoryModule)) private _memoryModules;

    // Vault permissions
    mapping(uint256 => mapping(address => Permission)) private _vaultPermissions;

    // ─── Events ─────────────────────────────────────────────────
    event AutoTradeAuthorized(uint256 indexed tokenId, uint256 maxPerTrade, uint256 maxDaily, uint256 expiresAt);
    event AutoTradeRevoked(uint256 indexed tokenId);
    event AgentTradeExecuted(uint256 indexed tokenId, address target, uint256 value);
    event ProfileUpdated(uint256 indexed tokenId);
    event VaultUpdated(uint256 indexed tokenId, string vaultURI, bytes32 vaultHash);

    // ─── Constructor ────────────────────────────────────────────
    constructor() ERC721("NFA Prediction Agent", "NFA") Ownable(msg.sender) {}

    // ─── Modifiers ──────────────────────────────────────────────
    modifier onlyTokenOwner(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        _;
    }

    modifier onlyActiveAgent(uint256 tokenId) {
        require(_agentStates[tokenId] == AgentState.ACTIVE, "Agent not active");
        _;
    }

    // ─── Minting ────────────────────────────────────────────────
    function mint(AgentMetadata calldata metadata) external payable whenNotPaused nonReentrant returns (uint256) {
        require(msg.value >= MINT_PRICE, "Insufficient mint fee");
        uint256 tokenId = _nextTokenId++;

        _safeMint(msg.sender, tokenId);
        _agentMetadata[tokenId] = metadata;
        _agentStates[tokenId] = AgentState.ACTIVE;

        return tokenId;
    }

    // ─── IBAP578: Execute Action ────────────────────────────────
    function executeAction(uint256 tokenId, bytes calldata data)
        external
        onlyTokenOwner(tokenId)
        onlyActiveAgent(tokenId)
        nonReentrant
        returns (bytes memory)
    {
        address logic = _logicAddresses[tokenId];
        require(logic != address(0), "No logic address set");

        (bool success, bytes memory result) = logic.call(data);
        require(success, "Action execution failed");

        emit ActionExecuted(tokenId, result);
        return result;
    }

    // ─── IBAP578: Fund / Withdraw ───────────────────────────────
    function fundAgent(uint256 tokenId) external payable onlyActiveAgent(tokenId) nonReentrant {
        require(msg.value > 0, "Must send BNB");
        _agentBalances[tokenId] += msg.value;
        emit AgentFunded(tokenId, msg.value);
    }

    function withdrawFromAgent(uint256 tokenId, uint256 amount)
        external
        onlyTokenOwner(tokenId)
        nonReentrant
    {
        require(amount > 0, "Amount must be > 0");
        require(_agentBalances[tokenId] >= amount, "Insufficient agent balance");
        _agentBalances[tokenId] -= amount;
        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "Transfer failed");
        emit AgentWithdrawn(tokenId, amount);
    }

    // ─── IBAP578: State Management ──────────────────────────────
    function pauseAgent(uint256 tokenId) external onlyTokenOwner(tokenId) {
        require(_agentStates[tokenId] == AgentState.ACTIVE, "Agent not active");
        _agentStates[tokenId] = AgentState.PAUSED;
        emit AgentPaused(tokenId);
    }

    function unpauseAgent(uint256 tokenId) external onlyTokenOwner(tokenId) {
        require(_agentStates[tokenId] == AgentState.PAUSED, "Agent not paused");
        _agentStates[tokenId] = AgentState.ACTIVE;
        emit AgentUnpaused(tokenId);
    }

    function terminateAgent(uint256 tokenId) external onlyTokenOwner(tokenId) {
        require(_agentStates[tokenId] != AgentState.TERMINATED, "Already terminated");
        _agentStates[tokenId] = AgentState.TERMINATED;
        emit AgentTerminated(tokenId);
    }

    function getState(uint256 tokenId) external view returns (AgentState) {
        _requireOwned(tokenId);
        return _agentStates[tokenId];
    }

    // ─── IBAP578: Metadata ──────────────────────────────────────
    function getAgentMetadata(uint256 tokenId) external view returns (AgentMetadata memory) {
        _requireOwned(tokenId);
        return _agentMetadata[tokenId];
    }

    function updateAgentMetadata(uint256 tokenId, AgentMetadata calldata metadata)
        external
        onlyTokenOwner(tokenId)
    {
        _agentMetadata[tokenId] = metadata;
        emit MetadataUpdated(tokenId);
    }

    // ─── IBAP578: Logic Address ─────────────────────────────────
    function setLogicAddress(uint256 tokenId, address logic)
        external
        onlyTokenOwner(tokenId)
    {
        _logicAddresses[tokenId] = logic;
        emit LogicAddressUpdated(tokenId, logic);
    }

    // ─── Prediction Profile ─────────────────────────────────────
    function updateProfile(
        uint256 tokenId,
        bytes32 newStyleRoot,
        uint256 totalPredictions,
        uint256 correctPredictions
    ) external onlyTokenOwner(tokenId) {
        PredictionProfile storage profile = _profiles[tokenId];
        profile.styleRoot = newStyleRoot;
        profile.totalPredictions = totalPredictions;
        profile.correctPredictions = correctPredictions;
        if (totalPredictions > 0) {
            profile.reputationScore = (correctPredictions * 10000) / totalPredictions;
        }
        emit ProfileUpdated(tokenId);
    }

    function getProfile(uint256 tokenId) external view returns (PredictionProfile memory) {
        _requireOwned(tokenId);
        return _profiles[tokenId];
    }

    // ─── Auto Trade Authorization ───────────────────────────────
    function authorizeAutoTrade(
        uint256 tokenId,
        address caller,
        uint256 maxPerTrade,
        uint256 maxDaily,
        uint256 duration
    ) external onlyTokenOwner(tokenId) {
        require(caller != address(0), "Invalid caller address");
        _autoTradeAuth[tokenId] = AutoTradeAuth({
            authorized: true,
            authorizedCaller: caller,
            maxAmountPerTrade: maxPerTrade,
            maxDailyAmount: maxDaily,
            dailyUsed: 0,
            lastResetDay: block.timestamp / 1 days,
            expiresAt: block.timestamp + duration
        });
        emit AutoTradeAuthorized(tokenId, maxPerTrade, maxDaily, block.timestamp + duration);
    }

    function revokeAutoTrade(uint256 tokenId) external onlyTokenOwner(tokenId) {
        _autoTradeAuth[tokenId].authorized = false;
        emit AutoTradeRevoked(tokenId);
    }

    function executeAgentTrade(
        uint256 tokenId,
        address target,
        bytes calldata data,
        uint256 value
    ) external onlyActiveAgent(tokenId) nonReentrant returns (bytes memory) {
        address tokenOwner = ownerOf(tokenId);
        AutoTradeAuth storage auth = _autoTradeAuth[tokenId];

        // Owner can always execute; others need authorization
        if (msg.sender != tokenOwner) {
            require(auth.authorized, "Not authorized");
            require(msg.sender == auth.authorizedCaller, "Not authorized caller");
            require(block.timestamp < auth.expiresAt, "Authorization expired");
            require(value <= auth.maxAmountPerTrade, "Exceeds per-trade limit");

            // Reset daily counter if new day
            uint256 today = block.timestamp / 1 days;
            if (today > auth.lastResetDay) {
                auth.dailyUsed = 0;
                auth.lastResetDay = today;
            }

            require(auth.dailyUsed + value <= auth.maxDailyAmount, "Exceeds daily limit");
            auth.dailyUsed += value;
        }

        require(_agentBalances[tokenId] >= value, "Insufficient agent balance");
        _agentBalances[tokenId] -= value;

        (bool success, bytes memory result) = target.call{value: value}(data);
        require(success, "Trade execution failed");

        emit AgentTradeExecuted(tokenId, target, value);
        return result;
    }

    function getAutoTradeAuth(uint256 tokenId) external view returns (AutoTradeAuth memory) {
        _requireOwned(tokenId);
        return _autoTradeAuth[tokenId];
    }

    // ─── ILearningModule ────────────────────────────────────────
    function updateLearning(uint256 tokenId, bytes32 newRoot, bytes calldata /* proof */)
        external
        onlyTokenOwner(tokenId)
    {
        LearningMetrics storage metrics = _learningMetrics[tokenId];
        metrics.learningRoot = newRoot;
        metrics.lastUpdated = block.timestamp;
        emit LearningUpdated(tokenId, newRoot);
    }

    function verifyLearning(uint256 tokenId, bytes32 claim, bytes32[] calldata proof)
        external
        view
        returns (bool)
    {
        _requireOwned(tokenId);
        bytes32 root = _learningMetrics[tokenId].learningRoot;
        if (root == bytes32(0)) return false;
        return MerkleProof.verify(proof, root, claim);
    }

    function getLearningMetrics(uint256 tokenId) external view returns (LearningMetrics memory) {
        _requireOwned(tokenId);
        return _learningMetrics[tokenId];
    }

    function recordInteraction(uint256 tokenId, bool success) external onlyTokenOwner(tokenId) {
        LearningMetrics storage metrics = _learningMetrics[tokenId];
        metrics.totalInteractions++;
        if (success) {
            metrics.successfulOutcomes++;
        }
        metrics.lastUpdated = block.timestamp;
        emit InteractionRecorded(tokenId, metrics.totalInteractions);
    }

    // ─── Token URI ────────────────────────────────────────────────
    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        return string(abi.encodePacked(_baseTokenURI, Strings.toString(tokenId), ".json"));
    }

    // ─── Admin ──────────────────────────────────────────────────
    function setPredictionMarket(address _predictionMarket) external onlyOwner {
        predictionMarket = _predictionMarket;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function getAgentBalance(uint256 tokenId) external view returns (uint256) {
        _requireOwned(tokenId);
        return _agentBalances[tokenId];
    }

    // ─── Vault Management ────────────────────────────────────────
    function updateVault(uint256 tokenId, string calldata newVaultURI, bytes32 newVaultHash)
        external
        onlyTokenOwner(tokenId)
    {
        _agentMetadata[tokenId].vaultURI = newVaultURI;
        _agentMetadata[tokenId].vaultHash = newVaultHash;
        emit VaultUpdated(tokenId, newVaultURI, newVaultHash);
    }

    // ─── IMemoryModuleRegistry ───────────────────────────────────
    function registerModule(uint256 tokenId, address moduleAddress, string memory metadata)
        external
        onlyTokenOwner(tokenId)
    {
        _memoryModules[tokenId][moduleAddress] = MemoryModule({
            moduleAddress: moduleAddress,
            metadata: metadata,
            metadataHash: keccak256(abi.encodePacked(metadata)),
            registrationTime: block.timestamp,
            isActive: true
        });
        emit ModuleRegistered(tokenId, moduleAddress);
    }

    function deactivateModule(uint256 tokenId, address moduleAddress)
        external
        onlyTokenOwner(tokenId)
    {
        _memoryModules[tokenId][moduleAddress].isActive = false;
        emit ModuleDeactivated(tokenId, moduleAddress);
    }

    function verifyModule(uint256 tokenId, address moduleAddress, bytes32 expectedHash)
        external
        view
        returns (bool)
    {
        return _memoryModules[tokenId][moduleAddress].metadataHash == expectedHash;
    }

    function getModule(uint256 tokenId, address moduleAddress)
        external
        view
        returns (MemoryModule memory)
    {
        return _memoryModules[tokenId][moduleAddress];
    }

    // ─── IVaultPermissionManager ─────────────────────────────────
    function delegateAccess(uint256 tokenId, address delegate, PermissionLevel level, uint256 expiryTime)
        external
        onlyTokenOwner(tokenId)
    {
        _vaultPermissions[tokenId][delegate] = Permission({
            delegate: delegate,
            level: level,
            expiryTime: expiryTime,
            isActive: true
        });
        emit AccessDelegated(tokenId, delegate, level, expiryTime);
    }

    function revokeAccess(uint256 tokenId, address delegate)
        external
        onlyTokenOwner(tokenId)
    {
        _vaultPermissions[tokenId][delegate].isActive = false;
        emit AccessRevoked(tokenId, delegate);
    }

    function verifyAccess(uint256 tokenId, address accessor, PermissionLevel requiredLevel)
        external
        view
        returns (bool)
    {
        Permission storage perm = _vaultPermissions[tokenId][accessor];
        if (!perm.isActive) return false;
        if (block.timestamp >= perm.expiryTime) return false;
        if (uint8(perm.level) < uint8(requiredLevel)) return false;
        return true;
    }

    function getPermission(uint256 tokenId, address delegate)
        external
        view
        returns (Permission memory)
    {
        return _vaultPermissions[tokenId][delegate];
    }

    // ─── Receive BNB ────────────────────────────────────────────
    receive() external payable {}
    fallback() external payable { revert("Use fundAgent()"); }
}
