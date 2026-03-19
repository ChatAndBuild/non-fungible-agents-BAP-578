// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./interfaces/IAgentLogic.sol";
import "./interfaces/IBAP578.sol";

/**
 * @title PriceAlert
 * @dev Example BAP-578 logic contract: on-chain price monitoring with alerts.
 *
 * Reads price data from Binance Oracle on BNB Chain. Binance Oracle's Feed
 * Adapters implement the AggregatorV2V3Interface, so this contract is also
 * compatible with any AggregatorV2V3-compliant price feed.
 *
 * Demonstrates how to build a logic contract that:
 *   1. Lets the agent owner configure price thresholds
 *   2. Allows anyone to trigger an alert check (keeper-compatible)
 *   3. Emits events that off-chain services can index
 *
 * Usage:
 *   1. Deploy this contract with the BAP-578 address
 *   2. Call `BAP578.setLogicAddress(tokenId, address(this))`
 *   3. Call `setAlert(tokenId, priceFeed, targetPrice, isAbove)`
 *      - priceFeed: Binance Oracle Feed Adapter address for the pair
 *        (see https://oracle.binance.com/docs/price-feeds/contract-addresses/)
 *   4. Keepers call `checkAlert(tokenId)` periodically
 *
 * ⚠️  This is an educational example. Do NOT use in production without
 *     a full security audit.
 */
contract PriceAlert is IAgentLogic {
    IBAP578 public immutable bap578;

    struct AlertConfig {
        address priceFeed; // Binance Oracle Feed Adapter address
        uint256 targetPrice; // Target price (8 decimals)
        bool isAbove; // true = alert when price goes above target
        bool triggered; // Has the alert already fired?
    }

    // tokenId => alert configuration
    mapping(uint256 => AlertConfig) public alerts;

    event AlertSet(uint256 indexed tokenId, address priceFeed, uint256 targetPrice, bool isAbove);
    event AlertTriggered(uint256 indexed tokenId, uint256 currentPrice, uint256 targetPrice);

    constructor(address _bap578) {
        require(_bap578 != address(0), "PriceAlert: zero BAP578 address");
        bap578 = IBAP578(_bap578);
    }

    /// @notice Configure a price alert for an agent.
    /// @param tokenId   The BAP-578 agent token ID.
    /// @param priceFeed Binance Oracle Feed Adapter address for the trading pair.
    /// @param targetPrice Target price with 8 decimals (e.g. 60000000000 = $600).
    /// @param isAbove   True to alert when price >= target, false for price <= target.
    function setAlert(
        uint256 tokenId,
        address priceFeed,
        uint256 targetPrice,
        bool isAbove
    ) external {
        require(bap578.ownerOf(tokenId) == msg.sender, "PriceAlert: not agent owner");
        require(priceFeed != address(0), "PriceAlert: zero price feed");
        require(targetPrice > 0, "PriceAlert: zero target price");

        alerts[tokenId] = AlertConfig({
            priceFeed: priceFeed,
            targetPrice: targetPrice,
            isAbove: isAbove,
            triggered: false
        });

        emit AlertSet(tokenId, priceFeed, targetPrice, isAbove);
    }

    /// @notice Check if the alert condition is met. Callable by anyone (keeper-compatible).
    function checkAlert(uint256 tokenId) external returns (bool) {
        return _checkAlert(tokenId);
    }

    /// @inheritdoc IAgentLogic
    function execute(
        uint256 tokenId,
        bytes calldata /* data */
    ) external payable returns (bytes memory) {
        require(bap578.ownerOf(tokenId) == msg.sender, "PriceAlert: not agent owner");
        bool triggered = _checkAlert(tokenId);
        return abi.encode(triggered);
    }

    /// @dev Internal alert check logic shared by checkAlert() and execute().
    function _checkAlert(uint256 tokenId) internal returns (bool) {
        AlertConfig storage alert = alerts[tokenId];
        require(alert.priceFeed != address(0), "PriceAlert: no alert set");
        require(!alert.triggered, "PriceAlert: already triggered");

        uint256 currentPrice = _getPrice(alert.priceFeed);

        bool conditionMet = alert.isAbove
            ? currentPrice >= alert.targetPrice
            : currentPrice <= alert.targetPrice;

        if (conditionMet) {
            alert.triggered = true;
            emit AlertTriggered(tokenId, currentPrice, alert.targetPrice);
        }

        return conditionMet;
    }

    /// @inheritdoc IAgentLogic
    function description() external pure returns (string memory) {
        return "On-chain price monitoring with Binance Oracle and keeper support";
    }

    /// @dev Read the latest price from a Binance Oracle Feed Adapter.
    ///      Uses latestRoundData() with staleness check instead of deprecated latestAnswer().
    function _getPrice(address priceFeed) internal view returns (uint256) {
        (, int256 price, , uint256 updatedAt, ) = IBinanceOracleFeed(priceFeed).latestRoundData();
        require(price > 0, "PriceAlert: invalid price");
        require(block.timestamp - updatedAt <= 1 hours, "PriceAlert: stale price");
        return uint256(price);
    }
}

/// @dev Minimal Binance Oracle Feed Adapter interface.
///      Compatible with AggregatorV2V3Interface.
///      See: https://oracle.binance.com/docs/price-feeds/feed-adapter/
interface IBinanceOracleFeed {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}
