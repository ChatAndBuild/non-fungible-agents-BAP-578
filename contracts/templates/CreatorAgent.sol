// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/ILearningModule.sol";

/**
 * @title CreatorAgent
 * @dev Enhanced template for creator agents with learning capabilities
 *      that serve as personalized brand assistants or digital twins
 */
contract CreatorAgent is Ownable, ReentrancyGuard {
    // The address of the BEP007 token that owns this logic
    address public agentToken;

    // Learning module integration
    address public learningModule;
    bool public learningEnabled;

    // The creator's profile
    struct CreatorProfile {
        string name;
        string bio;
        string niche;
        uint256 creativityLevel; // 0-100 scale
    }

    // The creator's profile
    CreatorProfile public profile;

    /**
     * @dev Initializes the contract
     * @param _agentToken The address of the BEP007 token
     * @param _name The creator's name
     * @param _bio The creator's bio
     * @param _niche The creator's niche
     */
    constructor(
        address _agentToken,
        string memory _name,
        string memory _bio,
        string memory _niche
    ) {
        require(_agentToken != address(0), "CreatorAgent: agent token is zero address");

        agentToken = _agentToken;

        profile = CreatorProfile({
            name: _name,
            bio: _bio,
            niche: _niche,
            creativityLevel: 50 // Default medium creativity
        });
    }

    /**
     * @dev Modifier to check if the caller is the agent token
     */
    modifier onlyAgentToken() {
        require(msg.sender == agentToken, "CreatorAgent: caller is not agent token");
        _;
    }

    /**
     * @dev Modifier to check if learning is enabled
     */
    modifier whenLearningEnabled() {
        require(
            learningEnabled && learningModule != address(0),
            "CreatorAgent: learning not enabled"
        );
        _;
    }

    /**
     * @dev Enables learning for this agent
     * @param _learningModule The address of the learning module
     */
    function enableLearning(address _learningModule) external onlyOwner {
        require(_learningModule != address(0), "CreatorAgent: learning module is zero address");
        require(!learningEnabled, "CreatorAgent: learning already enabled");

        learningModule = _learningModule;
        learningEnabled = true;
    }

    /**
     * @dev Updates the creator's profile with learning enhancements
     * @param _name The creator's name
     * @param _bio The creator's bio
     * @param _niche The creator's niche
     * @param _creativityLevel The creator's creativity level (0-100)
     */
    function updateProfile(
        string memory _name,
        string memory _bio,
        string memory _niche,
        uint256 _creativityLevel
    ) external onlyOwner {
        require(_creativityLevel <= 100, "CreatorAgent: creativity level must be 0-100");

        profile = CreatorProfile({
            name: _name,
            bio: _bio,
            niche: _niche,
            creativityLevel: _creativityLevel
        });
    }
}
