// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./interfaces/IAgentLogic.sol";
import "./interfaces/IBAP578.sol";

/**
 * @title SimpleTrader
 * @dev Example BAP-578 logic contract: a simple token swap executor.
 *
 * Demonstrates how to build a logic contract that:
 *   1. Verifies the caller owns the agent
 *   2. Reads agent state from BAP-578
 *   3. Executes an external call (e.g. DEX swap) on behalf of the agent
 *   4. Enforces per-trade and daily spend limits
 *
 * Usage:
 *   1. Deploy this contract with the BAP-578 address
 *   2. Call `BAP578.setLogicAddress(tokenId, address(this))`
 *   3. Call `execute(tokenId, abi.encode(target, value, callData))`
 *
 * ⚠️  This is an educational example. Do NOT use in production without
 *     a full security audit.
 */
contract SimpleTrader is IAgentLogic {
    IBAP578 public immutable bap578;

    uint256 public constant MAX_TRADE_AMOUNT = 1 ether;
    uint256 public constant MAX_DAILY_AMOUNT = 5 ether;

    // tokenId => day => total spent
    mapping(uint256 => mapping(uint256 => uint256)) public dailySpent;

    event TradeExecuted(uint256 indexed tokenId, address indexed target, uint256 value);

    constructor(address _bap578) {
        require(_bap578 != address(0), "SimpleTrader: zero BAP578 address");
        bap578 = IBAP578(_bap578);
    }

    /// @inheritdoc IAgentLogic
    function execute(
        uint256 tokenId,
        bytes calldata data
    ) external payable returns (bytes memory result) {
        // 1. Verify caller is the agent owner
        require(bap578.ownerOf(tokenId) == msg.sender, "SimpleTrader: not agent owner");

        // 2. Verify agent is active and bound to this logic contract
        (, bool active, address logicAddress, , ) = bap578.getAgentState(tokenId);
        require(active, "SimpleTrader: agent not active");
        require(logicAddress == address(this), "SimpleTrader: not bound to agent");

        // 3. Decode trade parameters
        (address target, uint256 value, bytes memory callData) = abi.decode(
            data,
            (address, uint256, bytes)
        );

        // 4. Enforce trade limits
        require(value <= MAX_TRADE_AMOUNT, "SimpleTrader: exceeds per-trade limit");
        uint256 today = block.timestamp / 1 days;
        dailySpent[tokenId][today] += value;
        require(
            dailySpent[tokenId][today] <= MAX_DAILY_AMOUNT,
            "SimpleTrader: exceeds daily limit"
        );

        // 5. Execute the trade
        bool success;
        (success, result) = target.call{ value: value }(callData);
        require(success, "SimpleTrader: trade failed");

        emit TradeExecuted(tokenId, target, value);
    }

    /// @inheritdoc IAgentLogic
    function description() external pure returns (string memory) {
        return "Simple token swap executor with per-trade and daily spend limits";
    }

    receive() external payable {}
}
