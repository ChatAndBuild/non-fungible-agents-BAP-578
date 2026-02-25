// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IBinanceOracle.sol";
import "./interfaces/INFAPredictionAgent.sol";

/**
 * @title PredictionMarket
 * @dev BNB-based prediction market with NFA agent integration on BSC.
 *
 * Features:
 * - Manual and oracle-based (Binance Oracle) market resolution
 * - User-created markets with daily rate limiting and creation fees
 * - NFA agent auto-trading via agentTakePosition()
 * - Winner-takes-proportional-share payout model
 * - BNB for market settlements and agent participation
 */
contract PredictionMarket is ReentrancyGuard, Ownable, Pausable {
    struct Market {
        string title;
        uint256 endTime;
        uint256 totalYes;
        uint256 totalNo;
        bool resolved;
        bool outcome; // true = Yes wins, false = No wins
        bool exists;
        // Oracle fields
        bool oracleEnabled;
        address priceFeed; // Oracle adapter address
        int256 targetPrice; // Target price (8 decimals)
        uint8 resolutionType; // 0=manual, 1=price_above, 2=price_below
        int256 resolvedPrice; // Actual price at resolution
    }

    struct Position {
        uint256 yesAmount;
        uint256 noAmount;
        bool claimed;
    }

    mapping(address => uint256) public balances;
    mapping(uint256 => Market) public markets;
    mapping(uint256 => mapping(address => Position)) public positions;
    uint256 public nextMarketId;

    // User market creation
    uint256 public marketCreationFee;
    uint256 public maxMarketsPerDay;
    address public nfaContract;

    mapping(address => uint256) public dailyMarketCount;
    mapping(address => uint256) public lastMarketCreationDay;
    mapping(uint256 => address) public marketCreator;

    uint256 public accumulatedFees;

    // Agent positions: marketId => agentTokenId => Position
    mapping(uint256 => mapping(uint256 => Position)) public agentPositions;

    // Per-agent balances within the prediction market (isolated from each other)
    mapping(uint256 => uint256) public agentBalances;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event MarketCreated(uint256 indexed marketId, string title, uint256 endTime);
    event MarketResolved(uint256 indexed marketId, bool outcome);
    event PositionTaken(uint256 indexed marketId, address indexed user, bool isYes, uint256 amount);
    event WinningsClaimed(uint256 indexed marketId, address indexed user, uint256 amount);
    event OracleMarketCreated(
        uint256 indexed marketId,
        address priceFeed,
        int256 targetPrice,
        uint8 resolutionType
    );
    event OracleResolution(uint256 indexed marketId, int256 price, bool outcome);
    event UserMarketCreated(
        uint256 indexed marketId,
        address indexed creator,
        string title,
        uint256 creationFee
    );
    event AgentPositionTaken(
        uint256 indexed marketId,
        uint256 indexed agentTokenId,
        bool isYes,
        uint256 amount
    );
    event MarketCreationFeeUpdated(uint256 newFee);
    event MaxMarketsPerDayUpdated(uint256 newMax);
    event NFAContractUpdated(address nfaContract);

    constructor() {
        marketCreationFee = 0.01 ether;
        maxMarketsPerDay = 3;
    }

    // --- Deposit / Withdraw ---

    function deposit() external payable nonReentrant whenNotPaused {
        require(msg.value > 0, "Must send BNB");
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Amount must be > 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        (bool sent, ) = msg.sender.call{ value: amount }("");
        require(sent, "BNB transfer failed");
        emit Withdraw(msg.sender, amount);
    }

    // --- Market Management ---

    function createMarket(
        string calldata title,
        uint256 endTime
    ) external onlyOwner returns (uint256) {
        require(endTime > block.timestamp, "End time must be in future");
        uint256 marketId = nextMarketId++;
        markets[marketId] = Market({
            title: title,
            endTime: endTime,
            totalYes: 0,
            totalNo: 0,
            resolved: false,
            outcome: false,
            exists: true,
            oracleEnabled: false,
            priceFeed: address(0),
            targetPrice: 0,
            resolutionType: 0,
            resolvedPrice: 0
        });
        emit MarketCreated(marketId, title, endTime);
        return marketId;
    }

    function createOracleMarket(
        string calldata title,
        uint256 endTime,
        address priceFeed,
        int256 targetPrice,
        uint8 resolutionType
    ) external onlyOwner returns (uint256) {
        require(endTime > block.timestamp, "End time must be in future");
        require(priceFeed != address(0), "Invalid price feed");
        require(resolutionType == 1 || resolutionType == 2, "Invalid resolution type");
        uint256 marketId = nextMarketId++;
        markets[marketId] = Market({
            title: title,
            endTime: endTime,
            totalYes: 0,
            totalNo: 0,
            resolved: false,
            outcome: false,
            exists: true,
            oracleEnabled: true,
            priceFeed: priceFeed,
            targetPrice: targetPrice,
            resolutionType: resolutionType,
            resolvedPrice: 0
        });
        emit MarketCreated(marketId, title, endTime);
        emit OracleMarketCreated(marketId, priceFeed, targetPrice, resolutionType);
        return marketId;
    }

    function resolveMarket(uint256 marketId, bool outcome) external onlyOwner {
        Market storage market = markets[marketId];
        require(market.exists, "Market does not exist");
        require(!market.resolved, "Already resolved");
        require(block.timestamp >= market.endTime, "Market not ended");
        market.resolved = true;
        market.outcome = outcome;
        emit MarketResolved(marketId, outcome);
    }

    function resolveByOracle(uint256 marketId) external {
        Market storage market = markets[marketId];
        require(market.exists, "Market does not exist");
        require(!market.resolved, "Already resolved");
        require(market.oracleEnabled, "Not oracle market");
        require(block.timestamp >= market.endTime, "Market not ended");

        AggregatorV2V3Interface oracle = AggregatorV2V3Interface(market.priceFeed);
        int256 currentPrice = oracle.latestAnswer();

        bool outcome;
        if (market.resolutionType == 1) {
            outcome = currentPrice >= market.targetPrice; // price_above
        } else {
            outcome = currentPrice <= market.targetPrice; // price_below
        }

        market.resolved = true;
        market.outcome = outcome;
        market.resolvedPrice = currentPrice;
        emit OracleResolution(marketId, currentPrice, outcome);
    }

    // --- Trading ---

    function takePosition(
        uint256 marketId,
        bool isYes,
        uint256 amount
    ) external nonReentrant whenNotPaused {
        require(amount > 0, "Amount must be > 0");
        Market storage market = markets[marketId];
        require(market.exists, "Market does not exist");
        require(!market.resolved, "Market already resolved");
        require(block.timestamp < market.endTime, "Market ended");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;

        Position storage pos = positions[marketId][msg.sender];
        if (isYes) {
            pos.yesAmount += amount;
            market.totalYes += amount;
        } else {
            pos.noAmount += amount;
            market.totalNo += amount;
        }

        emit PositionTaken(marketId, msg.sender, isYes, amount);
    }

    // --- Claim Winnings ---

    function claimWinnings(uint256 marketId) external nonReentrant whenNotPaused {
        Market storage market = markets[marketId];
        require(market.exists, "Market does not exist");
        require(market.resolved, "Market not resolved");

        Position storage pos = positions[marketId][msg.sender];
        require(!pos.claimed, "Already claimed");

        uint256 winnerAmount;
        uint256 totalWinnerPool;
        uint256 totalLoserPool;

        if (market.outcome) {
            winnerAmount = pos.yesAmount;
            totalWinnerPool = market.totalYes;
            totalLoserPool = market.totalNo;
        } else {
            winnerAmount = pos.noAmount;
            totalWinnerPool = market.totalNo;
            totalLoserPool = market.totalYes;
        }

        require(winnerAmount > 0, "No winning position");

        pos.claimed = true;

        // Winner gets back their stake + proportional share of loser pool
        uint256 reward = winnerAmount + (winnerAmount * totalLoserPool) / totalWinnerPool;

        balances[msg.sender] += reward;
        emit WinningsClaimed(marketId, msg.sender, reward);
    }

    // --- View ---

    function getMarket(
        uint256 marketId
    )
        external
        view
        returns (
            string memory title,
            uint256 endTime,
            uint256 totalYes,
            uint256 totalNo,
            bool resolved,
            bool outcome,
            bool oracleEnabled,
            address priceFeed,
            int256 targetPrice,
            uint8 resolutionType,
            int256 resolvedPrice
        )
    {
        Market storage m = markets[marketId];
        require(m.exists, "Market does not exist");
        return (
            m.title,
            m.endTime,
            m.totalYes,
            m.totalNo,
            m.resolved,
            m.outcome,
            m.oracleEnabled,
            m.priceFeed,
            m.targetPrice,
            m.resolutionType,
            m.resolvedPrice
        );
    }

    function getPosition(
        uint256 marketId,
        address user
    ) external view returns (uint256 yesAmount, uint256 noAmount, bool claimed) {
        Position storage p = positions[marketId][user];
        return (p.yesAmount, p.noAmount, p.claimed);
    }

    // --- Admin ---

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // --- User Market Creation ---

    function createUserMarket(
        string calldata title,
        uint256 endTime,
        uint256 initialLiquidity
    ) external payable nonReentrant whenNotPaused returns (uint256) {
        require(bytes(title).length >= 10, "Title too short");
        require(bytes(title).length <= 200, "Title too long");
        require(endTime > block.timestamp + 1 hours, "End time too soon");
        require(endTime <= block.timestamp + 90 days, "End time too far");

        // Daily rate limit
        uint256 today = block.timestamp / 86400;
        if (lastMarketCreationDay[msg.sender] != today) {
            dailyMarketCount[msg.sender] = 0;
            lastMarketCreationDay[msg.sender] = today;
        }
        require(dailyMarketCount[msg.sender] < maxMarketsPerDay, "Daily market limit reached");
        dailyMarketCount[msg.sender]++;

        // Collect creation fee in BNB
        require(msg.value >= marketCreationFee, "Insufficient creation fee");
        accumulatedFees += msg.value;

        // Create market
        uint256 marketId = nextMarketId++;
        markets[marketId] = Market({
            title: title,
            endTime: endTime,
            totalYes: 0,
            totalNo: 0,
            resolved: false,
            outcome: false,
            exists: true,
            oracleEnabled: false,
            priceFeed: address(0),
            targetPrice: 0,
            resolutionType: 0,
            resolvedPrice: 0
        });

        marketCreator[marketId] = msg.sender;

        // Initial liquidity from balance
        if (initialLiquidity > 0) {
            require(balances[msg.sender] >= initialLiquidity, "Insufficient balance for liquidity");
            uint256 half = initialLiquidity / 2;
            balances[msg.sender] -= initialLiquidity;
            markets[marketId].totalYes += half;
            markets[marketId].totalNo += (initialLiquidity - half);
            Position storage pos = positions[marketId][msg.sender];
            pos.yesAmount += half;
            pos.noAmount += (initialLiquidity - half);
        }

        emit UserMarketCreated(marketId, msg.sender, title, marketCreationFee);
        return marketId;
    }

    // --- Agent Position (NFA Integration) ---

    function agentDeposit(uint256 agentTokenId) external payable nonReentrant whenNotPaused {
        require(msg.sender == nfaContract, "Only NFA contract");
        require(msg.value > 0, "Must send BNB");
        agentBalances[agentTokenId] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function agentWithdraw(
        uint256 agentTokenId,
        uint256 amount
    ) external nonReentrant whenNotPaused {
        require(msg.sender == nfaContract, "Only NFA contract");
        require(amount > 0, "Amount must be > 0");
        require(agentBalances[agentTokenId] >= amount, "Insufficient agent balance");
        agentBalances[agentTokenId] -= amount;
        // Credit back to per-agent balance in NFA contract
        INFAPredictionAgent(nfaContract).creditAgentBalance{ value: amount }(agentTokenId);
        emit Withdraw(nfaContract, amount);
    }

    function agentTakePosition(
        uint256 agentTokenId,
        uint256 marketId,
        bool isYes,
        uint256 amount
    ) external payable nonReentrant whenNotPaused {
        require(msg.sender == nfaContract, "Only NFA contract");
        require(amount > 0, "Amount must be > 0");
        Market storage market = markets[marketId];
        require(market.exists, "Market does not exist");
        require(!market.resolved, "Market already resolved");
        require(block.timestamp < market.endTime, "Market ended");

        // Accept BNB and credit to per-agent balance
        if (msg.value > 0) {
            agentBalances[agentTokenId] += msg.value;
        }

        require(agentBalances[agentTokenId] >= amount, "Insufficient agent balance");
        agentBalances[agentTokenId] -= amount;

        // Track per-agent positions instead of merging into NFA contract address
        Position storage pos = agentPositions[marketId][agentTokenId];
        if (isYes) {
            pos.yesAmount += amount;
            market.totalYes += amount;
        } else {
            pos.noAmount += amount;
            market.totalNo += amount;
        }

        emit AgentPositionTaken(marketId, agentTokenId, isYes, amount);
    }

    function agentClaimWinnings(
        uint256 agentTokenId,
        uint256 marketId
    ) external nonReentrant whenNotPaused {
        require(msg.sender == nfaContract, "Only NFA contract");
        Market storage market = markets[marketId];
        require(market.exists, "Market does not exist");
        require(market.resolved, "Market not resolved");

        Position storage pos = agentPositions[marketId][agentTokenId];
        require(!pos.claimed, "Already claimed");

        uint256 winnerAmount;
        uint256 totalWinnerPool;
        uint256 totalLoserPool;

        if (market.outcome) {
            winnerAmount = pos.yesAmount;
            totalWinnerPool = market.totalYes;
            totalLoserPool = market.totalNo;
        } else {
            winnerAmount = pos.noAmount;
            totalWinnerPool = market.totalNo;
            totalLoserPool = market.totalYes;
        }

        require(winnerAmount > 0, "No winning position");

        pos.claimed = true;

        uint256 reward = winnerAmount + (winnerAmount * totalLoserPool) / totalWinnerPool;

        // Credit reward to per-agent balance (not contract-level)
        agentBalances[agentTokenId] += reward;
        emit WinningsClaimed(marketId, nfaContract, reward);
    }

    // --- Admin: User Market Settings ---

    function setNFAContract(address _nfa) external onlyOwner {
        nfaContract = _nfa;
        emit NFAContractUpdated(_nfa);
    }

    function setMarketCreationFee(uint256 _fee) external onlyOwner {
        marketCreationFee = _fee;
        emit MarketCreationFeeUpdated(_fee);
    }

    function setMaxMarketsPerDay(uint256 _max) external onlyOwner {
        maxMarketsPerDay = _max;
        emit MaxMarketsPerDayUpdated(_max);
    }

    function withdrawFees(uint256 amount) external onlyOwner {
        require(amount <= accumulatedFees, "Exceeds accumulated fees");
        accumulatedFees -= amount;
        (bool sent, ) = msg.sender.call{ value: amount }("");
        require(sent, "BNB transfer failed");
    }

    receive() external payable {
        revert("Use deposit()");
    }
}
