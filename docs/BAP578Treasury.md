# BAP578 Treasury

## Overview
The BAP578Treasury contract manages the collection, storage, and distribution of protocol fees and funds. It serves as the financial backbone of the BAP578 ecosystem, handling revenue from agent creation, upgrades, and transactions.

## Key Features
- **Fee Collection**: Collects fees from various protocol operations
- **Revenue Distribution**: Distributes revenue to stakeholders based on governance parameters
- **Fund Management**: Securely stores and manages protocol funds
- **Staking Rewards**: Calculates and distributes staking rewards
- **Governance Integration**: Configurable parameters controlled by governance

## Core Functions

### Fee Management
- `collectFee(FeeType feeType)`: Collects a fee of the specified type
- `setFeeAmount(FeeType feeType, uint256 amount)`: Updates the fee amount for a specific fee type
- `getFeeAmount(FeeType feeType)`: Returns the current fee amount for a specific fee type

### Revenue Distribution
- `distributeRevenue()`: Distributes accumulated revenue according to distribution parameters
- `setDistributionParameters(DistributionParams memory params)`: Updates revenue distribution parameters
- `getDistributionParameters()`: Returns current distribution parameters

### Fund Management
- `withdrawFunds(address recipient, uint256 amount)`: Withdraws funds to a specified recipient
- `depositFunds()`: Accepts deposits to the treasury
- `getTreasuryBalance()`: Returns the current treasury balance

### Staking Rewards
- `calculateRewards(address staker)`: Calculates rewards for a specific staker
- `distributeStakingRewards()`: Distributes rewards to all stakers
- `updateRewardRate(uint256 newRate)`: Updates the reward rate for staking

### Governance Controls
- `updateGovernanceAddress(address newGovernance)`: Updates the governance contract address
- `executeGovernanceProposal(bytes memory data)`: Executes a proposal approved by governance
- `pause()`: Pauses treasury operations in emergency situations
- `unpause()`: Resumes treasury operations

## Fee Types
```solidity
enum FeeType {
    CREATION,       // Fee for creating a new agent
    UPGRADE,        // Fee for upgrading agent logic
    TRANSACTION,    // Fee for agent transactions
    EXPERIENCE_MODULE,  // Fee for registering experience modules
    CUSTOM          // Custom fee type defined by governance
}
```

## Distribution Parameters
```solidity
struct DistributionParams {
    uint256 stakingRewardPercentage;    // Percentage allocated to stakers
    uint256 developmentFundPercentage;  // Percentage allocated to development
    uint256 communityTreasuryPercentage; // Percentage allocated to community treasury
    uint256 burnPercentage;             // Percentage of tokens to burn
}
```

## Events
- `FeeCollected(FeeType indexed feeType, address indexed payer, uint256 amount)`
- `RevenueDistributed(uint256 stakingAmount, uint256 developmentAmount, uint256 communityAmount, uint256 burnAmount)`
- `FeeUpdated(FeeType indexed feeType, uint256 oldAmount, uint256 newAmount)`
- `DistributionParametersUpdated()`
- `FundsWithdrawn(address indexed recipient, uint256 amount)`
- `FundsDeposited(address indexed depositor, uint256 amount)`
- `RewardRateUpdated(uint256 oldRate, uint256 newRate)`
- `GovernanceAddressUpdated(address indexed oldGovernance, address indexed newGovernance)`

## Security Considerations
- Access control ensures only authorized addresses can withdraw funds or update parameters
- Integration with circuit breaker for emergency pauses
- Reentrancy protection on all fund-handling functions
- Checks-Effects-Interactions pattern to prevent reentrancy attacks
- Governance timelock for sensitive parameter changes

## Integration with BAP578 Ecosystem
- Collects fees from AgentFactory for agent creation
- Receives transaction fees from agent operations
- Distributes rewards to $NFA token stakers
- Funds development initiatives based on governance decisions
- Manages community treasury for ecosystem growth
