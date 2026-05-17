// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IERC721Ownable
 */
interface IERC721Ownable {
    function ownerOf(uint256 tokenId) external view returns (address);
}

/**
 * @title IPancakeRouter02
 */
interface IPancakeRouter02 {
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin, address[] calldata path, address to, uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline
    ) external;
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function WETH() external pure returns (address);
}

/**
 * @title IFourMemeTokenManager
 */
interface IFourMemeTokenManager {
    function buyTokenAMAP(address token, uint256 funds, uint256 minAmount) external payable;
    function sellToken(address token, uint256 amount) external;
}

/**
 * @title IFourMemeHelper
 */
interface IFourMemeHelper {
    function getTokenInfo(address token) external view returns (
        uint256 version, address tokenManager, address quote, uint256 lastPrice,
        uint256 tradingFeeRate, uint256 minTradingFee, uint256 launchTime,
        uint256 offers, uint256 maxOffers, uint256 funds, uint256 maxFunds, bool liquidityAdded
    );
    function tryBuy(address token, uint256 amount, uint256 fundAmount) external view returns (
        address tokenManager, address quote, uint256 estimatedAmount, uint256 estimatedCost,
        uint256 estimatedFee, uint256 amountMsgValue, uint256 amountApproval, uint256 amountFunds
    );
}

/**
 * @title IERC20
 */
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

/**
 * @title HunterAgentLogic
 * @dev Social signal trading agent — hunts alpha in TG groups and X, verifies on-chain, trades.
 *
 *      Differences from CTOAgentLogic:
 *       - Multi-position: track up to MAX_POSITIONS tokens simultaneously (not single campaign)
 *       - On-chain metrics: totalActions, successfulActions, totalTrades, lifetimePnL — no event scanning needed
 *       - No social actions on-chain (post_content, raid_post etc. handled off-chain, zero gas)
 *       - Positions have entry price + stop-loss + take-profit built in
 *       - Same trading capabilities: PancakeSwap V2 + FourMeme bonding curve
 *
 * Security: same as CTOAgentLogic — ReentrancyGuard, SafeERC20, fee-on-transfer safe,
 *           pausable, two-step ownership, emergency withdrawal, gas reimbursement
 */
contract HunterAgentLogic {

    // ── Custom Errors ──
    error NotOwner();
    error NotAuthorized();
    error ContractPaused();
    error Reentrant();
    error NotAgentOwner();
    error Bap578NotConfigured();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidSlippage();
    error InsufficientBNB();
    error InsufficientTokens();
    error SwapFailed();
    error TransferFailed();
    error ApproveFailed();
    error FourMemeBuyFailed();
    error FourMemeSellFailed();
    error FourMemeQueryFailed();
    error NothingToRecover();
    error OverheadTooHigh();
    error NotPendingOwner();
    error MaxPositionsReached();
    error PositionNotFound();
    error PositionAlreadyExists();
    error InvalidStopLoss();
    error InvalidTakeProfit();

    // ── Constants ──
    IPancakeRouter02 public constant ROUTER = IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address public constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    IFourMemeTokenManager public constant FOURMEME = IFourMemeTokenManager(0x5c952063c7fc8610FFDB798152D69F0B9550762b);
    IFourMemeHelper public constant FOURMEME_HELPER = IFourMemeHelper(0xF251F83e40a78868FcfA3FA4599Dad6494E46034);

    uint256 public constant MAX_SLIPPAGE_BPS = 3000;
    uint256 public constant DEADLINE_EXTENSION = 300;
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MAX_POSITIONS = 10;

    // ── Structs ──

    /// @dev A tracked position — one token the hunter is holding
    struct Position {
        address tokenAddress;
        uint256 entryAmountBnb;       // BNB spent to buy
        uint256 tokenAmount;          // Tokens held
        uint256 entryTimestamp;       // When bought
        uint256 stopLossBps;          // Stop-loss: sell all if value drops below entry * (10000 - stopLossBps) / 10000
        uint256 takeProfitBps;        // Take-profit: sell half if value exceeds entry * takeProfitBps / 10000
        bool takeProfitExecuted;      // Whether take-profit was already triggered
        bool active;                  // Position is open
    }

    // ── State Variables ──

    string public constant name = "HunterAgentLogic";
    string public constant version = "1.0.0";

    IERC721Ownable public bap578;
    address public owner;
    address public pendingOwner;
    bool public paused;

    uint256 private _reentrancyStatus;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    mapping(address => bool) public authorizedCallers;
    uint256 public defaultSlippageBps = 500;
    bool public gasReimbursementEnabled = true;
    uint256 public gasOverhead = 50000;

    // ── Per-agent balances ──
    mapping(uint256 => uint256) public agentBNBBalance;
    mapping(uint256 => mapping(address => uint256)) public agentTokenBalance;

    // ── Per-agent positions: tokenId => token address => Position ──
    mapping(uint256 => mapping(address => Position)) public positions;
    // Track active position token addresses per agent for iteration
    mapping(uint256 => address[]) public positionList;

    // ══════════════════════════════════════════════════════════════
    //  ON-CHAIN METRICS — no event scanning needed, free view reads
    // ══════════════════════════════════════════════════════════════

    mapping(uint256 => uint256) public totalActions;
    mapping(uint256 => uint256) public successfulActions;
    mapping(uint256 => uint256) public totalTrades;        // buy + sell count
    mapping(uint256 => int256)  public lifetimePnL;        // cumulative realized PnL in wei
    mapping(uint256 => uint256) public totalInteractions;  // chat interactions recorded
    mapping(uint256 => uint256) public lastActiveTimestamp;

    // ── Events ──

    event ActionHandled(uint256 indexed tokenId, string action, bool success, bytes result);
    event SwapExecuted(uint256 indexed tokenId, string swapType, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    event Deposited(uint256 indexed tokenId, address token, uint256 amount);
    event Withdrawn(uint256 indexed tokenId, address token, uint256 amount, address to);
    event FourMemeBuy(uint256 indexed tokenId, address token, uint256 bnbSpent, uint256 tokensReceived);
    event FourMemeSell(uint256 indexed tokenId, address token, uint256 tokensSold, uint256 bnbReceived);
    event AgentOwnerWithdraw(uint256 indexed tokenId, address indexed agentOwner, address token, uint256 amount);
    event GasReimbursed(uint256 indexed tokenId, address indexed caller, uint256 gasUsed, uint256 gasCost);
    event TradingActionRequested(uint256 indexed tokenId, address indexed caller, string action, address tokenAddress, uint256 amount, uint256 slippageBps);
    event SlippageUpdated(uint256 oldBps, uint256 newBps);
    event CallerAuthorized(address caller);
    event CallerRevoked(address caller);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address account);
    event Unpaused(address account);
    event EmergencyWithdraw(address token, uint256 amount, address to);
    event Bap578Updated(address indexed oldAddress, address indexed newAddress);

    // Position events
    event PositionOpened(uint256 indexed tokenId, address indexed token, uint256 bnbSpent, uint256 tokensReceived, uint256 stopLossBps, uint256 takeProfitBps);
    event PositionClosed(uint256 indexed tokenId, address indexed token, uint256 tokensSold, uint256 bnbReceived, int256 pnl);
    event TakeProfitTriggered(uint256 indexed tokenId, address indexed token, uint256 tokensSold, uint256 bnbReceived);
    event StopLossTriggered(uint256 indexed tokenId, address indexed token, uint256 tokensSold, uint256 bnbReceived);

    // Activity events (for V5 compat)
    event ActivityRecorded(uint256 indexed tokenId, uint256 platform, uint256 timestamp);
    event LearningRecorded(uint256 indexed tokenId, bytes32 dataHash, uint256 interactionCount, uint256 timestamp);

    // ── Modifiers ──

    modifier onlyOwner() { if (msg.sender != owner) revert NotOwner(); _; }
    modifier onlyAuthorized() { if (!authorizedCallers[msg.sender] && msg.sender != owner) revert NotAuthorized(); _; }
    modifier whenNotPaused() { if (paused) revert ContractPaused(); _; }
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

    // ── Constructor ──

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
    function revokeCaller(address caller) external onlyOwner { authorizedCallers[caller] = false; emit CallerRevoked(caller); }
    function setDefaultSlippage(uint256 bps) external onlyOwner { if (bps < 50 || bps > MAX_SLIPPAGE_BPS) revert InvalidSlippage(); emit SlippageUpdated(defaultSlippageBps, bps); defaultSlippageBps = bps; }
    function transferOwnership(address newOwner) external onlyOwner { if (newOwner == address(0)) revert ZeroAddress(); pendingOwner = newOwner; emit OwnershipTransferStarted(owner, newOwner); }
    function acceptOwnership() external { if (msg.sender != pendingOwner) revert NotPendingOwner(); emit OwnershipTransferred(owner, pendingOwner); owner = pendingOwner; pendingOwner = address(0); }
    function pause() external onlyOwner { paused = true; emit Paused(msg.sender); }
    function unpause() external onlyOwner { paused = false; emit Unpaused(msg.sender); }
    function setBap578(address _bap578) external onlyOwner { if (_bap578 == address(0)) revert ZeroAddress(); emit Bap578Updated(address(bap578), _bap578); bap578 = IERC721Ownable(_bap578); }
    function setGasReimbursementEnabled(bool _enabled) external onlyOwner { gasReimbursementEnabled = _enabled; }
    function setGasOverhead(uint256 _overhead) external onlyOwner { if (_overhead > 500000) revert OverheadTooHigh(); gasOverhead = _overhead; }

    // ══════════════════════════════════════════════════════════════
    //  Deposit / Withdraw
    // ══════════════════════════════════════════════════════════════

    function depositBNB(uint256 tokenId) external payable whenNotPaused nonReentrant {
        if (msg.value == 0) revert ZeroAmount();
        if (address(bap578) != address(0)) bap578.ownerOf(tokenId);
        agentBNBBalance[tokenId] += msg.value;
        emit Deposited(tokenId, address(0), msg.value);
    }

    function depositToken(uint256 tokenId, address token, uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (token == address(0)) revert ZeroAddress();
        if (address(bap578) != address(0)) bap578.ownerOf(tokenId);
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

    function agentOwnerWithdrawBNB(uint256 tokenId, uint256 amount) external onlyAgentOwner(tokenId) whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (agentBNBBalance[tokenId] < amount) revert InsufficientBNB();
        agentBNBBalance[tokenId] -= amount;
        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        if (!sent) revert TransferFailed();
        emit AgentOwnerWithdraw(tokenId, msg.sender, address(0), amount);
    }

    function agentOwnerWithdrawToken(uint256 tokenId, address token, uint256 amount) external onlyAgentOwner(tokenId) whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (token == address(0)) revert ZeroAddress();
        if (agentTokenBalance[tokenId][token] < amount) revert InsufficientTokens();
        agentTokenBalance[tokenId][token] -= amount;
        _safeTransfer(token, msg.sender, amount);
        emit AgentOwnerWithdraw(tokenId, msg.sender, token, amount);
    }

    // Emergency
    function emergencyWithdrawBNB(address payable to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        uint256 bal = address(this).balance;
        if (bal == 0) revert NothingToRecover();
        paused = true; emit Paused(msg.sender);
        (bool sent, ) = to.call{value: bal}("");
        if (!sent) revert TransferFailed();
        emit EmergencyWithdraw(address(0), bal, to);
    }
    function emergencyWithdrawToken(address token, address to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal == 0) revert NothingToRecover();
        paused = true; emit Paused(msg.sender);
        _safeTransfer(token, to, bal);
        emit EmergencyWithdraw(token, bal, to);
    }
    function resetAgentBalance(uint256 tokenId) external onlyOwner { agentBNBBalance[tokenId] = 0; }
    function resetAgentTokenBalance(uint256 tokenId, address token) external onlyOwner { agentTokenBalance[tokenId][token] = 0; }

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

        // Increment metrics
        totalActions[tokenId]++;
        lastActiveTimestamp[tokenId] = block.timestamp;

        // ── Trading ──
        if (actionHash == keccak256(bytes("buy_token"))) {
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

        // ── Position Management ──
        } else if (actionHash == keccak256(bytes("open_position"))) {
            (success, result) = _handleOpenPosition(tokenId, payload);
        } else if (actionHash == keccak256(bytes("close_position"))) {
            (success, result) = _handleClosePosition(tokenId, payload);
        } else if (actionHash == keccak256(bytes("check_positions"))) {
            (success, result) = _handleCheckPositions(tokenId);
        } else if (actionHash == keccak256(bytes("check_exit_signals"))) {
            (success, result) = _handleCheckExitSignals(tokenId, payload);

        // ── Activity/Learning (V5 compat) ──
        } else if (actionHash == keccak256(bytes("record_activity"))) {
            (success, result) = _handleRecordActivity(tokenId, payload);
        } else if (actionHash == keccak256(bytes("record_learning"))) {
            (success, result) = _handleRecordLearning(tokenId, payload);

        } else {
            (success, result) = (false, abi.encode("Unknown action"));
        }

        if (success) successfulActions[tokenId]++;

        emit ActionHandled(tokenId, action, success, result);
        _reimburseGas(tokenId, gasStart);
    }

    // ══════════════════════════════════════════════════════════════
    //  Position Management — Multi-token tracking
    // ══════════════════════════════════════════════════════════════

    /// @dev Open a position: buy a token and track it with stop-loss/take-profit.
    ///      Payload: (address token, uint256 amountBnb, uint256 slippageBps, uint256 stopLossBps, uint256 takeProfitBps)
    ///      stopLossBps: 5000 = sell if value drops 50%. 0 = no stop-loss.
    ///      takeProfitBps: 20000 = sell half at 2x. 0 = no take-profit.
    function _handleOpenPosition(uint256 tokenId, bytes calldata payload) internal returns (bool, bytes memory) {
        (address token, uint256 amountBnb, uint256 slippageBps, uint256 stopLossBps, uint256 takeProfitBps) =
            abi.decode(payload, (address, uint256, uint256, uint256, uint256));

        if (token == address(0)) revert ZeroAddress();
        if (amountBnb == 0) revert ZeroAmount();
        if (agentBNBBalance[tokenId] < amountBnb) revert InsufficientBNB();
        if (positions[tokenId][token].active) revert PositionAlreadyExists();
        if (_getActivePositionCount(tokenId) >= MAX_POSITIONS) revert MaxPositionsReached();
        if (stopLossBps > BPS_DENOMINATOR) revert InvalidStopLoss();
        if (takeProfitBps != 0 && takeProfitBps <= BPS_DENOMINATOR) revert InvalidTakeProfit(); // must be > 1x

        if (slippageBps == 0) slippageBps = defaultSlippageBps;
        if (slippageBps > MAX_SLIPPAGE_BPS) revert InvalidSlippage();

        // Buy the token
        agentBNBBalance[tokenId] -= amountBnb;
        uint256 tokensReceived;

        // Check if FourMeme bonding curve
        (bool isFourMeme, bool liquidityAdded) = _verifyFourMemeToken(token);
        if (isFourMeme && !liquidityAdded) {
            uint256 balBefore = IERC20(token).balanceOf(address(this));
            uint256 minTokens = _estimateFourMemeBuy(token, amountBnb, slippageBps);
            FOURMEME.buyTokenAMAP{value: amountBnb}(token, amountBnb, minTokens);
            tokensReceived = IERC20(token).balanceOf(address(this)) - balBefore;
            if (tokensReceived == 0) revert FourMemeBuyFailed();
            emit FourMemeBuy(tokenId, token, amountBnb, tokensReceived);
        } else {
            tokensReceived = _swapBNBForToken(token, amountBnb, slippageBps);
            emit SwapExecuted(tokenId, "buy", WBNB, token, amountBnb, tokensReceived);
        }

        agentTokenBalance[tokenId][token] += tokensReceived;

        // Track position
        positions[tokenId][token] = Position({
            tokenAddress: token,
            entryAmountBnb: amountBnb,
            tokenAmount: tokensReceived,
            entryTimestamp: block.timestamp,
            stopLossBps: stopLossBps,
            takeProfitBps: takeProfitBps,
            takeProfitExecuted: false,
            active: true
        });
        positionList[tokenId].push(token);

        totalTrades[tokenId]++;

        emit PositionOpened(tokenId, token, amountBnb, tokensReceived, stopLossBps, takeProfitBps);
        return (true, abi.encode("Position opened", tokensReceived));
    }

    /// @dev Close a position: sell only the position's tracked tokens (not unrelated tokens).
    ///      Payload: (address token, uint256 slippageBps)
    function _handleClosePosition(uint256 tokenId, bytes calldata payload) internal returns (bool, bytes memory) {
        (address token, uint256 slippageBps) = abi.decode(payload, (address, uint256));

        Position storage pos = positions[tokenId][token];
        if (!pos.active) revert PositionNotFound();

        // Sell only the position's tracked amount, bounded by actual balance
        uint256 tokensToSell = pos.tokenAmount;
        uint256 actualBalance = agentTokenBalance[tokenId][token];
        if (tokensToSell > actualBalance) tokensToSell = actualBalance;
        if (tokensToSell == 0) revert InsufficientTokens();

        if (slippageBps == 0) slippageBps = defaultSlippageBps;
        if (slippageBps > MAX_SLIPPAGE_BPS) revert InvalidSlippage();

        agentTokenBalance[tokenId][token] -= tokensToSell;
        uint256 bnbReceived;

        (bool isFourMeme, bool liquidityAdded) = _verifyFourMemeToken(token);
        if (isFourMeme && !liquidityAdded) {
            _safeApprove(token, address(FOURMEME), 0);
            _safeApprove(token, address(FOURMEME), tokensToSell);
            uint256 balBefore = address(this).balance;
            FOURMEME.sellToken(token, tokensToSell);
            bnbReceived = address(this).balance - balBefore;
            if (bnbReceived == 0) revert FourMemeSellFailed();
            emit FourMemeSell(tokenId, token, tokensToSell, bnbReceived);
        } else {
            bnbReceived = _swapTokenForBNB(token, tokensToSell, slippageBps);
            emit SwapExecuted(tokenId, "sell", token, WBNB, tokensToSell, bnbReceived);
        }

        agentBNBBalance[tokenId] += bnbReceived;

        // Calculate PnL
        int256 pnl = int256(bnbReceived) - int256(pos.entryAmountBnb);
        lifetimePnL[tokenId] += pnl;
        totalTrades[tokenId]++;

        // Deactivate position
        pos.active = false;
        _removeFromPositionList(tokenId, token);

        emit PositionClosed(tokenId, token, tokensToSell, bnbReceived, pnl);
        return (true, abi.encode("Position closed", bnbReceived, pnl));
    }

    /// @dev Check all active positions — returns summary.
    function _handleCheckPositions(uint256 tokenId) internal view returns (bool, bytes memory) {
        address[] storage tokens = positionList[tokenId];
        uint256 count = tokens.length;

        if (count == 0) {
            return (true, abi.encode("No active positions"));
        }

        // Encode as array of (address, entryBnb, tokenAmount, entryTimestamp, stopLoss, takeProfit, tpExecuted)
        bytes memory result = abi.encode(count);
        for (uint256 i = 0; i < count; i++) {
            Position storage pos = positions[tokenId][tokens[i]];
            result = abi.encodePacked(result, abi.encode(
                pos.tokenAddress, pos.entryAmountBnb, pos.tokenAmount,
                pos.entryTimestamp, pos.stopLossBps, pos.takeProfitBps, pos.takeProfitExecuted
            ));
        }

        return (true, result);
    }

    /// @dev Check if any position has hit stop-loss or take-profit targets.
    ///      Payload: (address token, uint256 currentValueBnb) — current BNB value of the token holding
    ///      Runtime calls this with oracle price data.
    function _handleCheckExitSignals(uint256 tokenId, bytes calldata payload) internal view returns (bool, bytes memory) {
        (address token, uint256 currentValueBnb) = abi.decode(payload, (address, uint256));

        Position storage pos = positions[tokenId][token];
        if (!pos.active) revert PositionNotFound();

        uint256 entryValue = pos.entryAmountBnb;

        // Check stop-loss: value dropped below threshold
        if (pos.stopLossBps > 0) {
            uint256 stopLossThreshold = (entryValue * (BPS_DENOMINATOR - pos.stopLossBps)) / BPS_DENOMINATOR;
            if (currentValueBnb <= stopLossThreshold) {
                return (true, abi.encode("stop_loss", token, currentValueBnb, entryValue));
            }
        }

        // Check take-profit: value exceeded threshold (and not yet triggered)
        if (pos.takeProfitBps > 0 && !pos.takeProfitExecuted) {
            uint256 takeProfitThreshold = (entryValue * pos.takeProfitBps) / BPS_DENOMINATOR;
            if (currentValueBnb >= takeProfitThreshold) {
                return (true, abi.encode("take_profit", token, currentValueBnb, entryValue));
            }
        }

        return (true, abi.encode("hold", token, currentValueBnb, entryValue));
    }

    // ══════════════════════════════════════════════════════════════
    //  Trading Handlers (same as CTOAgentLogic V5)
    // ══════════════════════════════════════════════════════════════

    function _handleBuyToken(uint256 tokenId, bytes calldata payload) internal returns (bool, bytes memory) {
        (address tokenAddress, uint256 amountBNB, uint256 slippageBps) = abi.decode(payload, (address, uint256, uint256));
        if (tokenAddress == address(0)) revert ZeroAddress();
        if (slippageBps == 0) slippageBps = defaultSlippageBps;
        if (slippageBps > MAX_SLIPPAGE_BPS) revert InvalidSlippage();
        if (agentBNBBalance[tokenId] < amountBNB) revert InsufficientBNB();
        emit TradingActionRequested(tokenId, msg.sender, "buy_token", tokenAddress, amountBNB, slippageBps);
        agentBNBBalance[tokenId] -= amountBNB;
        uint256 tokensReceived = _swapBNBForToken(tokenAddress, amountBNB, slippageBps);
        agentTokenBalance[tokenId][tokenAddress] += tokensReceived;
        totalTrades[tokenId]++;
        emit SwapExecuted(tokenId, "buy", WBNB, tokenAddress, amountBNB, tokensReceived);
        return (true, abi.encode("Trade executed"));
    }

    function _handleSellToken(uint256 tokenId, bytes calldata payload) internal returns (bool, bytes memory) {
        (address tokenAddress, uint256 amountTokens, uint256 slippageBps) = abi.decode(payload, (address, uint256, uint256));
        if (tokenAddress == address(0)) revert ZeroAddress();
        if (slippageBps == 0) slippageBps = defaultSlippageBps;
        if (slippageBps > MAX_SLIPPAGE_BPS) revert InvalidSlippage();
        if (agentTokenBalance[tokenId][tokenAddress] < amountTokens) revert InsufficientTokens();
        emit TradingActionRequested(tokenId, msg.sender, "sell_token", tokenAddress, amountTokens, slippageBps);
        agentTokenBalance[tokenId][tokenAddress] -= amountTokens;
        uint256 bnbReceived = _swapTokenForBNB(tokenAddress, amountTokens, slippageBps);
        agentBNBBalance[tokenId] += bnbReceived;
        totalTrades[tokenId]++;
        emit SwapExecuted(tokenId, "sell", tokenAddress, WBNB, amountTokens, bnbReceived);
        return (true, abi.encode("Trade executed"));
    }

    function _handleCheckBalance(uint256 tokenId, bytes calldata payload) internal view returns (bool, bytes memory) {
        address tokenAddress = abi.decode(payload, (address));
        return (true, abi.encode(agentBNBBalance[tokenId], agentTokenBalance[tokenId][tokenAddress]));
    }

    function _handleGetPrice(bytes calldata payload) internal view returns (bool, bytes memory) {
        (address tokenAddress, uint256 amountIn, bool isBuyQuote) = abi.decode(payload, (address, uint256, bool));
        address[] memory path = new address[](2);
        if (isBuyQuote) { path[0] = WBNB; path[1] = tokenAddress; }
        else { path[0] = tokenAddress; path[1] = WBNB; }
        uint[] memory amounts = ROUTER.getAmountsOut(amountIn, path);
        return (true, abi.encode(amounts[1]));
    }

    function _handleBuyFourMeme(uint256 tokenId, bytes calldata payload) internal returns (bool, bytes memory) {
        (address tokenAddress, uint256 amountBNB, uint256 minTokens) = abi.decode(payload, (address, uint256, uint256));
        if (tokenAddress == address(0)) revert ZeroAddress();
        if (agentBNBBalance[tokenId] < amountBNB) revert InsufficientBNB();
        emit TradingActionRequested(tokenId, msg.sender, "buy_fourmeme", tokenAddress, amountBNB, 0);
        agentBNBBalance[tokenId] -= amountBNB;
        uint256 balBefore = IERC20(tokenAddress).balanceOf(address(this));
        FOURMEME.buyTokenAMAP{value: amountBNB}(tokenAddress, amountBNB, minTokens);
        uint256 received = IERC20(tokenAddress).balanceOf(address(this)) - balBefore;
        if (received == 0) revert FourMemeBuyFailed();
        agentTokenBalance[tokenId][tokenAddress] += received;
        totalTrades[tokenId]++;
        emit FourMemeBuy(tokenId, tokenAddress, amountBNB, received);
        return (true, abi.encode("FM buy ok"));
    }

    function _handleSellFourMeme(uint256 tokenId, bytes calldata payload) internal returns (bool, bytes memory) {
        (address tokenAddress, uint256 amountTokens) = abi.decode(payload, (address, uint256));
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
        totalTrades[tokenId]++;
        emit FourMemeSell(tokenId, tokenAddress, amountTokens, bnbReceived);
        return (true, abi.encode("FM sell ok"));
    }

    function _handleCheckFourMeme(bytes calldata payload) internal view returns (bool, bytes memory) {
        address tokenAddress = abi.decode(payload, (address));
        (bool ok, bytes memory rawResult) = address(FOURMEME_HELPER).staticcall(
            abi.encodeWithSelector(IFourMemeHelper.getTokenInfo.selector, tokenAddress)
        );
        if (!ok) revert FourMemeQueryFailed();
        return (true, rawResult);
    }

    // ── Activity/Learning (V5 compat) ──

    function _handleRecordActivity(uint256 tokenId, bytes calldata payload) internal returns (bool, bytes memory) {
        uint256 platform = abi.decode(payload, (uint256));
        totalInteractions[tokenId]++;
        emit ActivityRecorded(tokenId, platform, block.timestamp);
        return (true, abi.encode("Activity recorded"));
    }

    function _handleRecordLearning(uint256 tokenId, bytes calldata payload) internal returns (bool, bytes memory) {
        (bytes32 dataHash, uint256 interactionCount) = abi.decode(payload, (bytes32, uint256));
        emit LearningRecorded(tokenId, dataHash, interactionCount, block.timestamp);
        return (true, abi.encode("Learning recorded"));
    }

    // ══════════════════════════════════════════════════════════════
    //  View Functions (gas-free)
    // ══════════════════════════════════════════════════════════════

    function getPosition(uint256 tokenId, address token) external view returns (Position memory) {
        return positions[tokenId][token];
    }

    function getActivePositions(uint256 tokenId) external view returns (address[] memory) {
        return positionList[tokenId];
    }

    function getMetrics(uint256 tokenId) external view returns (
        uint256 _totalActions,
        uint256 _successfulActions,
        uint256 _totalTrades,
        int256 _lifetimePnL,
        uint256 _totalInteractions,
        uint256 _lastActive,
        uint256 _activePositions
    ) {
        return (
            totalActions[tokenId],
            successfulActions[tokenId],
            totalTrades[tokenId],
            lifetimePnL[tokenId],
            totalInteractions[tokenId],
            lastActiveTimestamp[tokenId],
            positionList[tokenId].length
        );
    }

    // ══════════════════════════════════════════════════════════════
    //  Internal Helpers
    // ══════════════════════════════════════════════════════════════

    function _reimburseGas(uint256 tokenId, uint256 gasStart) internal {
        if (!gasReimbursementEnabled) return;
        uint256 gasUsed = gasStart - gasleft() + gasOverhead;
        uint256 gasCost = gasUsed * tx.gasprice;
        if (agentBNBBalance[tokenId] < gasCost) revert InsufficientBNB();
        agentBNBBalance[tokenId] -= gasCost;
        (bool sent, ) = msg.sender.call{value: gasCost}("");
        if (sent) { emit GasReimbursed(tokenId, msg.sender, gasUsed, gasCost); }
        else { agentBNBBalance[tokenId] += gasCost; }
    }

    function _estimateFourMemeBuy(address tokenAddress, uint256 amountBNB, uint256 slippageBps) internal view returns (uint256) {
        try FOURMEME_HELPER.tryBuy(tokenAddress, 0, amountBNB) returns (
            address, address, uint256 estimatedAmount, uint256, uint256, uint256, uint256, uint256
        ) {
            if (estimatedAmount == 0) return 0;
            return (estimatedAmount * (BPS_DENOMINATOR - slippageBps)) / BPS_DENOMINATOR;
        } catch { return 0; }
    }

    function _verifyFourMemeToken(address tokenAddress) internal view returns (bool isFourMeme, bool liquidityAdded) {
        (bool ok, bytes memory rawResult) = address(FOURMEME_HELPER).staticcall(
            abi.encodeWithSelector(IFourMemeHelper.getTokenInfo.selector, tokenAddress)
        );
        if (!ok || rawResult.length == 0) return (false, false);
        (, address tokenManager,,,,,,,,,,bool _liquidityAdded) =
            abi.decode(rawResult, (uint256, address, address, uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256, bool));
        isFourMeme = (tokenManager != address(0));
        liquidityAdded = _liquidityAdded;
    }

    function _getActivePositionCount(uint256 tokenId) internal view returns (uint256) {
        return positionList[tokenId].length;
    }

    function _removeFromPositionList(uint256 tokenId, address token) internal {
        address[] storage list = positionList[tokenId];
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i] == token) {
                list[i] = list[list.length - 1];
                list.pop();
                return;
            }
        }
    }

    // ── Swap helpers ──

    function _swapBNBForToken(address tokenAddress, uint256 amountBNB, uint256 slippageBps) internal returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = WBNB; path[1] = tokenAddress;
        uint256 minOut = _getMinOut(amountBNB, path, slippageBps);
        uint256 balBefore = IERC20(tokenAddress).balanceOf(address(this));
        ROUTER.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amountBNB}(minOut, path, address(this), block.timestamp + DEADLINE_EXTENSION);
        uint256 received = IERC20(tokenAddress).balanceOf(address(this)) - balBefore;
        if (received == 0) revert SwapFailed();
        return received;
    }

    function _swapTokenForBNB(address tokenAddress, uint256 amountTokens, uint256 slippageBps) internal returns (uint256) {
        _safeApprove(tokenAddress, address(ROUTER), 0);
        _safeApprove(tokenAddress, address(ROUTER), amountTokens);
        address[] memory path = new address[](2);
        path[0] = tokenAddress; path[1] = WBNB;
        uint256 minOut = _getMinOut(amountTokens, path, slippageBps);
        uint256 balBefore = address(this).balance;
        ROUTER.swapExactTokensForETHSupportingFeeOnTransferTokens(amountTokens, minOut, path, address(this), block.timestamp + DEADLINE_EXTENSION);
        uint256 received = address(this).balance - balBefore;
        if (received == 0) revert SwapFailed();
        return received;
    }

    function _getMinOut(uint256 amountIn, address[] memory path, uint256 slippageBps) internal view returns (uint256) {
        uint[] memory expected = ROUTER.getAmountsOut(amountIn, path);
        return (expected[1] * (BPS_DENOMINATOR - slippageBps)) / BPS_DENOMINATOR;
    }

    // ── SafeERC20 ──

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount));
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
    function _safeApprove(address token, address spender, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.approve.selector, spender, amount));
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) revert ApproveFailed();
    }

    receive() external payable {}
}
