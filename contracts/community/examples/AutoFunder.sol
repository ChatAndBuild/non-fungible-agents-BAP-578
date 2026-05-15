// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./interfaces/IAgentLogic.sol";
import "./interfaces/IBAP578.sol";

/**
 * @title AutoFunder
 * @dev Example BAP-578 logic contract: automatic agent balance top-up.
 *
 * Demonstrates how to build a logic contract that:
 *   1. Monitors an agent's on-chain balance
 *   2. Automatically tops up the agent when balance drops below threshold
 *   3. Uses a pre-funded reserve managed by the agent owner
 *   4. Is keeper-compatible (anyone can trigger the top-up check)
 *
 * Usage:
 *   1. Deploy this contract with the BAP-578 address
 *   2. Call `BAP578.setLogicAddress(tokenId, address(this))`
 *   3. Call `configure(tokenId, minBalance, topUpAmount)`
 *   4. Fund the reserve: `depositReserve(tokenId)` with BNB
 *   5. Keepers call `checkAndFund(tokenId)` periodically
 *
 * ⚠️  This is an educational example. Do NOT use in production without
 *     a full security audit.
 */
contract AutoFunder is IAgentLogic {
    IBAP578 public immutable bap578;

    struct FundConfig {
        uint256 minBalance; // Trigger top-up when agent balance drops below this
        uint256 topUpAmount; // Amount to send to fundAgent()
        uint256 reserve; // Pre-funded BNB reserve held by this contract
    }

    // tokenId => funding configuration
    mapping(uint256 => FundConfig) public configs;

    event Configured(uint256 indexed tokenId, uint256 minBalance, uint256 topUpAmount);
    event ReserveDeposited(uint256 indexed tokenId, uint256 amount);
    event ReserveWithdrawn(uint256 indexed tokenId, uint256 amount);
    event AgentTopUp(uint256 indexed tokenId, uint256 amount);

    constructor(address _bap578) {
        require(_bap578 != address(0), "AutoFunder: zero BAP578 address");
        bap578 = IBAP578(_bap578);
    }

    /// @notice Configure auto-funding parameters for an agent.
    function configure(uint256 tokenId, uint256 minBalance, uint256 topUpAmount) external {
        require(bap578.ownerOf(tokenId) == msg.sender, "AutoFunder: not agent owner");
        require(minBalance > 0, "AutoFunder: zero min balance");
        require(topUpAmount > 0, "AutoFunder: zero top-up amount");

        configs[tokenId].minBalance = minBalance;
        configs[tokenId].topUpAmount = topUpAmount;

        emit Configured(tokenId, minBalance, topUpAmount);
    }

    /// @notice Deposit BNB into the reserve for a specific agent.
    function depositReserve(uint256 tokenId) external payable {
        require(msg.value > 0, "AutoFunder: zero deposit");
        bap578.ownerOf(tokenId); // reverts if token does not exist
        configs[tokenId].reserve += msg.value;
        emit ReserveDeposited(tokenId, msg.value);
    }

    /// @notice Withdraw unused reserve (agent owner only).
    function withdrawReserve(uint256 tokenId, uint256 amount) external {
        require(bap578.ownerOf(tokenId) == msg.sender, "AutoFunder: not agent owner");
        require(configs[tokenId].reserve >= amount, "AutoFunder: insufficient reserve");

        configs[tokenId].reserve -= amount;
        (bool success, ) = msg.sender.call{ value: amount }("");
        require(success, "AutoFunder: withdraw failed");

        emit ReserveWithdrawn(tokenId, amount);
    }

    /// @notice Check agent balance and top up if needed. Callable by anyone.
    function checkAndFund(uint256 tokenId) external returns (bool funded) {
        return _checkAndFund(tokenId);
    }

    /// @inheritdoc IAgentLogic
    function execute(
        uint256 tokenId,
        bytes calldata /* data */
    ) external payable returns (bytes memory) {
        require(bap578.ownerOf(tokenId) == msg.sender, "AutoFunder: not agent owner");
        bool funded = _checkAndFund(tokenId);
        return abi.encode(funded);
    }

    /// @dev Internal funding logic shared by checkAndFund() and execute().
    function _checkAndFund(uint256 tokenId) internal returns (bool) {
        FundConfig storage config = configs[tokenId];
        require(config.minBalance > 0, "AutoFunder: not configured");

        (uint256 balance, bool active, , , ) = bap578.getAgentState(tokenId);

        if (!active) return false;
        if (balance >= config.minBalance) return false;

        uint256 amount = config.topUpAmount;
        require(config.reserve >= amount, "AutoFunder: insufficient reserve");

        config.reserve -= amount;

        // Call BAP578.fundAgent(tokenId) with BNB
        bap578.fundAgent{ value: amount }(tokenId);

        emit AgentTopUp(tokenId, amount);
        return true;
    }

    /// @inheritdoc IAgentLogic
    function description() external pure returns (string memory) {
        return "Automatic agent balance top-up when balance drops below threshold";
    }

    receive() external payable {}
}
