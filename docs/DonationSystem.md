# BEP007 Donation System

## Overview

The BEP007 Donation System provides a comprehensive mechanism for collecting donations and distributing them according to the specified allocation percentages:

- **60% to the NFA/ChatAndBuild Foundation** for R&D and ecosystem expansion
- **25% to the Community Treasury** for growth initiatives such as developer incentives and partnerships
- **15% to the $NFA Staking Reward Pool** to incentivize long-term holders and create deflationary pressure

## Architecture

The donation system consists of three main contracts:

### 1. BEP007Treasury.sol
The central contract that handles donation collection and distribution.

**Key Features:**
- Accepts donations in BNB/ETH
- Automatically distributes funds according to allocation percentages
- Tracks all donations and distribution statistics
- Provides emergency controls and address management

**Core Functions:**
```solidity
// Accept a donation with an optional message
function donate(string memory message) external payable

// Get donation details
function getDonation(uint256 donationId) external view returns (Donation memory)

// Get treasury statistics
function getTreasuryStats() external view returns (uint256, uint256, uint256, uint256)
```

### 2. Staking Rewards Address
Designated address where users can stake their ETH themselves. The treasury sends 15% of donations to this address.

**Key Features:**
- Designated address receives 15% of all donations
- Users can stake their ETH at this address themselves
- Provides flexibility for different staking strategies
- Integrates with the treasury for automatic funding

### 3. AgentFactory Integration
The AgentFactory has been updated to collect a 0.01 BNB fee for each agent creation, which is automatically sent to the treasury via the `donate` method, triggering the 60/25/15 distribution.

## Usage Guide

### Making Donations

#### Direct Donation
```javascript
// Donate 1 BNB with a message
await treasury.donate("Supporting the NFA ecosystem!", { 
    value: ethers.utils.parseEther("1.0") 
});
```

#### Fallback Donation
```javascript
// Send BNB directly to treasury (will trigger fallback function)
await signer.sendTransaction({
    to: treasury.address,
    value: ethers.utils.parseEther("0.5")
});
```

### Staking Rewards

The treasury automatically sends 15% of all donations to the designated staking rewards address. Users can then stake their ETH at this address using whatever staking mechanism is implemented there.

#### Checking Staking Rewards Address
```javascript
// Get the address where staking rewards are sent
const stakingRewardsAddress = await treasury.stakingRewardsAddress();
console.log("Staking rewards address:", stakingRewardsAddress);
```

### Creating Agents with Fees

```javascript
// Create an agent (requires 0.01 BNB fee)
// The fee is automatically donated to the treasury, triggering 60/25/15 distribution
await agentFactory.createAgent(
    "My Agent",
    "MAG",
    logicAddress,
    "metadata-uri",
    { value: ethers.utils.parseEther("0.01") }
);
```

### How AgentFactory Integrates with Donation System

When you create an agent through the AgentFactory:

1. **Fee Collection**: The factory collects the 0.01 BNB creation fee
2. **Automatic Donation**: Instead of just transferring ETH to the treasury, it calls `treasury.donate("Agent creation fee")`
3. **Distribution Triggered**: This automatically triggers the 60/25/15 distribution:
   - 60% → NFA/ChatAndBuild Foundation
   - 25% → Community Treasury  
   - 15% → Designated Staking Address
4. **Event Emission**: The factory emits `AgentCreationFeeCollected` event for tracking

This means every agent creation automatically contributes to the ecosystem's funding without requiring manual donation steps.

## Fee Allocation Breakdown

### Example: 1 BNB Donation

| Recipient | Percentage | Amount | Purpose |
|-----------|------------|--------|---------|
| NFA/ChatAndBuild Foundation | 60% | 0.6 BNB | R&D and ecosystem expansion |
| Community Treasury | 25% | 0.25 BNB | Developer incentives and partnerships |
| $NFA Staking Reward Pool | 15% | 0.15 BNB | Long-term holder rewards |

### Example: Agent Creation Fee (0.01 BNB)

| Recipient | Percentage | Amount | Purpose |
|-----------|------------|--------|---------|
| NFA/ChatAndBuild Foundation | 60% | 0.006 BNB | R&D and ecosystem expansion |
| Community Treasury | 25% | 0.0025 BNB | Developer incentives and partnerships |
| Designated Staking Address | 15% | 0.0015 BNB | User staking incentives |

**Note**: This distribution happens automatically every time an agent is created through the AgentFactory.



## Security Features

### Circuit Breaker Integration
All donation and staking operations are paused when the circuit breaker is activated:

```javascript
// Check if system is paused
const isPaused = await circuitBreaker.globalPause();
```

### Access Controls
- Only contract owners can update treasury addresses
- Only contract owners can add rewards to the staking pool
- Emergency withdrawal functions for contract owners

### Reentrancy Protection
All fund-handling functions are protected against reentrancy attacks using OpenZeppelin's ReentrancyGuard.

## Governance Integration

The donation system integrates with the BEP007 governance system:

### Treasury Management
```javascript
// Governance can update treasury addresses
await governance.setTreasury(treasuryAddress);

// Governance can update agent factory
await governance.setAgentFactory(factoryAddress);
```

### Parameter Updates
Governance can update treasury addresses through proposals:
- Foundation address
- Community treasury address
- Staking rewards address

## Events and Monitoring

### Treasury Events
```solidity
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
```



## Deployment

### Prerequisites
1. Deploy CircuitBreaker contract
2. Deploy BEP007 implementation
3. Set up foundation and community treasury addresses

### Deployment Script
```bash
npx hardhat run scripts/deploy-donation-system.js --network <network>
```

### Post-Deployment Steps
1. Update foundation and community treasury addresses
2. Configure staking parameters
3. Set up governance timelock and multi-sig controls
4. Test the system thoroughly

## Testing

Run the comprehensive test suite:

```bash
npx hardhat test test/DonationSystem.test.js
```

The test suite covers:
- Donation collection and distribution
- Staking functionality
- Reward calculations
- Agent creation fees
- Circuit breaker integration
- Governance integration

## Best Practices

### For Donors
1. Always verify the treasury contract address
2. Include meaningful messages with donations
3. Monitor donation confirmations on-chain

### For Stakers
1. Understand the minimum staking period
2. Monitor reward accumulation
3. Consider the opportunity cost of staking

### For Developers
1. Integrate donation tracking in your applications
2. Provide clear UI for donation amounts
3. Display real-time treasury statistics

## Emergency Procedures

### Circuit Breaker Activation
If the circuit breaker is activated:
1. All donation and staking operations are paused
2. Emergency withdrawals are still available to contract owners
3. Governance can update parameters to resolve issues

### Emergency Withdrawal
Contract owners can perform emergency withdrawals:
```javascript
await treasury.emergencyWithdraw(recipientAddress, amount);
```

## Future Enhancements

### Planned Features
- Multi-token donation support
- Automated reward distribution schedules
- Advanced staking tiers
- Governance proposal integration for parameter updates

### Upgrade Path
All contracts use the UUPS upgradeable pattern, allowing for future enhancements while maintaining state and user funds.

## Support

For technical support or questions about the donation system:
1. Check the test files for usage examples
2. Review the contract source code
3. Consult the governance documentation
4. Join the community discussions
