// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IAgentLogic
 * @dev Standard interface for BAP-578 agent logic contracts.
 *
 * Logic contracts extend an agent's on-chain capabilities. Once deployed,
 * they are bound to an agent via `BAP578.setLogicAddress(tokenId, address)`.
 *
 * Any contract implementing this interface can serve as the "brain" of a
 * BAP-578 agent, enabling autonomous or owner-triggered on-chain actions.
 */
interface IAgentLogic {
    /// @notice Execute the logic contract's primary action.
    /// @param tokenId The BAP-578 agent token ID.
    /// @param data    Arbitrary calldata for the action.
    /// @return result The return data from execution.
    function execute(
        uint256 tokenId,
        bytes calldata data
    ) external payable returns (bytes memory result);

    /// @notice Human-readable description of what this logic contract does.
    function description() external view returns (string memory);
}
