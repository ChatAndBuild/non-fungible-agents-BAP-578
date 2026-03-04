// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./IPolicy.sol";
import "./IPolicyGuard.sol";

/// @title PolicyGuardExample — Minimal PolicyGuard Reference Implementation
/// @author SHLL Protocol (https://github.com/shll-protocol/shll)
/// @notice A simplified PolicyGuard implementation demonstrating the core pattern:
///         register policies → bind to agents → validate before execution → commit after.
///
///         This is a REFERENCE IMPLEMENTATION for learning and testing.
///         For production use, see SHLL's PolicyGuardV4 at:
///         https://bscscan.com/address/0x25d17eA0e3Bcb8CA08a2BFE917E817AFc05dbBB3
///
/// @dev Key design principles:
///      1. FAIL-CLOSE: any policy failure blocks the entire action
///      2. COMPOSABLE: agents can have different policy sets
///      3. ON-CHAIN: enforcement lives in smart contracts, not off-chain code
contract PolicyGuardExample is IPolicyGuard {
    // --- State ---

    /// @notice Contract owner
    address public owner;

    /// @notice Global registry of approved policies
    address[] private _registeredPolicies;
    mapping(address => bool) public isRegistered;

    /// @notice Per-agent bound policy sets
    mapping(uint256 => address[]) private _boundPolicies;

    // --- Modifiers ---

    modifier onlyOwner() {
        require(msg.sender == owner, "PolicyGuard: not owner");
        _;
    }

    // --- Constructor ---

    constructor() {
        owner = msg.sender;
    }

    // ═══════════════════════════════════════════════════════
    //                    ADMIN: Registry
    // ═══════════════════════════════════════════════════════

    /// @inheritdoc IPolicyGuard
    function registerPolicy(address policy) external onlyOwner {
        require(policy != address(0), "PolicyGuard: zero address");
        require(!isRegistered[policy], "PolicyGuard: already registered");

        isRegistered[policy] = true;
        _registeredPolicies.push(policy);

        emit PolicyRegistered(policy, IPolicy(policy).policyType());
    }

    /// @inheritdoc IPolicyGuard
    function removePolicy(address policy) external onlyOwner {
        require(isRegistered[policy], "PolicyGuard: not registered");

        isRegistered[policy] = false;
        _removeFromArray(_registeredPolicies, policy);

        emit PolicyRemoved(policy);
    }

    /// @inheritdoc IPolicyGuard
    function getRegisteredPolicies() external view returns (address[] memory) {
        return _registeredPolicies;
    }

    // ═══════════════════════════════════════════════════════
    //                  ADMIN: Agent Binding
    // ═══════════════════════════════════════════════════════

    /// @inheritdoc IPolicyGuard
    function bindPolicies(
        uint256 tokenId,
        address[] calldata policies
    ) external onlyOwner {
        // Validate all policies are registered
        for (uint256 i = 0; i < policies.length; i++) {
            require(
                isRegistered[policies[i]],
                "PolicyGuard: policy not registered"
            );
        }

        // Replace existing bound policies
        delete _boundPolicies[tokenId];
        for (uint256 i = 0; i < policies.length; i++) {
            _boundPolicies[tokenId].push(policies[i]);
        }

        emit PoliciesBound(tokenId, policies);
    }

    /// @inheritdoc IPolicyGuard
    function getBoundPolicies(
        uint256 tokenId
    ) external view returns (address[] memory) {
        return _boundPolicies[tokenId];
    }

    // ═══════════════════════════════════════════════════════
    //                  CORE: Validation
    // ═══════════════════════════════════════════════════════

    /// @inheritdoc IPolicyGuard
    /// @dev Iterates through ALL bound policies. FAIL-CLOSE: any failure blocks the action.
    ///      Note: validate() is `view` — it cannot emit events. The caller (the agent's
    ///      execute function) should emit ActionValidated after receiving the result.
    function validate(
        address /* nfa */,
        uint256 tokenId,
        address /* agentAccount */,
        address caller,
        address target,
        uint256 value,
        bytes calldata data
    ) external view override returns (bool ok, string memory reason) {
        address[] storage policies = _boundPolicies[tokenId];

        // No policies bound = no agent configured = block
        if (policies.length == 0) {
            return (false, "PolicyGuard: no policies bound");
        }

        // Extract function selector from calldata
        bytes4 selector = bytes4(0);
        if (data.length >= 4) {
            selector = bytes4(data[:4]);
        }

        // Check every bound policy (fail-close)
        for (uint256 i = 0; i < policies.length; i++) {
            (bool pOk, string memory pReason) = IPolicy(policies[i]).check(
                tokenId,
                caller,
                target,
                selector,
                data,
                value
            );
            if (!pOk) {
                return (false, pReason);
            }
        }

        return (true, "");
    }

    // ═══════════════════════════════════════════════════════
    //                  CORE: Commit
    // ═══════════════════════════════════════════════════════

    /// @inheritdoc IPolicyGuard
    /// @dev Called after successful execution for stateful policies.
    ///      In production (SHLL), this updates SpendingLimit daily counters.
    function commit(
        uint256 tokenId,
        address target,
        uint256 /* value */,
        bytes calldata /* data */
    ) external {
        // In a full implementation, iterate bound policies and call
        // a commit() hook on stateful ones (e.g. SpendingLimit tracking).
        // This example emits an event as a placeholder.
        emit ActionCommitted(tokenId, target);
    }

    // ═══════════════════════════════════════════════════════
    //                    INTERNAL
    // ═══════════════════════════════════════════════════════

    function _removeFromArray(address[] storage arr, address item) internal {
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == item) {
                arr[i] = arr[arr.length - 1];
                arr.pop();
                return;
            }
        }
    }
}
