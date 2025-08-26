// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/ILearningModule.sol";

/**
 * @title FinanceLearningAgent
 * @dev Simplified finance learning agent for market analysis and insights
 */
contract FinanceLearningAgent is Ownable, ReentrancyGuard {
    // The address of the BEP007 token that owns this logic
    address public agentToken;

    // Learning module integration
    address public learningModule;
    bool public learningEnabled;

    // Finance agent profile
    struct FinanceProfile {
        string name;
        string specialization;
        uint256 analysisDepth; // 0-100 scale
        uint256 learningRate; // 0-100 scale
        uint256 confidenceThreshold; // 0-100
    }

    // Analysis result structure
    struct AnalysisResult {
        bytes32 analysisId;
        address asset;
        string analysisType;
        uint256 confidence;
        int256 recommendation; // -100 to +100
        string insights;
        uint256 timestamp;
        bool wasAccurate;
    }

    // Market data structure
    struct MarketData {
        address asset;
        uint256 price;
        uint256 volume;
        uint256 marketCap;
        uint256 timestamp;
    }

    // Agent's finance profile
    FinanceProfile public profile;

    // Learning metrics
    uint256 public totalAnalyses;
    uint256 public accuratePredictions;
    uint256 public predictionAccuracy;

    // Data storage
    mapping(address => MarketData) public marketData;
    mapping(bytes32 => AnalysisResult) public analysisResults;
    mapping(address => bool) public supportedAssets;
    address[] public supportedAssetList;

    // Events
    event AnalysisPerformed(
        bytes32 indexed analysisId,
        address indexed asset,
        string analysisType,
        uint256 confidence,
        int256 recommendation,
        uint256 timestamp
    );

    event LearningUpdate(
        string updateType,
        bytes32 dataHash,
        uint256 accuracy,
        uint256 timestamp
    );

    event MarketDataUpdated(
        address indexed asset,
        uint256 price,
        uint256 volume,
        uint256 marketCap,
        uint256 timestamp
    );

    event PredictionValidated(
        bytes32 indexed analysisId,
        bool wasAccurate,
        uint256 actualOutcome,
        uint256 timestamp
    );

    /**
     * @dev Initializes the finance learning agent contract
     */
    constructor(
        address _agentToken,
        string memory _name,
        string memory _specialization,
        uint256 _analysisDepth
    ) {
        require(_agentToken != address(0), "FinanceLearningAgent: agent token is zero address");
        require(_analysisDepth <= 100, "FinanceLearningAgent: analysis depth must be 0-100");

        agentToken = _agentToken;

        profile = FinanceProfile({
            name: _name,
            specialization: _specialization,
            analysisDepth: _analysisDepth,
            learningRate: 75,
            confidenceThreshold: 70
        });
    }

    /**
     * @dev Modifier to check if the caller is the agent token
     */
    modifier onlyAgentToken() {
        require(msg.sender == agentToken, "FinanceLearningAgent: caller is not agent token");
        _;
    }

    /**
     * @dev Modifier to check if learning is enabled
     */
    modifier whenLearningEnabled() {
        require(learningEnabled && learningModule != address(0), "FinanceLearningAgent: learning not enabled");
        _;
    }

    /**
     * @dev Enables learning for this agent
     */
    function enableLearning(address _learningModule) external onlyOwner {
        require(_learningModule != address(0), "FinanceLearningAgent: learning module is zero address");
        require(!learningEnabled, "FinanceLearningAgent: learning already enabled");

        learningModule = _learningModule;
        learningEnabled = true;
    }

    /**
     * @dev Updates the finance agent's profile
     */
    function updateProfile(
        string memory _name,
        string memory _specialization,
        uint256 _analysisDepth,
        uint256 _learningRate,
        uint256 _confidenceThreshold
    ) external onlyOwner {
        require(_analysisDepth <= 100, "FinanceLearningAgent: analysis depth must be 0-100");
        require(_learningRate <= 100, "FinanceLearningAgent: learning rate must be 0-100");
        require(_confidenceThreshold <= 100, "FinanceLearningAgent: confidence threshold must be 0-100");

        profile.name = _name;
        profile.specialization = _specialization;
        profile.analysisDepth = _analysisDepth;
        profile.learningRate = _learningRate;
        profile.confidenceThreshold = _confidenceThreshold;
    }

    /**
     * @dev Adds a supported asset for analysis
     */
    function addSupportedAsset(address _asset) external onlyOwner {
        require(_asset != address(0), "FinanceLearningAgent: asset address is zero");
        require(!supportedAssets[_asset], "FinanceLearningAgent: asset already supported");

        supportedAssets[_asset] = true;
        supportedAssetList.push(_asset);
    }

    /**
     * @dev Updates market data for an asset
     */
    function updateMarketData(
        address _asset,
        uint256 _price,
        uint256 _volume,
        uint256 _marketCap
    ) external onlyOwner {
        require(supportedAssets[_asset], "FinanceLearningAgent: asset not supported");

        marketData[_asset] = MarketData({
            asset: _asset,
            price: _price,
            volume: _volume,
            marketCap: _marketCap,
            timestamp: block.timestamp
        });

        emit MarketDataUpdated(_asset, _price, _volume, _marketCap, block.timestamp);
    }

    /**
     * @dev Performs analysis on an asset
     */
    function performAnalysis(
        address _asset,
        string memory _analysisType
    ) external onlyOwner returns (bytes32 analysisId) {
        require(supportedAssets[_asset], "FinanceLearningAgent: asset not supported");

        // Generate unique analysis ID
        analysisId = keccak256(abi.encodePacked(_asset, _analysisType, block.timestamp, block.difficulty));

        // Perform analysis (simplified)
        (uint256 confidence, int256 recommendation, string memory insights) = _performAnalysis(_asset, _analysisType);

        // Store analysis result
        analysisResults[analysisId] = AnalysisResult({
            analysisId: analysisId,
            asset: _asset,
            analysisType: _analysisType,
            confidence: confidence,
            recommendation: recommendation,
            insights: insights,
            timestamp: block.timestamp,
            wasAccurate: false
        });

        totalAnalyses++;

        // Record learning data if enabled
        if (learningEnabled) {
            _recordAnalysisForLearning(analysisId, _asset, _analysisType, confidence, recommendation);
        }

        emit AnalysisPerformed(analysisId, _asset, _analysisType, confidence, recommendation, block.timestamp);

        return analysisId;
    }

    /**
     * @dev Validates a prediction
     */
    function validatePrediction(
        bytes32 _analysisId,
        uint256 _actualOutcome,
        bool _wasAccurate
    ) external onlyOwner {
        require(analysisResults[_analysisId].analysisId != bytes32(0), "FinanceLearningAgent: analysis not found");

        AnalysisResult storage result = analysisResults[_analysisId];
        result.wasAccurate = _wasAccurate;

        if (_wasAccurate) {
            accuratePredictions++;
        }

        // Recalculate prediction accuracy
        if (totalAnalyses > 0) {
            predictionAccuracy = accuratePredictions * 100 / totalAnalyses;
        }

        // Record learning data if enabled
        if (learningEnabled) {
            _recordPredictionValidation(_analysisId, _wasAccurate, _actualOutcome);
        }

        emit PredictionValidated(_analysisId, _wasAccurate, _actualOutcome, block.timestamp);
    }

    /**
     * @dev Gets analysis result by ID
     */
    function getAnalysisResult(bytes32 _analysisId) external view returns (AnalysisResult memory result) {
        return analysisResults[_analysisId];
    }

    /**
     * @dev Gets market data for an asset
     */
    function getMarketData(address _asset) external view returns (MarketData memory data) {
        return marketData[_asset];
    }

    /**
     * @dev Gets supported assets list
     */
    function getSupportedAssets() external view returns (address[] memory assets) {
        return supportedAssetList;
    }

    // Internal functions

    /**
     * @dev Performs analysis (simplified implementation)
     */
    function _performAnalysis(
        address _asset,
        string memory _analysisType
    ) internal view returns (uint256 confidence, int256 recommendation, string memory insights) {
        MarketData memory data = marketData[_asset];
        
        if (data.price > 0 && data.volume > 0) {
            if (data.price > 1e18) {
                confidence = 75;
                recommendation = 25;
                insights = "Price above $1 with good volume support";
            } else {
                confidence = 60;
                recommendation = -15;
                insights = "Price below $1, monitoring for support levels";
            }
        } else {
            confidence = 30;
            recommendation = 0;
            insights = "Insufficient data for analysis";
        }

        return (confidence, recommendation, insights);
    }

    /**
     * @dev Records analysis data for learning
     */
    function _recordAnalysisForLearning(
        bytes32 _analysisId,
        address _asset,
        string memory _analysisType,
        uint256 _confidence,
        int256 _recommendation
    ) internal whenLearningEnabled {
        bytes32 dataHash = keccak256(
            abi.encodePacked(
                _analysisId,
                _asset,
                _analysisType,
                _confidence,
                _recommendation,
                block.timestamp
            )
        );

        emit LearningUpdate("analysis_performed", dataHash, _confidence, block.timestamp);
    }

    /**
     * @dev Records prediction validation for learning
     */
    function _recordPredictionValidation(
        bytes32 _analysisId,
        bool _wasAccurate,
        uint256 _actualOutcome
    ) internal whenLearningEnabled {
        bytes32 dataHash = keccak256(
            abi.encodePacked(
                _analysisId,
                _wasAccurate,
                _actualOutcome,
                block.timestamp
            )
        );

        emit LearningUpdate("prediction_validated", dataHash, _wasAccurate ? 100 : 0, block.timestamp);
    }

    /**
     * @dev Allows contract to receive BNB
     */
    receive() external payable {}
}
