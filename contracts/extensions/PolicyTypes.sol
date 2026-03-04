// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title PolicyTypes — Standard Policy Type Identifiers
/// @author SHLL Protocol (https://github.com/kledx/shll)
/// @notice Defines the standard policy type identifiers for BAP-578 agents.
///         Each policy type represents a specific security constraint.
///
///         Four core policies provide complete coverage:
///         - SpendingLimit: value caps (includes token whitelist in production V2)
///         - Cooldown: time-based rate limiting
///         - DeFiGuard: contract + function filtering (subsumes DEX whitelisting)
///         - ReceiverGuard: output address restriction
///
///         Implementers MAY define custom policy types by following the same
///         pattern: keccak256("lowercase_type_name").
library PolicyTypes {
    /// @notice Per-action and daily value caps
    /// @dev Prevents overspending from hallucination or compromised operators.
    ///      Production V2 also integrates token whitelist + approve control.
    bytes32 internal constant SPENDING_LIMIT = keccak256("spending_limit");

    /// @notice Minimum time interval between actions
    /// @dev Prevents rapid-fire trading loops and gas drainage attacks
    bytes32 internal constant COOLDOWN = keccak256("cooldown");

    /// @notice DeFi contract + function selector filtering
    /// @dev Controls which contracts and functions the agent can call.
    ///      Subsumes DEX router whitelisting — no separate DEX policy needed.
    bytes32 internal constant DEFI_GUARD = keccak256("defi_guard");

    /// @notice Restrict fund recipient addresses
    /// @dev Prevents prompt injection attacks that redirect funds to attacker wallets.
    ///      Fail-close: no whitelist = no outbound transfers allowed.
    bytes32 internal constant RECEIVER_GUARD = keccak256("receiver_guard");
}
