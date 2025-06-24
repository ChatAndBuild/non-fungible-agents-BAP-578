// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/ILearningModule.sol";

/**
 * @title DAOAgent
 * @dev Enhanced template for DAO agents that can participate in governance with learning capabilities
 */
contract DAOAgent is Ownable {
    // The address of the BEP007 token that owns this logic
    address public agentToken;

    // The address of the DAO contract
    address public daoContract;

    // The voting strategy
    enum VotingStrategy {
        AlwaysFor,
        AlwaysAgainst,
        Threshold,
        Delegate,
        Learning
    }

    // The agent's voting strategy
    VotingStrategy public votingStrategy;

    // The threshold for the Threshold strategy (in basis points)
    uint256 public voteThreshold;

    // The delegate address for the Delegate strategy
    address public delegateAddress;

    // Learning module integration
    address public learningModule;
    bool public learningEnabled;
    uint256 public learningVersion;

    // Learning-based voting parameters
    uint256 public confidenceThreshold; // Minimum confidence to vote (scaled by 1e18)
    uint256 public learningWeight; // Weight given to learning recommendations (0-100)

    // The voting history
    struct VoteRecord {
        uint256 proposalId;
        bool support;
        uint256 timestamp;
        uint256 confidence; // Confidence level when vote was cast
        bool wasLearningBased; // Whether this vote used learning
    }

    // Enhanced proposal analysis
    struct ProposalAnalysis {
        uint256 proposalId;
        bytes32 proposalHash;
        uint256 riskScore; // Risk assessment (0-100)
        uint256 alignmentScore; // Alignment with past successful votes (0-100)
        uint256 confidenceScore; // Overall confidence in decision (scaled by 1e18)
        bool recommendedVote;
        uint256 analysisTimestamp;
    }

    // The voting history
    mapping(uint256 => VoteRecord) public voteHistory;
    uint256 public voteCount;

    // Proposal analysis history
    mapping(uint256 => ProposalAnalysis) public proposalAnalyses;

    // Learning metrics for DAO participation
    struct DAOLearningMetrics {
        uint256 totalProposalsAnalyzed;
        uint256 successfulPredictions;
        uint256 averageConfidence;
        uint256 lastLearningUpdate;
        uint256 votingAccuracy; // Percentage of votes that aligned with final outcomes
    }

    DAOLearningMetrics public learningMetrics;

    // Event emitted when the agent votes
    event Voted(uint256 indexed proposalId, bool support, uint256 confidence, bool learningBased);

    // Event emitted when the voting strategy is updated
    event VotingStrategyUpdated(VotingStrategy strategy);

    // Event emitted when learning is enabled/disabled
    event LearningToggled(bool enabled, address learningModule);

    // Event emitted when a proposal is analyzed
    event ProposalAnalyzed(
        uint256 indexed proposalId,
        uint256 riskScore,
        uint256 alignmentScore,
        bool recommendation
    );

    // Event emitted when learning metrics are updated
    event LearningMetricsUpdated(
        uint256 totalAnalyzed,
        uint256 successfulPredictions,
        uint256 accuracy
    );

    /**
     * @dev Initializes the contract
     * @param _agentToken The address of the BEP007 token
     * @param _daoContract The address of the DAO contract
     */
    constructor(address _agentToken, address _daoContract) {
        require(_agentToken != address(0), "DAOAgent: agent token is zero address");
        require(_daoContract != address(0), "DAOAgent: DAO contract is zero address");

        agentToken = _agentToken;
        daoContract = _daoContract;

        // Set default strategy
        votingStrategy = VotingStrategy.AlwaysFor;

        // Initialize learning parameters
        confidenceThreshold = 70e16; // 0.7 (70% confidence minimum)
        learningWeight = 50; // 50% weight to learning recommendations

        // Initialize learning metrics
        learningMetrics = DAOLearningMetrics({
            totalProposalsAnalyzed: 0,
            successfulPredictions: 0,
            averageConfidence: 0,
            lastLearningUpdate: block.timestamp,
            votingAccuracy: 0
        });
    }

    /**
     * @dev Modifier to check if the caller is the agent token
     */
    modifier onlyAgentToken() {
        require(msg.sender == agentToken, "DAOAgent: caller is not agent token");
        _;
    }

    /**
     * @dev Enables learning for the DAO agent
     * @param _learningModule The address of the learning module
     * @param _confidenceThreshold The minimum confidence threshold for voting
     * @param _learningWeight The weight given to learning recommendations (0-100)
     */
    function enableLearning(
        address _learningModule,
        uint256 _confidenceThreshold,
        uint256 _learningWeight
    ) external onlyOwner {
        require(_learningModule != address(0), "DAOAgent: learning module is zero address");
        require(_confidenceThreshold <= 1e18, "DAOAgent: confidence threshold too high");
        require(_learningWeight <= 100, "DAOAgent: learning weight too high");

        learningModule = _learningModule;
        learningEnabled = true;
        learningVersion++;
        confidenceThreshold = _confidenceThreshold;
        learningWeight = _learningWeight;

        emit LearningToggled(true, _learningModule);
    }

    /**
     * @dev Disables learning for the DAO agent
     */
    function disableLearning() external onlyOwner {
        learningEnabled = false;

        emit LearningToggled(false, address(0));
    }

    /**
     * @dev Sets the voting strategy to Learning-based
     */
    function setLearningStrategy() external onlyOwner {
        require(learningEnabled, "DAOAgent: learning not enabled");

        votingStrategy = VotingStrategy.Learning;
        emit VotingStrategyUpdated(VotingStrategy.Learning);
    }

    /**
     * @dev Sets the voting strategy to AlwaysFor
     */
    function setAlwaysForStrategy() external onlyOwner {
        votingStrategy = VotingStrategy.AlwaysFor;
        emit VotingStrategyUpdated(VotingStrategy.AlwaysFor);
    }

    /**
     * @dev Sets the voting strategy to AlwaysAgainst
     */
    function setAlwaysAgainstStrategy() external onlyOwner {
        votingStrategy = VotingStrategy.AlwaysAgainst;
        emit VotingStrategyUpdated(VotingStrategy.AlwaysAgainst);
    }

    /**
     * @dev Sets the voting strategy to Threshold
     * @param _voteThreshold The threshold for voting (in basis points)
     */
    function setThresholdStrategy(uint256 _voteThreshold) external onlyOwner {
        require(_voteThreshold <= 10_000, "DAOAgent: threshold must be <= 10000");

        votingStrategy = VotingStrategy.Threshold;
        voteThreshold = _voteThreshold;

        emit VotingStrategyUpdated(VotingStrategy.Threshold);
    }

    /**
     * @dev Sets the voting strategy to Delegate
     * @param _delegateAddress The address to delegate votes to
     */
    function setDelegateStrategy(address _delegateAddress) external onlyOwner {
        require(_delegateAddress != address(0), "DAOAgent: delegate is zero address");

        votingStrategy = VotingStrategy.Delegate;
        delegateAddress = _delegateAddress;

        emit VotingStrategyUpdated(VotingStrategy.Delegate);
    }

    /**
     * @dev Analyzes a proposal using learning capabilities
     * @param proposalId The ID of the proposal
     * @param proposalData The data of the proposal
     * @return analysis The proposal analysis result
     */
    function analyzeProposal(
        uint256 proposalId,
        bytes calldata proposalData
    ) external onlyOwner returns (ProposalAnalysis memory analysis) {
        require(learningEnabled, "DAOAgent: learning not enabled");

        // Generate proposal hash for tracking
        bytes32 proposalHash = keccak256(proposalData);

        // Perform analysis (simplified implementation)
        uint256 riskScore = _calculateRiskScore(proposalData);
        uint256 alignmentScore = _calculateAlignmentScore(proposalData);
        uint256 confidenceScore = _calculateConfidenceScore(riskScore, alignmentScore);
        bool recommendedVote = _generateRecommendation(riskScore, alignmentScore, confidenceScore);

        // Store analysis
        analysis = ProposalAnalysis({
            proposalId: proposalId,
            proposalHash: proposalHash,
            riskScore: riskScore,
            alignmentScore: alignmentScore,
            confidenceScore: confidenceScore,
            recommendedVote: recommendedVote,
            analysisTimestamp: block.timestamp
        });

        proposalAnalyses[proposalId] = analysis;

        // Update learning metrics
        learningMetrics.totalProposalsAnalyzed++;

        // Record interaction with learning module
        if (learningModule != address(0)) {
            try
                ILearningModule(learningModule).recordInteraction(
                    uint256(uint160(agentToken)), // Use agent token address as ID
                    "proposal_analysis",
                    true
                )
            {} catch {
                // Silently fail to not break functionality
            }
        }

        emit ProposalAnalyzed(proposalId, riskScore, alignmentScore, recommendedVote);

        return analysis;
    }

    /**
     * @dev Votes on a proposal with enhanced learning capabilities
     * @param proposalId The ID of the proposal
     * @param proposalData The data of the proposal
     */
    function vote(uint256 proposalId, bytes calldata proposalData) external onlyAgentToken {
        bool support;
        uint256 confidence = 0;
        bool wasLearningBased = false;

        if (votingStrategy == VotingStrategy.AlwaysFor) {
            support = true;
            confidence = 1e18; // 100% confidence
        } else if (votingStrategy == VotingStrategy.AlwaysAgainst) {
            support = false;
            confidence = 1e18; // 100% confidence
        } else if (votingStrategy == VotingStrategy.Threshold) {
            uint256 randomValue = uint256(
                keccak256(abi.encodePacked(block.timestamp, proposalId))
            ) % 10_000;
            support = randomValue <= voteThreshold;
            confidence = support ? (voteThreshold * 1e14) : ((10_000 - voteThreshold) * 1e14);
        } else if (votingStrategy == VotingStrategy.Delegate) {
            uint256 randomValue = uint256(
                keccak256(abi.encodePacked(block.timestamp, delegateAddress, proposalId))
            ) % 2;
            support = randomValue == 1;
            confidence = 5e17; // 50% confidence for delegate votes
        } else if (votingStrategy == VotingStrategy.Learning && learningEnabled) {
            // Use learning-based decision making
            ProposalAnalysis memory analysis = proposalAnalyses[proposalId];

            if (analysis.proposalId == proposalId) {
                // Use existing analysis
                support = analysis.recommendedVote;
                confidence = analysis.confidenceScore;
                wasLearningBased = true;
            } else {
                // Perform quick analysis
                analysis = this.analyzeProposal(proposalId, proposalData);
                support = analysis.recommendedVote;
                confidence = analysis.confidenceScore;
                wasLearningBased = true;
            }

            // Only vote if confidence meets threshold
            require(confidence >= confidenceThreshold, "DAOAgent: confidence below threshold");
        }

        // Record the vote
        voteCount += 1;
        voteHistory[voteCount] = VoteRecord({
            proposalId: proposalId,
            support: support,
            timestamp: block.timestamp,
            confidence: confidence,
            wasLearningBased: wasLearningBased
        });

        // Update learning metrics if learning was used
        if (wasLearningBased && learningModule != address(0)) {
            try
                ILearningModule(learningModule).recordInteraction(
                    uint256(uint160(agentToken)),
                    "dao_vote",
                    true
                )
            {} catch {
                // Silently fail
            }
        }

        emit Voted(proposalId, support, confidence, wasLearningBased);
    }

    /**
     * @dev Updates voting accuracy based on proposal outcomes
     * @param proposalId The ID of the proposal
     * @param actualOutcome The actual outcome of the proposal
     */
    function updateVotingAccuracy(uint256 proposalId, bool actualOutcome) external onlyOwner {
        // Find the vote record
        for (uint256 i = 1; i <= voteCount; i++) {
            if (voteHistory[i].proposalId == proposalId) {
                bool wasCorrect = (voteHistory[i].support == actualOutcome);

                if (wasCorrect) {
                    learningMetrics.successfulPredictions++;
                }

                // Recalculate accuracy
                learningMetrics.votingAccuracy =
                    (learningMetrics.successfulPredictions * 100) /
                    voteCount;

                emit LearningMetricsUpdated(
                    learningMetrics.totalProposalsAnalyzed,
                    learningMetrics.successfulPredictions,
                    learningMetrics.votingAccuracy
                );

                break;
            }
        }
    }

    /**
     * @dev Gets the voting history with learning data
     * @param count The number of votes to return
     * @return An array of vote records
     */
    function getVotingHistory(uint256 count) external view returns (VoteRecord[] memory) {
        uint256 resultCount = count > voteCount ? voteCount : count;
        VoteRecord[] memory history = new VoteRecord[](resultCount);

        for (uint256 i = 0; i < resultCount; i++) {
            history[i] = voteHistory[voteCount - i];
        }

        return history;
    }

    /**
     * @dev Gets the learning metrics for the DAO agent
     * @return The current learning metrics
     */
    function getLearningMetrics() external view returns (DAOLearningMetrics memory) {
        return learningMetrics;
    }

    /**
     * @dev Gets the proposal analysis for a specific proposal
     * @param proposalId The ID of the proposal
     * @return The proposal analysis
     */
    function getProposalAnalysis(
        uint256 proposalId
    ) external view returns (ProposalAnalysis memory) {
        return proposalAnalyses[proposalId];
    }

    /**
     * @dev Delegates voting power to another address
     * @param delegatee The address to delegate to
     */
    function delegate(address delegatee) external onlyOwner {
        require(delegatee != address(0), "DAOAgent: delegatee is zero address");

        delegateAddress = delegatee;
    }

    /**
     * @dev Updates learning parameters
     * @param _confidenceThreshold The new confidence threshold
     * @param _learningWeight The new learning weight
     */
    function updateLearningParameters(
        uint256 _confidenceThreshold,
        uint256 _learningWeight
    ) external onlyOwner {
        require(_confidenceThreshold <= 1e18, "DAOAgent: confidence threshold too high");
        require(_learningWeight <= 100, "DAOAgent: learning weight too high");

        confidenceThreshold = _confidenceThreshold;
        learningWeight = _learningWeight;
    }

    // Internal helper functions for proposal analysis

    /**
     * @dev Calculates risk score for a proposal (simplified implementation)
     * @param proposalData The proposal data
     * @return The risk score (0-100)
     */
    function _calculateRiskScore(bytes calldata proposalData) internal pure returns (uint256) {
        // Simplified risk calculation based on data length and content
        uint256 dataLength = proposalData.length;
        uint256 complexity = dataLength > 1000 ? 80 : (dataLength * 80) / 1000;

        return complexity > 100 ? 100 : complexity;
    }

    /**
     * @dev Calculates alignment score with past successful votes (simplified implementation)
     * @param proposalData The proposal data
     * @return The alignment score (0-100)
     */
    function _calculateAlignmentScore(bytes calldata proposalData) internal view returns (uint256) {
        // Simplified alignment calculation
        if (learningMetrics.votingAccuracy > 0) {
            return learningMetrics.votingAccuracy;
        }

        return 50; // Default neutral alignment
    }

    /**
     * @dev Calculates overall confidence score
     * @param riskScore The risk score
     * @param alignmentScore The alignment score
     * @return The confidence score (scaled by 1e18)
     */
    function _calculateConfidenceScore(
        uint256 riskScore,
        uint256 alignmentScore
    ) internal pure returns (uint256) {
        // Higher alignment and lower risk = higher confidence
        uint256 baseConfidence = (alignmentScore * 2 + (100 - riskScore)) / 3;
        return (baseConfidence * 1e18) / 100;
    }

    /**
     * @dev Generates voting recommendation based on analysis
     * @param riskScore The risk score
     * @param alignmentScore The alignment score
     * @param confidenceScore The confidence score
     * @return The recommended vote
     */
    function _generateRecommendation(
        uint256 riskScore,
        uint256 alignmentScore,
        uint256 confidenceScore
    ) internal pure returns (bool) {
        // Vote in favor if low risk and high alignment
        return (riskScore < 50 && alignmentScore > 60) || confidenceScore > 8e17; // 80% confidence
    }
}
