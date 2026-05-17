// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./MetricsTracker.sol";

/**
 * @title IERC721Ownable
 * @dev Minimal interface to check NFT ownership on BAP578
 */
interface IERC721Ownable {
    function ownerOf(uint256 tokenId) external view returns (address);
}

/**
 * @title IPancakeRouter02
 * @dev Minimal interface for PancakeSwap V2 Router on BSC
 */
interface IPancakeRouter02 {
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts);

    function WETH() external pure returns (address);
}

/**
 * @title IFourMemeTokenManager
 * @dev Interface for FourMeme bonding curve (TokenManager2) on BSC
 */
interface IFourMemeTokenManager {
    function buyTokenAMAP(address token, uint256 funds, uint256 minAmount) external payable;
    function sellToken(address token, uint256 amount) external;
}

/**
 * @title IFourMemeHelper
 * @dev Interface for FourMeme TokenManagerHelper3 (read-only queries)
 */
interface IFourMemeHelper {
    function getTokenInfo(address token) external view returns (
        uint256 version,
        address tokenManager,
        address quote,
        uint256 lastPrice,
        uint256 tradingFeeRate,
        uint256 minTradingFee,
        uint256 launchTime,
        uint256 offers,
        uint256 maxOffers,
        uint256 funds,
        uint256 maxFunds,
        bool liquidityAdded
    );

    function tryBuy(address token, uint256 amount, uint256 fundAmount) external view returns (
        address tokenManager,
        address quote,
        uint256 estimatedAmount,
        uint256 estimatedCost,
        uint256 estimatedFee,
        uint256 amountMsgValue,
        uint256 amountApproval,
        uint256 amountFunds
    );
}

/**
 * @title IERC20
 * @dev Minimal ERC20 interface for token interactions
 */
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

/**
 * @title CTOAgentLogic
 * @dev Community Takeover Agent — unified trading + social logic contract.
 *
 *      This agent evaluates FourMeme-launched tokens based on oracle-fed
 *      market cap and holder concentration data, runs single-token CTO
 *      campaigns with graduated take-profit exits, and manages an X/Twitter
 *      presence for community growth — all from one contract.
 *
 *      Core capabilities:
 *       - CTO campaign lifecycle: configure → evaluate → start → buy → exit → complete
 *       - On-chain threshold validation (max top holder %, market cap range)
 *       - FourMeme-only token verification via FOURMEME_HELPER.getTokenInfo
 *       - Graduated exit: configurable take-profit tranches (e.g. 25% at 2x, 25% at 5x, 50% at 10x)
 *       - PancakeSwap V2 + FourMeme bonding curve trading (auto-routes based on liquidity status)
 *       - Social/X actions: post, schedule, raid, engagement tracking, mention monitoring
 *       - Holder distribution reporting for alpha-call content generation
 *       - Gas reimbursement from agent vault (NFT itself pays, never admin/third party)
 *       - Activity and learning recording
 *
 * Security:
 *  - ReentrancyGuard (manual, no OZ dependency)
 *  - SafeERC20 pattern (checked return values + approve(0) reset)
 *  - Fee-on-transfer safe (balance-diff accounting)
 *  - Campaign state machine enforcement (no skipping states)
 *  - Pausable with two-step ownership transfer
 *  - Emergency withdrawal for stuck BNB/tokens
 *  - NFT ownership checked at call time (not cached)
 *  - Gas reimbursement reverts entire tx if agent vault insufficient
 */
contract CTOAgentLogic is MetricsTracker {

    // ── Custom Errors (bytecode size optimization) ──

    // Access
    error NotOwner();
    error NotAuthorized();
    error ContractPaused();
    error Reentrant();
    error NotAgentOwner();
    error Bap578NotConfigured();

    // Validation
    error ZeroAddress();
    error ZeroAmount();
    error InvalidSlippage();
    error InvalidTrancheCount();
    error InvalidThresholds();

    // Balance
    error InsufficientBNB();
    error InsufficientTokens();

    // Campaign
    error CampaignActive();
    error CampaignNotActive();
    error CampaignNotInactive();
    error ThresholdsNotConfigured();
    error MustEvaluateFirst();
    error AlreadyBought();
    error TokenMismatch();
    error NotFourMemeToken();
    error NoEntryRecorded();
    error TrancheAlreadyExecuted();
    error InvalidTrancheIndex();
    error NothingToSell();
    error NoCampaignToEnd();

    // Tranche validation
    error ArrayLengthMismatch();
    error MultipliersNotIncreasing();
    error ZeroSellPercent();
    error SellPercentsMustSum10000();
    error MaxBuyExceeded();

    // Trading
    error SwapFailed();
    error TransferFailed();
    error ApproveFailed();
    error FourMemeBuyFailed();
    error FourMemeSellFailed();
    error FourMemeQueryFailed();

    // Other
    error ScheduleInPast();
    error NothingToRecover();
    error OverheadTooHigh();
    error NotPendingOwner();
    error PnlOverflow();

    // ── PancakeSwap V2 Router on BSC Mainnet ──
    IPancakeRouter02 public constant ROUTER =
        IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    // ── WBNB on BSC Mainnet ──
    address public constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    // ── FourMeme Bonding Curve Contracts on BSC Mainnet ──
    IFourMemeTokenManager public constant FOURMEME =
        IFourMemeTokenManager(0x5c952063c7fc8610FFDB798152D69F0B9550762b);
    IFourMemeHelper public constant FOURMEME_HELPER =
        IFourMemeHelper(0xF251F83e40a78868FcfA3FA4599Dad6494E46034);

    // ── Trading constants ──
    uint256 public constant MAX_SLIPPAGE_BPS = 3000;   // 30% max
    uint256 public constant DEADLINE_EXTENSION = 300;   // 5 minutes
    uint256 public constant BPS_DENOMINATOR = 10000;    // Basis points denominator
    uint256 public constant MAX_TRANCHES = 10;          // Max take-profit tranches

    // ══════════════════════════════════════════════════════════════
    //  Enums
    // ══════════════════════════════════════════════════════════════

    /// @dev Campaign lifecycle states
    enum CampaignStatus {
        INACTIVE,     // 0 — No active campaign
        EVALUATING,   // 1 — Token under evaluation (thresholds being checked)
        ACTIVE,       // 2 — Campaign live, position open
        EXITING,      // 3 — Executing graduated exit tranches
        COMPLETED     // 4 — All tranches sold or campaign force-ended
    }

    // ══════════════════════════════════════════════════════════════
    //  Structs
    // ══════════════════════════════════════════════════════════════

    /// @dev Take-profit tranche configuration and execution state
    struct TakeProfitTranche {
        uint256 mcapMultiplierBps;  // Market cap multiplier in bps relative to entry (20000 = 2x)
        uint256 sellPercentBps;     // % of *original* position to sell (2500 = 25%)
        bool executed;              // Whether this tranche has been sold
        uint256 executedAt;         // Timestamp when executed (0 if not yet)
        uint256 bnbReceived;        // BNB received from selling this tranche
    }

    /// @dev Campaign evaluation thresholds (per-agent, configurable)
    struct CampaignThresholds {
        uint256 maxTopHolderPct;    // Max top holder % in bps (500 = 5%)
        uint256 minMarketCapWei;    // Min market cap to consider
        uint256 maxMarketCapWei;    // Max market cap to consider (still "low")
        uint256 maxBuyAmountBnb;    // Max BNB to spend on initial buy
    }

    /// @dev Per-agent campaign state (single campaign at a time)
    struct Campaign {
        address tokenAddress;         // The FourMeme token being traded
        CampaignStatus status;        // Current lifecycle state
        uint256 entryMarketCapWei;    // Market cap at time of buy
        uint256 entryTokenAmount;     // Tokens acquired (original position size)
        uint256 remainingTokenAmount; // Tokens still held after partial exits
        uint256 totalBnbSpent;        // BNB spent buying in
        uint256 totalBnbReceived;     // BNB received from all exits
        uint256 startedAt;            // Timestamp campaign started
        uint256 completedAt;          // Timestamp campaign completed (0 if active)
        uint256 trancheCount;         // Number of take-profit tranches
        bool isFourMemeBonding;       // true = still on bonding curve at entry
    }

    // ══════════════════════════════════════════════════════════════
    //  State Variables
    // ══════════════════════════════════════════════════════════════

    string public name = "CTOAgentLogic";
    string public version = "1.0.0";

    // ── BAP578 NFT contract for ownership verification ──
    IERC721Ownable public bap578;

    // ── Per-agent BNB balances ──
    mapping(uint256 => uint256) public agentBNBBalance;

    // ── Per-agent token balances: tokenId => token => balance ──
    mapping(uint256 => mapping(address => uint256)) public agentTokenBalance;

    // ── CTO Campaign state ──
    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => CampaignThresholds) public campaignThresholds;
    mapping(uint256 => mapping(uint256 => TakeProfitTranche)) public campaignTranches;
    mapping(uint256 => uint256) public completedCampaignCount;

    // ── Authorized callers (runtime signers) ──
    mapping(address => bool) public authorizedCallers;
    address public owner;
    address public pendingOwner;

    // ── Pausable ──
    bool public paused;

    // ── Reentrancy guard ──
    uint256 private _reentrancyStatus;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    // ── Slippage config (basis points, 100 = 1%) ──
    uint256 public defaultSlippageBps = 500; // 5% default slippage tolerance

    // ── Gas reimbursement config ──
    bool public gasReimbursementEnabled = true;
    uint256 public gasOverhead = 50000;

    // ── Social media state ──
    mapping(uint256 => uint256) public totalPosts;
    mapping(uint256 => uint256) public totalEngagements;
    mapping(bytes32 => bool) public scheduledPosts;

    // ══════════════════════════════════════════════════════════════
    //  Events — Trading (from V5)
    // ══════════════════════════════════════════════════════════════

    event ActionHandled(uint256 indexed tokenId, string action, bool success, bytes result);
    event TradingActionRequested(
        uint256 indexed tokenId,
        address indexed caller,
        string action,
        address tokenAddress,
        uint256 amount,
        uint256 slippageBps
    );
    event SwapExecuted(
        uint256 indexed tokenId,
        string swapType,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );
    event Deposited(uint256 indexed tokenId, address token, uint256 amount);
    event Withdrawn(uint256 indexed tokenId, address token, uint256 amount, address to);
    event CallerAuthorized(address caller);
    event CallerRevoked(address caller);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address account);
    event Unpaused(address account);
    event SlippageUpdated(uint256 oldBps, uint256 newBps);
    event EmergencyWithdraw(address token, uint256 amount, address to);
    event FourMemeBuy(uint256 indexed tokenId, address token, uint256 bnbSpent, uint256 tokensReceived);
    event FourMemeSell(uint256 indexed tokenId, address token, uint256 tokensSold, uint256 bnbReceived);
    event AgentOwnerWithdraw(uint256 indexed tokenId, address indexed agentOwner, address token, uint256 amount);
    event Bap578Updated(address indexed oldAddress, address indexed newAddress);
    event GasReimbursed(uint256 indexed tokenId, address indexed caller, uint256 gasUsed, uint256 gasCost);

    // ══════════════════════════════════════════════════════════════
    //  Events — Activity/Learning (from V5)
    // ══════════════════════════════════════════════════════════════

    event ActivityRecorded(uint256 indexed tokenId, uint256 platform, uint256 timestamp);
    event LearningRecorded(uint256 indexed tokenId, bytes32 dataHash, uint256 interactionCount, uint256 timestamp);

    // ══════════════════════════════════════════════════════════════
    //  Events — CTO Campaign
    // ══════════════════════════════════════════════════════════════

    event CampaignConfigured(
        uint256 indexed tokenId,
        uint256 maxTopHolderPct,
        uint256 minMarketCap,
        uint256 maxMarketCap,
        uint256 maxBuyAmount,
        uint256 trancheCount
    );
    event TokenEvaluated(
        uint256 indexed tokenId,
        address indexed tokenAddress,
        uint256 oracleMarketCap,
        uint256 oracleTopHolderPct,
        bool passed
    );
    event CampaignStarted(
        uint256 indexed tokenId,
        address indexed tokenAddress,
        uint256 timestamp
    );
    event CampaignBuyExecuted(
        uint256 indexed tokenId,
        address indexed tokenAddress,
        uint256 bnbSpent,
        uint256 tokensReceived,
        uint256 entryMarketCap
    );
    event ExitConditionChecked(
        uint256 indexed tokenId,
        uint256 currentMarketCap,
        uint256 entryMarketCap,
        uint256 nextTrancheIndex,
        bool triggered
    );
    event TrancheExecuted(
        uint256 indexed tokenId,
        uint256 trancheIndex,
        uint256 tokensSold,
        uint256 bnbReceived,
        uint256 mcapMultiplierBps
    );
    event CampaignEnded(
        uint256 indexed tokenId,
        address indexed tokenAddress,
        uint256 totalBnbSpent,
        uint256 totalBnbReceived,
        int256 pnlWei,
        uint256 timestamp
    );
    event CampaignStatusChanged(
        uint256 indexed tokenId,
        CampaignStatus oldStatus,
        CampaignStatus newStatus
    );

    // ══════════════════════════════════════════════════════════════
    //  Events — Social/X
    // ══════════════════════════════════════════════════════════════

    event SocialActionRequested(
        uint256 indexed tokenId,
        address indexed caller,
        string action,
        uint8 platform,
        string target
    );
    event SocialActionCompleted(
        uint256 indexed tokenId,
        string action,
        uint8 platform,
        bool success,
        bytes32 postId,
        string message
    );
    event RaidExecuted(
        uint256 indexed tokenId,
        uint8 platform,
        string targetPostId,
        uint256 timestamp
    );
    event HolderDistributionReported(
        uint256 indexed tokenId,
        uint256 topHolderCount,
        uint256 totalHolders,
        uint256 topHolderPctBps,
        uint256 timestamp
    );

    // ══════════════════════════════════════════════════════════════
    //  Modifiers
    // ══════════════════════════════════════════════════════════════

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyAuthorized() {
        if (!authorizedCallers[msg.sender] && msg.sender != owner) revert NotAuthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyStatus == _ENTERED) revert Reentrant();
        _reentrancyStatus = _ENTERED;
        _;
        _reentrancyStatus = _NOT_ENTERED;
    }

    modifier onlyAgentOwner(uint256 tokenId) {
        if (address(bap578) == address(0)) revert Bap578NotConfigured();
        if (bap578.ownerOf(tokenId) != msg.sender) revert NotAgentOwner();
        _;
    }

    // ══════════════════════════════════════════════════════════════
    //  Constructor
    // ══════════════════════════════════════════════════════════════

    constructor(address _bap578) {
        if (_bap578 == address(0)) revert ZeroAddress();
        owner = msg.sender;
        authorizedCallers[msg.sender] = true;
        _reentrancyStatus = _NOT_ENTERED;
        bap578 = IERC721Ownable(_bap578);
    }

    // ══════════════════════════════════════════════════════════════
    //  Admin
    // ══════════════════════════════════════════════════════════════

    function authorizeCaller(address caller) external onlyOwner {
        if (caller == address(0)) revert ZeroAddress();
        authorizedCallers[caller] = true;
        emit CallerAuthorized(caller);
    }

    function revokeCaller(address caller) external onlyOwner {
        authorizedCallers[caller] = false;
        emit CallerRevoked(caller);
    }

    function setDefaultSlippage(uint256 bps) external onlyOwner {
        if (bps < 50 || bps > MAX_SLIPPAGE_BPS) revert InvalidSlippage(); // LOW-5 fix: min 0.5%
        emit SlippageUpdated(defaultSlippageBps, bps);
        defaultSlippageBps = bps;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert NotPendingOwner();
        emit OwnershipTransferred(owner, pendingOwner);
        owner = pendingOwner;
        pendingOwner = address(0);
    }

    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function setBap578(address _bap578) external onlyOwner {
        if (_bap578 == address(0)) revert ZeroAddress();
        emit Bap578Updated(address(bap578), _bap578);
        bap578 = IERC721Ownable(_bap578);
    }

    function setGasReimbursementEnabled(bool _enabled) external onlyOwner {
        gasReimbursementEnabled = _enabled;
    }

    function setGasOverhead(uint256 _overhead) external onlyOwner {
        if (_overhead > 500000) revert OverheadTooHigh();
        gasOverhead = _overhead;
    }

    // ══════════════════════════════════════════════════════════════
    //  Deposit / Withdraw
    // ══════════════════════════════════════════════════════════════

    function depositBNB(uint256 tokenId) external payable whenNotPaused nonReentrant {
        if (msg.value == 0) revert ZeroAmount();
        if (address(bap578) != address(0)) {
            bap578.ownerOf(tokenId); // reverts if tokenId doesn't exist
        }
        agentBNBBalance[tokenId] += msg.value;
        emit Deposited(tokenId, address(0), msg.value);
    }

    function depositToken(uint256 tokenId, address token, uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (token == address(0)) revert ZeroAddress();
        if (address(bap578) != address(0)) {
            bap578.ownerOf(tokenId);
        }

        uint256 balBefore = IERC20(token).balanceOf(address(this));
        _safeTransferFrom(token, msg.sender, address(this), amount);
        uint256 received = IERC20(token).balanceOf(address(this)) - balBefore;
        if (received == 0) revert ZeroAmount();

        agentTokenBalance[tokenId][token] += received;
        emit Deposited(tokenId, token, received);
    }

    function withdrawBNB(uint256 tokenId, uint256 amount, address payable to) external onlyOwner nonReentrant {
        if (agentBNBBalance[tokenId] < amount) revert InsufficientBNB();
        if (to == address(0)) revert ZeroAddress();
        agentBNBBalance[tokenId] -= amount;
        (bool sent, ) = to.call{value: amount}("");
        if (!sent) revert TransferFailed();
        emit Withdrawn(tokenId, address(0), amount, to);
    }

    function withdrawToken(uint256 tokenId, address token, uint256 amount, address to) external onlyOwner nonReentrant {
        if (agentTokenBalance[tokenId][token] < amount) revert InsufficientTokens();
        if (to == address(0)) revert ZeroAddress();
        agentTokenBalance[tokenId][token] -= amount;
        _safeTransfer(token, to, amount);
        emit Withdrawn(tokenId, token, amount, to);
    }

    // ── NFT Owner Withdrawals ──

    function agentOwnerWithdrawBNB(uint256 tokenId, uint256 amount)
        external
        onlyAgentOwner(tokenId)
        whenNotPaused
        nonReentrant
    {
        if (amount == 0) revert ZeroAmount();
        if (agentBNBBalance[tokenId] < amount) revert InsufficientBNB();
        agentBNBBalance[tokenId] -= amount;
        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        if (!sent) revert TransferFailed();
        emit AgentOwnerWithdraw(tokenId, msg.sender, address(0), amount);
    }

    function agentOwnerWithdrawToken(uint256 tokenId, address token, uint256 amount)
        external
        onlyAgentOwner(tokenId)
        whenNotPaused
        nonReentrant
    {
        if (amount == 0) revert ZeroAmount();
        if (token == address(0)) revert ZeroAddress();
        if (agentTokenBalance[tokenId][token] < amount) revert InsufficientTokens();
        agentTokenBalance[tokenId][token] -= amount;
        _safeTransfer(token, msg.sender, amount);
        emit AgentOwnerWithdraw(tokenId, msg.sender, token, amount);
    }

    // ── Emergency ──

    /// @dev CRITICAL-3 fix: Emergency withdraw pauses contract to prevent stale balance usage
    function emergencyWithdrawBNB(address payable to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        uint256 contractBal = address(this).balance;
        if (contractBal == 0) revert NothingToRecover();
        paused = true; // Auto-pause to prevent stale balance operations
        emit Paused(msg.sender);
        (bool sent, ) = to.call{value: contractBal}("");
        if (!sent) revert TransferFailed();
        emit EmergencyWithdraw(address(0), contractBal, to);
    }

    function emergencyWithdrawToken(address token, address to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        uint256 contractBal = IERC20(token).balanceOf(address(this));
        if (contractBal == 0) revert NothingToRecover();
        paused = true; // Auto-pause to prevent stale balance operations
        emit Paused(msg.sender);
        _safeTransfer(token, to, contractBal);
        emit EmergencyWithdraw(token, contractBal, to);
    }

    /// @dev CRITICAL-3 fix: Reset agent balance after emergency (call per affected agent)
    function resetAgentBalance(uint256 tokenId) external onlyOwner {
        agentBNBBalance[tokenId] = 0;
    }

    function resetAgentTokenBalance(uint256 tokenId, address token) external onlyOwner {
        agentTokenBalance[tokenId][token] = 0;
    }

    // ══════════════════════════════════════════════════════════════
    //  handleAction — Main Dispatcher
    // ══════════════════════════════════════════════════════════════

    function handleAction(
        uint256 tokenId,
        string calldata action,
        bytes calldata payload
    ) external onlyAuthorized whenNotPaused nonReentrant returns (bool success, bytes memory result) {
        uint256 gasStart = gasleft();
        bytes32 actionHash = keccak256(bytes(action));

        // ── CTO Campaign Actions ──
        if (actionHash == keccak256(bytes("configure_campaign"))) {
            (success, result) = _handleConfigureCampaign(tokenId, payload);
        } else if (actionHash == keccak256(bytes("evaluate_token"))) {
            (success, result) = _handleEvaluateToken(tokenId, payload);
        } else if (actionHash == keccak256(bytes("start_campaign"))) {
            (success, result) = _handleStartCampaign(tokenId, payload);
        } else if (actionHash == keccak256(bytes("execute_buy"))) {
            (success, result) = _handleExecuteBuy(tokenId, payload);
        } else if (actionHash == keccak256(bytes("check_exit_conditions"))) {
            (success, result) = _handleCheckExitConditions(tokenId, payload);
        } else if (actionHash == keccak256(bytes("execute_exit"))) {
            (success, result) = _handleExecuteExit(tokenId, payload);
        } else if (actionHash == keccak256(bytes("end_campaign"))) {
            (success, result) = _handleEndCampaign(tokenId, payload);
        } else if (actionHash == keccak256(bytes("get_campaign_status"))) {
            (success, result) = _handleGetCampaignStatus(tokenId);

        // ── Trading Actions (from V5) ──
        } else if (actionHash == keccak256(bytes("buy_token"))) {
            (success, result) = _handleBuyToken(tokenId, payload);
        } else if (actionHash == keccak256(bytes("sell_token"))) {
            (success, result) = _handleSellToken(tokenId, payload);
        } else if (actionHash == keccak256(bytes("check_balance"))) {
            (success, result) = _handleCheckBalance(tokenId, payload);
        } else if (actionHash == keccak256(bytes("get_price"))) {
            (success, result) = _handleGetPrice(payload);
        } else if (actionHash == keccak256(bytes("buy_fourmeme"))) {
            (success, result) = _handleBuyFourMeme(tokenId, payload);
        } else if (actionHash == keccak256(bytes("sell_fourmeme"))) {
            (success, result) = _handleSellFourMeme(tokenId, payload);
        } else if (actionHash == keccak256(bytes("check_fourmeme"))) {
            (success, result) = _handleCheckFourMeme(payload);

        // ── Social/X Actions ──
        } else if (actionHash == keccak256(bytes("post_content"))) {
            (success, result) = _handlePostContent(tokenId, payload);
        } else if (actionHash == keccak256(bytes("schedule_post"))) {
            (success, result) = _handleSchedulePost(tokenId, payload);
        } else if (actionHash == keccak256(bytes("track_engagement"))) {
            (success, result) = _handleTrackEngagement(tokenId, payload);
        } else if (actionHash == keccak256(bytes("monitor_mentions"))) {
            (success, result) = _handleMonitorMentions(tokenId, payload);
        } else if (actionHash == keccak256(bytes("raid_post"))) {
            (success, result) = _handleRaidPost(tokenId, payload);
        } else if (actionHash == keccak256(bytes("report_holders"))) {
            (success, result) = _handleReportHolders(tokenId, payload);

        // ── Activity/Learning (from V5) ──
        } else if (actionHash == keccak256(bytes("record_activity"))) {
            (success, result) = _handleRecordActivity(tokenId, payload);
        } else if (actionHash == keccak256(bytes("record_learning"))) {
            (success, result) = _handleRecordLearning(tokenId, payload);

        } else {
            (success, result) = (false, abi.encode("Unknown action"));
        }

        emit ActionHandled(tokenId, action, success, result);

        // On-chain metrics — increment counters and update lastActiveTimestamp.
        // Inlined trade-action detection avoids extra function dispatch overhead.
        bool _isTrade =
            actionHash == keccak256(bytes("execute_buy")) ||
            actionHash == keccak256(bytes("execute_exit")) ||
            actionHash == keccak256(bytes("buy_token")) ||
            actionHash == keccak256(bytes("sell_token")) ||
            actionHash == keccak256(bytes("buy_fourmeme")) ||
            actionHash == keccak256(bytes("sell_fourmeme"));
        _recordAction(tokenId, success, _isTrade);

        // Reimburse gas from agent vault
        _reimburseGas(tokenId, gasStart);
    }

    // ══════════════════════════════════════════════════════════════
    //  CTO Campaign Handlers
    // ══════════════════════════════════════════════════════════════

    /// @dev Configure campaign thresholds and take-profit tranches.
    ///      Can only be called when campaign is INACTIVE or COMPLETED.
    ///      Payload: (uint256 maxTopHolderPct, uint256 minMarketCapWei, uint256 maxMarketCapWei,
    ///               uint256 maxBuyAmountBnb, uint256 trancheCount,
    ///               uint256[] mcapMultipliersBps, uint256[] sellPercentsBps)
    function _handleConfigureCampaign(
        uint256 tokenId,
        bytes calldata payload
    ) internal returns (bool, bytes memory) {
        CampaignStatus currentStatus = campaigns[tokenId].status;
        if (currentStatus != CampaignStatus.INACTIVE && currentStatus != CampaignStatus.COMPLETED) revert CampaignActive();

        // Decode scalar params and arrays separately to avoid stack-too-deep
        (
            uint256 maxTopHolderPct,
            uint256 minMarketCapWei,
            uint256 maxMarketCapWei,
            uint256 maxBuyAmountBnb,
            uint256 trancheCount,
            ,
        ) = abi.decode(payload, (uint256, uint256, uint256, uint256, uint256, uint256[], uint256[]));

        if (maxTopHolderPct == 0 || maxTopHolderPct > BPS_DENOMINATOR) revert InvalidThresholds();
        if (maxMarketCapWei <= minMarketCapWei) revert InvalidThresholds();
        if (maxBuyAmountBnb == 0) revert ZeroAmount();
        if (trancheCount == 0 || trancheCount > MAX_TRANCHES) revert InvalidTrancheCount();

        // Store thresholds early to free stack slots
        campaignThresholds[tokenId] = CampaignThresholds({
            maxTopHolderPct: maxTopHolderPct,
            minMarketCapWei: minMarketCapWei,
            maxMarketCapWei: maxMarketCapWei,
            maxBuyAmountBnb: maxBuyAmountBnb
        });

        // MEDIUM-1 fix: Clear stale tranches from previous campaigns
        uint256 oldTrancheCount = campaigns[tokenId].trancheCount;
        for (uint256 i = 0; i < oldTrancheCount; i++) {
            delete campaignTranches[tokenId][i];
        }

        // Decode and store tranches via helper to avoid stack-too-deep
        _decodeTranches(tokenId, trancheCount, payload);

        // Reset campaign state
        campaigns[tokenId] = Campaign({
            tokenAddress: address(0),
            status: CampaignStatus.INACTIVE,
            entryMarketCapWei: 0,
            entryTokenAmount: 0,
            remainingTokenAmount: 0,
            totalBnbSpent: 0,
            totalBnbReceived: 0,
            startedAt: 0,
            completedAt: 0,
            trancheCount: trancheCount,
            isFourMemeBonding: false
        });

        emit CampaignConfigured(tokenId, maxTopHolderPct, minMarketCapWei, maxMarketCapWei, maxBuyAmountBnb, trancheCount);
        return (true, abi.encode("Configured"));
    }

    /// @dev Helper to decode and store tranches — extracted to avoid stack-too-deep.
    function _decodeTranches(
        uint256 tokenId,
        uint256 trancheCount,
        bytes calldata payload
    ) internal {
        (,,,,,
            uint256[] memory mcapMultipliersBps,
            uint256[] memory sellPercentsBps
        ) = abi.decode(payload, (uint256, uint256, uint256, uint256, uint256, uint256[], uint256[]));

        if (mcapMultipliersBps.length != trancheCount) revert ArrayLengthMismatch();
        if (sellPercentsBps.length != trancheCount) revert ArrayLengthMismatch();

        uint256 totalSellPercent = 0;
        uint256 prevMultiplier = BPS_DENOMINATOR;

        for (uint256 i = 0; i < trancheCount; i++) {
            if (mcapMultipliersBps[i] <= prevMultiplier) revert MultipliersNotIncreasing();
            if (sellPercentsBps[i] == 0) revert ZeroSellPercent();
            prevMultiplier = mcapMultipliersBps[i];
            totalSellPercent += sellPercentsBps[i];

            campaignTranches[tokenId][i] = TakeProfitTranche({
                mcapMultiplierBps: mcapMultipliersBps[i],
                sellPercentBps: sellPercentsBps[i],
                executed: false,
                executedAt: 0,
                bnbReceived: 0
            });
        }

        if (totalSellPercent != BPS_DENOMINATOR) revert SellPercentsMustSum10000();
    }

    /// @dev Evaluate a FourMeme token against configured thresholds.
    ///      Oracle/runtime provides current market cap and top holder %.
    ///      Payload: (address tokenAddress, uint256 oracleMarketCapWei, uint256 oracleTopHolderPctBps)
    function _handleEvaluateToken(
        uint256 tokenId,
        bytes calldata payload
    ) internal returns (bool, bytes memory) {
        if (campaigns[tokenId].status != CampaignStatus.INACTIVE) revert CampaignNotInactive();
        if (campaignThresholds[tokenId].maxMarketCapWei == 0) revert ThresholdsNotConfigured();

        (address tokenAddress, uint256 oracleMarketCapWei, uint256 oracleTopHolderPctBps) =
            abi.decode(payload, (address, uint256, uint256));

        if (tokenAddress == address(0)) revert ZeroAddress();

        // Verify FourMeme and store token info in scoped block
        {
            (bool isFourMeme, bool liquidityAdded) = _verifyFourMemeToken(tokenAddress);
            if (!isFourMeme) revert NotFourMemeToken();
            campaigns[tokenId].isFourMemeBonding = !liquidityAdded;
        }

        // Evaluate against thresholds
        bool holderCheck = oracleTopHolderPctBps <= campaignThresholds[tokenId].maxTopHolderPct;
        bool mcapCheck = oracleMarketCapWei >= campaignThresholds[tokenId].minMarketCapWei &&
                         oracleMarketCapWei <= campaignThresholds[tokenId].maxMarketCapWei;

        emit TokenEvaluated(tokenId, tokenAddress, oracleMarketCapWei, oracleTopHolderPctBps, holderCheck && mcapCheck);

        if (!(holderCheck && mcapCheck)) {
            // Reset bonding flag since evaluation failed
            campaigns[tokenId].isFourMemeBonding = false;
            string memory reason = !holderCheck ? "Top holder too concentrated" : "Market cap out of range";
            return (true, abi.encode(false, reason));
        }

        campaigns[tokenId].tokenAddress = tokenAddress;
        _setCampaignStatus(tokenId, CampaignStatus.EVALUATING);

        return (true, abi.encode(true, "Evaluation passed"));
    }

    /// @dev Start a campaign for the evaluated token.
    ///      Payload: (address tokenAddress)
    function _handleStartCampaign(
        uint256 tokenId,
        bytes calldata payload
    ) internal returns (bool, bytes memory) {
        if (campaigns[tokenId].status != CampaignStatus.EVALUATING) revert MustEvaluateFirst();

        address tokenAddress = abi.decode(payload, (address));
        if (tokenAddress != campaigns[tokenId].tokenAddress) revert TokenMismatch();

        campaigns[tokenId].startedAt = block.timestamp;
        _setCampaignStatus(tokenId, CampaignStatus.ACTIVE);

        emit CampaignStarted(tokenId, tokenAddress, block.timestamp);
        return (true, abi.encode("Started"));
    }

    /// @dev Buy the campaign token. Routes through FourMeme or PancakeSwap.
    ///      Payload: (uint256 amountBNB, uint256 slippageBps, uint256 currentMarketCapWei)
    function _handleExecuteBuy(
        uint256 tokenId,
        bytes calldata payload
    ) internal returns (bool, bytes memory) {
        Campaign storage campaign = campaigns[tokenId];
        if (campaign.status != CampaignStatus.ACTIVE) revert CampaignNotActive();
        if (campaign.entryTokenAmount != 0) revert AlreadyBought();

        (uint256 amountBNB, uint256 slippageBps, uint256 currentMarketCapWei) =
            abi.decode(payload, (uint256, uint256, uint256));

        CampaignThresholds storage thresholds = campaignThresholds[tokenId];
        if (amountBNB > thresholds.maxBuyAmountBnb) revert MaxBuyExceeded();
        if (agentBNBBalance[tokenId] < amountBNB) revert InsufficientBNB();

        if (slippageBps == 0) slippageBps = defaultSlippageBps;
        if (slippageBps > MAX_SLIPPAGE_BPS) revert InvalidSlippage();

        address tokenAddress = campaign.tokenAddress;

        // Re-check FourMeme status (may have bonded since evaluation)
        (, bool liquidityAdded) = _verifyFourMemeToken(tokenAddress);
        campaign.isFourMemeBonding = !liquidityAdded;

        agentBNBBalance[tokenId] -= amountBNB;
        uint256 tokensReceived;

        if (!liquidityAdded) {
            // Still on bonding curve — buy via FourMeme with slippage protection
            uint256 balBefore = IERC20(tokenAddress).balanceOf(address(this));
            // HIGH-5 fix: estimate tokens via tryBuy and apply slippage tolerance
            uint256 minTokens = _estimateFourMemeBuy(tokenAddress, amountBNB, slippageBps);
            FOURMEME.buyTokenAMAP{value: amountBNB}(tokenAddress, amountBNB, minTokens);
            tokensReceived = IERC20(tokenAddress).balanceOf(address(this)) - balBefore;
            if (tokensReceived == 0) revert FourMemeBuyFailed();
            emit FourMemeBuy(tokenId, tokenAddress, amountBNB, tokensReceived);
        } else {
            // Bonded — buy via PancakeSwap
            tokensReceived = _swapBNBForToken(tokenAddress, amountBNB, slippageBps);
            emit SwapExecuted(tokenId, "buy", WBNB, tokenAddress, amountBNB, tokensReceived);
        }

        agentTokenBalance[tokenId][tokenAddress] += tokensReceived;

        // Record campaign entry
        campaign.entryMarketCapWei = currentMarketCapWei;
        campaign.entryTokenAmount = tokensReceived;
        campaign.remainingTokenAmount = tokensReceived;
        campaign.totalBnbSpent = amountBNB;

        emit CampaignBuyExecuted(tokenId, tokenAddress, amountBNB, tokensReceived, currentMarketCapWei);
        return (true, abi.encode("Buy executed", tokensReceived));
    }

    /// @dev Check if any take-profit tranche is triggered.
    ///      Payload: (uint256 currentMarketCapWei)
    function _handleCheckExitConditions(
        uint256 tokenId,
        bytes calldata payload
    ) internal returns (bool, bytes memory) {
        Campaign storage campaign = campaigns[tokenId];
        if (campaign.status != CampaignStatus.ACTIVE && campaign.status != CampaignStatus.EXITING) revert CampaignNotActive();
        if (campaign.entryMarketCapWei == 0) revert NoEntryRecorded();

        uint256 currentMarketCapWei = abi.decode(payload, (uint256));

        // Calculate current multiplier in bps
        uint256 currentMultiplierBps = (currentMarketCapWei * BPS_DENOMINATOR) / campaign.entryMarketCapWei;

        // Find first unexecuted tranche whose threshold is met
        uint256 trancheCount = campaign.trancheCount;
        bool triggered = false;
        uint256 nextTrancheIndex = 0;

        for (uint256 i = 0; i < trancheCount; i++) {
            TakeProfitTranche storage tranche = campaignTranches[tokenId][i];
            if (!tranche.executed && currentMultiplierBps >= tranche.mcapMultiplierBps) {
                triggered = true;
                nextTrancheIndex = i;
                break;
            }
        }

        if (triggered && campaign.status == CampaignStatus.ACTIVE) {
            _setCampaignStatus(tokenId, CampaignStatus.EXITING);
        }

        emit ExitConditionChecked(tokenId, currentMarketCapWei, campaign.entryMarketCapWei, nextTrancheIndex, triggered);
        return (true, abi.encode(nextTrancheIndex, triggered));
    }

    /// @dev Execute a take-profit tranche sell.
    ///      Payload: (uint256 trancheIndex, uint256 slippageBps)
    function _handleExecuteExit(
        uint256 tokenId,
        bytes calldata payload
    ) internal returns (bool, bytes memory) {
        Campaign storage campaign = campaigns[tokenId];
        if (campaign.status != CampaignStatus.ACTIVE && campaign.status != CampaignStatus.EXITING) revert CampaignNotActive();

        (uint256 trancheIndex, uint256 slippageBps) = abi.decode(payload, (uint256, uint256));

        if (trancheIndex >= campaign.trancheCount) revert InvalidTrancheIndex();
        TakeProfitTranche storage tranche = campaignTranches[tokenId][trancheIndex];
        if (tranche.executed) revert TrancheAlreadyExecuted();

        if (slippageBps == 0) slippageBps = defaultSlippageBps;
        if (slippageBps > MAX_SLIPPAGE_BPS) revert InvalidSlippage();

        address tokenAddress = campaign.tokenAddress;

        // Calculate sell amount: % of original position
        uint256 sellAmount = (campaign.entryTokenAmount * tranche.sellPercentBps) / BPS_DENOMINATOR;

        // If this is the last tranche or rounding leaves dust, sell remaining
        if (sellAmount > campaign.remainingTokenAmount) {
            sellAmount = campaign.remainingTokenAmount;
        }

        if (sellAmount == 0) revert NothingToSell();
        if (agentTokenBalance[tokenId][tokenAddress] < sellAmount) revert InsufficientTokens();

        // Re-check FourMeme bonding status
        (, bool liquidityAdded) = _verifyFourMemeToken(tokenAddress);

        agentTokenBalance[tokenId][tokenAddress] -= sellAmount;
        uint256 bnbReceived;

        if (!liquidityAdded) {
            // Still on bonding curve — sell via FourMeme
            _safeApprove(tokenAddress, address(FOURMEME), 0);
            _safeApprove(tokenAddress, address(FOURMEME), sellAmount);
            uint256 balBefore = address(this).balance;
            FOURMEME.sellToken(tokenAddress, sellAmount);
            bnbReceived = address(this).balance - balBefore;
            if (bnbReceived == 0) revert FourMemeSellFailed();
            emit FourMemeSell(tokenId, tokenAddress, sellAmount, bnbReceived);
        } else {
            // Bonded — sell via PancakeSwap
            bnbReceived = _swapTokenForBNB(tokenAddress, sellAmount, slippageBps);
            emit SwapExecuted(tokenId, "sell", tokenAddress, WBNB, sellAmount, bnbReceived);
        }

        agentBNBBalance[tokenId] += bnbReceived;

        // Update tranche state
        tranche.executed = true;
        tranche.executedAt = block.timestamp;
        tranche.bnbReceived = bnbReceived;

        // Update campaign
        campaign.remainingTokenAmount -= sellAmount;
        campaign.totalBnbReceived += bnbReceived;

        emit TrancheExecuted(tokenId, trancheIndex, sellAmount, bnbReceived, tranche.mcapMultiplierBps);

        // Check if all tranches executed → auto-complete
        if (_checkAllTranchesExecuted(tokenId)) {
            campaign.completedAt = block.timestamp;
            completedCampaignCount[tokenId]++;
            int256 pnl = int256(campaign.totalBnbReceived) - int256(campaign.totalBnbSpent);
            _setCampaignStatus(tokenId, CampaignStatus.COMPLETED);
            emit CampaignEnded(
                tokenId, tokenAddress,
                campaign.totalBnbSpent, campaign.totalBnbReceived,
                pnl, block.timestamp
            );
        }

        return (true, abi.encode("Tranche executed", bnbReceived));
    }

    /// @dev Force-end a campaign. Sells any remaining tokens.
    ///      Payload: (uint256 slippageBps)
    function _handleEndCampaign(
        uint256 tokenId,
        bytes calldata payload
    ) internal returns (bool, bytes memory) {
        Campaign storage campaign = campaigns[tokenId];
        if (campaign.status == CampaignStatus.INACTIVE || campaign.status == CampaignStatus.COMPLETED) revert NoCampaignToEnd();

        uint256 slippageBps = abi.decode(payload, (uint256));
        if (slippageBps == 0) slippageBps = defaultSlippageBps;
        if (slippageBps > MAX_SLIPPAGE_BPS) revert InvalidSlippage();

        address tokenAddress = campaign.tokenAddress;
        uint256 remaining = campaign.remainingTokenAmount;

        // Sell remaining tokens if any
        if (remaining > 0 && agentTokenBalance[tokenId][tokenAddress] >= remaining) {
            (, bool liquidityAdded) = _verifyFourMemeToken(tokenAddress);

            agentTokenBalance[tokenId][tokenAddress] -= remaining;
            uint256 bnbReceived;

            if (!liquidityAdded) {
                _safeApprove(tokenAddress, address(FOURMEME), 0);
                _safeApprove(tokenAddress, address(FOURMEME), remaining);
                uint256 balBefore = address(this).balance;
                FOURMEME.sellToken(tokenAddress, remaining);
                bnbReceived = address(this).balance - balBefore;
                if (bnbReceived == 0) revert FourMemeSellFailed(); // MEDIUM-4 fix
                emit FourMemeSell(tokenId, tokenAddress, remaining, bnbReceived);
            } else {
                bnbReceived = _swapTokenForBNB(tokenAddress, remaining, slippageBps);
                if (bnbReceived > 0) {
                    emit SwapExecuted(tokenId, "sell", tokenAddress, WBNB, remaining, bnbReceived);
                }
            }

            agentBNBBalance[tokenId] += bnbReceived;
            campaign.totalBnbReceived += bnbReceived;
            campaign.remainingTokenAmount = 0;
        }

        campaign.completedAt = block.timestamp;

        // Only count as completed campaign if a trade was actually made
        if (campaign.totalBnbSpent > 0) {
            completedCampaignCount[tokenId]++;
        }

        int256 pnl = int256(campaign.totalBnbReceived) - int256(campaign.totalBnbSpent);
        _setCampaignStatus(tokenId, CampaignStatus.COMPLETED);

        emit CampaignEnded(
            tokenId, tokenAddress,
            campaign.totalBnbSpent, campaign.totalBnbReceived,
            pnl, block.timestamp
        );
        return (true, abi.encode("Campaign ended", pnl));
    }

    /// @dev Return full campaign state (read-only action).
    function _handleGetCampaignStatus(
        uint256 tokenId
    ) internal view returns (bool, bytes memory) {
        Campaign storage campaign = campaigns[tokenId];
        CampaignThresholds storage thresholds = campaignThresholds[tokenId];

        bytes memory result = abi.encode(
            campaign.tokenAddress,
            uint256(campaign.status),
            campaign.entryMarketCapWei,
            campaign.entryTokenAmount,
            campaign.remainingTokenAmount,
            campaign.totalBnbSpent,
            campaign.totalBnbReceived,
            campaign.startedAt,
            campaign.completedAt,
            campaign.trancheCount,
            campaign.isFourMemeBonding,
            thresholds.maxTopHolderPct,
            thresholds.minMarketCapWei,
            thresholds.maxMarketCapWei,
            thresholds.maxBuyAmountBnb
        );

        return (true, result);
    }

    // ══════════════════════════════════════════════════════════════
    //  Trading Handlers (from V5)
    // ══════════════════════════════════════════════════════════════

    function _handleBuyToken(
        uint256 tokenId,
        bytes calldata payload
    ) internal returns (bool, bytes memory) {
        (address tokenAddress, uint256 amountBNB, uint256 slippageBps) =
            abi.decode(payload, (address, uint256, uint256));

        if (tokenAddress == address(0)) revert ZeroAddress();
        if (slippageBps == 0) slippageBps = defaultSlippageBps;
        if (slippageBps > MAX_SLIPPAGE_BPS) revert InvalidSlippage();
        if (agentBNBBalance[tokenId] < amountBNB) revert InsufficientBNB();

        emit TradingActionRequested(tokenId, msg.sender, "buy_token", tokenAddress, amountBNB, slippageBps);
        agentBNBBalance[tokenId] -= amountBNB;

        uint256 tokensReceived = _swapBNBForToken(tokenAddress, amountBNB, slippageBps);
        agentTokenBalance[tokenId][tokenAddress] += tokensReceived;

        emit SwapExecuted(tokenId, "buy", WBNB, tokenAddress, amountBNB, tokensReceived);
        return (true, abi.encode("Trade executed"));
    }

    function _handleSellToken(
        uint256 tokenId,
        bytes calldata payload
    ) internal returns (bool, bytes memory) {
        (address tokenAddress, uint256 amountTokens, uint256 slippageBps) =
            abi.decode(payload, (address, uint256, uint256));

        if (tokenAddress == address(0)) revert ZeroAddress();
        if (slippageBps == 0) slippageBps = defaultSlippageBps;
        if (slippageBps > MAX_SLIPPAGE_BPS) revert InvalidSlippage();
        if (agentTokenBalance[tokenId][tokenAddress] < amountTokens) revert InsufficientTokens();

        emit TradingActionRequested(tokenId, msg.sender, "sell_token", tokenAddress, amountTokens, slippageBps);
        agentTokenBalance[tokenId][tokenAddress] -= amountTokens;

        uint256 bnbReceived = _swapTokenForBNB(tokenAddress, amountTokens, slippageBps);
        agentBNBBalance[tokenId] += bnbReceived;

        emit SwapExecuted(tokenId, "sell", tokenAddress, WBNB, amountTokens, bnbReceived);
        return (true, abi.encode("Trade executed"));
    }

    function _handleCheckBalance(
        uint256 tokenId,
        bytes calldata payload
    ) internal view returns (bool, bytes memory) {
        address tokenAddress = abi.decode(payload, (address));

        uint256 tokenBal = agentTokenBalance[tokenId][tokenAddress];
        uint256 bnbBal = agentBNBBalance[tokenId];

        return (true, abi.encode(bnbBal, tokenBal));
    }

    function _handleGetPrice(
        bytes calldata payload
    ) internal view returns (bool, bytes memory) {
        (address tokenAddress, uint256 amountIn, bool isBuyQuote) =
            abi.decode(payload, (address, uint256, bool));

        address[] memory path = new address[](2);
        if (isBuyQuote) {
            path[0] = WBNB;
            path[1] = tokenAddress;
        } else {
            path[0] = tokenAddress;
            path[1] = WBNB;
        }

        uint[] memory amounts = ROUTER.getAmountsOut(amountIn, path);
        return (true, abi.encode(amounts[1]));
    }

    function _handleBuyFourMeme(
        uint256 tokenId,
        bytes calldata payload
    ) internal returns (bool, bytes memory) {
        (address tokenAddress, uint256 amountBNB, uint256 minTokens) =
            abi.decode(payload, (address, uint256, uint256));

        if (tokenAddress == address(0)) revert ZeroAddress();
        if (agentBNBBalance[tokenId] < amountBNB) revert InsufficientBNB();

        emit TradingActionRequested(tokenId, msg.sender, "buy_fourmeme", tokenAddress, amountBNB, 0);
        agentBNBBalance[tokenId] -= amountBNB;

        uint256 balBefore = IERC20(tokenAddress).balanceOf(address(this));
        FOURMEME.buyTokenAMAP{value: amountBNB}(tokenAddress, amountBNB, minTokens);
        uint256 received = IERC20(tokenAddress).balanceOf(address(this)) - balBefore;
        if (received == 0) revert FourMemeBuyFailed();

        agentTokenBalance[tokenId][tokenAddress] += received;

        emit FourMemeBuy(tokenId, tokenAddress, amountBNB, received);
        return (true, abi.encode("FM buy ok"));
    }

    function _handleSellFourMeme(
        uint256 tokenId,
        bytes calldata payload
    ) internal returns (bool, bytes memory) {
        (address tokenAddress, uint256 amountTokens) =
            abi.decode(payload, (address, uint256));

        if (tokenAddress == address(0)) revert ZeroAddress();
        if (agentTokenBalance[tokenId][tokenAddress] < amountTokens) revert InsufficientTokens();

        emit TradingActionRequested(tokenId, msg.sender, "sell_fourmeme", tokenAddress, amountTokens, 0);
        agentTokenBalance[tokenId][tokenAddress] -= amountTokens;

        _safeApprove(tokenAddress, address(FOURMEME), 0);
        _safeApprove(tokenAddress, address(FOURMEME), amountTokens);

        uint256 balBefore = address(this).balance;
        FOURMEME.sellToken(tokenAddress, amountTokens);
        uint256 bnbReceived = address(this).balance - balBefore;
        if (bnbReceived == 0) revert FourMemeSellFailed();

        agentBNBBalance[tokenId] += bnbReceived;

        emit FourMemeSell(tokenId, tokenAddress, amountTokens, bnbReceived);
        return (true, abi.encode("FM sell ok"));
    }

    function _handleCheckFourMeme(
        bytes calldata payload
    ) internal view returns (bool, bytes memory) {
        address tokenAddress = abi.decode(payload, (address));

        (bool ok, bytes memory rawResult) = address(FOURMEME_HELPER).staticcall(
            abi.encodeWithSelector(IFourMemeHelper.getTokenInfo.selector, tokenAddress)
        );
        if (!ok) revert FourMemeQueryFailed();

        return (true, rawResult);
    }

    // ══════════════════════════════════════════════════════════════
    //  Social/X Handlers
    // ══════════════════════════════════════════════════════════════

    // Platform constants: 0=Twitter/X, 1=Discord, 2=Telegram, 3=Instagram, 4=Reddit

    /// @dev Post content to X/Twitter (or other platform). Off-chain runtime picks up event.
    function _handlePostContent(
        uint256 tokenId,
        bytes calldata payload
    ) internal returns (bool, bytes memory) {
        (uint8 platform, , ) =
            abi.decode(payload, (uint8, string, string));

        emit SocialActionRequested(tokenId, msg.sender, "post_content", platform, "new_post");

        bytes32 postId = _generatePostId(tokenId, platform, block.timestamp);
        totalPosts[tokenId]++;

        emit SocialActionCompleted(tokenId, "post_content", platform, true, postId, "Content posted");
        return (true, abi.encode(postId, platform));
    }

    /// @dev Schedule a post for future execution.
    function _handleSchedulePost(
        uint256 tokenId,
        bytes calldata payload
    ) internal returns (bool, bytes memory) {
        (uint8 platform, string memory content, uint256 scheduledTime) =
            abi.decode(payload, (uint8, string, uint256));

        if (scheduledTime <= block.timestamp) revert ScheduleInPast();

        emit SocialActionRequested(tokenId, msg.sender, "schedule_post", platform, "scheduled");

        bytes32 scheduleHash = keccak256(abi.encodePacked(tokenId, platform, content, scheduledTime));
        scheduledPosts[scheduleHash] = true;

        bytes32 postId = _generatePostId(tokenId, platform, scheduledTime);

        emit SocialActionCompleted(tokenId, "schedule_post", platform, true, postId, "Post scheduled");
        return (true, abi.encode(postId, platform, scheduledTime));
    }

    /// @dev Track engagement metrics for a post.
    function _handleTrackEngagement(
        uint256 tokenId,
        bytes calldata payload
    ) internal returns (bool, bytes memory) {
        (string memory postIdStr, uint8 platform) = abi.decode(payload, (string, uint8));

        emit SocialActionRequested(tokenId, msg.sender, "track_engagement", platform, postIdStr);

        // Off-chain runtime provides actual metrics. On-chain we emit the event
        // and increment engagement counter.
        totalEngagements[tokenId]++;

        bytes32 postId = keccak256(bytes(postIdStr));
        emit SocialActionCompleted(tokenId, "track_engagement", platform, true, postId, "Engagement tracked");
        return (true, abi.encode(postId, platform));
    }

    /// @dev Monitor mentions/keywords on X.
    function _handleMonitorMentions(
        uint256 tokenId,
        bytes calldata payload
    ) internal returns (bool, bytes memory) {
        (uint8 platform, string memory keyword) = abi.decode(payload, (uint8, string));

        emit SocialActionRequested(tokenId, msg.sender, "monitor_mentions", platform, keyword);
        emit SocialActionCompleted(tokenId, "monitor_mentions", platform, true, bytes32(0), "Mentions monitored");
        return (true, abi.encode(platform, keyword));
    }

    /// @dev Raid a specific post (reply/quote-tweet). Core CTO tactic.
    ///      Off-chain runtime picks up event and executes via X API.
    function _handleRaidPost(
        uint256 tokenId,
        bytes calldata payload
    ) internal returns (bool, bytes memory) {
        (uint8 platform, string memory targetPostId, ) =
            abi.decode(payload, (uint8, string, string));

        emit SocialActionRequested(tokenId, msg.sender, "raid_post", platform, targetPostId);
        emit RaidExecuted(tokenId, platform, targetPostId, block.timestamp);

        totalPosts[tokenId]++;
        totalEngagements[tokenId]++;

        bytes32 replyId = _generatePostId(tokenId, platform, block.timestamp);

        emit SocialActionCompleted(tokenId, "raid_post", platform, true, replyId, "Raid executed");
        return (true, abi.encode(replyId, targetPostId, platform));
    }

    /// @dev Record holder distribution snapshot from oracle.
    ///      Payload: (uint256 topHolderCount, uint256 totalHolders, uint256 topHolderPctBps)
    function _handleReportHolders(
        uint256 tokenId,
        bytes calldata payload
    ) internal returns (bool, bytes memory) {
        (uint256 topHolderCount, uint256 totalHolders, uint256 topHolderPctBps) =
            abi.decode(payload, (uint256, uint256, uint256));

        emit HolderDistributionReported(tokenId, topHolderCount, totalHolders, topHolderPctBps, block.timestamp);
        return (true, abi.encode(topHolderCount, totalHolders, topHolderPctBps));
    }

    // ══════════════════════════════════════════════════════════════
    //  Activity/Learning Handlers (from V5)
    // ══════════════════════════════════════════════════════════════

    function _handleRecordActivity(
        uint256 tokenId,
        bytes calldata payload
    ) internal returns (bool, bytes memory) {
        uint256 platform = abi.decode(payload, (uint256));
        emit ActivityRecorded(tokenId, platform, block.timestamp);
        return (true, abi.encode("Activity recorded"));
    }

    function _handleRecordLearning(
        uint256 tokenId,
        bytes calldata payload
    ) internal returns (bool, bytes memory) {
        (bytes32 dataHash, uint256 interactionCount) = abi.decode(payload, (bytes32, uint256));
        emit LearningRecorded(tokenId, dataHash, interactionCount, block.timestamp);
        return (true, abi.encode("Learning recorded"));
    }

    // ══════════════════════════════════════════════════════════════
    //  View Functions (gas-free)
    // ══════════════════════════════════════════════════════════════

    function getCampaign(uint256 tokenId) external view returns (Campaign memory) {
        return campaigns[tokenId];
    }

    function getTranche(uint256 tokenId, uint256 trancheIndex) external view returns (TakeProfitTranche memory) {
        if (trancheIndex >= campaigns[tokenId].trancheCount) revert InvalidTrancheIndex(); // LOW-6 fix
        return campaignTranches[tokenId][trancheIndex];
    }

    function getAllTranches(uint256 tokenId) external view returns (TakeProfitTranche[] memory) {
        uint256 count = campaigns[tokenId].trancheCount;
        TakeProfitTranche[] memory tranches = new TakeProfitTranche[](count);
        for (uint256 i = 0; i < count; i++) {
            tranches[i] = campaignTranches[tokenId][i];
        }
        return tranches;
    }

    function getThresholds(uint256 tokenId) external view returns (CampaignThresholds memory) {
        return campaignThresholds[tokenId];
    }

    function calculatePnL(uint256 tokenId) external view returns (int256 realizedPnl, uint256 remainingTokens) {
        Campaign storage campaign = campaigns[tokenId];
        realizedPnl = int256(campaign.totalBnbReceived) - int256(campaign.totalBnbSpent);
        remainingTokens = campaign.remainingTokenAmount;
    }

    // ══════════════════════════════════════════════════════════════
    //  Internal Helpers
    // ══════════════════════════════════════════════════════════════

    /// @dev Gas reimbursement — deducts cost from agent vault, pays caller
    function _reimburseGas(uint256 tokenId, uint256 gasStart) internal {
        if (!gasReimbursementEnabled) return;

        uint256 gasUsed = gasStart - gasleft() + gasOverhead;
        uint256 gasCost = gasUsed * tx.gasprice;

        if (agentBNBBalance[tokenId] < gasCost) revert InsufficientBNB();

        agentBNBBalance[tokenId] -= gasCost;
        (bool sent, ) = msg.sender.call{value: gasCost}("");
        if (sent) {
            emit GasReimbursed(tokenId, msg.sender, gasUsed, gasCost);
        } else {
            agentBNBBalance[tokenId] += gasCost;
        }
    }

    /// @dev HIGH-5 fix: Estimate FourMeme buy amount with slippage protection
    function _estimateFourMemeBuy(address tokenAddress, uint256 amountBNB, uint256 slippageBps) internal view returns (uint256) {
        try FOURMEME_HELPER.tryBuy(tokenAddress, 0, amountBNB) returns (
            address, address, uint256 estimatedAmount, uint256, uint256, uint256, uint256, uint256
        ) {
            if (estimatedAmount == 0) return 0;
            return (estimatedAmount * (BPS_DENOMINATOR - slippageBps)) / BPS_DENOMINATOR;
        } catch {
            return 0; // Fallback: no minimum (better than reverting)
        }
    }

    /// @dev Verify a token was launched on FourMeme
    function _verifyFourMemeToken(address tokenAddress) internal view returns (bool isFourMeme, bool liquidityAdded) {
        (bool ok, bytes memory rawResult) = address(FOURMEME_HELPER).staticcall(
            abi.encodeWithSelector(IFourMemeHelper.getTokenInfo.selector, tokenAddress)
        );
        if (!ok || rawResult.length == 0) return (false, false);

        (
            ,                    // version
            address tokenManager,
            ,                    // quote
            ,                    // lastPrice
            ,                    // tradingFeeRate
            ,                    // minTradingFee
            ,                    // launchTime
            ,                    // offers
            ,                    // maxOffers
            ,                    // funds
            ,                    // maxFunds
            bool _liquidityAdded
        ) = abi.decode(rawResult, (uint256, address, address, uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256, bool));

        isFourMeme = (tokenManager != address(0));
        liquidityAdded = _liquidityAdded;
    }

    /// @dev Transition campaign status with event emission
    function _setCampaignStatus(uint256 tokenId, CampaignStatus newStatus) internal {
        CampaignStatus oldStatus = campaigns[tokenId].status;
        campaigns[tokenId].status = newStatus;
        emit CampaignStatusChanged(tokenId, oldStatus, newStatus);
    }

    /// @dev Check if all take-profit tranches have been executed
    function _checkAllTranchesExecuted(uint256 tokenId) internal view returns (bool) {
        uint256 count = campaigns[tokenId].trancheCount;
        for (uint256 i = 0; i < count; i++) {
            if (!campaignTranches[tokenId][i].executed) {
                return false;
            }
        }
        return true;
    }

    /// @dev Generate a deterministic post ID as bytes32 (cheaper than string conversion)
    function _generatePostId(uint256 tokenId, uint8 platform, uint256 timestamp) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(tokenId, platform, timestamp, totalPosts[tokenId])); // LOW-7 fix: nonce
    }

    // ── Swap helpers ──

    function _swapBNBForToken(address tokenAddress, uint256 amountBNB, uint256 slippageBps) internal returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = WBNB;
        path[1] = tokenAddress;

        uint256 minOut = _getMinOut(amountBNB, path, slippageBps);
        uint256 balBefore = IERC20(tokenAddress).balanceOf(address(this));

        ROUTER.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amountBNB}(
            minOut, path, address(this), block.timestamp + DEADLINE_EXTENSION
        );

        uint256 received = IERC20(tokenAddress).balanceOf(address(this)) - balBefore;
        if (received == 0) revert SwapFailed();
        return received;
    }

    function _swapTokenForBNB(address tokenAddress, uint256 amountTokens, uint256 slippageBps) internal returns (uint256) {
        _safeApprove(tokenAddress, address(ROUTER), 0);
        _safeApprove(tokenAddress, address(ROUTER), amountTokens);

        address[] memory path = new address[](2);
        path[0] = tokenAddress;
        path[1] = WBNB;

        uint256 minOut = _getMinOut(amountTokens, path, slippageBps);
        uint256 balBefore = address(this).balance;

        ROUTER.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountTokens, minOut, path, address(this), block.timestamp + DEADLINE_EXTENSION
        );

        uint256 received = address(this).balance - balBefore;
        if (received == 0) revert SwapFailed();
        return received;
    }

    function _getMinOut(uint256 amountIn, address[] memory path, uint256 slippageBps) internal view returns (uint256) {
        uint[] memory expected = ROUTER.getAmountsOut(amountIn, path);
        return (expected[1] * (BPS_DENOMINATOR - slippageBps)) / BPS_DENOMINATOR;
    }

    // ── SafeERC20 helpers ──

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeApprove(address token, address spender, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.approve.selector, spender, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert ApproveFailed();
    }

    // ── Receive BNB from PancakeSwap and FourMeme ──
    receive() external payable {}
}
