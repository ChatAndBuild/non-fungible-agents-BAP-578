// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./IPolicy.sol";
import "./PolicyTypes.sol";

/// @title SpendingLimitExample — Example Policy Implementation
/// @author SHLL Protocol (https://github.com/shll-protocol/shll)
/// @notice Demonstrates how to implement the IPolicy interface.
///         Enforces a per-action spending cap on native value (BNB).
///
///         This is a SIMPLIFIED example for learning purposes.
///         Production version: SpendingLimitPolicyV2
///         https://bscscan.com/address/0x28efC8D513D44252EC26f710764ADe22b2569115
contract SpendingLimitExample is IPolicy {
    /// @notice Per-agent spending limit in wei
    mapping(uint256 => uint256) public limits;

    /// @notice Contract owner
    address public owner;

    // --- Events ---
    event LimitSet(uint256 indexed tokenId, uint256 limit);

    // --- Constructor ---
    constructor() {
        owner = msg.sender;
    }

    // --- Admin ---

    /// @notice Set the per-action spending limit for an agent
    /// @param tokenId The NFA token ID
    /// @param limit   Maximum native value per action (in wei)
    function setLimit(uint256 tokenId, uint256 limit) external {
        require(msg.sender == owner, "SpendingLimit: not owner");
        limits[tokenId] = limit;
        emit LimitSet(tokenId, limit);
    }

    // --- IPolicy Implementation ---

    /// @inheritdoc IPolicy
    function check(
        uint256 tokenId,
        address /* caller */,
        address /* target */,
        bytes4 /* selector */,
        bytes calldata /* callData */,
        uint256 value
    ) external view override returns (bool ok, string memory reason) {
        uint256 limit = limits[tokenId];

        // Fail-close: if no limit is configured, block all valued actions
        if (limit == 0 && value > 0) {
            return (false, "SpendingLimit: no limit configured");
        }

        // Check against limit
        if (value > limit) {
            return (false, "SpendingLimit: exceeds per-action limit");
        }

        return (true, "");
    }

    /// @inheritdoc IPolicy
    function policyType() external pure override returns (bytes32) {
        return PolicyTypes.SPENDING_LIMIT;
    }

    /// @inheritdoc IPolicy
    function renterConfigurable() external pure override returns (bool) {
        // Spending limits are owner-controlled, not renter-configurable
        return false;
    }
}
