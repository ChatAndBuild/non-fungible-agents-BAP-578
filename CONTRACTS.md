# BAP-700 Contract Documentation

This document provides detailed documentation for the key contracts in the BAP-700 Non-Fungible Agent (NFA) standard. It explains the purpose, functionality, and usage of each contract.

## Table of Contents

1. [BAP700.sol](#bap700sol)
2. [AgentFactory.sol](#agentfactorysol)
3. [BAP700Governance.sol](#bap700governancesol)
4. [ExperienceModuleRegistry.sol](#experiencemoduleregistrysol)
5. [VaultPermissionManager.sol](#vaultpermissionmanagersol)
6. [CircuitBreaker.sol](#circuitbreakersol)
7. [BAP700Treasury.sol](#bap700treasurysol)
8. [Template Contracts](#template-contracts)

## BAP700.sol

The core contract implementing the Non-Fungible Agent (NFA) token standard.

### Purpose
BAP700.sol extends ERC-721 to create a token standard specifically designed for autonomous agents. It provides functionality for agent creation, state management, action execution, and metadata handling.

### Key Features
- Agent creation with extended metadata
- Action execution via delegatecall
- Logic upgradeability
- Agent state management (active, paused, terminated)
- Circuit breaker for emergency pauses
- Funding mechanism for gas fees

### Key Functions
- `createAgent(address to, address logicAddress, string memory metadataURI, AgentMetadata memory extendedMetadata)`: Creates a new agent token with extended metadata
- `executeAction(uint256 tokenId, bytes calldata data)`: Executes an action using the agent's logic
- `setLogicAddress(uint256 tokenId, address newLogic)`: Updates the logic address for the agent
- `fundAgent(uint256 tokenId)`: Funds the agent with BNB for gas fees
- `getState(uint256 tokenId)`: Returns the current state of the agent
- `getAgentMetadata(uint256 tokenId)`: Gets the agent's extended metadata
- `updateAgentMetadata(uint256 tokenId, AgentMetadata memory metadata)`: Updates the agent's extended metadata

### Usage Example
```javascript
// Create an agent with extended metadata
const extendedMetadata = {
  persona: "Strategic crypto analyst",
  experience: "crypto intelligence, FUD scanner",
  voiceHash: "bafkreigh2akiscaildc...",
  animationURI: "ipfs://Qm.../nfa700_intro.mp4",
  vaultURI: "ipfs://Qm.../nfa700_vault.json",
  vaultHash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("vault_content"))
};

const tokenId = await bap700.createAgent(
  ownerAddress,
  logicAddress,
  "ipfs://metadata-uri",
  extendedMetadata
);

// Fund the agent
await bap700.fundAgent(tokenId, { value: ethers.utils.parseEther("0.1") });

// Execute an action
const data = logicContract.interface.encodeFunctionData("performAction", [param1, param2]);
await bap700.executeAction(tokenId, data);
```

## AgentFactory.sol

Factory contract for deploying Non-Fungible Agent (NFA) tokens.

### Purpose
AgentFactory.sol provides a standardized way to create new agent contracts with consistent initialization. It manages templates and ensures that only approved logic contracts can be used.

### Key Features
- Template management (approval, revocation)
- Agent creation with consistent initialization
- Version tracking for templates

### Key Functions
- `createAgent(string memory name, string memory symbol, address logicAddress, string memory metadataURI, IBAP700.AgentMetadata memory extendedMetadata)`: Creates a new agent with extended metadata
- `approveTemplate(address template, string memory category, string memory version)`: Approves a new template
- `revokeTemplate(address template)`: Revokes approval for a template
- `getLatestTemplate(string memory category)`: Gets the latest template for a category

### Usage Example
```javascript
// Get the latest DeFi template
const defiTemplate = await agentFactory.getLatestTemplate("DeFi");

// Create an agent using the template
const tx = await agentFactory.createAgent(
  "My DeFi Agent",
  "MDA",
  defiTemplate,
  "ipfs://metadata-uri",
  extendedMetadata
);

// Get the agent address from the event
const receipt = await tx.wait();
const agentCreatedEvent = receipt.events.find(e => e.event === "AgentCreated");
const agentAddress = agentCreatedEvent.args.agent;
```

## BAP700Governance.sol

Governance contract for the BAP-700 ecosystem.

### Purpose
BAP700Governance.sol manages the governance of the BAP-700 ecosystem, including protocol upgrades, parameter changes, and emergency actions.

### Key Features
- Proposal creation and voting
- Protocol parameter management
- Emergency circuit breaker control
- Treasury fund allocation

### Key Functions
- `createProposal(string memory description, address target, bytes memory data)`: Creates a new governance proposal
- `castVote(uint256 proposalId, bool support)`: Casts a vote on a proposal
- `executeProposal(uint256 proposalId)`: Executes an approved proposal
- `setEmergencyAdmin(address admin)`: Sets the emergency admin address
- `triggerCircuitBreaker(bool paused)`: Triggers the global circuit breaker

### Usage Example
```javascript
// Create a proposal to update a parameter
const data = someContract.interface.encodeFunctionData("updateParameter", [newValue]);
const proposalId = await governance.createProposal(
  "Update parameter X to improve Y",
  someContract.address,
  data
);

// Cast votes
await governance.castVote(proposalId, true);

// Execute the proposal after voting period
await governance.executeProposal(proposalId);
```

## ExperienceModuleRegistry.sol

Registry for agent experience modules.

### Purpose
ExperienceModuleRegistry.sol allows agents to register approved external experience sources, providing a way to extend an agent's capabilities without modifying the core contract.

### Key Features
- Cryptographic verification for module registration
- Module approval and revocation
- Metadata management for modules

### Key Functions
- `registerModule(uint256 tokenId, address moduleAddress, string memory metadata, bytes memory signature)`: Registers a experience module
- `revokeModule(uint256 tokenId, address moduleAddress)`: Revokes a experience module
- `isModuleApproved(uint256 tokenId, address moduleAddress)`: Checks if a module is approved
- `getModuleMetadata(uint256 tokenId, address moduleAddress)`: Gets the metadata for a module

### Usage Example
```javascript
// Create module metadata
const moduleMetadata = JSON.stringify({
  context_id: "nfa700-experience-001",
  owner: ownerAddress,
  created: new Date().toISOString(),
  persona: "Strategic crypto analyst"
});

// Sign the registration
const messageHash = ethers.utils.solidityKeccak256(
  ["uint256", "address", "string"],
  [tokenId, moduleAddress, moduleMetadata]
);
const signature = await wallet.signMessage(ethers.utils.arrayify(messageHash));

// Register the module
await experienceRegistry.registerModule(
  tokenId,
  moduleAddress,
  moduleMetadata,
  signature
);
```

## VaultPermissionManager.sol

Manages permissions for agent vaults.

### Purpose
VaultPermissionManager.sol handles cryptographic key-pair delegation for vault access, allowing agent owners to grant temporary access to their agent's off-chain data.

### Key Features
- Time-based access delegation
- Cryptographic verification for access requests
- Access revocation

### Key Functions
- `delegateAccess(uint256 tokenId, address delegate, uint256 expiryTime, bytes memory signature)`: Delegates vault access
- `revokeAccess(uint256 tokenId, address delegate)`: Revokes vault access
- `hasVaultAccess(uint256 tokenId, address delegate)`: Checks if an address has vault access
- `getAccessExpiry(uint256 tokenId, address delegate)`: Gets the expiry time for access

### Usage Example
```javascript
// Set expiry time (1 day from now)
const expiryTime = Math.floor(Date.now() / 1000) + 86400;

// Sign the delegation
const messageHash = ethers.utils.solidityKeccak256(
  ["uint256", "address", "uint256"],
  [tokenId, delegateAddress, expiryTime]
);
const signature = await wallet.signMessage(ethers.utils.arrayify(messageHash));

// Delegate access
await vaultManager.delegateAccess(
  tokenId,
  delegateAddress,
  expiryTime,
  signature
);
```

## CircuitBreaker.sol

Emergency shutdown mechanism for the BAP-700 ecosystem.

### Purpose
CircuitBreaker.sol provides a way to pause the system in case of emergencies, protecting users and their assets from potential exploits.

### Key Features
- Global pause for system-wide emergencies
- Contract-specific pauses for targeted intervention
- Multi-level authorization (governance and emergency multi-sig)

### Key Functions
- `setGlobalPause(bool paused)`: Sets the global pause state
- `setContractPause(address contract_, bool paused)`: Sets the pause state for a specific contract
- `isContractPaused(address contract_)`: Checks if a contract is paused
- `isGloballyPaused()`: Checks if the system is globally paused

### Usage Example
```javascript
// Pause the system in case of emergency
await circuitBreaker.setGlobalPause(true);

// Pause a specific contract
await circuitBreaker.setContractPause(vulnerableContract.address, true);

// Check if a contract is paused
const isPaused = await circuitBreaker.isContractPaused(someContract.address);
```

## BAP700Treasury.sol

Treasury management for the BAP-700 ecosystem.

### Purpose
BAP700Treasury.sol manages the funds allocated for ecosystem development, grants, and other initiatives.

### Key Features
- Fund allocation and distribution
- Multi-signature approval for withdrawals
- Transparent fund tracking
- Grant program management

### Key Functions
- `allocateFunds(address recipient, uint256 amount, string memory purpose)`: Allocates funds for a specific purpose
- `approveAllocation(uint256 allocationId)`: Approves a fund allocation
- `executeAllocation(uint256 allocationId)`: Executes an approved allocation
- `depositFunds()`: Deposits funds into the treasury

### Usage Example
```javascript
// Allocate funds for a grant
const allocationId = await treasury.allocateFunds(
  grantRecipient.address,
  ethers.utils.parseEther("10"),
  "Community development grant"
);

// Approve the allocation (by multiple signers)
await treasury.connect(signer1).approveAllocation(allocationId);
await treasury.connect(signer2).approveAllocation(allocationId);

// Execute the allocation after sufficient approvals
await treasury.executeAllocation(allocationId);
```

## Template Contracts

The BAP-700 ecosystem includes several template contracts for creating specialized agent types.

### DeFiAgent.sol

Template for DeFi-focused agents.

#### Purpose
DeFiAgent.sol provides pre-configured logic for agents that interact with DeFi protocols, such as trading, liquidity provision, and yield farming.

#### Key Features
- Swap functionality across DEXes
- Liquidity provision and withdrawal
- Yield farming strategy execution
- Price monitoring and alerts

#### Key Functions
- `performSwap(address tokenA, address tokenB, uint256 amount)`: Performs a token swap
- `addLiquidity(address pair, uint256 amountA, uint256 amountB)`: Adds liquidity to a pool
- `harvestYield(address farm)`: Harvests yield from a farming protocol
- `setTradingParameters(uint256 slippage, uint256 deadline)`: Sets trading parameters

### GameAgent.sol

Template for gaming-focused agents.

#### Purpose
GameAgent.sol provides pre-configured logic for agents that interact with blockchain games, such as NPCs, item management, and quest systems.

#### Key Features
- Game state interaction
- Item management and trading
- Quest progression tracking
- Player interaction handling

#### Key Functions
- `interactWithPlayer(address player, bytes memory data)`: Interacts with a player
- `manageInventory(uint256[] memory items, uint8[] memory actions)`: Manages the agent's inventory
- `progressQuest(uint256 questId, uint8 action)`: Progresses a quest
- `setGameParameters(address game, bytes memory params)`: Sets game-specific parameters

### DAOAgent.sol

Template for DAO-focused agents.

#### Purpose
DAOAgent.sol provides pre-configured logic for agents that interact with DAOs, such as voting, proposal creation, and treasury management.

#### Key Features
- Proposal creation and voting
- Treasury management
- Member coordination
- Governance parameter optimization

#### Key Functions
- `createProposal(address dao, bytes memory proposalData)`: Creates a proposal in a DAO
- `castVote(address dao, uint256 proposalId, bool support)`: Casts a vote on a proposal
- `executeProposal(address dao, uint256 proposalId)`: Executes an approved proposal
- `setVotingStrategy(uint8 strategy, bytes memory params)`: Sets the agent's voting strategy
