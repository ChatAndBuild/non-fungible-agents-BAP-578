// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
 * @title MetricsTracker
 * @dev On-chain action counters for BORT logic contracts.
 *
 *      Inheriting contracts call `_recordAction(tokenId, success, isTrade)` at the
 *      end of their handleAction dispatcher.
 *
 *      Storage uses internal mappings (instead of public) to keep bytecode small
 *      enough that bloated parents (CTOAgentLogic) still fit under the Spurious
 *      Dragon 24576-byte deploy limit. Read all counters via getMetrics().
 *
 *      Note on lifetimePnL / activePositions: those need protocol-specific accounting
 *      (Hunter has it because Hunter manages positions). For Trading/CTO the runtime's
 *      TradeHistoryService is the source of truth for PnL, so this base returns 0 for
 *      those slots — the leaderboard still reads PnL via TradeHistoryService.
 */
abstract contract MetricsTracker {
    // Internal — read via getMetrics(). public getters add ~80 bytes each.
    mapping(uint256 => uint256) internal _totalActionsCount;
    mapping(uint256 => uint256) internal _successfulActionsCount;
    mapping(uint256 => uint256) internal _totalTradesCount;
    mapping(uint256 => uint256) internal _lastActiveTimestamp;

    function _recordAction(uint256 tokenId, bool success, bool isTrade) internal {
        unchecked { _totalActionsCount[tokenId] += 1; }
        if (success) {
            unchecked { _successfulActionsCount[tokenId] += 1; }
        }
        if (isTrade) {
            unchecked { _totalTradesCount[tokenId] += 1; }
        }
        _lastActiveTimestamp[tokenId] = block.timestamp;
    }

    /**
     * @notice Hunter-compatible getter so AgentMetricsService can read every logic
     *         type through the same ABI without per-contract specialization.
     */
    function getMetrics(uint256 tokenId) external view returns (
        uint256 _totalActions,
        uint256 _successfulActions,
        uint256 _totalTrades,
        int256  _lifetimePnL,
        uint256 _totalInteractions,
        uint256 _lastActive,
        uint256 _activePositions
    ) {
        uint256 succ = _successfulActionsCount[tokenId];
        return (
            _totalActionsCount[tokenId],
            succ,
            _totalTradesCount[tokenId],
            int256(0),                       // PnL tracked off-chain in TradeHistoryService
            succ,                            // totalInteractions aliases successfulActions
            _lastActiveTimestamp[tokenId],
            uint256(0)                       // positions tracked off-chain
        );
    }
}
