// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

/// @title INFA1CircuitBreaker - NFA-1 Emergency Circuit Breaker Extension
/// @notice Optional extension for ecosystem-wide and per-agent emergency pause
/// @dev Provides a safety mechanism independent of individual agent pause/unpause.
///      While INFA1Core.pause() is per-agent and owner-controlled,
///      the circuit breaker enables a governance or emergency multi-sig to halt
///      operations across the entire contract or specific agents.
///
///      This is a SEPARATE concern from agent lifecycle:
///      - Agent pause (INFA1Core): Owner pauses their own agent
///      - Circuit breaker: Governance/emergency pauses the ecosystem
///
///      Inspired by: Official BAP-578 paused/emergencyWithdraw pattern (ChatAndBuild)
interface INFA1CircuitBreaker {

    /// @notice Emitted when the global pause state changes
    event GlobalPauseUpdated(bool paused);

    /// @notice Emitted when a specific agent's circuit breaker state changes
    event AgentCircuitBreakerUpdated(uint256 indexed tokenId, bool paused);

    /// @notice Check if the global circuit breaker is active
    /// @return True if all agent operations are globally paused
    function isGloballyPaused() external view returns (bool);

    /// @notice Check if a specific agent is paused by the circuit breaker
    /// @dev This is independent of the agent's lifecycle Status.
    ///      An agent can be Active (lifecycle) but circuit-broken (emergency).
    /// @param tokenId The agent token ID
    /// @return True if the agent is paused by circuit breaker
    function isCircuitBroken(uint256 tokenId) external view returns (bool);

    /// @notice Activate or deactivate the global circuit breaker
    /// @dev Authorization MUST be restricted to governance or emergency multi-sig.
    ///      MUST NOT be callable by individual token owners.
    /// @param paused True to activate global pause, false to deactivate
    function setGlobalPause(bool paused) external;

    /// @notice Activate or deactivate the circuit breaker for a specific agent
    /// @dev Authorization model is implementation-defined (governance, admin, or owner)
    /// @param tokenId The agent token ID
    /// @param paused True to circuit-break this agent, false to restore
    function setAgentCircuitBreaker(uint256 tokenId, bool paused) external;
}
