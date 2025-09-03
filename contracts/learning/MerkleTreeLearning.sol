// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import "../interfaces/ILearningModule.sol";

/**
 * @title MerkleTreeLearning
 * @dev Implementation of Merkle tree-based learning for BAP578 agents
 */
contract MerkleTreeLearning is
    ILearningModule,
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using MerkleProofUpgradeable for bytes32[];

    // Mapping from token ID to learning tree root
    mapping(uint256 => bytes32) private _learningRoots;

    // Mapping from token ID to learning metrics
    mapping(uint256 => LearningMetrics) private _learningMetrics;

    /**
     * @dev Initializes the contract
     */
    function initialize() public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
    }

    /**
     * @dev Verifies a learning claim using Merkle proof
     * @param tokenId The ID of the agent token
     * @param claim The claim to verify
     * @param proof The Merkle proof
     * @return Whether the claim is valid
     */
    function verifyLearning(
        uint256 tokenId,
        bytes32 claim,
        bytes32[] calldata proof
    ) external view override returns (bool) {
        bytes32 root = _learningRoots[tokenId];
        return proof.verify(root, claim);
    }

    /**
     * @dev Gets the current learning metrics for an agent
     * @param tokenId The ID of the agent token
     * @return The learning metrics
     */
    function getLearningMetrics(
        uint256 tokenId
    ) external view override onlyOwner returns (LearningMetrics memory) {
        return _learningMetrics[tokenId];
    }

    /**
     * @dev Gets the current learning tree root for an agent
     * @param tokenId The ID of the agent token
     * @return The Merkle root of the learning tree
     */
    function getLearningRoot(uint256 tokenId) external view override onlyOwner returns (bytes32) {
        return _learningRoots[tokenId];
    }
}
