// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import "../interfaces/ILearningModule.sol";
import "../BEP007.sol";

/**
 * @title MerkleTreeLearning
 * @dev Implementation of Merkle tree-based learning for BEP007 agents
 */
contract MerkleTreeLearning is
    ILearningModule,
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using MerkleProofUpgradeable for bytes32[];

    // BEP007 token contract
    BEP007 public bep007Token;

    // Mapping from token ID to learning tree root
    mapping(uint256 => bytes32) private _learningRoots;

    // Mapping from token ID to learning metrics
    mapping(uint256 => LearningMetrics) private _learningMetrics;

    // Mapping from token ID to learning enabled status
    mapping(uint256 => bool) private _learningEnabled;

    // Mapping from token ID to authorized updaters
    mapping(uint256 => mapping(address => bool)) private _authorizedUpdaters;

    // Learning milestones thresholds
    uint256 public constant MILESTONE_INTERACTIONS_100 = 100;
    uint256 public constant MILESTONE_INTERACTIONS_1000 = 1000;
    uint256 public constant MILESTONE_CONFIDENCE_80 = 80e16; // 0.8 scaled by 1e18
    uint256 public constant MILESTONE_CONFIDENCE_95 = 95e16; // 0.95 scaled by 1e18

    // Maximum learning updates per day to prevent spam
    uint256 public constant MAX_UPDATES_PER_DAY = 50;
    mapping(uint256 => mapping(uint256 => uint256)) private _dailyUpdateCounts;

    /**
     * @dev Modifier to check if the caller is authorized to update learning
     */
    modifier onlyAuthorized(uint256 tokenId) {
        address owner = bep007Token.ownerOf(tokenId);
        require(
            msg.sender == owner || _authorizedUpdaters[tokenId][msg.sender],
            "MerkleTreeLearning: not authorized"
        );
        _;
    }

    /**
     * @dev Modifier to check if learning is enabled for the agent
     */
    modifier whenLearningEnabled(uint256 tokenId) {
        require(_learningEnabled[tokenId], "MerkleTreeLearning: learning not enabled");
        _;
    }

    /**
     * @dev Initializes the contract
     * @param _bep007Token The address of the BEP007 token contract
     */
    function initialize(address payable _bep007Token) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();

        require(_bep007Token != address(0), "MerkleTreeLearning: token is zero address");
        bep007Token = BEP007(_bep007Token);
    }

    /**
     * @dev Enables learning for an agent
     * @param tokenId The ID of the agent token
     * @param initialRoot The initial learning tree root
     */
    function enableLearning(uint256 tokenId, bytes32 initialRoot) external {
        address owner = bep007Token.ownerOf(tokenId);
        require(msg.sender == owner, "MerkleTreeLearning: not token owner");
        require(!_learningEnabled[tokenId], "MerkleTreeLearning: already enabled");

        _learningEnabled[tokenId] = true;
        _learningRoots[tokenId] = initialRoot;

        // Initialize learning metrics
        _learningMetrics[tokenId] = LearningMetrics({
            totalInteractions: 0,
            learningEvents: 0,
            lastUpdateTimestamp: block.timestamp,
            learningVelocity: 0,
            confidenceScore: 0
        });

        emit LearningUpdated(tokenId, bytes32(0), initialRoot, block.timestamp);
    }

    /**
     * @dev Updates the learning state for an agent
     * @param tokenId The ID of the agent token
     * @param update The learning update data
     */
    function updateLearning(
        uint256 tokenId,
        LearningUpdate calldata update
    ) external nonReentrant onlyAuthorized(tokenId) whenLearningEnabled(tokenId) {
        // Check daily update limit
        uint256 today = block.timestamp / 86400; // Days since epoch
        require(
            _dailyUpdateCounts[tokenId][today] < MAX_UPDATES_PER_DAY,
            "MerkleTreeLearning: daily update limit exceeded"
        );

        // Verify the previous root matches
        require(
            _learningRoots[tokenId] == update.previousRoot,
            "MerkleTreeLearning: invalid previous root"
        );

        // Update the learning root
        _learningRoots[tokenId] = update.newRoot;

        // Update metrics
        LearningMetrics storage metrics = _learningMetrics[tokenId];
        metrics.learningEvents++;

        // Calculate learning velocity (events per day)
        uint256 timeDiff = block.timestamp - metrics.lastUpdateTimestamp;
        if (timeDiff > 0) {
            metrics.learningVelocity =
                (metrics.learningEvents * 86400 * 1e18) /
                (block.timestamp - metrics.lastUpdateTimestamp + timeDiff);
        }

        metrics.lastUpdateTimestamp = block.timestamp;

        // Increment daily update count
        _dailyUpdateCounts[tokenId][today]++;

        // Check for milestones
        _checkMilestones(tokenId, metrics);

        emit LearningUpdated(tokenId, update.previousRoot, update.newRoot, block.timestamp);
    }

    /**
     * @dev Records an interaction for learning metrics
     * @param tokenId The ID of the agent token
     * @param interactionType The type of interaction
     * @param success Whether the interaction was successful
     */
    function recordInteraction(
        uint256 tokenId,
        string calldata interactionType,
        bool success
    ) external onlyAuthorized(tokenId) whenLearningEnabled(tokenId) {
        LearningMetrics storage metrics = _learningMetrics[tokenId];
        metrics.totalInteractions++;

        // Update confidence score based on success rate
        if (success) {
            // Increase confidence slightly for successful interactions
            metrics.confidenceScore = _updateConfidence(metrics.confidenceScore, true);
        } else {
            // Decrease confidence slightly for failed interactions
            metrics.confidenceScore = _updateConfidence(metrics.confidenceScore, false);
        }

        // Check for interaction milestones
        if (metrics.totalInteractions == MILESTONE_INTERACTIONS_100) {
            emit LearningMilestone(tokenId, "interactions_100", 100, block.timestamp);
        } else if (metrics.totalInteractions == MILESTONE_INTERACTIONS_1000) {
            emit LearningMilestone(tokenId, "interactions_1000", 1000, block.timestamp);
        }
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
     * @dev Checks if an agent has learning enabled
     * @param tokenId The ID of the agent token
     * @return Whether learning is enabled
     */
    function isLearningEnabled(uint256 tokenId) external view override returns (bool) {
        return _learningEnabled[tokenId];
    }

    /**
     * @dev Gets the learning module version
     * @return The version string
     */
    function getVersion() external pure override returns (string memory) {
        return "1.0.0";
    }

    /**
     * @dev Authorizes an address to update learning for an agent
     * @param tokenId The ID of the agent token
     * @param updater The address to authorize
     * @param authorized Whether to authorize or revoke
     */
    function setAuthorizedUpdater(uint256 tokenId, address updater, bool authorized) external {
        address owner = bep007Token.ownerOf(tokenId);
        require(msg.sender == owner, "MerkleTreeLearning: not token owner");

        _authorizedUpdaters[tokenId][updater] = authorized;
    }

    /**
     * @dev Checks if an address is authorized to update learning
     * @param tokenId The ID of the agent token
     * @param updater The address to check
     * @return Whether the address is authorized
     */
    function isAuthorizedUpdater(uint256 tokenId, address updater) external view returns (bool) {
        return _authorizedUpdaters[tokenId][updater];
    }

    /**
     * @dev Internal function to update confidence score
     * @param currentScore The current confidence score
     * @param success Whether the interaction was successful
     * @return The updated confidence score
     */
    function _updateConfidence(uint256 currentScore, bool success) internal pure returns (uint256) {
        if (success) {
            // Increase confidence by 1% of remaining confidence gap
            uint256 gap = 1e18 - currentScore;
            return currentScore + (gap / 100);
        } else {
            // Decrease confidence by 2%
            uint256 decrease = currentScore / 50; // 2%
            return currentScore > decrease ? currentScore - decrease : 0;
        }
    }

    /**
     * @dev Internal function to check for learning milestones
     * @param tokenId The ID of the agent token
     * @param metrics The current learning metrics
     */
    function _checkMilestones(uint256 tokenId, LearningMetrics memory metrics) internal {
        // Check confidence milestones
        if (
            metrics.confidenceScore >= MILESTONE_CONFIDENCE_80 &&
            metrics.confidenceScore < MILESTONE_CONFIDENCE_80 + 1e16
        ) {
            emit LearningMilestone(tokenId, "confidence_80", 80, block.timestamp);
        } else if (
            metrics.confidenceScore >= MILESTONE_CONFIDENCE_95 &&
            metrics.confidenceScore < MILESTONE_CONFIDENCE_95 + 1e16
        ) {
            emit LearningMilestone(tokenId, "confidence_95", 95, block.timestamp);
        }
    }

    /**
     * @dev Disables learning for an agent (emergency function)
     * @param tokenId The ID of the agent token
     */
    function disableLearning(uint256 tokenId) external {
        address owner = bep007Token.ownerOf(tokenId);
        require(msg.sender == owner, "MerkleTreeLearning: not token owner");

        _learningEnabled[tokenId] = false;
    }
}
