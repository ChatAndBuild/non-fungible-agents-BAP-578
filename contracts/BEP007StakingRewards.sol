// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "./BEP007.sol";
import "./interfaces/ICircuitBreaker.sol";

/**
 * @title BEP007StakingRewards
 * @dev Staking rewards contract for $NFA token holders
 * Manages the staking reward pool and distributes rewards to long-term holders
 */
contract BEP007StakingRewards is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    // Circuit breaker for emergency controls
    ICircuitBreaker public circuitBreaker;

    // BEP007 token contract
    BEP007 public bep007Token;

    // Staking parameters
    uint256 public minimumStakeAmount;
    uint256 public stakingPeriod; // in days
    uint256 public rewardMultiplier; // basis points (10000 = 100%)

    // Staking tracking
    struct Stake {
        uint256 amount;
        uint256 startTime;
        uint256 lastRewardTime;
        uint256 totalRewardsEarned;
        bool isActive;
    }

    mapping(address => Stake) public stakes;
    mapping(address => uint256) public pendingRewards;

    // Statistics
    uint256 public totalStaked;
    uint256 public totalRewardsDistributed;
    uint256 public totalStakers;
    uint256 public rewardPoolBalance;

    // Events
    event Staked(address indexed staker, uint256 amount, uint256 startTime);
    event Unstaked(address indexed staker, uint256 amount, uint256 totalRewards);
    event RewardsClaimed(address indexed staker, uint256 amount);
    event RewardsAdded(uint256 amount, uint256 newPoolBalance);
    event StakingParametersUpdated(uint256 minimumStake, uint256 stakingPeriod, uint256 multiplier);

    /**
     * @dev Modifier to check if the system is not paused
     */
    modifier whenNotPaused() {
        require(!ICircuitBreaker(circuitBreaker).globalPause(), "StakingRewards: system is paused");
        _;
    }

    /**
     * @dev Modifier to check if the caller has an active stake
     */
    modifier hasActiveStake() {
        require(stakes[msg.sender].isActive, "StakingRewards: no active stake");
        _;
    }

    /**
     * @dev Initializes the contract
     * @param _circuitBreaker The address of the circuit breaker contract
     * @param _bep007Token The address of the BEP007 token contract
     * @param _minimumStakeAmount Minimum amount required to stake
     * @param _stakingPeriod Minimum staking period in days
     * @param _rewardMultiplier Reward multiplier in basis points
     * @param _owner The address of the contract owner
     */
    function initialize(
        address _circuitBreaker,
        address payable _bep007Token,
        uint256 _minimumStakeAmount,
        uint256 _stakingPeriod,
        uint256 _rewardMultiplier,
        address _owner
    ) public initializer {
        require(_circuitBreaker != address(0), "StakingRewards: circuit breaker is zero address");
        require(_bep007Token != address(0), "StakingRewards: token is zero address");
        require(_owner != address(0), "StakingRewards: owner is zero address");

        __Ownable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        circuitBreaker = ICircuitBreaker(_circuitBreaker);
        bep007Token = BEP007(_bep007Token);
        minimumStakeAmount = _minimumStakeAmount;
        stakingPeriod = _stakingPeriod;
        rewardMultiplier = _rewardMultiplier;

        transferOwnership(_owner);
    }

    /**
     * @dev Stakes BEP007 tokens to earn rewards
     * @param tokenIds Array of BEP007 token IDs to stake
     */
    function stake(uint256[] calldata tokenIds) external whenNotPaused nonReentrant {
        require(tokenIds.length > 0, "StakingRewards: no tokens provided");
        require(!stakes[msg.sender].isActive, "StakingRewards: already staking");

        uint256 totalStakeAmount = 0;

        // Verify ownership and calculate stake amount
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(bep007Token.ownerOf(tokenId) == msg.sender, "StakingRewards: not token owner");

            // Each token contributes 1 unit to stake amount (can be modified based on token value)
            totalStakeAmount += 1;
        }

        require(
            totalStakeAmount >= minimumStakeAmount,
            "StakingRewards: insufficient stake amount"
        );

        // Create stake record
        stakes[msg.sender] = Stake({
            amount: totalStakeAmount,
            startTime: block.timestamp,
            lastRewardTime: block.timestamp,
            totalRewardsEarned: 0,
            isActive: true
        });

        totalStaked += totalStakeAmount;
        totalStakers++;

        emit Staked(msg.sender, totalStakeAmount, block.timestamp);
    }

    /**
     * @dev Unstakes tokens and claims rewards
     */
    function unstake() external hasActiveStake whenNotPaused nonReentrant {
        Stake storage userStake = stakes[msg.sender];

        require(
            block.timestamp >= userStake.startTime + (stakingPeriod * 1 days),
            "StakingRewards: staking period not met"
        );

        // Calculate final rewards
        uint256 finalRewards = _calculateRewards(msg.sender);
        uint256 stakeAmount = userStake.amount;

        // Reset stake
        delete stakes[msg.sender];
        totalStaked -= stakeAmount;
        totalStakers--;

        // Transfer rewards if any
        if (finalRewards > 0) {
            require(rewardPoolBalance >= finalRewards, "StakingRewards: insufficient reward pool");
            rewardPoolBalance -= finalRewards;
            totalRewardsDistributed += finalRewards;

            (bool success, ) = payable(msg.sender).call{ value: finalRewards }("");
            require(success, "StakingRewards: reward transfer failed");

            emit RewardsClaimed(msg.sender, finalRewards);
        }

        emit Unstaked(msg.sender, stakeAmount, finalRewards);
    }

    /**
     * @dev Claims pending rewards without unstaking
     */
    function claimRewards() external hasActiveStake whenNotPaused nonReentrant {
        uint256 rewards = _calculateRewards(msg.sender);
        require(rewards > 0, "StakingRewards: no rewards to claim");

        Stake storage userStake = stakes[msg.sender];
        userStake.lastRewardTime = block.timestamp;
        userStake.totalRewardsEarned += rewards;

        require(rewardPoolBalance >= rewards, "StakingRewards: insufficient reward pool");
        rewardPoolBalance -= rewards;
        totalRewardsDistributed += rewards;

        (bool success, ) = payable(msg.sender).call{ value: rewards }("");
        require(success, "StakingRewards: reward transfer failed");

        emit RewardsClaimed(msg.sender, rewards);
    }

    /**
     * @dev Adds rewards to the reward pool (called by treasury)
     */
    function addRewards() external payable onlyOwner {
        require(msg.value > 0, "StakingRewards: no rewards to add");

        rewardPoolBalance += msg.value;

        emit RewardsAdded(msg.value, rewardPoolBalance);
    }

    /**
     * @dev Updates staking parameters (only owner)
     * @param _minimumStakeAmount New minimum stake amount
     * @param _stakingPeriod New staking period in days
     * @param _rewardMultiplier New reward multiplier in basis points
     */
    function updateStakingParameters(
        uint256 _minimumStakeAmount,
        uint256 _stakingPeriod,
        uint256 _rewardMultiplier
    ) external onlyOwner {
        minimumStakeAmount = _minimumStakeAmount;
        stakingPeriod = _stakingPeriod;
        rewardMultiplier = _rewardMultiplier;

        emit StakingParametersUpdated(_minimumStakeAmount, _stakingPeriod, _rewardMultiplier);
    }

    /**
     * @dev Emergency withdrawal function (only owner)
     * @param recipient The address to withdraw to
     * @param amount The amount to withdraw
     */
    function emergencyWithdraw(address payable recipient, uint256 amount) external onlyOwner {
        require(recipient != address(0), "StakingRewards: recipient is zero address");
        require(amount <= address(this).balance, "StakingRewards: insufficient balance");

        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "StakingRewards: emergency withdrawal failed");
    }

    /**
     * @dev Calculates pending rewards for a staker
     * @param staker The address of the staker
     * @return The amount of pending rewards
     */
    function calculateRewards(address staker) external view returns (uint256) {
        return _calculateRewards(staker);
    }

    /**
     * @dev Internal function to calculate rewards
     * @param staker The address of the staker
     * @return The amount of pending rewards
     */
    function _calculateRewards(address staker) internal view returns (uint256) {
        Stake storage userStake = stakes[staker];

        if (!userStake.isActive) {
            return 0;
        }

        uint256 timeStaked = block.timestamp - userStake.lastRewardTime;

        // Calculate rewards based on stake amount, time, and multiplier
        // Multiply first to avoid precision loss, then divide
        uint256 rewards = (userStake.amount * timeStaked * rewardMultiplier) / (1 days * 10000);

        // Cap rewards by the available reward pool balance
        if (rewards > rewardPoolBalance) {
            rewards = rewardPoolBalance;
        }

        return rewards;
    }

    /**
     * @dev Gets staking information for a user
     * @param staker The address of the staker
     * @return stake information
     */
    function getStakeInfo(address staker) external view returns (Stake memory) {
        return stakes[staker];
    }

    /**
     * @dev Gets contract statistics
     * @return totalStakedAmount Total staked amount
     * @return totalRewardsDistributedAmount Total rewards distributed
     * @return totalStakersCount Total number of stakers
     * @return rewardPoolBalanceAmount Current reward pool balance
     */
    function getStakingStats()
        external
        view
        returns (
            uint256 totalStakedAmount,
            uint256 totalRewardsDistributedAmount,
            uint256 totalStakersCount,
            uint256 rewardPoolBalanceAmount
        )
    {
        return (totalStaked, totalRewardsDistributed, totalStakers, rewardPoolBalance);
    }

    /**
     * @dev Checks if a user can unstake
     * @param staker The address of the staker
     * @return Whether the user can unstake
     */
    function canUnstake(address staker) external view returns (bool) {
        Stake storage userStake = stakes[staker];

        if (!userStake.isActive) {
            return false;
        }

        return block.timestamp >= userStake.startTime + (stakingPeriod * 1 days);
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

    /**
     * @dev Fallback function to accept ETH
     */
    receive() external payable {}
}
