// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

/// @title INFA1Payment - NFA-1 Payment Compatibility Extension
/// @notice Optional extension for agent fund management and X402 protocol compatibility
/// @dev Enables NFAs to participate in the X402 payment ecosystem, allowing agents
///      to autonomously pay for and provide services.
///
///      X402 Payment Flow for NFAs:
///      1. NFA-backed service returns HTTP 402 with payment requirements
///      2. Client constructs EIP-712 signed payment authorization
///      3. Payment references the NFA tokenId as service provider identity
///      4. Facilitator verifies payment, settles on-chain
///      5. NFA contract receives funds via fundAgent()
///      6. Contract emits PaymentProcessed event
interface INFA1Payment {

    /// @notice Emitted when an agent makes or receives a payment
    event PaymentProcessed(
        uint256 indexed tokenId,
        address indexed counterparty,
        uint256 amount,
        bytes32 paymentRef    // Reference to X402 payment hash
    );

    /// @notice Withdraw from an agent's internal balance
    /// @dev MUST only be callable by token owner or approved
    /// @dev MUST revert if amount > agent balance
    /// @param tokenId The agent token ID
    /// @param recipient Address to receive the withdrawn funds
    /// @param amount Amount to withdraw
    function withdrawFromAgent(
        uint256 tokenId,
        address payable recipient,
        uint256 amount
    ) external;

    /// @notice Get the agent's current spendable balance
    function getAgentBalance(uint256 tokenId) external view returns (uint256);
}
