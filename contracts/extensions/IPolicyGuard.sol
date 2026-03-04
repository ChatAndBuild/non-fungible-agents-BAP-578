// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IPolicyGuard — On-Chain Firewall Interface
/// @author SHLL Protocol (https://github.com/kledx/shll)
/// @notice Coordinates multiple IPolicy validators for NFA agent actions.
///         The PolicyGuard acts as a composable policy engine that enforces
///         all active policies before any agent action is executed.
///
///         BAP-578 Extension: Policy Validation Framework
///         Extends §4.7 Security Mechanisms.
///
///         Design principle: FAIL-CLOSE
///         - If ANY policy returns false, the entire action is blocked.
///         - If a policy contract reverts, the action is blocked.
///         - Only explicit ok=true from ALL policies permits execution.
interface IPolicyGuard {
    /// @notice Validate an action against all active policies
    /// @param nfa          The AgentNFA contract address
    /// @param tokenId      The NFA token ID
    /// @param agentAccount The agent's vault/account address
    /// @param caller       The address that initiated the execute call
    /// @param target       The target contract of the action
    /// @param value        The native value (BNB) sent with the action
    /// @param data         The full calldata of the action
    /// @return ok          Whether all policies pass
    /// @return reason      Human-readable rejection reason (empty if ok)
    function validate(
        address nfa,
        uint256 tokenId,
        address agentAccount,
        address caller,
        address target,
        uint256 value,
        bytes calldata data
    ) external view returns (bool ok, string memory reason);

    /// @notice Post-execution state update
    /// @dev Called after successful action execution for stateful policies
    ///      (e.g. SpendingLimit tracks daily cumulative spending)
    /// @param tokenId The NFA token ID
    /// @param target  The target contract of the executed action
    /// @param value   The native value sent
    /// @param data    The calldata that was executed
    function commit(
        uint256 tokenId,
        address target,
        uint256 value,
        bytes calldata data
    ) external;

    /// @notice Register a policy in the global approved set
    /// @param policy The IPolicy contract address
    function registerPolicy(address policy) external;

    /// @notice Remove a policy from the global approved set
    /// @param policy The IPolicy contract address
    function removePolicy(address policy) external;

    /// @notice Get all registered policies
    /// @return Array of IPolicy contract addresses
    function getRegisteredPolicies() external view returns (address[] memory);

    /// @notice Bind a set of policies to a specific agent
    /// @param tokenId  The NFA token ID
    /// @param policies Array of IPolicy addresses to bind
    function bindPolicies(
        uint256 tokenId,
        address[] calldata policies
    ) external;

    /// @notice Get all policies bound to a specific agent
    /// @param tokenId The NFA token ID
    /// @return Array of IPolicy contract addresses
    function getBoundPolicies(
        uint256 tokenId
    ) external view returns (address[] memory);

    // --- Events ---

    event ActionValidated(
        uint256 indexed tokenId,
        address indexed target,
        bool allowed,
        string reason
    );

    event ActionCommitted(uint256 indexed tokenId, address indexed target);

    event PolicyRegistered(address indexed policy, bytes32 policyType);

    event PolicyRemoved(address indexed policy);

    event PoliciesBound(uint256 indexed tokenId, address[] policies);
}
