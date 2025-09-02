// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import "../interfaces/ILearningModule.sol";

/**
 * @title MerkleTreeLearning
 * @dev Implementation of Merkle tree-based learning for BEP007 agents
 * Supports updating Merkle roots when extended data changes
 * Stores complete Merkle tree structure including child nodes
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

    // Mapping from token ID to learning update history
    mapping(uint256 => LearningUpdate[]) private _learningUpdates;

    // Mapping from token ID to current update count
    mapping(uint256 => uint256) private _updateCounts;

    // Mapping from token ID to last update timestamp
    mapping(uint256 => uint256) private _lastUpdateTimestamps;

    // Mapping from token ID to Merkle tree nodes
    mapping(uint256 => mapping(bytes32 => TreeNode)) private _treeNodes;

    // Mapping from token ID to array of all node hashes
    mapping(uint256 => bytes32[]) private _nodeHashes;

    // Mapping from token ID to node count
    mapping(uint256 => uint256) private _nodeCounts;

    /**
     * @dev Struct representing a Merkle tree node
     */
    struct TreeNode {
        bytes32 hash;           // Hash of this node
        bytes32 leftChild;      // Hash of left child (or zero if leaf)
        bytes32 rightChild;     // Hash of right child (or zero if leaf)
        bytes data;             // Raw data for leaf nodes
        uint256 level;          // Level in the tree (0 = leaf, 1 = parent, etc.)
        uint256 position;       // Position within the level
        bool isLeaf;            // Whether this is a leaf node
        uint256 timestamp;      // When this node was added
    }

    /**
     * @dev Struct representing a complete tree update
     */
    struct TreeUpdate {
        bytes32 previousRoot;
        bytes32 newRoot;
        bytes32[] addedNodes;      // New nodes added in this update
        bytes32[] removedNodes;    // Nodes removed in this update
        bytes proof;
        string reason;
        uint256 timestamp;
    }

    /**
     * @dev Emitted when a tree node is added
     */
    event TreeNodeAdded(
        uint256 indexed tokenId,
        bytes32 indexed nodeHash,
        bytes32 leftChild,
        bytes32 rightChild,
        uint256 level,
        uint256 position,
        bool isLeaf
    );

    /**
     * @dev Emitted when a tree node is updated
     */
    event TreeNodeUpdated(
        uint256 indexed tokenId,
        bytes32 indexed nodeHash,
        bytes32 previousLeftChild,
        bytes32 previousRightChild,
        bytes32 newLeftChild,
        bytes32 newRightChild
    );

    /**
     * @dev Emitted when a tree node is removed
     */
    event TreeNodeRemoved(
        uint256 indexed tokenId,
        bytes32 indexed nodeHash
    );

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
     * @dev Updates the learning tree root for an agent when extended data changes
     * @param tokenId The ID of the agent token
     * @param newRoot The new Merkle root
     * @param proof Optional proof of the update (can be empty bytes)
     * @param reason Optional reason for the update
     */
    function updateLearningRoot(
        uint256 tokenId,
        bytes32 newRoot,
        bytes calldata proof,
        string calldata reason
    ) external onlyOwner nonReentrant {
        _updateLearningRootInternal(tokenId, newRoot, proof, reason);
    }

    /**
     * @dev Updates the learning tree root with complete tree structure
     * @param tokenId The ID of the agent token
     * @param newRoot The new Merkle root
     * @param nodes Array of tree nodes to add/update
     * @param proof Optional proof of the update
     * @param reason Optional reason for the update
     */
    function updateLearningRootWithNodes(
        uint256 tokenId,
        bytes32 newRoot,
        TreeNode[] calldata nodes,
        bytes calldata proof,
        string calldata reason
    ) external onlyOwner nonReentrant {
        _updateLearningRootWithNodesInternal(tokenId, newRoot, nodes, proof, reason);
    }

    /**
     * @dev Internal function to update the learning tree root with nodes
     * @param tokenId The ID of the agent token
     * @param newRoot The new Merkle root
     * @param nodes Array of tree nodes to add/update
     * @param proof Optional proof of the update
     */
    function _updateLearningRootWithNodesInternal(
        uint256 tokenId,
        bytes32 newRoot,
        TreeNode[] calldata nodes,
        bytes calldata proof,
        string calldata /* reason */
    ) internal {
        require(newRoot != bytes32(0), "MerkleTreeLearning: new root cannot be zero");
        require(newRoot != _learningRoots[tokenId], "MerkleTreeLearning: new root must be different");

        bytes32 previousRoot = _learningRoots[tokenId];
        
        // Update the root
        _learningRoots[tokenId] = newRoot;
        
        // Add/update tree nodes
        _updateTreeNodes(tokenId, nodes);
        
        // Update learning metrics
        _updateLearningMetrics(tokenId);
        
        // Record the learning update
        LearningUpdate memory update = LearningUpdate({
            previousRoot: previousRoot,
            newRoot: newRoot,
            proof: proof,
            timestamp: block.timestamp
        });
        
        _learningUpdates[tokenId].push(update);
        _updateCounts[tokenId]++;
        _lastUpdateTimestamps[tokenId] = block.timestamp;
        
        // Update confidence score after update count is incremented
        _learningMetrics[tokenId].confidenceScore = _calculateConfidenceScore(tokenId);
        
        // Emit learning updated event
        emit LearningUpdated(tokenId, previousRoot, newRoot, block.timestamp);
        
        // Check for learning milestones
        _checkLearningMilestones(tokenId);
    }

    /**
     * @dev Internal function to update the learning tree root
     * @param tokenId The ID of the agent token
     * @param newRoot The new Merkle root
     * @param proof Optional proof of the update (can be empty bytes)
     */
    function _updateLearningRootInternal(
        uint256 tokenId,
        bytes32 newRoot,
        bytes calldata proof,
        string calldata /* reason */
    ) internal {
        require(newRoot != bytes32(0), "MerkleTreeLearning: new root cannot be zero");
        require(newRoot != _learningRoots[tokenId], "MerkleTreeLearning: new root must be different");

        bytes32 previousRoot = _learningRoots[tokenId];
        
        // Update the root
        _learningRoots[tokenId] = newRoot;
        
        // Update learning metrics
        _updateLearningMetrics(tokenId);
        
        // Record the learning update
        LearningUpdate memory update = LearningUpdate({
            previousRoot: previousRoot,
            newRoot: newRoot,
            proof: proof,
            timestamp: block.timestamp
        });
        
        _learningUpdates[tokenId].push(update);
        _updateCounts[tokenId]++;
        _lastUpdateTimestamps[tokenId] = block.timestamp;
        
        // Update confidence score after update count is incremented
        _learningMetrics[tokenId].confidenceScore = _calculateConfidenceScore(tokenId);
        
        // Emit learning updated event
        emit LearningUpdated(tokenId, previousRoot, newRoot, block.timestamp);
        
        // Check for learning milestones
        _checkLearningMilestones(tokenId);
    }

    /**
     * @dev Internal function to update tree nodes
     * @param tokenId The ID of the agent token
     * @param nodes Array of tree nodes to add/update
     */
    function _updateTreeNodes(uint256 tokenId, TreeNode[] calldata nodes) internal {
        for (uint256 i = 0; i < nodes.length; i++) {
            TreeNode calldata node = nodes[i];
            
            // Validate node
            require(node.hash != bytes32(0), "MerkleTreeLearning: node hash cannot be zero");
            
            // Check if node already exists
            bool nodeExists = _treeNodes[tokenId][node.hash].hash != bytes32(0);
            
            if (nodeExists) {
                // Update existing node
                TreeNode storage existingNode = _treeNodes[tokenId][node.hash];
                bytes32 previousLeftChild = existingNode.leftChild;
                bytes32 previousRightChild = existingNode.rightChild;
                
                existingNode.leftChild = node.leftChild;
                existingNode.rightChild = node.rightChild;
                existingNode.data = node.data;
                existingNode.level = node.level;
                existingNode.position = node.position;
                existingNode.isLeaf = node.isLeaf;
                existingNode.timestamp = block.timestamp;
                
                emit TreeNodeUpdated(
                    tokenId,
                    node.hash,
                    previousLeftChild,
                    previousRightChild,
                    node.leftChild,
                    node.rightChild
                );
            } else {
                // Add new node
                _treeNodes[tokenId][node.hash] = TreeNode({
                    hash: node.hash,
                    leftChild: node.leftChild,
                    rightChild: node.rightChild,
                    data: node.data,
                    level: node.level,
                    position: node.position,
                    isLeaf: node.isLeaf,
                    timestamp: block.timestamp
                });
                
                _nodeHashes[tokenId].push(node.hash);
                _nodeCounts[tokenId]++;
                
                emit TreeNodeAdded(
                    tokenId,
                    node.hash,
                    node.leftChild,
                    node.rightChild,
                    node.level,
                    node.position,
                    node.isLeaf
                );
            }
        }
    }

    /**
     * @dev Batch updates multiple learning roots with tree structures
     * @param tokenIds Array of token IDs
     * @param newRoots Array of new Merkle roots
     * @param nodesArray Array of node arrays for each token
     * @param proofs Array of proofs (can be empty)
     * @param reasons Array of reasons for updates
     */
    function batchUpdateLearningRootsWithNodes(
        uint256[] calldata tokenIds,
        bytes32[] calldata newRoots,
        TreeNode[][] calldata nodesArray,
        bytes[] calldata proofs,
        string[] calldata reasons
    ) external onlyOwner nonReentrant {
        require(
            tokenIds.length == newRoots.length &&
            newRoots.length == nodesArray.length &&
            nodesArray.length == proofs.length &&
            proofs.length == reasons.length,
            "MerkleTreeLearning: array lengths must match"
        );
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _updateLearningRootWithNodesInternal(tokenIds[i], newRoots[i], nodesArray[i], proofs[i], reasons[i]);
        }
    }

    /**
     * @dev Batch updates multiple learning roots (without tree structures)
     * @param tokenIds Array of token IDs
     * @param newRoots Array of new Merkle roots
     * @param proofs Array of proofs (can be empty)
     * @param reasons Array of reasons for updates
     */
    function batchUpdateLearningRoots(
        uint256[] calldata tokenIds,
        bytes32[] calldata newRoots,
        bytes[] calldata proofs,
        string[] calldata reasons
    ) external onlyOwner nonReentrant {
        require(
            tokenIds.length == newRoots.length &&
            newRoots.length == proofs.length &&
            proofs.length == reasons.length,
            "MerkleTreeLearning: array lengths must match"
        );
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _updateLearningRootInternal(tokenIds[i], newRoots[i], proofs[i], reasons[i]);
        }
    }

    /**
     * @dev Gets the current learning metrics for an agent
     * @param tokenId The ID of the agent token
     * @return The learning metrics
     */
    function getLearningMetrics(
        uint256 tokenId
    ) external view override returns (LearningMetrics memory) {
        return _learningMetrics[tokenId];
    }

    /**
     * @dev Gets the current learning tree root for an agent
     * @param tokenId The ID of the agent token
     * @return The Merkle root of the learning tree
     */
    function getLearningRoot(uint256 tokenId) external view override returns (bytes32) {
        return _learningRoots[tokenId];
    }

    /**
     * @dev Gets the learning update history for an agent
     * @param tokenId The ID of the agent token
     * @return Array of learning updates
     */
    function getLearningUpdates(uint256 tokenId) external view returns (LearningUpdate[] memory) {
        return _learningUpdates[tokenId];
    }

    /**
     * @dev Gets the latest learning update for an agent
     * @param tokenId The ID of the agent token
     * @return The latest learning update
     */
    function getLatestLearningUpdate(uint256 tokenId) external view returns (LearningUpdate memory) {
        require(_learningUpdates[tokenId].length > 0, "MerkleTreeLearning: no updates found");
        return _learningUpdates[tokenId][_learningUpdates[tokenId].length - 1];
    }

    /**
     * @dev Gets the update count for an agent
     * @param tokenId The ID of the agent token
     * @return The number of updates
     */
    function getUpdateCount(uint256 tokenId) external view returns (uint256) {
        return _updateCounts[tokenId];
    }

    /**
     * @dev Gets the last update timestamp for an agent
     * @param tokenId The ID of the agent token
     * @return The timestamp of the last update
     */
    function getLastUpdateTimestamp(uint256 tokenId) external view returns (uint256) {
        return _lastUpdateTimestamps[tokenId];
    }

    /**
     * @dev Gets a specific tree node for an agent
     * @param tokenId The ID of the agent token
     * @param nodeHash The hash of the node to retrieve
     * @return The tree node
     */
    function getTreeNode(uint256 tokenId, bytes32 nodeHash) external view returns (TreeNode memory) {
        TreeNode memory node = _treeNodes[tokenId][nodeHash];
        require(node.hash != bytes32(0), "MerkleTreeLearning: node not found");
        return node;
    }

    /**
     * @dev Gets all tree nodes for an agent
     * @param tokenId The ID of the agent token
     * @return Array of all tree nodes
     */
    function getAllTreeNodes(uint256 tokenId) external view returns (TreeNode[] memory) {
        bytes32[] memory hashes = _nodeHashes[tokenId];
        TreeNode[] memory nodes = new TreeNode[](hashes.length);
        
        for (uint256 i = 0; i < hashes.length; i++) {
            nodes[i] = _treeNodes[tokenId][hashes[i]];
        }
        
        return nodes;
    }

    /**
     * @dev Gets tree nodes at a specific level for an agent
     * @param tokenId The ID of the agent token
     * @param level The level in the tree
     * @return Array of tree nodes at the specified level
     */
    function getTreeNodesAtLevel(uint256 tokenId, uint256 level) external view returns (TreeNode[] memory) {
        bytes32[] memory hashes = _nodeHashes[tokenId];
        uint256 count = 0;
        
        // Count nodes at the specified level
        for (uint256 i = 0; i < hashes.length; i++) {
            if (_treeNodes[tokenId][hashes[i]].level == level) {
                count++;
            }
        }
        
        // Create array and populate with nodes at the specified level
        TreeNode[] memory nodes = new TreeNode[](count);
        uint256 index = 0;
        
        for (uint256 i = 0; i < hashes.length; i++) {
            TreeNode memory node = _treeNodes[tokenId][hashes[i]];
            if (node.level == level) {
                nodes[index] = node;
                index++;
            }
        }
        
        return nodes;
    }

    /**
     * @dev Gets leaf nodes for an agent
     * @param tokenId The ID of the agent token
     * @return Array of leaf nodes
     */
    function getLeafNodes(uint256 tokenId) external view returns (TreeNode[] memory) {
        bytes32[] memory hashes = _nodeHashes[tokenId];
        uint256 count = 0;
        
        // Count leaf nodes
        for (uint256 i = 0; i < hashes.length; i++) {
            if (_treeNodes[tokenId][hashes[i]].isLeaf) {
                count++;
            }
        }
        
        // Create array and populate with leaf nodes
        TreeNode[] memory nodes = new TreeNode[](count);
        uint256 index = 0;
        
        for (uint256 i = 0; i < hashes.length; i++) {
            TreeNode memory node = _treeNodes[tokenId][hashes[i]];
            if (node.isLeaf) {
                nodes[index] = node;
                index++;
            }
        }
        
        return nodes;
    }

    /**
     * @dev Gets the number of tree nodes for an agent
     * @param tokenId The ID of the agent token
     * @return The number of tree nodes
     */
    function getNodeCount(uint256 tokenId) external view returns (uint256) {
        return _nodeCounts[tokenId];
    }

    /**
     * @dev Gets the tree depth for an agent
     * @param tokenId The ID of the agent token
     * @return The maximum level in the tree
     */
    function getTreeDepth(uint256 tokenId) external view returns (uint256) {
        bytes32[] memory hashes = _nodeHashes[tokenId];
        uint256 maxLevel = 0;
        
        for (uint256 i = 0; i < hashes.length; i++) {
            uint256 level = _treeNodes[tokenId][hashes[i]].level;
            if (level > maxLevel) {
                maxLevel = level;
            }
        }
        
        return maxLevel;
    }

    /**
     * @dev Verifies if a root exists in the update history
     * @param tokenId The ID of the agent token
     * @param root The root to verify
     * @return Whether the root exists in history
     */
    function verifyRootInHistory(uint256 tokenId, bytes32 root) external view returns (bool) {
        LearningUpdate[] memory updates = _learningUpdates[tokenId];
        for (uint256 i = 0; i < updates.length; i++) {
            if (updates[i].previousRoot == root || updates[i].newRoot == root) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Verifies if a node exists in the tree for an agent
     * @param tokenId The ID of the agent token
     * @param nodeHash The hash of the node to verify
     * @return Whether the node exists
     */
    function verifyNodeExists(uint256 tokenId, bytes32 nodeHash) external view returns (bool) {
        return _treeNodes[tokenId][nodeHash].hash != bytes32(0);
    }

    /**
     * @dev Gets the path from a leaf node to the root
     * @param tokenId The ID of the agent token
     * @param leafHash The hash of the leaf node
     * @return Array of node hashes representing the path
     */
    function getPathToRoot(uint256 tokenId, bytes32 leafHash) external view returns (bytes32[] memory) {
        require(_treeNodes[tokenId][leafHash].hash != bytes32(0), "MerkleTreeLearning: leaf node not found");
        require(_treeNodes[tokenId][leafHash].isLeaf, "MerkleTreeLearning: node is not a leaf");
        
        bytes32 currentHash = leafHash;
        bytes32[] memory path = new bytes32[](256); // Maximum possible path length
        uint256 pathLength = 0;
        
        while (currentHash != _learningRoots[tokenId] && pathLength < 256) {
            path[pathLength] = currentHash;
            pathLength++;
            
            // Find parent node
            bool found = false;
            bytes32[] memory hashes = _nodeHashes[tokenId];
            
            for (uint256 i = 0; i < hashes.length; i++) {
                TreeNode memory node = _treeNodes[tokenId][hashes[i]];
                if (node.leftChild == currentHash || node.rightChild == currentHash) {
                    currentHash = node.hash;
                    found = true;
                    break;
                }
            }
            
            if (!found) {
                break; // Cannot find parent, tree structure is incomplete
            }
        }
        
        // Add root to path
        if (currentHash == _learningRoots[tokenId]) {
            path[pathLength] = currentHash;
            pathLength++;
        }
        
        // Create properly sized array
        bytes32[] memory result = new bytes32[](pathLength);
        for (uint256 i = 0; i < pathLength; i++) {
            result[i] = path[i];
        }
        
        return result;
    }

    /**
     * @dev Internal function to update learning metrics
     * @param tokenId The ID of the agent token
     */
    function _updateLearningMetrics(uint256 tokenId) internal {
        LearningMetrics storage metrics = _learningMetrics[tokenId];
        
        uint256 timeSinceLastUpdate = block.timestamp - metrics.lastUpdateTimestamp;
        
        // Update metrics
        metrics.totalInteractions++;
        metrics.learningEvents++;
        metrics.lastUpdateTimestamp = block.timestamp;
        
        // Calculate learning velocity (updates per day)
        if (timeSinceLastUpdate > 0) {
            metrics.learningVelocity = (1 * 1 days) / timeSinceLastUpdate;
        }
    }

    /**
     * @dev Internal function to calculate confidence score
     * @param tokenId The ID of the agent token
     * @return The confidence score
     */
    function _calculateConfidenceScore(uint256 tokenId) internal view returns (uint256) {
        uint256 updateCount = _updateCounts[tokenId];
        
        // Base confidence on update frequency - minimum 100 points per update
        uint256 frequencyScore = updateCount * 100;
        
        // For the first update, ensure we have a minimum score
        if (updateCount == 0) {
            return 0;
        }
        
        // Add time-based score if we have update history
        uint256 timeScore = 0;
        if (_lastUpdateTimestamps[tokenId] > 0) {
            uint256 timeSinceLastUpdate = block.timestamp - _lastUpdateTimestamps[tokenId];
            // Add 1 point per hour since last update (minimum 1 point)
            timeScore = (timeSinceLastUpdate / 1 hours) + 1;
        }
        
        return frequencyScore + timeScore;
    }

    /**
     * @dev Internal function to check for learning milestones
     * @param tokenId The ID of the agent token
     */
    function _checkLearningMilestones(uint256 tokenId) internal {
        uint256 updateCount = _updateCounts[tokenId];
        
        // Check for milestone updates
        if (updateCount == 10) {
            emit LearningMilestone(tokenId, "First Decade", 10, block.timestamp);
        } else if (updateCount == 100) {
            emit LearningMilestone(tokenId, "Century Mark", 100, block.timestamp);
        } else if (updateCount == 1000) {
            emit LearningMilestone(tokenId, "Millennium", 1000, block.timestamp);
        }
        
        // Check for time-based milestones
        uint256 timeSinceLastUpdate = block.timestamp - _lastUpdateTimestamps[tokenId];
        if (timeSinceLastUpdate >= 30 days) {
            emit LearningMilestone(tokenId, "Monthly Update", timeSinceLastUpdate, block.timestamp);
        }
    }

    /**
     * @dev Emergency function to reset learning root (only owner)
     * @param tokenId The ID of the agent token
     * @param newRoot The new root to set
     */
    function emergencyResetRoot(uint256 tokenId, bytes32 newRoot) external onlyOwner {
        require(newRoot != bytes32(0), "MerkleTreeLearning: new root cannot be zero");
        
        bytes32 previousRoot = _learningRoots[tokenId];
        _learningRoots[tokenId] = newRoot;
        
        // Record emergency update
        LearningUpdate memory update = LearningUpdate({
            previousRoot: previousRoot,
            newRoot: newRoot,
            proof: "",
            timestamp: block.timestamp
        });
        
        _learningUpdates[tokenId].push(update);
        _updateCounts[tokenId]++;
        _lastUpdateTimestamps[tokenId] = block.timestamp;
        
        // Update confidence score after update count is incremented
        _learningMetrics[tokenId].confidenceScore = _calculateConfidenceScore(tokenId);
        
        emit LearningUpdated(tokenId, previousRoot, newRoot, block.timestamp);
    }
}
