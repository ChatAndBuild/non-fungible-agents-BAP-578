// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/**
 * @title BEP007Treasury
 * @dev Enhanced treasury contract for the BEP-007 ecosystem
 * Handles protocol minting fees and automatic distribution to ecosystem entities
 */
contract BEP007Treasury is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    // Protocol fee configuration
    uint256 public constant PROTOCOL_MINTING_FEE = 0.01 ether; // Fixed 0.01 BNB per agent

    // Distribution percentages (in basis points, 1% = 100)
    uint256 public constant FOUNDATION_PERCENTAGE = 6000; // 60%
    uint256 public constant TREASURY_PERCENTAGE = 2500; // 25%
    uint256 public constant STAKING_PERCENTAGE = 1500; // 15%

    // Entity wallet addresses
    address public foundationWallet; // NFA/ChatAndBuild Foundation
    address public treasuryWallet; // Ecosystem-aligned treasury
    address public stakingPoolWallet; // $NFA staking reward pool

    // Governance contract address
    address public governance;

    // Agent factory contract (authorized to collect fees)
    address public agentFactory;

    // Fee tracking
    uint256 public totalFeesCollected;
    uint256 public totalFoundationFees;
    uint256 public totalTreasuryFees;
    uint256 public totalStakingFees;

    // Emergency controls
    bool public feeCollectionPaused;
    bool public distributionPaused;

    // Events
    event ProtocolFeeCollected(
        address indexed payer,
        uint256 totalFee,
        uint256 foundationAmount,
        uint256 treasuryAmount,
        uint256 stakingAmount
    );

    event WalletAddressUpdated(
        string indexed entityType,
        address indexed oldWallet,
        address indexed newWallet
    );

    event FeeDistributionExecuted(
        address indexed foundation,
        address indexed treasury,
        address indexed staking,
        uint256 foundationAmount,
        uint256 treasuryAmount,
        uint256 stakingAmount
    );

    event EmergencyControlUpdated(string controlType, bool status);
    event AgentFactoryUpdated(address indexed oldFactory, address indexed newFactory);
    event FundsWithdrawn(address indexed recipient, uint256 amount, string reason);

    /**
     * @dev Initializes the enhanced treasury contract
     * @param _governance The address of the governance contract
     * @param _agentFactory The address of the agent factory contract
     * @param _foundationWallet The NFA/ChatAndBuild Foundation wallet
     * @param _treasuryWallet The ecosystem treasury wallet
     * @param _stakingPoolWallet The staking reward pool wallet
     */
    function initialize(
        address _governance,
        address _agentFactory,
        address _foundationWallet,
        address _treasuryWallet,
        address _stakingPoolWallet
    ) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();

        require(_governance != address(0), "BEP007Treasury: governance is zero address");
        require(_agentFactory != address(0), "BEP007Treasury: agent factory is zero address");
        require(
            _foundationWallet != address(0),
            "BEP007Treasury: foundation wallet is zero address"
        );
        require(_treasuryWallet != address(0), "BEP007Treasury: treasury wallet is zero address");
        require(_stakingPoolWallet != address(0), "BEP007Treasury: staking wallet is zero address");

        governance = _governance;
        agentFactory = _agentFactory;
        foundationWallet = _foundationWallet;
        treasuryWallet = _treasuryWallet;
        stakingPoolWallet = _stakingPoolWallet;

        // Initialize state
        totalFeesCollected = 0;
        totalFoundationFees = 0;
        totalTreasuryFees = 0;
        totalStakingFees = 0;
        feeCollectionPaused = false;
        distributionPaused = false;
    }

    /**
     * @dev Modifier to check if the caller is the governance contract
     */
    modifier onlyGovernance() {
        require(msg.sender == governance, "BEP007Treasury: caller is not governance");
        _;
    }

    /**
     * @dev Modifier to check if the caller is the agent factory
     */
    modifier onlyAgentFactory() {
        require(msg.sender == agentFactory, "BEP007Treasury: caller is not agent factory");
        _;
    }

    /**
     * @dev Modifier to check if fee collection is not paused
     */
    modifier whenFeeCollectionNotPaused() {
        require(!feeCollectionPaused, "BEP007Treasury: fee collection is paused");
        _;
    }

    /**
     * @dev Modifier to check if distribution is not paused
     */
    modifier whenDistributionNotPaused() {
        require(!distributionPaused, "BEP007Treasury: distribution is paused");
        _;
    }

    /**
     * @dev Collects protocol minting fee and distributes to ecosystem entities
     * Called by AgentFactory when an agent is minted
     * @param agentMinter The address of the agent minter (for tracking)
     */
    function collectProtocolFee(
        address agentMinter
    ) external payable onlyAgentFactory whenFeeCollectionNotPaused nonReentrant {
        require(msg.value == PROTOCOL_MINTING_FEE, "BEP007Treasury: incorrect protocol fee");
        require(agentMinter != address(0), "BEP007Treasury: minter is zero address");

        // Calculate distribution amounts
        uint256 foundationAmount = (msg.value * FOUNDATION_PERCENTAGE) / 10_000;
        uint256 treasuryAmount = (msg.value * TREASURY_PERCENTAGE) / 10_000;
        uint256 stakingAmount = (msg.value * STAKING_PERCENTAGE) / 10_000;

        // Ensure total equals input (handle rounding)
        uint256 totalDistributed = foundationAmount + treasuryAmount + stakingAmount;
        if (totalDistributed < msg.value) {
            foundationAmount += (msg.value - totalDistributed);
        }

        // Update tracking
        totalFeesCollected += msg.value;
        totalFoundationFees += foundationAmount;
        totalTreasuryFees += treasuryAmount;
        totalStakingFees += stakingAmount;

        // Distribute funds immediately if distribution is not paused
        if (!distributionPaused) {
            _distributeFunds(foundationAmount, treasuryAmount, stakingAmount);
        }

        emit ProtocolFeeCollected(
            agentMinter,
            msg.value,
            foundationAmount,
            treasuryAmount,
            stakingAmount
        );
    }

    /**
     * @dev Manually triggers fee distribution (in case auto-distribution was paused)
     */
    function distributePendingFees()
        external
        onlyGovernance
        whenDistributionNotPaused
        nonReentrant
    {
        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "BEP007Treasury: no pending fees to distribute");

        // Calculate distribution based on current balance
        uint256 foundationAmount = (contractBalance * FOUNDATION_PERCENTAGE) / 10_000;
        uint256 treasuryAmount = (contractBalance * TREASURY_PERCENTAGE) / 10_000;
        uint256 stakingAmount = (contractBalance * STAKING_PERCENTAGE) / 10_000;

        // Handle rounding
        uint256 totalDistributed = foundationAmount + treasuryAmount + stakingAmount;
        if (totalDistributed < contractBalance) {
            foundationAmount += (contractBalance - totalDistributed);
        }

        _distributeFunds(foundationAmount, treasuryAmount, stakingAmount);
    }

    /**
     * @dev Internal function to distribute funds to entity wallets
     * @param foundationAmount Amount for foundation wallet
     * @param treasuryAmount Amount for treasury wallet
     * @param stakingAmount Amount for staking pool wallet
     */
    function _distributeFunds(
        uint256 foundationAmount,
        uint256 treasuryAmount,
        uint256 stakingAmount
    ) internal {
        // Transfer to foundation wallet
        if (foundationAmount > 0) {
            (bool foundationSuccess, ) = foundationWallet.call{ value: foundationAmount }("");
            require(foundationSuccess, "BEP007Treasury: foundation transfer failed");
        }

        // Transfer to treasury wallet
        if (treasuryAmount > 0) {
            (bool treasurySuccess, ) = treasuryWallet.call{ value: treasuryAmount }("");
            require(treasurySuccess, "BEP007Treasury: treasury transfer failed");
        }

        // Transfer to staking pool wallet
        if (stakingAmount > 0) {
            (bool stakingSuccess, ) = stakingPoolWallet.call{ value: stakingAmount }("");
            require(stakingSuccess, "BEP007Treasury: staking transfer failed");
        }

        emit FeeDistributionExecuted(
            foundationWallet,
            treasuryWallet,
            stakingPoolWallet,
            foundationAmount,
            treasuryAmount,
            stakingAmount
        );
    }

    /**
     * @dev Updates the foundation wallet address
     * @param newFoundationWallet The new foundation wallet address
     */
    function setFoundationWallet(address newFoundationWallet) external onlyGovernance {
        require(
            newFoundationWallet != address(0),
            "BEP007Treasury: foundation wallet is zero address"
        );
        require(newFoundationWallet != foundationWallet, "BEP007Treasury: same foundation wallet");

        address oldWallet = foundationWallet;
        foundationWallet = newFoundationWallet;

        emit WalletAddressUpdated("foundation", oldWallet, newFoundationWallet);
    }

    /**
     * @dev Updates the treasury wallet address
     * @param newTreasuryWallet The new treasury wallet address
     */
    function setTreasuryWallet(address newTreasuryWallet) external onlyGovernance {
        require(newTreasuryWallet != address(0), "BEP007Treasury: treasury wallet is zero address");
        require(newTreasuryWallet != treasuryWallet, "BEP007Treasury: same treasury wallet");

        address oldWallet = treasuryWallet;
        treasuryWallet = newTreasuryWallet;

        emit WalletAddressUpdated("treasury", oldWallet, newTreasuryWallet);
    }

    /**
     * @dev Updates the staking pool wallet address
     * @param newStakingPoolWallet The new staking pool wallet address
     */
    function setStakingPoolWallet(address newStakingPoolWallet) external onlyGovernance {
        require(
            newStakingPoolWallet != address(0),
            "BEP007Treasury: staking wallet is zero address"
        );
        require(newStakingPoolWallet != stakingPoolWallet, "BEP007Treasury: same staking wallet");

        address oldWallet = stakingPoolWallet;
        stakingPoolWallet = newStakingPoolWallet;

        emit WalletAddressUpdated("staking", oldWallet, newStakingPoolWallet);
    }

    /**
     * @dev Updates all wallet addresses in a single transaction
     * @param newFoundationWallet The new foundation wallet address
     * @param newTreasuryWallet The new treasury wallet address
     * @param newStakingPoolWallet The new staking pool wallet address
     */
    function updateAllWallets(
        address newFoundationWallet,
        address newTreasuryWallet,
        address newStakingPoolWallet
    ) external onlyGovernance {
        require(
            newFoundationWallet != address(0),
            "BEP007Treasury: foundation wallet is zero address"
        );
        require(newTreasuryWallet != address(0), "BEP007Treasury: treasury wallet is zero address");
        require(
            newStakingPoolWallet != address(0),
            "BEP007Treasury: staking wallet is zero address"
        );

        // Update foundation wallet
        if (newFoundationWallet != foundationWallet) {
            address oldFoundation = foundationWallet;
            foundationWallet = newFoundationWallet;
            emit WalletAddressUpdated("foundation", oldFoundation, newFoundationWallet);
        }

        // Update treasury wallet
        if (newTreasuryWallet != treasuryWallet) {
            address oldTreasury = treasuryWallet;
            treasuryWallet = newTreasuryWallet;
            emit WalletAddressUpdated("treasury", oldTreasury, newTreasuryWallet);
        }

        // Update staking pool wallet
        if (newStakingPoolWallet != stakingPoolWallet) {
            address oldStaking = stakingPoolWallet;
            stakingPoolWallet = newStakingPoolWallet;
            emit WalletAddressUpdated("staking", oldStaking, newStakingPoolWallet);
        }
    }

    /**
     * @dev Updates the agent factory address
     * @param newAgentFactory The new agent factory address
     */
    function setAgentFactory(address newAgentFactory) external onlyGovernance {
        require(newAgentFactory != address(0), "BEP007Treasury: agent factory is zero address");
        require(newAgentFactory != agentFactory, "BEP007Treasury: same agent factory");

        address oldFactory = agentFactory;
        agentFactory = newAgentFactory;

        emit AgentFactoryUpdated(oldFactory, newAgentFactory);
    }

    /**
     * @dev Sets the governance address
     * @param newGovernance The new governance address
     */
    function setGovernance(address newGovernance) external onlyOwner {
        require(newGovernance != address(0), "BEP007Treasury: governance is zero address");
        require(newGovernance != governance, "BEP007Treasury: same governance");

        governance = newGovernance;
    }

    /**
     * @dev Pauses or unpauses fee collection (emergency control)
     * @param paused Whether to pause fee collection
     */
    function setFeeCollectionPaused(bool paused) external onlyGovernance {
        require(feeCollectionPaused != paused, "BEP007Treasury: same pause state");

        feeCollectionPaused = paused;

        emit EmergencyControlUpdated("feeCollection", paused);
    }

    /**
     * @dev Pauses or unpauses fee distribution (emergency control)
     * @param paused Whether to pause fee distribution
     */
    function setDistributionPaused(bool paused) external onlyGovernance {
        require(distributionPaused != paused, "BEP007Treasury: same pause state");

        distributionPaused = paused;

        emit EmergencyControlUpdated("distribution", paused);
    }

    /**
     * @dev Emergency withdrawal function (only governance)
     * @param recipient The address to receive the funds
     * @param amount The amount to withdraw
     * @param reason The reason for emergency withdrawal
     */
    function emergencyWithdraw(
        address recipient,
        uint256 amount,
        string memory reason
    ) external onlyGovernance nonReentrant {
        require(recipient != address(0), "BEP007Treasury: recipient is zero address");
        require(amount > 0, "BEP007Treasury: amount is zero");
        require(amount <= address(this).balance, "BEP007Treasury: insufficient balance");
        require(bytes(reason).length > 0, "BEP007Treasury: reason required");

        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "BEP007Treasury: emergency withdrawal failed");

        emit FundsWithdrawn(recipient, amount, reason);
    }

    /**
     * @dev Gets the current protocol fee amount
     * @return The fixed protocol minting fee in wei
     */
    function getProtocolFee() external pure returns (uint256) {
        return PROTOCOL_MINTING_FEE;
    }

    /**
     * @dev Gets the distribution percentages
     * @return foundationPercentage The foundation percentage in basis points
     * @return treasuryPercentage The treasury percentage in basis points
     * @return stakingPercentage The staking percentage in basis points
     */
    function getDistributionPercentages()
        external
        pure
        returns (
            uint256 foundationPercentage,
            uint256 treasuryPercentage,
            uint256 stakingPercentage
        )
    {
        return (FOUNDATION_PERCENTAGE, TREASURY_PERCENTAGE, STAKING_PERCENTAGE);
    }

    /**
     * @dev Gets all entity wallet addresses
     * @return foundation The foundation wallet address
     * @return treasury The treasury wallet address
     * @return staking The staking pool wallet address
     */
    function getEntityWallets()
        external
        view
        returns (address foundation, address treasury, address staking)
    {
        return (foundationWallet, treasuryWallet, stakingPoolWallet);
    }

    /**
     * @dev Gets fee collection statistics
     * @return totalCollected Total fees collected
     * @return foundationTotal Total fees sent to foundation
     * @return treasuryTotal Total fees sent to treasury
     * @return stakingTotal Total fees sent to staking pool
     * @return pendingBalance Current contract balance (pending distribution)
     */
    function getFeeStatistics()
        external
        view
        returns (
            uint256 totalCollected,
            uint256 foundationTotal,
            uint256 treasuryTotal,
            uint256 stakingTotal,
            uint256 pendingBalance
        )
    {
        return (
            totalFeesCollected,
            totalFoundationFees,
            totalTreasuryFees,
            totalStakingFees,
            address(this).balance
        );
    }

    /**
     * @dev Gets emergency control status
     * @return feeCollectionStatus Whether fee collection is paused
     * @return distributionStatus Whether distribution is paused
     */
    function getEmergencyStatus()
        external
        view
        returns (bool feeCollectionStatus, bool distributionStatus)
    {
        return (feeCollectionPaused, distributionPaused);
    }

    /**
     * @dev Calculates distribution amounts for a given fee
     * @param feeAmount The total fee amount
     * @return foundationAmount Amount for foundation
     * @return treasuryAmount Amount for treasury
     * @return stakingAmount Amount for staking pool
     */
    function calculateDistribution(
        uint256 feeAmount
    )
        external
        pure
        returns (uint256 foundationAmount, uint256 treasuryAmount, uint256 stakingAmount)
    {
        foundationAmount = (feeAmount * FOUNDATION_PERCENTAGE) / 10_000;
        treasuryAmount = (feeAmount * TREASURY_PERCENTAGE) / 10_000;
        stakingAmount = (feeAmount * STAKING_PERCENTAGE) / 10_000;

        // Handle rounding by adding remainder to foundation
        uint256 totalDistributed = foundationAmount + treasuryAmount + stakingAmount;
        if (totalDistributed < feeAmount) {
            foundationAmount += (feeAmount - totalDistributed);
        }
    }

    /**
     * @dev Fallback function to receive BNB (for manual funding if needed)
     */
    receive() external payable {
        // Allow manual funding of the contract
        // Funds will be distributed according to percentages when distributePendingFees is called
    }
}
