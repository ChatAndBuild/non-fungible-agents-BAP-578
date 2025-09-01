# BAP-578: Non-Fungible Agent (NFA) Token Standard

![BAP-578 Non-Fungible Agents](https://github.com/christelbuchanan/bep007-non-fungible-agents-nfa/blob/main/NFA-ReadMe-Header.png)

## Overview

BAP-578 introduces Non-Fungible Agents (NFAs)—programmable, autonomous tokens that act as on-chain "agents" capable of executing tasks, evolving, and interacting with other contracts. This standard merges the uniqueness of NFTs with autonomous functionality, positioning BNB Chain as the home for decentralized automation.

This implementation provides a complete framework for creating, managing, and governing autonomous agent tokens on the BNB Chain with **optional learning capabilities** that allow agents to evolve and improve over time.

For a comprehensive technical breakdown, read the [Whitepaper](https://nfa.xyz/)

## 🚀 Enhanced Learning Capabilities

BAP-578 now offers **two development paths** to accommodate different use cases and developer preferences:

### **Path 1: JSON Light Experience (Default)**

Perfect for most developers and immediate deployment:

- ✅ **Simple**: Familiar JSON metadata approach (like standard NFTs)
- ✅ **Fast**: Deploy agents immediately with no complexity
- ✅ **Compatible**: Works with all existing NFT infrastructure
- ✅ **Cost-effective**: Minimal gas costs for basic operations

### **Path 2: Merkle Tree Learning (Optional)**

For advanced developers wanting truly evolving agents:

- 🧠 **Evolving**: Agents that genuinely learn and improve over time
- 🔒 **Provable**: Cryptographically verifiable learning history
- ⚡ **Efficient**: Only 32-byte Merkle roots stored on-chain
- 🚀 **Advanced**: Cutting-edge AI agent capabilities from day 1

### **Key Benefits**

- **Backward Compatibility**: All existing agents continue working unchanged
- **Optional Adoption**: Choose your complexity level
- **Upgrade Path**: Simple agents can enable learning later
- **Gas Optimized**: Learning data stored off-chain with on-chain verification
- **Future-Proof**: Architecture supports advanced AI developments

## Why a Token Standard?

### The Need for Standardization

While traditional NFTs (BEP-721) provide uniqueness and ownership, they lack the standardized interfaces needed for autonomous behavior and cross-platform agent interactions. BAP-578 addresses this gap by defining:

1. **Consistent Agent Interfaces**: Standardized methods for action execution, state management, and logic upgrades that enable predictable interactions across platforms.

2. **Interoperability Framework**: Common patterns for how agents interact with other contracts, services, and each other, creating an ecosystem where agents from different developers can work together.

3. **Hybrid On-Chain/Off-Chain Architecture**: Clear separation between on-chain identity and permissions versus off-chain extended experience and complex behaviors, optimizing for both gas efficiency and rich functionality.

4. **Optional Learning System**: Standardized interfaces for agent learning and evolution, allowing developers to choose between simple static agents or sophisticated learning agents.

5. **Security Boundaries**: Standardized circuit breaker patterns, permission systems, and access controls that protect users and their assets.

### On-Chain vs. Off-Chain Components

BAP-578 carefully balances which components belong on-chain versus off-chain:

| Component               | Storage                              | Rationale                                                  |
| ----------------------- | ------------------------------------ | ---------------------------------------------------------- |
| Agent Identity          | On-chain                             | Core identity must be immutable and universally accessible |
| Ownership & Permissions | On-chain                             | Security and access control require consensus verification |
| Basic Metadata          | On-chain                             | Essential for marketplace display and basic interactions   |
| Logic Address           | On-chain                             | Determines how the agent behaves when actions are executed |
| Learning Tree Root      | On-chain                             | Cryptographic proof of learning state (32 bytes only)      |
| Extended Experience     | Off-chain (with hash verification)   | Rich experience would be prohibitively expensive on-chain  |
| Learning Tree Data      | Off-chain (with Merkle verification) | Detailed learning data with cryptographic integrity        |
| Complex Behaviors       | Off-chain                            | Advanced AI behaviors require off-chain computation        |
| Voice/Animation         | Off-chain (with URI reference)       | Media assets are too large for on-chain storage            |

This hybrid approach ensures that:

- Critical security and identity information is secured by blockchain consensus
- Gas costs remain reasonable for agent operations
- Rich agent experiences can evolve without blockchain limitations
- Learning capabilities are cryptographically verifiable yet cost-efficient

### Ecosystem Benefits

Standardization through BAP-578 enables:

1. **Developer Ecosystem**: Common interfaces allow developers to build agent-compatible applications without custom integration for each agent implementation.

2. **Marketplace Integration**: Platforms can display, trade, and interact with agents using standardized methods, regardless of the agent's specific purpose or learning capabilities.

3. **Cross-Platform Compatibility**: Agents can move between applications while maintaining their identity, experience, and learned behaviors.

4. **User Ownership**: Clear separation of on-chain and off-chain components ensures users maintain control of their agents' data and behavior.

5. **Innovation Acceleration**: Developers can focus on creating unique agent behaviors rather than reinventing infrastructure patterns.

6. **Learning Portability**: Agents with learning enabled can carry their knowledge and experience across different platforms and applications.

## Key Features

- **Autonomous Behavior**: Agents execute predefined logic (e.g., trading, interacting with contracts) without manual intervention
- **Statefulness**: Each agent maintains mutable state variables stored on-chain
- **Interoperability**: Agents can interact with any smart contract on the BNB Chain, including BEP-20 and BEP-721 tokens
- **Upgradability**: Agent logic can be upgraded by their owners via proxy patterns or modular logic
- **Optional Learning**: Agents can evolve and improve through cryptographically verifiable learning systems
- **Governance**: Protocol-level governance for parameter updates and improvements
- **Security**: Robust circuit breaker system for emergency pauses at both global and contract-specific levels
- **Extensibility**: Template system for creating specialized agent types
- **Enhanced Metadata**: Rich metadata structure with persona, experience, voice, and animation capabilities
- **Experience Modules**: Support for external experience sources with cryptographic verification
- **Vault System**: Secure access control for off-chain data with delegated permissions
- **Learning Metrics**: Track agent evolution with verifiable learning statistics

## Token Structure

- **Inheritance**: Extends BEP-721 (NFT standard) with additional agent-specific functions
- **Metadata**: Includes static attributes, dynamic metadata, state variables, and optional learning data
- **Smart Contract Design**: Implements key functions like executeAction(), setLogicAddress(), fundAgent(), getState(), and optional learning functions
- **Hybrid Storage**: Essential data on-chain, extended data off-chain with secure references
- **Learning Integration**: Optional Merkle tree-based learning with cryptographic verification

## Architecture

The BAP-578 standard consists of the following components:

### Core Contracts

- **`BAP578Enhanced.sol`**: The enhanced NFA contract that implements the agent token standard with optional learning
- **`BAP578.sol`**: The original NFA contract for backward compatibility
- **`CircuitBreaker.sol`**: Emergency shutdown mechanism with global and targeted pause capabilities
- **`AgentFactory.sol`**: Factory contract for deploying new agent tokens with customizable templates
- **`BAP578Governance.sol`**: Governance contract for protocol-level decisions
- **`BAP578Treasury.sol`**: Treasury management for fee collection and distribution
- **`ExperienceModuleRegistry.sol`**: Registry for managing external experience modules with cryptographic verification
- **`VaultPermissionManager.sol`**: Manages secure access to off-chain data vaults with time-based delegation

### Learning System

- **`MerkleTreeLearning.sol`**: Implementation of Merkle tree-based learning with cryptographic verification

### Interfaces and Examples

- **`IBAP578.sol`**: Interface defining the core functionality for BAP-578 compliant tokens
- **`ILearningModule.sol`**: Interface defining the standard for pluggable learning systems
- **`learning-integration.js`**: Demonstrates how to use the enhanced BAP700 standard with optional learning capabilities from day 1

### Agent Templates

- **`StrategicAgent.sol`**: Template for agents to monitor trends, detect mentions, and analyze sentiment across various platforms
- **`DeFiAgent.sol`**: Template for DeFi-focused agents (trading, liquidity provision)
- **`GameAgent.sol`**: Template for gaming-focused agents (NPCs, item management)
- **`DAOAgent.sol`**: Template for DAO-focused agents (voting, proposal execution)
- **`CreatorAgent.sol`**: Template for content creator agents (brand management, content scheduling)
- **`MockAgentLogic.sol`**: Template for basic functionality to validate the agent interaction model without complex business logic
- **`DAOAmbassadorAgent.sol`**: Alternative template for DAO-focused agents with optional learning capability
- **`LifestyleAgent.sol`**: Template for travel and personal assistant focused agents
- **`FanCollectibleAgent.sol`**: Template for agents for anime, game, or fictional characters with AI conversation capabilities

## Extended Metadata

BAP-578 tokens include an enhanced metadata structure with:

### Basic Metadata

- **persona**: JSON-encoded string representing character traits, style, tone, and behavioral intent
- **experience**: Short summary string describing the agent's default role or purpose
- **voiceHash**: Reference ID to a stored audio profile (e.g., via IPFS or Arweave)
- **animationURI**: URI to a video or Lottie-compatible animation file
- **vaultURI**: URI to the agent's vault (extended data storage)
- **vaultHash**: Hash of the vault contents for verification

### Learning Enhancements

- **learningEnabled**: Boolean flag indicating if learning is active
- **learningModule**: Address of the learning module contract
- **learningTreeRoot**: Merkle root of the agent's learning tree
- **learningVersion**: Version number of the learning implementation

## Use Cases

### Traditional Agents (JSON Light Experience)

- **DeFi Agents**: Autonomous portfolio managers with predefined strategies
- **Gaming NPCs**: Characters with static personalities and behaviors
- **DAO Participants**: Agents executing predefined governance rules
- **IoT Integration**: Digital twins for physical devices with fixed parameters

### Learning Agents (Merkle Tree Learning)

- **Adaptive DeFi Agents**: Portfolio managers that learn from market conditions and user preferences
- **Evolving Game Characters**: NPCs that develop based on player interactions and game events
- **Smart DAO Agents**: Governance participants that learn from proposal outcomes and community feedback
- **Personal AI Assistants**: Agents that adapt to user preferences and improve task execution over time
- **Content Creator Agents**: Brand assistants that learn audience preferences and optimize content strategies

## Getting Started

### Prerequisites

- Node.js (v14+)
- npm or yarn
- Hardhat

### Installation

1. Clone the repository:

```bash
git clone https://github.com/yourusername/non-fungible-agents-BAP-578.git
cd BAP578
```

2. Install dependencies:

```bash
npm install
```

3. Create a `.env` file based on `.env.example` and add your private key and BNB Chain RPC URL.

### Compilation

Compile the smart contracts:

```bash
npx hardhat compile
```

### Testing

Run the test suite:

```bash
npx hardhat test
```

### Deployment

Deploy to the BNB Chain testnet:

```bash
npx hardhat run scripts/deploy.js --network testnet
```

## Usage

### Creating a Simple Agent (JSON Light Experience)

To create a traditional agent with static metadata:

```javascript
// Use the simple createAgent function - learning disabled by default
const tx = await agentFactory.createAgent(
  "My Simple Agent",
  "MSA",
  logicAddress,
  "ipfs://metadata-uri"
);

const receipt = await tx.wait();
const agentCreatedEvent = receipt.events.find(e => e.event === "AgentCreated");
const agentAddress = agentCreatedEvent.args.agent;

console.log(`✅ Simple agent created at: ${agentAddress}`);
```

### Creating a Learning Agent from Day 1

To create an agent with learning capabilities enabled from the start:

```javascript
// 1. Create initial learning tree
const initialLearningData = {
  preferences: { indentation: "2-spaces", naming: "camelCase" },
  patterns: ["functional", "modular"],
  confidence: 0.1
};

const learningTree = createLearningTree(initialLearningData);
const initialRoot = ethers.utils.keccak256(
  ethers.utils.toUtf8Bytes(JSON.stringify(learningTree.branches))
);

// 2. Create enhanced metadata with learning enabled
const enhancedMetadata = {
  persona: JSON.stringify({
    traits: ["analytical", "helpful", "adaptive"],
    style: "professional",
    tone: "friendly"
  }),
  experience: "AI coding assistant specialized in blockchain development",
  voiceHash: "bafkreigh2akiscaild...",
  animationURI: "ipfs://Qm.../agent_avatar.mp4",
  vaultURI: "ipfs://Qm.../agent_vault.json",
  vaultHash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("vault_content")),
  // Learning fields
  learningEnabled: true,
  learningModule: merkleTreeLearning.address,
  learningTreeRoot: initialRoot,
  learningVersion: 1
};

// 3. Create the agent with enhanced metadata
const tx = await agentFactory.createAgent(
  "My Learning Agent",
  "MLA",
  logicAddress,
  "ipfs://metadata-uri",
  enhancedMetadata
);

console.log(`🧠 Learning agent created with evolving capabilities`);
```

### Upgrading Existing Agent to Learning

To enable learning on an existing simple agent:

```javascript
// Create initial learning tree
const learningTree = createLearningTree({ tokenId });
const initialRoot = ethers.utils.keccak256(
  ethers.utils.toUtf8Bytes(JSON.stringify(learningTree.branches))
);

// Enable learning on existing agent
const tx = await BAP700Enhanced.enableLearning(
  tokenId,
  merkleTreeLearning.address,
  initialRoot
);

await tx.wait();
console.log(`🔄 Learning enabled for existing agent`);
```

### Recording Learning Interactions

To record interactions that help the agent learn:

```javascript
// Record successful interaction
await BAP578Enhanced.recordInteraction(
  tokenId,
  "code_generation",
  true // success
);

// Record failed interaction
await BAP578Enhanced.recordInteraction(
  tokenId,
  "bug_fixing", 
  false // failure
);

console.log(`📊 Interactions recorded for learning`);
```

### Checking Learning Progress

To view an agent's learning metrics:

```javascript
const { enabled, moduleAddress, metrics } = await BAP578Enhanced.getLearningInfo(tokenId);

if (enabled) {
  console.log(`🧠 Learning Module: ${moduleAddress}`);
  console.log(`📊 Total Interactions: ${metrics.totalInteractions}`);
  console.log(`🎯 Learning Events: ${metrics.learningEvents}`);
  console.log(`⚡ Learning Velocity: ${ethers.utils.formatUnits(metrics.learningVelocity, 18)}`);
  console.log(`🎖️ Confidence Score: ${ethers.utils.formatUnits(metrics.confidenceScore, 18)}`);
} else {
  console.log("📚 Agent using JSON light experience (learning disabled)");
}
```

### Executing Agent Actions

To execute an action with your agent (works for both simple and learning agents):

```javascript
// Encode the function call
const data = agentLogic.interface.encodeFunctionData("performTask", [
  param1,
  param2,
  param3
]);

// Execute the action
await agent.executeAction(data);

// For learning agents, interactions are automatically recorded
```

### Upgrading Agent Logic

To upgrade an agent's logic (works for both simple and learning agents):

```javascript
// Deploy new logic
const NewAgentLogic = await ethers.getContractFactory("NewAgentLogic");
const newAgentLogic = await NewAgentLogic.deploy();
await newAgentLogic.deployed();

// Update the agent's logic
await agent.setLogicAddress(newAgentLogic.address);
```

### Working with Experience Modules

To register a experience module:

```javascript
// Create module metadata
const moduleMetadata = JSON.stringify({
  context_id: "nfa578-experience-001",
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

### Managing Vault Permissions

To delegate vault access:

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

## Learning System Deep Dive

### Learning Tree Structure

Learning data is stored off-chain in a structured format with cryptographic verification:

```json
{
  "root": "0x...", // Merkle root (stored on-chain)
  "branches": {
    "codingStyle": {
      "indentation": "2-spaces",
      "naming": "camelCase",
      "patterns": ["functional", "modular"],
      "confidence": 0.85
    },
    "userPreferences": {
      "frameworks": ["React", "Vue"],
      "languages": ["TypeScript", "Solidity"],
      "testingStyle": "jest-focused"
    },
    "interactions": {
      "totalSessions": 47,
      "avgSessionLength": "23min",
      "successfulTasks": 89,
      "learningVelocity": 0.12
    }
  },
  "metadata": {
    "version": "1.0.0",
    "lastUpdated": "2025-01-20T10:00:00Z",
    "agentId": 123
  }
}
```

### Learning Metrics

The system tracks comprehensive learning metrics:

- **Total Interactions**: Number of user interactions
- **Learning Events**: Significant learning updates
- **Learning Velocity**: Rate of learning (events per day)
- **Confidence Score**: Overall agent confidence (0-1)
- **Milestones**: Achievement markers (100 interactions, 80% confidence, etc.)

### Security Features

- **Rate Limiting**: Maximum 50 learning updates per day per agent
- **Access Control**: Only agent owners can update learning
- **Cryptographic Verification**: All learning claims require Merkle proofs
- **Tamper-Proof History**: Learning history cannot be falsified

## Migration Strategy

### Phase 1: Foundation (Current)

- Enhanced metadata structure with learning flags
- Basic Merkle tree learning implementation
- Full backward compatibility maintained

### Phase 2: Advanced Learning (3-6 months)

- Specialized learning modules for different domains
- Cross-agent learning networks
- Learning marketplaces and reputation systems

### Phase 3: Ecosystem Evolution (6-12 months)

- Agent intelligence valuations
- Decentralized learning protocols
- AI agent collaboration networks

## Security Considerations

- **Circuit Breaker**: The protocol includes a dual-layer pause mechanism:
  - Global pause for system-wide emergencies
  - Contract-specific pauses for targeted intervention
  - Controlled by both governance and emergency multi-sig for rapid response
- **Reentrancy Protection**: All fund-handling functions are protected against reentrancy attacks
- **Gas Limits**: Delegatecall operations have gas limits to prevent out-of-gas attacks
- **Access Control**: Strict access control for sensitive operations
- **Balance Management**: Agents maintain their own balance for gas fees
- **Cryptographic Verification**: Signature-based verification for experience module registration and vault access
- **Time-based Permissions**: Delegated vault access with expiry times
- **Learning Security**: Rate limiting, access control, and cryptographic verification for all learning operations

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgements

- OpenZeppelin for their secure contract implementations
- BNB Chain team for their support of the BAP-578 standard
- The AI and blockchain communities for inspiring the learning capabilities
