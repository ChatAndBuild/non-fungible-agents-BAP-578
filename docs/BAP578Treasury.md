# BAP578 Treasury - Donation System

## Overview
The BAP578Treasury contract manages donations and their distribution within the BAP578 ecosystem. It serves as a transparent donation collection and distribution system, allocating funds to the Foundation, Community Treasury, and Staking Rewards.

## Key Features
- **Donation Collection**: Accepts ETH donations with optional messages
- **Automatic Distribution**: Distributes donations according to fixed percentages
- **Transparent Tracking**: Records all donations and distributions on-chain
- **Whitelist Security**: Only authorized treasury addresses can receive funds
- **Emergency Controls**: Owner can withdraw funds in emergency situations
- **Circuit Breaker Integration**: Can be paused during emergencies

## Distribution Allocation
- **Foundation**: 60% (6000 basis points)
- **Community Treasury**: 25% (2500 basis points)  
- **Staking Rewards**: 15% (1500 basis points)

## Core Functions

### Donation Management
- `donate(string memory message)`: Accept donations with an optional message
- `distributeDonation(uint256 donationId)`: Manually distribute a specific donation (owner only)
- `getDonation(uint256 donationId)`: Get details of a specific donation
- `getDonorDonations(address donor)`: Get all donation IDs for a specific donor
- `getTotalDonations()`: Get the total number of donations

### Treasury Address Management
- `updateTreasuryAddresses(address foundation, address treasury, address staking)`: Update recipient addresses (owner only)
- `getAuthorizedAddresses()`: Get list of all authorized treasury addresses
- **Security Note**: Old addresses are properly deauthorized when updating

### Emergency Functions
- `withdrawETH(uint256 amount)`: Withdraw specific amount (owner only)
- `withdrawAllETH()`: Withdraw all ETH (owner only)
- `emergencyWithdraw(address recipient, uint256 amount)`: Emergency withdrawal to specific address (owner only)

### Statistics
- `getTreasuryStats()`: Returns total donations received and distributions made

## Data Structures

### Donation
```solidity
struct Donation {
    uint256 id;
    address donor;
    uint256 amount;
    uint256 timestamp;
    string message;
    bool distributed;
}
```

## Events
- `DonationReceived(uint256 indexed donationId, address indexed donor, uint256 amount, string message, uint256 timestamp)`
- `DonationDistributed(uint256 indexed donationId, uint256 foundationAmount, uint256 treasuryAmount, uint256 stakingAmount)`
- `TreasuryAddressesUpdated(address foundationAddress, address communityTreasuryAddress, address stakingRewardsAddress)`
- `EmergencyWithdraw(address indexed recipient, uint256 amount)`
- `AuthorizedTransfer(address indexed recipient, uint256 amount, string addressType)`

## Security Features

### Whitelist Mechanism
- Only pre-authorized treasury addresses can receive distributed funds
- Authorization is managed through `authorizedTreasuryAddresses` mapping
- Addresses are added/removed when treasury addresses are updated

### Access Control
- Owner-only functions for critical operations
- Circuit breaker integration for emergency pauses
- Reentrancy protection on all fund-handling functions

### Fund Distribution Security
- Automatic distribution upon donation
- State updates before external calls (checks-effects-interactions pattern)
- Validation of recipient addresses before transfers
- Slither-suppressed false positive for arbitrary ETH sends (funds only go to whitelisted addresses)

## Integration with BAP578 Ecosystem
- Receives donations from the community
- Distributes funds to Foundation for development
- Allocates to Community Treasury for ecosystem initiatives
- Provides staking rewards allocation
- Integrates with CircuitBreaker for emergency controls

## Recent Updates
- Fixed bug in `updateTreasuryAddresses()` where old addresses are now properly removed from the authorized list
- Enhanced documentation for security model
- Added comprehensive test coverage for address authorization management
