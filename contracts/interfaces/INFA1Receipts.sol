// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

/// @title INFA1Receipts - NFA-1 Receipts and Audit Trail Extension
/// @notice Recommended extension for creating on-chain audit trails of agent actions
/// @dev Receipts store hashes (not raw data) on-chain to minimize gas costs.
///      The actual input/output data is Verifiably On-Chain: stored off-chain
///      but verifiable via the on-chain hash commitment.
///
///      Every agent action that produces a receipt creates an immutable record
///      documenting what was executed, with what inputs, and the result.
///      This addresses the "receipts" requirement for trustworthy AI agents.
interface INFA1Receipts {

    /// @notice A receipt for an agent action
    struct Receipt {
        uint256 tokenId;        // Agent that performed the action
        uint256 timestamp;      // When the action occurred
        bytes4 actionSelector;  // Function selector of the action
        bytes32 inputHash;      // keccak256 of input data
        bytes32 outputHash;     // keccak256 of output/result data
        bool success;           // Whether the action succeeded
    }

    /// @notice MUST be emitted for every agent action that produces a receipt
    event ReceiptCreated(
        uint256 indexed tokenId,
        uint256 indexed receiptIndex,
        bytes4 actionSelector,
        bytes32 inputHash,
        bytes32 outputHash,
        bool success
    );

    /// @notice Get the total number of receipts for an agent
    function getReceiptCount(uint256 tokenId) external view returns (uint256);

    /// @notice Get a specific receipt by index
    function getReceipt(uint256 tokenId, uint256 index)
        external view returns (Receipt memory);
}
