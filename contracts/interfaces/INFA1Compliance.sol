// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

/// @title INFA1Compliance - NFA-1 Compliance Metadata Extension
/// @notice Optional extension for enterprise and regulatory compliance
/// @dev All sensitive KYC data is stored off-chain; only the hash attestation
///      goes on-chain (Verifiably On-Chain pattern).
interface INFA1Compliance {

    struct ComplianceMetadata {
        bytes32 kycHash;           // Hash of KYC attestation document
        uint256 kycTimestamp;      // When KYC was completed
        address kycProvider;       // Address of KYC attestation provider
        uint8 complianceLevel;     // 0=none, 1=basic, 2=enhanced, 3=institutional
        bool sanctionsCleared;     // Sanctions screening result
    }

    event ComplianceUpdated(
        uint256 indexed tokenId,
        address indexed kycProvider,
        uint8 complianceLevel
    );

    /// @notice Get compliance metadata for an agent
    function getComplianceMetadata(uint256 tokenId)
        external view returns (ComplianceMetadata memory);

    /// @notice Update compliance metadata
    /// @dev Authorization model is implementation-defined
    function updateCompliance(
        uint256 tokenId,
        ComplianceMetadata calldata metadata
    ) external;
}
