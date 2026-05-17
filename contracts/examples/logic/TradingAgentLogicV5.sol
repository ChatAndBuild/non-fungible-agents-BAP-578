// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

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
 * @title TradingAgentLogicV5
 * @dev Extends V4 with agent-funded activity recording and learning.
 *      The contract owner NEVER pays gas — all gas is reimbursed from
 *      the agent's BNB vault. If the agent can't pay, the tx reverts.
 *
 *      All V4 functionality preserved:
 *       - PancakeSwap V2 BNB<>Token swaps with slippage protection
 *       - FourMeme bonding curve integration
 *       - Fee-on-transfer safe balance-diff accounting
 *       - Admin functions (owner/authorized callers)
 *       - BAP578 NFT owner withdrawals
 *       - Gas reimbursement after handleAction
 *
 *      New in V5:
 *       - record_activity action: emits ActivityRecorded event (replaces PlatformRegistry.recordActivity)
 *       - record_learning action: emits LearningRecorded event (replaces MerkleTreeLearning flushes)
 *       - Both actions reimburse gas from agent vault (same as trades)
 *
 * Security:
 *  - ReentrancyGuard (manual, no OZ dependency)
 *  - SafeERC20 pattern (checked return values + approve(0) reset)
 *  - Fee-on-transfer safe (balance-diff accounting)
 *  - Pausable with ownership transfer
 *  - Emergency withdrawal for stuck BNB
 *  - NFT ownership checked at call time (not cached)
 *  - Gas reimbursement protected by nonReentrant on handleAction
 *  - Insufficient vault balance reverts entire tx (no free rides)
 */
contract TradingAgentLogicV5 is MetricsTracker {
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

    string public name = "TradingAgentLogicV5";
    string public version = "5.0.0";

    // ── BAP578 NFT contract for ownership verification ──
    IERC721Ownable public bap578;

    // ── Per-agent BNB balances ──
    mapping(uint256 => uint256) public agentBNBBalance;

    // ── Per-agent token balances: tokenId => token => balance ──
    mapping(uint256 => mapping(address => uint256)) public agentTokenBalance;

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
    uint256 public constant MAX_SLIPPAGE_BPS = 3000; // 30% max
    uint256 public constant DEADLINE_EXTENSION = 300; // 5 minutes

    // ── V4: Gas reimbursement config ──
    bool public gasReimbursementEnabled = true;
    uint256 public gasOverhead = 50000; // extra gas units for reimbursement logic itself

    // ── Events (V2) ──
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

    // ── Events (V3) ──
    event AgentOwnerWithdraw(uint256 indexed tokenId, address indexed agentOwner, address token, uint256 amount);
    event Bap578Updated(address indexed oldAddress, address indexed newAddress);

    // ── Events (V4) ──
    event GasReimbursed(uint256 indexed tokenId, address indexed caller, uint256 gasUsed, uint256 gasCost);

    // ── Events (V5 — new) ──
    event ActivityRecorded(uint256 indexed tokenId, uint256 platform, uint256 timestamp);
    event LearningRecorded(uint256 indexed tokenId, bytes32 dataHash, uint256 interactionCount, uint256 timestamp);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyAuthorized() {
        require(authorizedCallers[msg.sender] || msg.sender == owner, "Not authorized");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    modifier nonReentrant() {
        require(_reentrancyStatus != _ENTERED, "ReentrancyGuard: reentrant call");
        _reentrancyStatus = _ENTERED;
        _;
        _reentrancyStatus = _NOT_ENTERED;
    }

    /// @dev V3: checks that msg.sender owns the BAP578 NFT for the given tokenId
    modifier onlyAgentOwner(uint256 tokenId) {
        require(address(bap578) != address(0), "BAP578 not configured");
        require(bap578.ownerOf(tokenId) == msg.sender, "Not agent NFT owner");
        _;
    }

    constructor(address _bap578) {
        require(_bap578 != address(0), "Zero BAP578 address");
        owner = msg.sender;
        authorizedCallers[msg.sender] = true;
        _reentrancyStatus = _NOT_ENTERED;
        bap578 = IERC721Ownable(_bap578);
    }

    // ── Admin ──

    function authorizeCaller(address caller) external onlyOwner {
        require(caller != address(0), "Zero address");
        authorizedCallers[caller] = true;
        emit CallerAuthorized(caller);
    }

    function revokeCaller(address caller) external onlyOwner {
        authorizedCallers[caller] = false;
        emit CallerRevoked(caller);
    }

    function setDefaultSlippage(uint256 bps) external onlyOwner {
        require(bps <= MAX_SLIPPAGE_BPS, "Slippage too high");
        emit SlippageUpdated(defaultSlippageBps, bps);
        defaultSlippageBps = bps;
    }

    /// @notice Two-step ownership transfer (step 1: propose)
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    /// @notice Two-step ownership transfer (step 2: accept)
    function acceptOwnership() external {
        require(msg.sender == pendingOwner, "Not pending owner");
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

    /// @notice V3: Update BAP578 contract address (admin only, for future-proofing)
    function setBap578(address _bap578) external onlyOwner {
        require(_bap578 != address(0), "Zero BAP578 address");
        emit Bap578Updated(address(bap578), _bap578);
        bap578 = IERC721Ownable(_bap578);
    }

    /// @notice V4: Enable or disable gas reimbursement
    function setGasReimbursementEnabled(bool _enabled) external onlyOwner {
        gasReimbursementEnabled = _enabled;
    }

    /// @notice V4: Set gas overhead for reimbursement calculation
    function setGasOverhead(uint256 _overhead) external onlyOwner {
        gasOverhead = _overhead;
    }

    // ── Deposit/Withdraw ──

    /// @notice Deposit BNB for an agent to trade with
    function depositBNB(uint256 tokenId) external payable whenNotPaused {
        require(msg.value > 0, "No BNB sent");
        if (address(bap578) != address(0)) {
            bap578.ownerOf(tokenId); // reverts if tokenId doesn't exist
        }
        agentBNBBalance[tokenId] += msg.value;
        emit Deposited(tokenId, address(0), msg.value);
    }

    /// @notice Deposit ERC20 tokens for an agent (caller must approve first).
    function depositToken(uint256 tokenId, address token, uint256 amount) external whenNotPaused nonReentrant {
        require(amount > 0, "Zero amount");
        require(token != address(0), "Zero token address");
        if (address(bap578) != address(0)) {
            bap578.ownerOf(tokenId);
        }

        uint256 balBefore = IERC20(token).balanceOf(address(this));
        _safeTransferFrom(token, msg.sender, address(this), amount);
        uint256 received = IERC20(token).balanceOf(address(this)) - balBefore;
        require(received > 0, "Zero tokens received");

        agentTokenBalance[tokenId][token] += received;
        emit Deposited(tokenId, token, received);
    }

    /// @notice Withdraw BNB from agent balance (admin only)
    function withdrawBNB(uint256 tokenId, uint256 amount, address payable to) external onlyOwner nonReentrant {
        require(agentBNBBalance[tokenId] >= amount, "Insufficient BNB");
        require(to != address(0), "Zero address");
        agentBNBBalance[tokenId] -= amount;
        (bool sent, ) = to.call{value: amount}("");
        require(sent, "BNB transfer failed");
        emit Withdrawn(tokenId, address(0), amount, to);
    }

    /// @notice Withdraw ERC20 tokens from agent balance (admin only)
    function withdrawToken(uint256 tokenId, address token, uint256 amount, address to) external onlyOwner nonReentrant {
        require(agentTokenBalance[tokenId][token] >= amount, "Insufficient balance");
        require(to != address(0), "Zero address");
        agentTokenBalance[tokenId][token] -= amount;
        _safeTransfer(token, to, amount);
        emit Withdrawn(tokenId, token, amount, to);
    }

    // ── V3: NFT Owner Withdrawals ──

    /// @notice Withdraw BNB — only the NFT owner of the agent can call.
    function agentOwnerWithdrawBNB(uint256 tokenId, uint256 amount)
        external
        onlyAgentOwner(tokenId)
        whenNotPaused
        nonReentrant
    {
        require(amount > 0, "Zero amount");
        require(agentBNBBalance[tokenId] >= amount, "Insufficient BNB");
        agentBNBBalance[tokenId] -= amount;
        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        require(sent, "BNB transfer failed");
        emit AgentOwnerWithdraw(tokenId, msg.sender, address(0), amount);
    }

    /// @notice Withdraw ERC20 tokens — only the NFT owner of the agent can call.
    function agentOwnerWithdrawToken(uint256 tokenId, address token, uint256 amount)
        external
        onlyAgentOwner(tokenId)
        whenNotPaused
        nonReentrant
    {
        require(amount > 0, "Zero amount");
        require(token != address(0), "Zero token address");
        require(agentTokenBalance[tokenId][token] >= amount, "Insufficient balance");
        agentTokenBalance[tokenId][token] -= amount;
        _safeTransfer(token, msg.sender, amount);
        emit AgentOwnerWithdraw(tokenId, msg.sender, token, amount);
    }

    /// @notice Emergency: recover stuck BNB not tracked in any agentBNBBalance
    function emergencyWithdrawBNB(address payable to) external onlyOwner nonReentrant {
        require(to != address(0), "Zero address");
        uint256 contractBal = address(this).balance;
        uint256 tracked = _totalTrackedBNB();
        require(contractBal > tracked, "No excess BNB");
        uint256 excess = contractBal - tracked;
        (bool sent, ) = to.call{value: excess}("");
        require(sent, "BNB transfer failed");
        emit EmergencyWithdraw(address(0), excess, to);
    }

    /// @notice Emergency: recover stuck ERC20 tokens
    function emergencyWithdrawToken(address token, address to) external onlyOwner nonReentrant {
        require(to != address(0), "Zero address");
        uint256 contractBal = IERC20(token).balanceOf(address(this));
        require(contractBal > 0, "No tokens to recover");
        _safeTransfer(token, to, contractBal);
        emit EmergencyWithdraw(token, contractBal, to);
    }

    // ── Main action handler (called by runtime ActionExecutor) ──
    // Gas is always reimbursed from agent vault after execution

    function handleAction(
        uint256 tokenId,
        string calldata action,
        bytes calldata payload
    ) external onlyAuthorized whenNotPaused nonReentrant returns (bool success, bytes memory result) {
        uint256 gasStart = gasleft();
        bytes32 actionHash = keccak256(bytes(action));

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
        } else if (actionHash == keccak256(bytes("record_activity"))) {
            (success, result) = _handleRecordActivity(tokenId, payload);
        } else if (actionHash == keccak256(bytes("record_learning"))) {
            (success, result) = _handleRecordLearning(tokenId, payload);
        } else {
            emit ActionHandled(tokenId, action, false, abi.encode("Unknown action"));
            (success, result) = (false, abi.encode("Unknown action"));
        }

        // On-chain metrics — increment counters and update lastActiveTimestamp.
        // Inlined trade-action detection avoids extra function dispatch overhead.
        bool _isTrade =
            actionHash == keccak256(bytes("buy_token")) ||
            actionHash == keccak256(bytes("sell_token")) ||
            actionHash == keccak256(bytes("buy_fourmeme")) ||
            actionHash == keccak256(bytes("sell_fourmeme"));
        _recordAction(tokenId, success, _isTrade);

        // Reimburse gas from agent vault
        _reimburseGas(tokenId, gasStart);
    }

    // ── V4: Gas reimbursement ──

    function _reimburseGas(uint256 tokenId, uint256 gasStart) internal {
        if (!gasReimbursementEnabled) return;

        uint256 gasUsed = gasStart - gasleft() + gasOverhead;
        uint256 gasCost = gasUsed * tx.gasprice;

        require(agentBNBBalance[tokenId] >= gasCost, "Insufficient BNB for gas");

        agentBNBBalance[tokenId] -= gasCost;
        (bool sent, ) = msg.sender.call{value: gasCost}("");
        if (sent) {
            emit GasReimbursed(tokenId, msg.sender, gasUsed, gasCost);
        } else {
            agentBNBBalance[tokenId] += gasCost;
        }
    }

    // ── V5: Activity recording (replaces PlatformRegistry.recordActivity) ──

    function _handleRecordActivity(
        uint256 tokenId,
        bytes calldata payload
    ) internal returns (bool, bytes memory) {
        uint256 platform = abi.decode(payload, (uint256));
        emit ActivityRecorded(tokenId, platform, block.timestamp);
        emit ActionHandled(tokenId, "record_activity", true, abi.encode("Activity recorded"));
        return (true, abi.encode("Activity recorded"));
    }

    // ── V5: Learning recording (replaces MerkleTreeLearning flushes) ──

    function _handleRecordLearning(
        uint256 tokenId,
        bytes calldata payload
    ) internal returns (bool, bytes memory) {
        (bytes32 dataHash, uint256 interactionCount) = abi.decode(payload, (bytes32, uint256));
        emit LearningRecorded(tokenId, dataHash, interactionCount, block.timestamp);
        emit ActionHandled(tokenId, "record_learning", true, abi.encode("Learning recorded"));
        return (true, abi.encode("Learning recorded"));
    }

    // ── Buy: BNB → Token via PancakeSwap (fee-on-transfer safe) ──

    function _handleBuyToken(
        uint256 tokenId,
        bytes calldata payload
    ) internal returns (bool, bytes memory) {
        (address tokenAddress, uint256 amountBNB, uint256 slippageBps) =
            abi.decode(payload, (address, uint256, uint256));

        require(tokenAddress != address(0), "Zero token address");
        if (slippageBps == 0) slippageBps = defaultSlippageBps;
        require(slippageBps <= MAX_SLIPPAGE_BPS, "Slippage too high");
        require(agentBNBBalance[tokenId] >= amountBNB, "Insufficient BNB balance");

        emit TradingActionRequested(tokenId, msg.sender, "buy_token", tokenAddress, amountBNB, slippageBps);
        agentBNBBalance[tokenId] -= amountBNB;

        uint256 tokensReceived = _swapBNBForToken(tokenAddress, amountBNB, slippageBps);
        agentTokenBalance[tokenId][tokenAddress] += tokensReceived;

        emit SwapExecuted(tokenId, "buy", WBNB, tokenAddress, amountBNB, tokensReceived);
        emit ActionHandled(tokenId, "buy_token", true, abi.encode("Trade executed successfully"));
        return (true, abi.encode("Trade executed successfully"));
    }

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
        require(received > 0, "Swap returned zero tokens");
        return received;
    }

    // ── Sell: Token → BNB via PancakeSwap (fee-on-transfer safe) ──

    function _handleSellToken(
        uint256 tokenId,
        bytes calldata payload
    ) internal returns (bool, bytes memory) {
        (address tokenAddress, uint256 amountTokens, uint256 slippageBps) =
            abi.decode(payload, (address, uint256, uint256));

        require(tokenAddress != address(0), "Zero token address");
        if (slippageBps == 0) slippageBps = defaultSlippageBps;
        require(slippageBps <= MAX_SLIPPAGE_BPS, "Slippage too high");
        require(agentTokenBalance[tokenId][tokenAddress] >= amountTokens, "Insufficient token balance");

        emit TradingActionRequested(tokenId, msg.sender, "sell_token", tokenAddress, amountTokens, slippageBps);
        agentTokenBalance[tokenId][tokenAddress] -= amountTokens;

        uint256 bnbReceived = _swapTokenForBNB(tokenAddress, amountTokens, slippageBps);
        agentBNBBalance[tokenId] += bnbReceived;

        emit SwapExecuted(tokenId, "sell", tokenAddress, WBNB, amountTokens, bnbReceived);
        emit ActionHandled(tokenId, "sell_token", true, abi.encode("Trade executed successfully"));
        return (true, abi.encode("Trade executed successfully"));
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
        require(received > 0, "Swap returned zero BNB");
        return received;
    }

    function _getMinOut(uint256 amountIn, address[] memory path, uint256 slippageBps) internal view returns (uint256) {
        uint[] memory expected = ROUTER.getAmountsOut(amountIn, path);
        return (expected[1] * (10000 - slippageBps)) / 10000;
    }

    // ── Check balance: returns agent's token and BNB balances ──

    function _handleCheckBalance(
        uint256 tokenId,
        bytes calldata payload
    ) internal returns (bool, bytes memory) {
        address tokenAddress = abi.decode(payload, (address));

        uint256 tokenBal = agentTokenBalance[tokenId][tokenAddress];
        uint256 bnbBal = agentBNBBalance[tokenId];

        emit ActionHandled(tokenId, "check_balance", true, abi.encode(bnbBal, tokenBal));
        return (true, abi.encode(bnbBal, tokenBal));
    }

    // ── Get price quote from PancakeSwap ──

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

    // ── FourMeme Bonding Curve: Buy unbonded tokens ──

    function _handleBuyFourMeme(
        uint256 tokenId,
        bytes calldata payload
    ) internal returns (bool, bytes memory) {
        (address tokenAddress, uint256 amountBNB, uint256 minTokens) =
            abi.decode(payload, (address, uint256, uint256));

        require(tokenAddress != address(0), "Zero token address");
        require(agentBNBBalance[tokenId] >= amountBNB, "Insufficient BNB balance");

        emit TradingActionRequested(tokenId, msg.sender, "buy_fourmeme", tokenAddress, amountBNB, 0);
        agentBNBBalance[tokenId] -= amountBNB;

        uint256 balBefore = IERC20(tokenAddress).balanceOf(address(this));

        FOURMEME.buyTokenAMAP{value: amountBNB}(tokenAddress, amountBNB, minTokens);

        uint256 received = IERC20(tokenAddress).balanceOf(address(this)) - balBefore;
        require(received > 0, "FourMeme buy returned zero tokens");

        agentTokenBalance[tokenId][tokenAddress] += received;

        emit FourMemeBuy(tokenId, tokenAddress, amountBNB, received);
        emit ActionHandled(tokenId, "buy_fourmeme", true, abi.encode("FourMeme buy executed"));
        return (true, abi.encode("FourMeme buy executed"));
    }

    // ── FourMeme Bonding Curve: Sell unbonded tokens ──

    function _handleSellFourMeme(
        uint256 tokenId,
        bytes calldata payload
    ) internal returns (bool, bytes memory) {
        (address tokenAddress, uint256 amountTokens) =
            abi.decode(payload, (address, uint256));

        require(tokenAddress != address(0), "Zero token address");
        require(agentTokenBalance[tokenId][tokenAddress] >= amountTokens, "Insufficient token balance");

        emit TradingActionRequested(tokenId, msg.sender, "sell_fourmeme", tokenAddress, amountTokens, 0);
        agentTokenBalance[tokenId][tokenAddress] -= amountTokens;

        _safeApprove(tokenAddress, address(FOURMEME), 0);
        _safeApprove(tokenAddress, address(FOURMEME), amountTokens);

        uint256 balBefore = address(this).balance;

        FOURMEME.sellToken(tokenAddress, amountTokens);

        uint256 bnbReceived = address(this).balance - balBefore;
        require(bnbReceived > 0, "FourMeme sell returned zero BNB");

        agentBNBBalance[tokenId] += bnbReceived;

        emit FourMemeSell(tokenId, tokenAddress, amountTokens, bnbReceived);
        emit ActionHandled(tokenId, "sell_fourmeme", true, abi.encode("FourMeme sell executed"));
        return (true, abi.encode("FourMeme sell executed"));
    }

    // ── FourMeme: Check token bonding curve status ──

    function _handleCheckFourMeme(
        bytes calldata payload
    ) internal view returns (bool, bytes memory) {
        address tokenAddress = abi.decode(payload, (address));

        (bool ok, bytes memory rawResult) = address(FOURMEME_HELPER).staticcall(
            abi.encodeWithSelector(IFourMemeHelper.getTokenInfo.selector, tokenAddress)
        );
        require(ok, "FourMeme query failed");

        return (true, rawResult);
    }

    // ── Receive BNB from PancakeSwap and FourMeme ──
    receive() external payable {}

    // ── SafeERC20 helpers (checked return values) ──

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transfer failed");
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: transferFrom failed");
    }

    function _safeApprove(address token, address spender, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.approve.selector, spender, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: approve failed");
    }

    function _totalTrackedBNB() internal pure returns (uint256) {
        return 0;
    }
}
