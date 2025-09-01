// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "./BEP007.sol";

/**
 * @title BEP007Governance
 * @dev Governance contract for the BEP-007 ecosystem
 * Handles proposals, voting, and protocol parameter updates
 */
contract BEP007Governance is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    // BEP007 token contract
    BEP007 public bep007Token;

    // Agent factory contract
    address public agentFactory;

    // Treasury contract
    address public treasury;

    // Proposal counter
    CountersUpgradeable.Counter private _proposalIdCounter;

    // Voting parameters
    uint256 public votingPeriod; // in days
    uint256 public quorumPercentage; // percentage of total supply needed
    uint256 public executionDelay; // in days

    // Proposal struct
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        bytes callData;
        address targetContract;
        uint256 createdAt;
        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
        bool canceled;
        mapping(address => bool) hasVoted;
    }

    // Mapping from proposal ID to Proposal
    mapping(uint256 => Proposal) public proposals;

    // Events
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);
    event TreasuryUpdated(address indexed newTreasury);
    event AgentFactoryUpdated(address indexed newAgentFactory);
    event TreasuryAddressUpdated(address indexed newTreasury);
    event VotingParametersUpdated(
        uint256 votingPeriod,
        uint256 quorumPercentage,
        uint256 executionDelay
    );

    /**
     * @dev Initializes the contract
     * @param _bep007Token The address of the BEP007 token contract
     * @param _owner The address of the initial owner
     * @param _votingPeriod The voting period in days
     * @param _quorumPercentage The quorum percentage
     * @param _executionDelay The execution delay in days
     */
    function initialize(
        address payable _bep007Token,
        address _owner,
        uint256 _votingPeriod,
        uint256 _quorumPercentage,
        uint256 _executionDelay
    ) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();

        require(_bep007Token != address(0), "BEP007Governance: token is zero address");
        require(_owner != address(0), "BEP007Governance: owner is zero address");
        require(_quorumPercentage <= 100, "BEP007Governance: quorum percentage exceeds 100");

        transferOwnership(_owner);
        bep007Token = BEP007(_bep007Token);
        votingPeriod = _votingPeriod;
        quorumPercentage = _quorumPercentage;
        executionDelay = _executionDelay;
    }

    /**
     * @dev Creates a new proposal
     * @param description The description of the proposal
     * @param callData The call data to execute if the proposal passes
     * @param targetContract The contract to call
     * @return proposalId The ID of the created proposal
     */
    function createProposal(
        string memory description,
        bytes memory callData,
        address targetContract
    ) external returns (uint256) {
        require(targetContract != address(0), "BEP007Governance: target is zero address");

        _proposalIdCounter.increment();
        uint256 proposalId = _proposalIdCounter.current();

        Proposal storage proposal = proposals[proposalId];
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.description = description;
        proposal.callData = callData;
        proposal.targetContract = targetContract;
        proposal.createdAt = block.timestamp;
        proposal.executed = false;
        proposal.canceled = false;

        emit ProposalCreated(proposalId, msg.sender, description);

        return proposalId;
    }

    /**
     * @dev Casts a vote on a proposal
     * @param proposalId The ID of the proposal
     * @param support Whether to support the proposal
     */
    function castVote(uint256 proposalId, bool support) external {
        Proposal storage proposal = proposals[proposalId];

        require(proposal.id != 0, "BEP007Governance: proposal does not exist");
        require(!proposal.executed, "BEP007Governance: proposal already executed");
        require(!proposal.canceled, "BEP007Governance: proposal canceled");
        require(
            block.timestamp <= proposal.createdAt + votingPeriod * 1 days,
            "BEP007Governance: voting period ended"
        );
        require(!proposal.hasVoted[msg.sender], "BEP007Governance: already voted");

        // Get voter's voting weight (1 token = 1 vote)
        uint256 weight = bep007Token.balanceOf(msg.sender);
        require(weight > 0, "BEP007Governance: no voting weight");

        proposal.hasVoted[msg.sender] = true;

        if (support) {
            proposal.votesFor += weight;
        } else {
            proposal.votesAgainst += weight;
        }

        emit VoteCast(proposalId, msg.sender, support, weight);
    }

    /**
     * @dev Executes a proposal that has passed
     * @param proposalId The ID of the proposal
     */
    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];

        require(proposal.id != 0, "BEP007Governance: proposal does not exist");
        require(!proposal.executed, "BEP007Governance: proposal already executed");
        require(!proposal.canceled, "BEP007Governance: proposal canceled");

        // Check if voting period has ended
        require(
            block.timestamp > proposal.createdAt + votingPeriod * 1 days,
            "BEP007Governance: voting period not ended"
        );

        // Check if execution delay has passed
        require(
            block.timestamp >= proposal.createdAt + (votingPeriod + executionDelay) * 1 days,
            "BEP007Governance: execution delay not passed"
        );

        // Check if proposal passed (more votes for than against and meets quorum)
        uint256 totalSupply = bep007Token.totalSupply();
        uint256 quorumVotes = (totalSupply * quorumPercentage) / 100;

        require(proposal.votesFor > proposal.votesAgainst, "BEP007Governance: proposal rejected");
        require(proposal.votesFor >= quorumVotes, "BEP007Governance: quorum not reached");

        proposal.executed = true;

        // Execute the proposal
        (bool success, ) = proposal.targetContract.call(proposal.callData);
        require(success, "BEP007Governance: execution failed");

        emit ProposalExecuted(proposalId);
    }

    /**
     * @dev Cancels a proposal (only proposer or owner)
     * @param proposalId The ID of the proposal
     */
    function cancelProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];

        require(proposal.id != 0, "BEP007Governance: proposal does not exist");
        require(!proposal.executed, "BEP007Governance: proposal already executed");
        require(!proposal.canceled, "BEP007Governance: proposal already canceled");
        require(
            msg.sender == proposal.proposer || msg.sender == owner(),
            "BEP007Governance: not proposer or owner"
        );

        proposal.canceled = true;

        emit ProposalCanceled(proposalId);
    }
    /**
     * @dev Sets the agent factory address
     * @param _agentFactory The new agent factory address
     */
    function setAgentFactory(address _agentFactory) external onlyOwner {
        require(_agentFactory != address(0), "BEP007Governance: factory is zero address");
        agentFactory = _agentFactory;
        emit AgentFactoryUpdated(_agentFactory);
    }

    /**
     * @dev Sets the treasury address
     * @param _treasury The new treasury address
     */
    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "BEP007Governance: treasury is zero address");
        treasury = _treasury;
        emit TreasuryAddressUpdated(_treasury);
    }

    /**
     * @dev Updates the voting parameters
     * @param _votingPeriod The new voting period in days
     * @param _quorumPercentage The new quorum percentage
     * @param _executionDelay The new execution delay in days
     */
    function updateVotingParameters(
        uint256 _votingPeriod,
        uint256 _quorumPercentage,
        uint256 _executionDelay
    ) external onlyOwner {
        require(_quorumPercentage <= 100, "BEP007Governance: quorum percentage exceeds 100");

        votingPeriod = _votingPeriod;
        quorumPercentage = _quorumPercentage;
        executionDelay = _executionDelay;

        emit VotingParametersUpdated(_votingPeriod, _quorumPercentage, _executionDelay);
    }

    /**
     * @dev Upgrades the contract to a new implementation and calls a function on the new implementation.
     * This function is part of the UUPS (Universal Upgradeable Proxy Standard) pattern.
     * @param newImplementation The address of the new implementation contract
     * @param data The calldata to execute on the new implementation after upgrade
     * @notice Only the contract owner can perform upgrades for security
     * @notice This function is payable to support implementations that require ETH
     */
    function upgradeToAndCall(
        address newImplementation,
        bytes memory data
    ) public payable override onlyOwner {}

    /**
     * @dev Upgrades the contract to a new implementation.
     * This function is part of the UUPS (Universal Upgradeable Proxy Standard) pattern.
     * @param newImplementation The address of the new implementation contract
     * @notice Only the contract owner can perform upgrades for security
     * @notice Use upgradeToAndCall if you need to call initialization functions on the new implementation
     */
    function upgradeTo(address newImplementation) public override onlyOwner {}

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract.
     * Called by {upgradeTo} and {upgradeToAndCall}.
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
