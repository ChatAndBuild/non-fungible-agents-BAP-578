// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IPolicy — Composable Policy Plugin Interface
/// @author SHLL Protocol (https://github.com/shll-protocol/shll)
/// @notice Standard interface for NFA agent action validation policies.
///         Each policy is a standalone contract that validates a single aspect
///         of an action (e.g. token whitelist, spending limit, cooldown).
///
///         BAP-578 Extension: Policy Validation Framework
///         Extends §4.7 Security Mechanisms with granular, per-transaction enforcement.
interface IPolicy {
    /// @notice Validate whether an action is allowed under this policy
    /// @param tokenId   The NFA token ID
    /// @param caller    The address that initiated the execute call
    /// @param target    The target contract of the action
    /// @param selector  The function selector (first 4 bytes of calldata)
    /// @param callData  The full calldata of the action
    /// @param value     The native value (BNB) sent with the action
    /// @return ok       True if the action passes this policy
    /// @return reason   Human-readable rejection reason (empty if ok)
    function check(
        uint256 tokenId,
        address caller,
        address target,
        bytes4 selector,
        bytes calldata callData,
        uint256 value
    ) external view returns (bool ok, string memory reason);

    /// @notice Returns the policy type identifier
    /// @dev Standard types defined in PolicyTypes.sol
    /// @return The keccak256 hash of the policy type string
    function policyType() external pure returns (bytes32);

    /// @notice Whether this policy can be modified by the agent renter
    /// @dev Core security policies (e.g. ReceiverGuard) return false —
    ///      only the owner can configure them. Policies like TokenWhitelist
    ///      return true — renters can add tokens within the owner's ceiling.
    function renterConfigurable() external pure returns (bool);
}
