# CircuitBreaker

## Overview
The CircuitBreaker contract provides an emergency shutdown mechanism for the BAP-700 ecosystem. It allows authorized entities to pause functionality at both the global level and for specific contracts, serving as a safety measure in case of vulnerabilities or attacks.

## Key Features
- Global pause functionality for the entire ecosystem
- Contract-specific pause controls
- Dual authorization system (governance and emergency multi-sig)
- Real-time pause state checking

## Contract Structure

### State Variables
- `governance`: Address of the governance contract
- `emergencyMultiSig`: Address of the emergency multi-signature wallet
- `globalPause`: Boolean indicating if the entire system is paused
- `contractPauses`: Mapping of contract addresses to their individual pause states

### Events
- `GlobalPauseUpdated`: Emitted when the global pause state changes
- `ContractPauseUpdated`: Emitted when a specific contract's pause state changes

### Functions

#### Initialization
```solidity
function initialize(
    address _governance,
    address _emergencyMultiSig
) public initializer
```
Initializes the contract with governance and emergency multi-sig addresses.

#### Pause Controls
```solidity
function setGlobalPause(bool paused) external onlyAuthorized
```
Sets the global pause state for the entire ecosystem.

```solidity
function setContractPause(address contractAddress, bool paused) external onlyAuthorized
```
Sets the pause state for a specific contract.

```solidity
function isContractPaused(address contractAddress) external view returns (bool)
```
Checks if a specific contract is paused (either by global pause or contract-specific pause).

#### Configuration
```solidity
function setGovernance(address _governance) external onlyAuthorized
```
Updates the governance address.

```solidity
function setEmergencyMultiSig(address _emergencyMultiSig) external onlyAuthorized
```
Updates the emergency multi-sig address.

## Security Considerations
- Dual authorization system provides redundancy for emergency actions
- Clear separation between global and contract-specific controls
- View function for external contracts to check pause status

## Integration Points
- Used by other contracts in the ecosystem to check their pause status
- Controlled by governance for routine management
- Emergency multi-sig for urgent situations
