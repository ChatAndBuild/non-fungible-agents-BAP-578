# BAP-578 Enhanced Architecture Guide

This document provides a comprehensive overview of the enhanced BAP-578 Non-Fungible Agent (NFA) architecture, explaining the key components and their interactions with the new learning capabilities. It serves as a guide for developers working with both simple and learning-enabled agents in the BAP-578 standard.

## Table of Contents

1. [Enhanced Smart Contract Architecture](#enhanced-smart-contract-architecture)
2. [Dual-Path Development System](#dual-path-development-system)
3. [Core Components](#core-components)
4. [Enhanced Metadata Schema](#enhanced-metadata-schema)
5. [Learning Module System](#learning-module-system)
6. [Experience Module System](#experience-module-system)
7. [Vault Permission System](#vault-permission-system)
8. [Agent Templates](#agent-templates)
9. [Security Mechanisms](#security-mechanisms)
10. [Integration Patterns](#integration-patterns)
11. [Migration and Upgrade Paths](#migration-and-upgrade-paths)

## Enhanced Smart Contract Architecture

The enhanced BAP-578 token standard builds upon ERC-721 to introduce a composable framework for intelligent, evolving agents with cryptographically verifiable learning capabilities. The architecture has been designed to accommodate both static NFT functionality and dynamic extensions critical for agent behavior, media, experience, and learning progression.

### Design Principles

1. **ERC-721 Compatibility**: BAP-578 maintains compatibility by inheriting core functionality: unique token IDs, safe transfers, ownership tracking, and metadata URI referencing.

2. **Dual-Path Architecture**: The system provides two distinct development paths:
   - **Simple Agents**: Traditional NFT functionality with agent-specific extensions
   - **Learning Agents**: Advanced agents with cryptographically verifiable learning capabilities

3. **Modularity**: The system is designed with separate components that can be upgraded or replaced independently, including pluggable learning modules.

4. **Hybrid Storage**: Essential agent identity attributes and learning tree roots are committed on-chain to optimize gas usage. Full persona trees, voice samples, extended experience, and detailed learning data reside off-chain in vaults, referenced by URI and validated using hash checks.

5. **Security First**: Granular access control and cryptographic verification ensure that only authorized parties can modify agent data, access sensitive information, or update learning states.

6. **Forward Compatibility**: The standard is designed to support future extensions and upgrades without breaking existing functionality, including new learning algorithms and cross-chain capabilities.

## Dual-Path Development System

The enhanced BAP-578 standard provides developers with two distinct development paths while maintaining 100% backward compatibility:

### Path 1: Simple Agents (JSON Light Experience)
```
Agent Creation → Static Metadata → Traditional NFT Behavior
     ↓
JSON-based persona, experience, and attributes
     ↓
Familiar development patterns
     ↓
Lower gas costs and complexity
```

**Use Cases**: Basic automation, simple interactions, traditional NFT functionality
**Benefits**: Lower costs, simpler development, immediate deployment
**Limitations**: Static behavior, no learning capabilities

### Path 2: Learning Agents (Merkle Tree Learning)
```
Agent Creation → Enhanced Metadata → Learning-Enabled Behavior
     ↓
Merkle root storage + off-chain learning tree
     ↓
Cryptographically verifiable evolution
     ↓
Adaptive behavior and intelligence growth
```

**Use Cases**: AI assistants, adaptive automation, intelligent services
**Benefits**: Evolving capabilities, verifiable intelligence, higher market value
**Trade-offs**: Higher complexity, increased gas costs, off-chain infrastructure requirements

## Core Components

### Enhanced BAP578.sol

The main contract that implements the enhanced Non-Fungible Agent token standard. It extends ERC-721 with agent-specific functionality and optional learning capabilities.

Key features:
- Agent creation with enhanced metadata (simple and learning modes)
- Action execution via delegatecall with learning integration
- Logic upgradeability with learning module support
- Agent state management including learning states
- Circuit breaker for emergency pauses including learning-specific controls

```solidity
// Example: Creating a simple agent
function createAgent(
    address to, 
    address logicAddress, 
    string memory metadataURI,
    AgentMetadata memory extendedMetadata
) external returns (uint256 tokenId);

// Example: Creating a learning agent
function createLearningAgent(
    address to,
    address logicAddress,
    string memory metadataURI,
    EnhancedAgentMetadata memory extendedMetadata,
    address learningModule,
    bytes32 initialLearningRoot
) external returns (uint256 tokenId);

// Example: Executing an agent action with learning integration
function executeAction(
    uint256 tokenId, 
    bytes calldata data
) external nonReentrant whenAgentActive(tokenId);

// Example: Enabling learning on existing agent
function enableLearning(
    uint256 tokenId,
    address learningModule,
    bytes32 initialLearningRoot
) external onlyOwner(tokenId);
```

### Enhanced AgentFactory.sol

Factory contract for deploying new agent tokens with customizable templates and learning configurations.

Key features:
- Template management (approval, revocation) with learning support
- Agent creation with consistent initialization for both simple and learning agents
- Version tracking for templates and learning modules
- Learning module registry and approval system

```solidity
// Example: Creating a simple agent through the factory
function createAgent(
    string memory name,
    string memory symbol,
    address logicAddress,
    string memory metadataURI,
    IBAP578.AgentMetadata memory extendedMetadata
) external returns (address agent);

// Example: Creating a learning agent through the factory
function createLearningAgent(
    string memory name,
    string memory symbol,
    address logicAddress,
    string memory metadataURI,
    IBAP578Enhanced.EnhancedAgentMetadata memory extendedMetadata,
    address learningModule
) external returns (address agent);

// Example: Registering a learning module
function registerLearningModule(
    address moduleAddress,
    bytes32 moduleHash,
    string memory specification
) external onlyGovernance;
```

### MerkleTreeLearning.sol

Core learning module implementing Merkle tree-based learning for cryptographically verifiable agent evolution.

Key features:
- Merkle tree root storage for learning data integrity
- Learning metrics tracking (interactions, confidence, velocity)
- Rate limiting to prevent spam and gaming
- Milestone system for learning achievements
- Cryptographic verification for all learning claims

```solidity
// Example: Updating learning state
function updateLearning(
    uint256 tokenId,
    LearningUpdate calldata update
) external nonReentrant onlyAuthorized(tokenId);

// Example: Recording an interaction
function recordInteraction(
    uint256 tokenId,
    string calldata interactionType,
    bool success
) external onlyAuthorized(tokenId);

// Example: Verifying a learning claim
function verifyLearning(
    uint256 tokenId,
    bytes32 claim,
    bytes32[] calldata proof
) external view returns (bool);
```

### Enhanced ExperienceModuleRegistry.sol

Registry for agent experience modules that allows agents to register approved external experience sources with learning support.

Key features:
- Cryptographic verification for module registration
- Module approval and revocation with learning module support
- Metadata management for modules including learning specifications
- Learning module performance tracking

```solidity
// Example: Registering a learning-enabled experience module
function registerLearningModule(
    uint256 tokenId,
    address moduleAddress,
    string memory metadata,
    LearningType learningType,
    bytes memory signature
) external nonReentrant;

// Example: Verifying learning module compatibility
function verifyLearningModule(
    address moduleAddress,
    bytes32 expectedHash
) external view returns (bool);
```

### Enhanced VaultPermissionManager.sol

Manages permissions for agent vaults with enhanced support for learning data access control.

Key features:
- Time-based access delegation with learning-specific permissions
- Cryptographic verification for access requests
- Access revocation with learning data protection
- Learning data permission levels (read, write, admin)

```solidity
// Example: Delegating learning data access
function delegateLearningAccess(
    uint256 tokenId,
    address delegate,
    LearningPermissionLevel level,
    uint256 expiryTime,
    bytes memory signature
) external nonReentrant;

// Example: Verifying learning data access
function verifyLearningAccess(
    uint256 tokenId,
    address accessor,
    LearningPermissionLevel requiredLevel
) external view returns (bool);
```

### Enhanced CircuitBreaker.sol

Emergency shutdown mechanism with global and targeted pause capabilities, including learning-specific controls.

Key features:
- Global pause for system-wide emergencies
- Contract-specific pauses for targeted intervention
- Learning-specific pause controls
- Multi-level authorization (governance and emergency multi-sig)

```solidity
// Example: Pausing learning globally
function pauseLearningGlobally() external onlyGovernance;

// Example: Pausing learning for specific agent
function pauseAgentLearning(uint256 tokenId) external onlyOwnerOrGovernance(tokenId);
```

## Enhanced Metadata Schema

BAP-578 extends the standard ERC-721 metadata with additional fields specifically designed for agent functionality and learning capabilities:

### Core Agent Metadata
```solidity
struct AgentMetadata {
    string persona;       // JSON-encoded string for character traits, style, tone
    string experience;        // Short summary string for agent's role/purpose
    string voiceHash;     // Reference ID to stored audio profile
    string animationURI;  // URI to video or animation file
    string vaultURI;      // URI to the agent's vault (extended data storage)
    bytes32 vaultHash;    // Hash of the vault contents for verification
}
```

### Enhanced Learning Metadata
```solidity
struct EnhancedAgentMetadata {
    // Original BAP-578 fields
    string persona;           // JSON-encoded character traits
    string experience;            // Agent's role/purpose summary
    string voiceHash;         // Audio profile reference
    string animationURI;      // Animation/avatar URI
    string vaultURI;          // Extended data storage URI
    bytes32 vaultHash;        // Vault content verification hash
    
    // Enhanced learning fields
    bool learningEnabled;     // Learning capability flag
    address learningModule;   // Learning module contract address
    bytes32 learningTreeRoot; // Merkle root of learning tree
    uint256 learningVersion;  // Learning implementation version
    uint256 lastLearningUpdate; // Timestamp of last learning update
}
```

### Metadata Fields Explained

#### Original Fields
- **persona**: A JSON-encoded string representing character traits, style, tone, and behavioral intent. This defines how the agent should behave and interact.

- **experience**: A short summary string describing the agent's default role or purpose. This provides context for the agent's actions.

- **voiceHash**: A reference ID to a stored audio profile (e.g., via IPFS or Arweave). This allows agents to have consistent voice characteristics.

- **animationURI**: A URI to a video or Lottie-compatible animation file. This provides visual representation for the agent.

- **vaultURI**: A URI to the agent's vault, which contains extended data that would be too expensive to store on-chain.

- **vaultHash**: A hash of the vault contents for verification. This ensures the integrity of off-chain data.

#### Enhanced Learning Fields
- **learningEnabled**: Boolean flag indicating whether learning capabilities are active for this agent.

- **learningModule**: Contract address of the learning module implementation that handles the agent's learning logic.

- **learningTreeRoot**: 32-byte Merkle root representing the current state of the agent's learning tree, enabling cryptographic verification of learning claims.

- **learningVersion**: Version number for learning implementation compatibility, allowing for future upgrades and migrations.

- **lastLearningUpdate**: Timestamp of the last learning update, used for rate limiting and performance tracking.

## Learning Module System

The Learning Module system provides a standardized interface for implementing different learning algorithms while maintaining cryptographic verifiability and security.

### ILearningModule Interface

```solidity
interface ILearningModule {
    struct LearningMetrics {
        uint256 totalInteractions;    // Total user interactions
        uint256 learningEvents;       // Significant learning updates
        uint256 lastUpdateTimestamp;  // Last learning update time
        uint256 learningVelocity;     // Learning rate (scaled by 1e18)
        uint256 confidenceScore;      // Overall confidence (scaled by 1e18)
    }

    struct LearningUpdate {
        bytes32 previousRoot;         // Previous Merkle root
        bytes32 newRoot;              // New Merkle root
        bytes32[] proof;              // Merkle proof for update
        bytes metadata;               // Encoded learning data
    }

    function updateLearning(uint256 tokenId, LearningUpdate calldata update) external;
    function verifyLearning(uint256 tokenId, bytes32 claim, bytes32[] calldata proof) external view returns (bool);
    function getLearningMetrics(uint256 tokenId) external view returns (LearningMetrics memory);
    function recordInteraction(uint256 tokenId, bytes calldata interactionData) external;
    function isLearningEnabled(uint256 tokenId) external view returns (bool);
    function getVersion() external pure returns (string memory);
}
```

### Learning Tree Structure

Learning data is organized in a hierarchical tree structure stored off-chain with on-chain verification:

```json
{
  "root": "0x...", // Merkle root (32 bytes, stored on-chain)
  "version": 15,
  "agent_id": 123,
  "last_updated": "2025-01-20T10:00:00Z",
  "branches": {
    "user_preferences": {
      "communication_style": "professional",
      "preferred_frameworks": ["React", "Vue"],
      "working_hours": "9am-5pm EST",
      "confidence": 0.92
    },
    "domain_knowledge": {
      "blockchain": {
        "ethereum": 0.95,
        "binance_smart_chain": 0.88,
        "polygon": 0.75
      },
      "programming": {
        "javascript": 0.98,
        "solidity": 0.85,
        "python": 0.70
      }
    },
    "interaction_patterns": {
      "total_sessions": 247,
      "avg_session_length": "18min",
      "successful_tasks": 89,
      "learning_velocity": 0.15,
      "adaptation_rate": 0.12
    },
    "behavioral_evolution": {
      "personality_drift": {
        "formality_level": 0.8,
        "helpfulness_score": 0.95,
        "proactivity": 0.7
      },
      "skill_development": {
        "problem_solving": 0.88,
        "communication": 0.92,
        "technical_accuracy": 0.85
      }
    }
  },
  "metadata": {
    "total_nodes": 156,
    "tree_depth": 4,
    "compression_ratio": 0.65,
    "verification_complexity": "O(log n)"
  }
}
```

### Learning Module Types

#### 1. Merkle Tree Learning (Default)
- **Storage**: Merkle tree with cryptographic verification
- **Benefits**: Efficient verification, tamper-proof, gas-optimized
- **Use Cases**: General-purpose learning, skill development, preference adaptation

#### 2. Federated Learning Module
- **Storage**: Distributed learning with privacy preservation
- **Benefits**: Cross-agent knowledge sharing, privacy-preserving, network effects
- **Use Cases**: Collaborative intelligence, knowledge markets, collective learning

#### 3. Specialized Learning Modules
- **Domain-Specific**: Custom learning for specific use cases (DeFi, gaming, etc.)
- **Algorithm-Specific**: Different learning algorithms (reinforcement, supervised, etc.)
- **Performance-Optimized**: Optimized for specific performance characteristics

### Registration Process

1. **Module Development**: Create learning module implementing ILearningModule interface
2. **Security Audit**: Module undergoes security review and testing
3. **Governance Proposal**: Community votes on module approval
4. **Registry Addition**: Approved modules added to registry
5. **Agent Integration**: Agents can enable learning with approved modules

## Experience Module System

The Experience Module system allows agents to register and manage external experience sources, providing a way to extend an agent's capabilities without modifying the core contract. The enhanced system includes support for learning-enabled experienceexperience modules.

### Enhanced Experience Module Schema

Experience modules are structured as JSON documents that include structured experience layers, custom prompts, modular behaviors, and learning capabilities:

```json
{
  "context_id": "nfa578-experience-001",
  "owner": "0xUserWalletAddress",
  "created": "2025-01-20T10:00:00Z",
  "persona": "Strategic crypto analyst with learning capabilities",
  "learning_enabled": true,
  "learning_type": "adaptive_experience",
  "experience_slots": [
    {
      "type": "alert_keywords",
      "data": ["FUD", "rugpull", "hack", "$BNB", "scam"],
      "learning_weight": 0.8,
      "adaptation_rate": 0.1
    },
    {
      "type": "watchlist",
      "data": ["CZ", "Binance", "Tether", "SEC"],
      "learning_weight": 0.9,
      "confidence_score": 0.85
    },
    {
      "type": "behavior_rules",
      "data": [
        "If sentiment drops >10% in 24h, alert user",
        "If wallet activity spikes, summarize top 5 tokens"
      ],
      "learning_enabled": true,
      "rule_evolution": {
        "threshold_adaptation": true,
        "response_optimization": true
      }
    },
    {
      "type": "learning_patterns",
      "data": {
        "user_interaction_patterns": {
          "preferred_alert_frequency": "high",
          "response_detail_level": "comprehensive",
          "learning_feedback_integration": true
        },
        "market_analysis_evolution": {
          "prediction_accuracy": 0.78,
          "strategy_adaptation": true,
          "confidence_calibration": 0.82
        }
      }
    }
  ],
  "learning_metrics": {
    "total_adaptations": 45,
    "accuracy_improvements": 0.15,
    "user_satisfaction_score": 0.89,
    "learning_velocity": 0.12
  },
  "last_updated": "2025-01-20T11:00:00Z",
  "signed": "0xAgentSig"
}
```

### Enhanced Registration Process

1. The agent owner creates a experience module with desired functionality and learning configuration
2. The owner signs the module data with their private key
3. The module is registered with the ExperienceModuleRegistry contract with learning specifications
4. The registry verifies the signature and learning module compatibility
5. The agent can now access and use the registered module with learning capabilities

## Vault Permission System

The enhanced Vault Permission System provides secure access control for off-chain data vaults with special considerations for learning data access.

### Enhanced Key Features

- **Owner Control**: Only the agent owner can delegate or revoke access
- **Time-Based Delegation**: Access can be granted for specific time periods
- **Learning Data Permissions**: Granular control over learning data access levels
- **Cryptographic Verification**: All access requests are verified using cryptographic signatures
- **Revocation**: Access can be revoked at any time by the owner
- **Privacy Protection**: Learning data access is privacy-preserving

### Learning Permission Levels

```solidity
enum LearningPermissionLevel {
    READ_ONLY,           // Read access to learning data
    LEARNING_WRITE,      // Write access to learning updates
    LEARNING_ADMIN,      // Admin access to learning configuration
    FULL_LEARNING_CONTROL // Complete learning data control
}
```

### Enhanced Delegation Process

1. The agent owner decides to delegate access to a specific address with learning permissions
2. The owner specifies the learning permission level and duration
3. The owner signs a message containing the token ID, delegate address, permission level, and expiry time
4. The delegation is registered with the VaultPermissionManager contract
5. The manager verifies the signature and grants appropriate access
6. The delegate can access the vault and learning data according to their permission level until expiry or revocation

## Agent Templates

BAP-578 includes an enhanced template system for creating specialized agent types with learning support. These templates provide pre-configured logic for specific use cases.

### Enhanced Available Templates

#### **DeFiAgent.sol**: Enhanced DeFi Template with Learning
Template for DeFi-focused agents with adaptive trading strategies:

```solidity
contract DeFiAgent is BAP578Enhanced {
    struct TradingExperience {
        mapping(address => uint256) tokenPerformance;
        mapping(bytes32 => uint256) strategySuccess;
        uint256 totalTrades;
        uint256 successfulTrades;
        uint256 learningConfidence;
        bytes32 adaptiveStrategyRoot;
    }
    
    mapping(uint256 => TradingExperience) public tradingExperience;
    
    function executeTrade(uint256 tokenId, address tokenIn, address tokenOut, uint256 amountIn) external returns (uint256);
    function updateTradingStrategy(uint256 tokenId, bytes32 strategyHash, bytes calldata strategyData) external;
    function adaptToMarketConditions(uint256 tokenId, bytes calldata marketData) external;
}
```

#### **GameAgent.sol**: Enhanced Gaming Template with Learning
Template for gaming-focused agents with evolving NPCs and adaptive behavior:

```solidity
contract GameAgent is BAP578Enhanced {
    struct GameExperience {
        mapping(bytes32 => uint256) skillLevels;
        mapping(address => uint256) playerInteractions;
        uint256 experiencePoints;
        uint256 adaptationLevel;
        bytes32 personalityEvolution;
        bytes32 behaviorLearningRoot;
    }
    
    mapping(uint256 => GameExperience) public gameExperience;
    
    function levelUpSkill(uint256 tokenId, bytes32 skillId) external;
    function adaptToPlayer(uint256 tokenId, address player, bytes calldata behaviorData) external;
    function evolvePersonality(uint256 tokenId, bytes32 newPersonalityHash) external;
}
```

#### **DAOAgent.sol**: Enhanced DAO Template with Learning
Template for DAO-focused agents with adaptive governance participation:

```solidity
contract DAOAgent is BAP578Enhanced {
    struct GovernanceExperience {
        mapping(uint256 => bool) proposalVotes;
        mapping(bytes32 => uint256) topicExpertise;
        uint256 participationScore;
        uint256 reputationScore;
        bytes32 votingPatternHash;
        bytes32 expertiseLearningRoot;
    }
    
    mapping(uint256 => GovernanceExperience) public governanceExperience;
    
    function voteOnProposal(uint256 tokenId, uint256 proposalId, bool support) external;
    function updateExpertise(uint256 tokenId, bytes32 topic, uint256 expertiseLevel) external;
    function adaptVotingPattern(uint256 tokenId, bytes32 newPatternHash) external;
}
```

### Enhanced Template Usage

Templates are approved by governance and can be used through the AgentFactory with learning configuration:

```javascript
// Get the latest DeFi template with learning support
const defiTemplate = await agentFactory.getLatestTemplate("DeFi");

// Create a simple DeFi agent
const simpleTx = await agentFactory.createAgent(
  "My DeFi Agent",
  "MDA",
  defiTemplate,
  "ipfs://metadata-uri",
  extendedMetadata
);

// Create a learning DeFi agent
const learningTx = await agentFactory.createLearningAgent(
  "My Learning DeFi Agent",
  "MLDA",
  defiTemplate,
  "ipfs://metadata-uri",
  enhancedMetadata,
  merkleTreeLearning.address
);
```

## Security Mechanisms

BAP-578 implements several enhanced security mechanisms to protect agents, their owners, and learning data:

### Enhanced Circuit Breaker

The protocol includes a dual-layer pause mechanism with learning-specific controls:
- Global pause for system-wide emergencies
- Learning-specific global pause for learning-related issues
- Contract-specific pauses for targeted intervention
- Agent-specific learning pause for individual agent issues
- Controlled by both governance and emergency multi-sig for rapid response

### Reentrancy Protection

All fund-handling and learning functions are protected against reentrancy attacks using OpenZeppelin's ReentrancyGuard.

### Enhanced Gas Limits

Delegatecall operations and learning updates have gas limits to prevent out-of-gas attacks:

```solidity
uint256 public constant MAX_GAS_FOR_DELEGATECALL = 3000000;
uint256 public constant MAX_GAS_FOR_LEARNING_UPDATE = 500000;

// Execute the action via delegatecall with gas limit
(bool success, bytes memory result) = agentState.logicAddress.delegatecall{gas: MAX_GAS_FOR_DELEGATECALL}(data);

// Update learning with gas limit
(bool learningSuccess,) = learningModule.call{gas: MAX_GAS_FOR_LEARNING_UPDATE}(learningData);
```

### Enhanced Access Control

Strict access control for sensitive operations including learning:

```solidity
modifier onlyAgentOwner(uint256 tokenId) {
    require(ownerOf(tokenId) == msg.sender, "BAP578: caller is not agent owner");
    _;
}

modifier onlyLearningAuthorized(uint256 tokenId) {
    require(
        ownerOf(tokenId) == msg.sender || 
        isAuthorizedLearningUpdater(tokenId, msg.sender),
        "BAP578: not authorized for learning operations"
    );
    _;
}

modifier onlyApprovedLearningModule(uint256 tokenId) {
    require(
        approvedLearningModules[msg.sender] || 
        learningModules[tokenId] == msg.sender,
        "BAP578: not approved learning module"
    );
    _;
}
```

### Enhanced Cryptographic Verification

Signature-based verification for experience module registration, vault access, and learning updates:

```solidity
// Verify learning update signature
bytes32 learningHash = keccak256(abi.encodePacked(tokenId, newLearningRoot, timestamp));
bytes32 ethSignedMessageHash = learningHash.toEthSignedMessageHash();
address signer = ethSignedMessageHash.recover(signature);

require(signer == ownerOf(tokenId) || isAuthorizedLearningUpdater(tokenId, signer), "Invalid learning signature");

// Verify Merkle proof for learning claims
function verifyLearningClaim(uint256 tokenId, bytes32 claim, bytes32[] calldata proof) external view returns (bool) {
    bytes32 root = getLearningTreeRoot(tokenId);
    return MerkleProof.verify(proof, root, claim);
}
```

### Learning-Specific Security

- **Rate Limiting**: Maximum learning updates per day to prevent spam
- **Learning Module Approval**: Only governance-approved learning modules can be used
- **Learning Data Integrity**: All learning claims must be cryptographically verifiable
- **Emergency Learning Reset**: Ability to reset learning state in emergencies
- **Privacy Protection**: Learning data access is controlled and auditable

## Integration Patterns

### Creating and Managing Simple Agents

```javascript
// 1. Deploy a logic contract
const SimpleAgent = await ethers.getContractFactory("SimpleAgent");
const simpleAgent = await SimpleAgent.deploy();
await simpleAgent.deployed();

// 2. Create basic metadata
const basicMetadata = {
  persona: "Helpful assistant",
  experience: "general assistance",
  voiceHash: "bafkreigh2akiscaildc...",
  animationURI: "ipfs://Qm.../simple_intro.mp4",
  vaultURI: "ipfs://Qm.../simple_vault.json",
  vaultHash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("vault_content"))
};

// 3. Create the simple agent
const tx = await agentFactory.createAgent(
  "My Simple Agent",
  "MSA",
  simpleAgent.address,
  "ipfs://metadata-uri",
  basicMetadata
);
```

### Creating and Managing Learning Agents

```javascript
// 1. Deploy a learning-enabled logic contract
const LearningAgent = await ethers.getContractFactory("LearningDeFiAgent");
const learningAgent = await LearningAgent.deploy();
await learningAgent.deployed();

// 2. Create enhanced metadata with learning fields
const enhancedMetadata = {
  persona: "Strategic crypto analyst with adaptive capabilities",
  experience: "crypto intelligence with learning",
  voiceHash: "bafkreigh2akiscaildc...",
  animationURI: "ipfs://Qm.../learning_intro.mp4",
  vaultURI: "ipfs://Qm.../learning_vault.json",
  vaultHash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("vault_content")),
  learningEnabled: true,
  learningModule: merkleTreeLearning.address,
  learningTreeRoot: initialMerkleRoot,
  learningVersion: 1,
  lastLearningUpdate: 0
};

// 3. Create the learning agent
const tx = await agentFactory.createLearningAgent(
  "My Learning Agent",
  "MLA",
  learningAgent.address,
  "ipfs://metadata-uri",
  enhancedMetadata,
  merkleTreeLearning.address
);

// 4. Fund the agent
const agent = await ethers.getContractAt("BAP578Enhanced", agentAddress);
await agent.fundAgent({ value: ethers.utils.parseEther("0.1") });

// 5. Execute an action with learning integration
const data = learningAgent.interface.encodeFunctionData("performSwap", [tokenA, tokenB, amount]);
await agent.executeAction(data);

// 6. Record interaction for learning
await merkleTreeLearning.recordInteraction(tokenId, "swap_execution", true);
```

### Working with Enhanced Experience Modules

```javascript
// 1. Create enhanced module metadata with learning support
const enhancedModuleMetadata = JSON.stringify({
  context_id: "nfa578-experience-001",
  owner: ownerAddress,
  created: new Date().toISOString(),
  persona: "Strategic crypto analyst with learning",
  learning_enabled: true,
  learning_type: "adaptive_experience",
  experience_slots: [
    {
      type: "alert_keywords",
      data: ["FUD", "rugpull", "hack"],
      learning_weight: 0.8
    }
  ]
});

// 2. Sign the enhanced registration
const messageHash = ethers.utils.solidityKeccak256(
  ["uint256", "address", "string"],
  [tokenId, moduleAddress, enhancedModuleMetadata]
);
const signature = await wallet.signMessage(ethers.utils.arrayify(messageHash));

// 3. Register the enhanced module
await experienceRegistry.registerLearningModule(
  tokenId,
  moduleAddress,
  enhancedModuleMetadata,
  "ADAPTIVE", // LearningType
  signature
);
```

### Managing Learning Data and Permissions

```javascript
// 1. Delegate learning data access
const expiryTime = Math.floor(Date.now() / 1000) + 86400; // 1 day
const permissionLevel = 2; // LEARNING_WRITE

const messageHash = ethers.utils.solidityKeccak256(
  ["uint256", "address", "uint256", "uint256"],
  [tokenId, delegateAddress, permissionLevel, expiryTime]
);
const signature = await wallet.signMessage(ethers.utils.arrayify(messageHash));

await vaultManager.delegateLearningAccess(
  tokenId,
  delegateAddress,
  permissionLevel,
  expiryTime,
  signature
);

// 2. Update learning tree
const learningUpdate = {
  previousRoot: currentLearningRoot,
  newRoot: newLearningRoot,
  proof: merkleProof,
  metadata: encodedLearningData
};

await merkleTreeLearning.updateLearning(tokenId, learningUpdate);

// 3. Verify learning claim
const isValid = await merkleTreeLearning.verifyLearning(
  tokenId,
  learningClaim,
  merkleProof
);
```

## Migration and Upgrade Paths

### Simple to Learning Agent Migration

```javascript
// 1. Prepare learning infrastructure
const initialLearningRoot = await generateInitialLearningTree(tokenId);
const learningModule = merkleTreeLearning.address;

// 2. Enable learning on existing simple agent
await bap578Enhanced.enableLearning(
  tokenId,
  learningModule,
  initialLearningRoot
);

// 3. Verify learning is enabled
const isLearningEnabled = await bap578Enhanced.isLearningEnabled(tokenId);
console.log("Learning enabled:", isLearningEnabled);

// 4. Start recording interactions
await merkleTreeLearning.recordInteraction(
  tokenId,
  "migration_complete",
  true
);
```

### Learning Module Upgrades

```javascript
// 1. Prepare migration data
const currentRoot = await oldLearningModule.getLearningRoot(tokenId);
const migrationData = await prepareMigrationData(tokenId, currentRoot);

// 2. Upgrade to new learning module
await bap578Enhanced.upgradeLearningModule(
  tokenId,
  newLearningModule.address,
  migrationData
);

// 3. Verify migration success
const newRoot = await newLearningModule.getLearningRoot(tokenId);
const migrationSuccess = await verifyMigration(tokenId, currentRoot, newRoot);
```

### Cross-Chain Learning Migration

```javascript
// 1. Prepare cross-chain migration package
const migrationPackage = await bap578Enhanced.prepareCrossChainMigration(tokenId);

// 2. Bridge learning data to target chain
const bridgeTx = await learningBridge.migrateLearningData(
  tokenId,
  targetChainId,
  migrationPackage
);

// 3. Verify migration on target chain
const targetAgent = await ethers.getContractAt("BAP578Enhanced", targetAgentAddress);
const migrationSuccess = await targetAgent.verifyMigration(tokenId, migrationPackage);
```

This enhanced architecture guide provides a comprehensive overview of the BAP-578 standard with learning capabilities, enabling developers to build both simple and sophisticated agents while maintaining security, verifiability, and backward compatibility. The dual-path approach ensures that the standard can accommodate current needs while enabling future innovation in autonomous agent intelligence.
