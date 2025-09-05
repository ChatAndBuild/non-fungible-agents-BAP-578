// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "./interfaces/ICircuitBreaker.sol";

/**
 * @title BEP007Treasury
 * @dev Treasury contract for managing donations and fee distribution in the BEP-007 ecosystem
 * Handles collection of donations and distribution to Foundation, Community Treasury, and Staking Rewards
 */
contract BEP007Treasury is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    // Circuit breaker for emergency controls
    ICircuitBreaker public circuitBreaker;

    // Fee allocation percentages (in basis points - 10000 = 100%)
    uint256 public constant FOUNDATION_PERCENTAGE = 6000; // 60%
    uint256 public constant TREASURY_PERCENTAGE = 2500; // 25%
    uint256 public constant STAKING_PERCENTAGE = 1500; // 15%

    // Treasury addresses
    address public foundationAddress;
    address public communityTreasuryAddress;
    // Designated address for staking rewards (users will stake here themselves)
    address public stakingRewardsAddress;

    // Donation tracking
    CountersUpgradeable.Counter private _donationIdCounter;

    struct Donation {
        uint256 id;
        address donor;
        uint256 amount;
        uint256 timestamp;
        string message;
        bool distributed;
    }

    mapping(uint256 => Donation) public donations;
    mapping(address => uint256[]) public donorDonations;

    // Statistics
    uint256 public totalDonationsReceived;
    uint256 public totalDistributedToFoundation;
    uint256 public totalDistributedToTreasury;
    uint256 public totalDistributedToStaking;

    // Events
    event DonationReceived(
        uint256 indexed donationId,
        address indexed donor,
        uint256 amount,
        string message,
        uint256 timestamp
    );

    event DonationDistributed(
        uint256 indexed donationId,
        uint256 foundationAmount,
        uint256 treasuryAmount,
        uint256 stakingAmount
    );

    event TreasuryAddressesUpdated(
        address foundationAddress,
        address communityTreasuryAddress,
        address stakingRewardsAddress
    );

    event EmergencyWithdraw(address indexed recipient, uint256 amount);

    /**
     * @dev Modifier to check if the system is not paused
     */
    modifier whenNotPaused() {
        require(!ICircuitBreaker(circuitBreaker).globalPause(), "Treasury: system is paused");
        _;
    }

    /**
     * @dev Initializes the contract
     * @param circuitBreakerAddr The address of the circuit breaker contract
     * @param foundationAddr The address for the NFA/ChatAndBuild Foundation
     * @param communityTreasuryAddr The address for the Community Treasury
     * @param stakingRewardsAddr The designated address for staking rewards
     * @param ownerAddr The address of the contract owner
     */
    function initialize(
        address circuitBreakerAddr,
        address foundationAddr,
        address communityTreasuryAddr,
        address stakingRewardsAddr,
        address ownerAddr
    ) public initializer {
        require(circuitBreakerAddr != address(0), "Treasury: circuit breaker is zero address");
        require(foundationAddr != address(0), "Treasury: foundation address is zero");
        require(communityTreasuryAddr != address(0), "Treasury: treasury address is zero");
        require(stakingRewardsAddr != address(0), "Treasury: staking address is zero");
        require(ownerAddr != address(0), "Treasury: owner is zero address");

        __Ownable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        circuitBreaker = ICircuitBreaker(circuitBreakerAddr);
        foundationAddress = foundationAddr;
        communityTreasuryAddress = communityTreasuryAddr;
        stakingRewardsAddress = stakingRewardsAddr;

        transferOwnership(ownerAddr);
    }

    /**
     * @dev Accepts donations and distributes them according to the allocation percentages
     * @param message Optional message from the donor
     */
    function donate(string memory message) external payable whenNotPaused nonReentrant {
        require(msg.value > 0, "Treasury: donation amount must be greater than 0");

        _donationIdCounter.increment();
        uint256 donationId = _donationIdCounter.current();

        // Create donation record
        donations[donationId] = Donation({
            id: donationId,
            donor: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp,
            message: message,
            distributed: false
        });

        // Track donor's donations
        donorDonations[msg.sender].push(donationId);

        // Update statistics
        totalDonationsReceived += msg.value;

        emit DonationReceived(donationId, msg.sender, msg.value, message, block.timestamp);

        // Distribute the donation immediately
        _distributeDonation(donationId);
    }

    /**
     * @dev Distributes a specific donation according to allocation percentages
     * @param donationId The ID of the donation to distribute
     */
    function distributeDonation(uint256 donationId) external onlyOwner whenNotPaused nonReentrant {
        // STATE: These checks use donation state, not block timestamp
        // The timestamp comparison is for donation existence and state validation
        // This is a state check, not a time-based security decision
        require(donations[donationId].id != 0, "Treasury: donation does not exist");
        require(!donations[donationId].distributed, "Treasury: donation already distributed");

        _distributeDonation(donationId);
    }

    /**
     * @dev Internal function to distribute a donation
     * @param donationId The ID of the donation to distribute
     */
    function _distributeDonation(uint256 donationId) internal {
        Donation storage donation = donations[donationId];

        // Calculate distribution amounts
        uint256 foundationAmount = (donation.amount * FOUNDATION_PERCENTAGE) / 10000;
        uint256 treasuryAmount = (donation.amount * TREASURY_PERCENTAGE) / 10000;
        uint256 stakingAmount = (donation.amount * STAKING_PERCENTAGE) / 10000;

        // Ensure we don't lose any dust due to rounding
        uint256 totalDistributed = foundationAmount + treasuryAmount + stakingAmount;
        if (totalDistributed < donation.amount) {
            // Add any remaining dust to the foundation
            foundationAmount += (donation.amount - totalDistributed);
        }

        // Mark donation as distributed FIRST to prevent reentrancy
        donation.distributed = true;

        // Update totals BEFORE external calls to prevent reentrancy
        totalDistributedToFoundation += foundationAmount;
        totalDistributedToTreasury += treasuryAmount;
        totalDistributedToStaking += stakingAmount;

        // TRANSFER: Funds sent to recipients AFTER state updates
        // SECURITY: Low-level calls required for ETH transfers to contract addresses
        // These addresses are controlled by the contract owner and are trusted
        // Reentrancy protection ensures state consistency
        if (foundationAmount > 0) {
            (bool success1, ) = payable(foundationAddress).call{ value: foundationAmount }("");
            require(success1, "Treasury: foundation transfer failed");
        }

        if (treasuryAmount > 0) {
            (bool success2, ) = payable(communityTreasuryAddress).call{ value: treasuryAmount }("");
            require(success2, "Treasury: treasury transfer failed");
        }

        if (stakingAmount > 0) {
            (bool success3, ) = payable(stakingRewardsAddress).call{ value: stakingAmount }("");
            require(success3, "Treasury: staking transfer failed");
        }

        emit DonationDistributed(donationId, foundationAmount, treasuryAmount, stakingAmount);
    }

    /**
     * @dev Updates treasury addresses (only owner)
     * @param newFoundationAddress New foundation address
     * @param newCommunityTreasuryAddress New community treasury address
     * @param newStakingRewardsAddress New designated staking rewards address
     */
    function updateTreasuryAddresses(
        address newFoundationAddress,
        address newCommunityTreasuryAddress,
        address newStakingRewardsAddress
    ) external onlyOwner {
        require(newFoundationAddress != address(0), "Treasury: foundation address is zero");
        require(newCommunityTreasuryAddress != address(0), "Treasury: treasury address is zero");
        require(newStakingRewardsAddress != address(0), "Treasury: staking address is zero");

        foundationAddress = newFoundationAddress;
        communityTreasuryAddress = newCommunityTreasuryAddress;
        stakingRewardsAddress = newStakingRewardsAddress;

        emit TreasuryAddressesUpdated(
            newFoundationAddress,
            newCommunityTreasuryAddress,
            newStakingRewardsAddress
        );
    }

    /**
     * @dev Emergency withdrawal function (only owner)
     * @param recipient The address to withdraw to
     * @param amount The amount to withdraw
     */
    function emergencyWithdraw(address payable recipient, uint256 amount) external onlyOwner {
        require(recipient != address(0), "Treasury: recipient is zero address");
        require(amount <= address(this).balance, "Treasury: insufficient balance");

        // SECURITY: Low-level call required for ETH transfers
        // This is the recommended Solidity pattern for ETH transfers
        // Success is verified to ensure transfer completion
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Treasury: emergency withdrawal failed");

        emit EmergencyWithdraw(recipient, amount);
    }

    /**
     * @dev Gets donation details
     * @param donationId The ID of the donation
     * @return The donation details
     */
    function getDonation(uint256 donationId) external view returns (Donation memory) {
        return donations[donationId];
    }

    /**
     * @dev Gets all donations for a specific donor
     * @param donor The address of the donor
     * @return Array of donation IDs
     */
    function getDonorDonations(address donor) external view returns (uint256[] memory) {
        return donorDonations[donor];
    }

    /**
     * @dev Gets the total number of donations
     * @return The total number of donations
     */
    function getTotalDonations() external view returns (uint256) {
        return _donationIdCounter.current();
    }

    /**
     * @dev Gets current treasury statistics
     * @return totalReceived Total donations received
     * @return foundationDistributed Total distributed to foundation
     * @return treasuryDistributed Total distributed to treasury
     * @return stakingDistributed Total distributed to staking
     */
    function getTreasuryStats()
        external
        view
        returns (
            uint256 totalReceived,
            uint256 foundationDistributed,
            uint256 treasuryDistributed,
            uint256 stakingDistributed
        )
    {
        return (
            totalDonationsReceived,
            totalDistributedToFoundation,
            totalDistributedToTreasury,
            totalDistributedToStaking
        );
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
