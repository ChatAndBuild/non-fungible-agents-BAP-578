# NFA-1: Non-Fungible Agent Standard

**Status**: Draft
**Version**: 1.4
**Created**: 2026-02-08
**Authors**: NFA-1 Working Group
**License**: CC0-1.0
**Requires**: ERC-721, ERC-165
**Based on**: [BAP-578 BEP Draft](https://github.com/bnb-chain/BEPs/blob/master/BAPs/BAP-578.md) (BNB Chain Official)

---

## Table of Contents

- [Section 0: Conventions](#section-0-conventions)
- [Section 1: Abstract](#section-1-abstract)
- [Section 2: Motivation](#section-2-motivation)
- [Section 3: Core Specification](#section-3-core-specification)
- [Section 4: Optional Extensions](#section-4-optional-extensions)
- [Section 5: Security Requirements](#section-5-security-requirements)
- [Section 6: Upgradeability Statement](#section-6-upgradeability-statement)
- [Section 7: Compliance Tiers](#section-7-compliance-tiers)
- [Section 8: Cross-Protocol Integration](#section-8-cross-protocol-integration)
- [Section 9: Reference Implementation](#section-9-reference-implementation)
- [Section 10: Design Rationale](#section-10-design-rationale)
- [Section 11: Security Considerations](#section-11-security-considerations)
- [Section 12: Backwards Compatibility](#section-12-backwards-compatibility)
- [Section 13: Copyright](#section-13-copyright)

---

## Section 0: Conventions

### 0.1 Key Words

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in [RFC 2119](https://www.ietf.org/rfc/rfc2119.txt).

### 0.2 Data Classification Model

NFA-1 distinguishes three tiers of data storage. Every data field in this specification is classified into one of these tiers:

| Tier | Label | Description | Trust Model |
|------|-------|-------------|-------------|
| 1 | **On-Chain** | Stored directly in contract storage. Any node can read it. | Trustless — consensus-verified |
| 2 | **Verifiably On-Chain** | Data lives off-chain, but a cryptographic commitment (hash, Merkle root) is stored on-chain. Anyone can verify integrity by recomputing the hash. | Trust-minimized — verifiable |
| 3 | **Off-Chain** | No on-chain commitment. Depends on the hosting provider. | Trusted — custodial |

**Why this matters**: AI agent data is large (conversation histories, model weights, knowledge bases). Putting everything on-chain is economically infeasible. The Verifiably On-Chain tier gives the best tradeoff: off-chain storage costs with on-chain integrity guarantees.

Examples:
- `Status`, `balance`, `learningRoot` → **On-Chain** (Tier 1)
- `vaultHash` anchoring vault JSON → **Verifiably On-Chain** (Tier 2)
- Animation files at `animationURI` → **Off-Chain** (Tier 3)

### 0.3 Terminology

| Term | Definition |
|------|-----------|
| **NFA** | Non-Fungible Agent — an ERC-721 token representing an AI agent with identity, state, and learning capability |
| **Agent** | The on-chain + off-chain entity represented by an NFA token |
| **Vault** | Off-chain JSON containing the agent's full data (personality, memories, training config) |
| **Learning Root** | On-chain hash commitment to the agent's cumulative learning data |
| **Logic Contract** | A separate smart contract to which an agent delegates action execution |
| **Proof-of-Prompt** | Immutable hash of the agent's initial training configuration, set at mint time |

---

## Section 1: Abstract

NFA-1 defines a standard interface for **Non-Fungible Agents** — ERC-721 tokens that represent ownable, tradeable, and learnable AI agents on EVM-compatible blockchains.

While ERC-721 defines ownership and transferability for static digital assets, NFA-1 extends it with:

1. **Lifecycle management** — Agents have states (Active, Paused, Terminated) with defined transitions
2. **Learning progression** — A versioned, verifiable on-chain commitment to off-chain learning data
3. **Delegated action execution** — Agents can perform on-chain actions through pluggable logic contracts
4. **Identity and metadata** — Structured agent metadata bridging on-chain state and off-chain data vaults

NFA-1 defines **interfaces and behaviors** (the *what*), not implementation details (the *how*). It is chain-agnostic across EVM networks and compatible with the broader AI agent ecosystem including ERC-8004 (Agent Identity), X402 (Machine Payments), and A2A (Agent-to-Agent) protocols.

The shift is conceptual: from **AI-as-a-Service** (you rent access) to **AI-as-an-Asset** (you own the agent, its growth is your equity).

---

## Section 2: Motivation

### 2.1 The Gap Between NFTs and AI Agents

Current NFTs (ERC-721) represent static assets — images, music, collectibles. They have no concept of:
- **State**: An NFT is either owned or not. There is no "paused" or "terminated" state.
- **Learning**: An NFT's metadata is set once. There is no standard for progressive improvement.
- **Action**: An NFT cannot autonomously execute on-chain transactions.
- **Identity**: An NFT does not carry structured metadata describing an agent's capabilities.

Meanwhile, AI agents are dynamic entities that learn, act, and evolve. The absence of a standard for representing agents as ownable on-chain assets creates fragmentation: every project invents its own approach, agents cannot interoperate, and there is no composable agent economy.

### 2.2 Why ERC-721 Is Not Enough

ERC-721 provides ownership and transferability, but lacks:
- Lifecycle states (how to pause/terminate an agent without burning the token)
- Learning semantics (how to track agent improvement on-chain)
- Action delegation (how to let an agent execute on-chain transactions safely)
- Structured agent metadata (persona, voice, capabilities)

### 2.3 Why ERC-8004 Is Not Enough

ERC-8004 (Trustless Agents) defines an agent identity registry and Agent Cards, which is excellent for agent discovery and reputation. However, it does not address:
- **Ownership**: ERC-8004 agents are not inherently ownable/tradeable assets
- **Learning lifecycle**: No standard for tracking agent progression
- **Lifecycle management**: No pause/terminate/status semantics
- **Asset semantics**: Agents are not treated as appreciable digital assets

### 2.4 NFA-1 Fills the Gap

NFA-1 sits between ERC-721 (ownership) and ERC-8004 (identity):

```
ERC-721          NFA-1              ERC-8004
Ownership  +  Agent Semantics  +  Agent Discovery
(static)      (dynamic, learning)   (registry)
```

NFA-1 is designed to be composed with both: an NFA token can be linked to an ERC-8004 registry entry (via the Identity extension), and its underlying ownership is standard ERC-721.

---

## Section 3: Core Specification

### 3.1 Interface: INFA1Core

Every NFA-1 compliant contract MUST implement the `INFA1Core` interface. The contract MUST also be ERC-721 and ERC-165 compliant.

```solidity
interface INFA1Core /* is IERC721 */ {
    enum Status { Active, Paused, Terminated }

    struct State {
        uint256 balance;
        Status status;
        address owner;
        address logicAddress;
        uint256 lastActionTimestamp;
    }

    struct AgentMetadata {
        string persona;
        string experience;
        string voiceHash;
        string animationURI;
        string vaultURI;
        bytes32 vaultHash;
    }

    struct LearningState {
        bytes32 learningRoot;
        uint256 learningVersion;
        uint256 lastLearningUpdate;
        bool learningEnabled;
    }
}
```

### 3.2 Lifecycle States

Agents MUST exist in exactly one of three states:

| State | Value | Description |
|-------|-------|-------------|
| Active | 0 | Normal operation. All functions available. |
| Paused | 1 | Action execution blocked. Transfers MUST remain allowed. |
| Terminated | 2 | Permanent. MUST NOT be reversible under any circumstance. |

**State transition rules:**

```
         pause()           terminate()
Active ────────► Paused ─────────────► Terminated
  │                                       ▲
  │              terminate()              │
  └───────────────────────────────────────┘
         unpause()
Paused ────────► Active
```

- Active → Paused: MUST be allowed (reversible)
- Paused → Active: MUST be allowed (reversible)
- Active → Terminated: MUST be allowed (irreversible)
- Paused → Terminated: MUST be allowed (irreversible)
- Terminated → *: MUST be prohibited

**Critical requirement**: Paused agents MUST remain transferable. An agent's lifecycle state MUST NOT block ERC-721 transfer operations. This preserves asset liquidity — an owner must always be able to sell or transfer a paused agent.

### 3.3 Data Structures

#### 3.3.1 State (On-Chain)

All fields in the `State` struct are **On-Chain** (Tier 1):

| Field | Type | Classification | Description |
|-------|------|---------------|-------------|
| `balance` | uint256 | On-Chain | Agent's internal funding balance (native currency) |
| `status` | Status | On-Chain | Current lifecycle state |
| `owner` | address | On-Chain | Current owner (MUST reflect ERC-721 ownerOf) |
| `logicAddress` | address | On-Chain | Delegated logic contract (address(0) = none) |
| `lastActionTimestamp` | uint256 | On-Chain | Timestamp of last executeAction call |

#### 3.3.2 AgentMetadata (Mixed)

| Field | Type | Classification | Description |
|-------|------|---------------|-------------|
| `persona` | string | On-Chain | JSON-encoded personality traits |
| `experience` | string | On-Chain | Role/purpose summary |
| `voiceHash` | string | On-Chain | Hash reference for voice identity (MAY be empty) |
| `animationURI` | string | On-Chain | URI for animation/avatar (MAY be empty) |
| `vaultURI` | string | On-Chain | URI pointing to off-chain vault data |
| `vaultHash` | bytes32 | **Verifiably On-Chain** | keccak256 of vault JSON (integrity anchor) |

The `vaultHash` field is the bridge between on-chain state and off-chain data. It enables anyone to:
1. Fetch the vault JSON from `vaultURI`
2. Compute `keccak256(stableStringify(vaultJSON))`
3. Compare with the on-chain `vaultHash`
4. Verify integrity without trusting the hosting provider

#### 3.3.3 LearningState (On-Chain)

| Field | Type | Classification | Description |
|-------|------|---------------|-------------|
| `learningRoot` | bytes32 | **Verifiably On-Chain** | Merkle root or hash of learning data |
| `learningVersion` | uint256 | On-Chain | Monotonically increasing version counter |
| `lastLearningUpdate` | uint256 | On-Chain | Block timestamp of last update |
| `learningEnabled` | bool | On-Chain | Whether learning updates are accepted |

### 3.4 Core Events

Implementations MUST emit the following events at the specified points:

```solidity
// MUST emit when executeAction is called
event ActionExecuted(uint256 indexed tokenId, bytes result);

// MUST emit when logic address changes
event LogicUpgraded(uint256 indexed tokenId, address indexed oldLogic, address indexed newLogic);

// MUST emit when an agent receives funding
event AgentFunded(uint256 indexed tokenId, address indexed funder, uint256 amount);

// MUST emit on any status transition
event StatusChanged(uint256 indexed tokenId, Status newStatus);

// MUST emit when metadata is updated
event MetadataUpdated(uint256 indexed tokenId, string metadataURI);

// MUST emit when learning state is updated
event LearningUpdated(uint256 indexed tokenId, bytes32 indexed oldRoot, bytes32 indexed newRoot, uint256 newVersion);
```

### 3.5 Core Functions

#### 3.5.1 Action Execution

```solidity
function executeAction(uint256 tokenId, bytes calldata data)
    external returns (bytes memory result);
```

- MUST revert if `status != Active`
- MUST revert if `logicAddress == address(0)`
- MUST update `lastActionTimestamp` to `block.timestamp`
- MUST emit `ActionExecuted`
- SHOULD enforce a gas limit on the delegated call
- MUST only be callable by token owner or approved

```solidity
function setLogicAddress(uint256 tokenId, address newLogic) external;
```

- MUST only be callable by token owner or approved
- MUST NOT revert if `newLogic == address(0)` (this disables the logic contract)
- MUST emit `LogicUpgraded`

#### 3.5.2 Funding

```solidity
function fundAgent(uint256 tokenId) external payable;
```

- MUST be callable by anyone (permissionless)
- MUST emit `AgentFunded`

#### 3.5.3 Lifecycle Management

```solidity
function pause(uint256 tokenId) external;
function unpause(uint256 tokenId) external;
function terminate(uint256 tokenId) external;
```

- `pause()`: MUST revert if status is not Active. MUST only be callable by owner or approved.
- `unpause()`: MUST revert if status is not Paused. MUST only be callable by owner or approved.
- `terminate()`: MUST revert if already Terminated. MUST only be callable by owner or approved. MUST NOT be reversible.
- All three MUST emit `StatusChanged`.

#### 3.5.4 State Queries

```solidity
function getState(uint256 tokenId) external view returns (State memory);
function getAgentMetadata(uint256 tokenId) external view returns (AgentMetadata memory);
function getLearningState(uint256 tokenId) external view returns (LearningState memory);
```

- `getState()` MUST return the `owner` field reflecting the current ERC-721 `ownerOf()` result.

#### 3.5.5 Metadata Updates

```solidity
function updateAgentMetadata(uint256 tokenId, AgentMetadata calldata metadata) external;
```

- MUST revert if Terminated
- MUST only be callable by owner, approved, or a designated updater role
- MUST emit `MetadataUpdated`

#### 3.5.6 Learning System

```solidity
function updateLearning(
    uint256 tokenId,
    string calldata newVaultURI,
    bytes32 newVaultHash,
    bytes32 newLearningRoot,
    uint256 newVersion
) external;
```

- MUST revert if `learningEnabled == false`
- MUST revert if `newVersion <= current learningVersion` (monotonic enforcement)
- MUST revert if Terminated
- MUST emit `LearningUpdated`
- Authorization model is implementation-defined (owner, designated updater, or oracle)

```solidity
function getLearningRoot(uint256 tokenId) external view returns (bytes32);
function isLearningEnabled(uint256 tokenId) external view returns (bool);
function getLearningVersion(uint256 tokenId) external view returns (uint256);
function getLastLearningUpdate(uint256 tokenId) external view returns (uint256);
```

### 3.6 Proof-of-Prompt

Implementations SHOULD support a Proof-of-Prompt (PoP) mechanism:

- At mint time, a `proofOfPromptHash` (bytes32) SHOULD be submitted and stored immutably
- The PoP hash MUST NOT be modifiable after mint
- The PoP document (stored off-chain) SHOULD include:

```json
{
  "model": "gpt-4o-mini",
  "systemPromptHash": "0xabc...",
  "configHash": "0xdef...",
  "trainingDataHash": "0x123...",
  "timestamp": 1707350400
}
```

**Privacy note**: The actual system prompt does not go on-chain. Only the hash is stored. The owner can selectively disclose the full PoP document to prove their agent's training lineage.

### 3.7 Data Verification Architecture

#### 3.7.1 Vault Hash Verification

```
vaultHash = keccak256(stableStringify(vaultJSON))
```

Where `stableStringify` is a deterministic JSON serializer (keys sorted alphabetically, no trailing spaces, consistent number formatting). Implementations MUST document their serialization method.

#### 3.7.2 Learning Root Computation

Two paths are defined. Implementations MUST document which path they use.

**Path A — JSON Light Memory (simpler)**

```
learningRoot = keccak256(vaultHash || summaryHash)
```

Where `summaryHash = keccak256(stableStringify(learningSummaryJSON))`. Suitable for implementations where learning data is small and stored as part of the vault or as a simple summary.

**Path B — Merkle Tree Learning (scalable)**

```
memoriesRoot = MerkleTree(memory1Hash, memory2Hash, ..., memoryNHash)
learningRoot = keccak256(vaultHash || memoriesRoot || summaryHash)
```

Where each memory entry is independently hashable and the memories form a Merkle tree. Suitable for implementations with large or granular learning data.

### 3.8 Access Control

NFA-1 defines **what** access control rules must be enforced, not **how** to implement them:

| Function | Required Authorization |
|----------|----------------------|
| `executeAction` | Token owner or approved |
| `setLogicAddress` | Token owner or approved |
| `pause` / `unpause` / `terminate` | Token owner or approved |
| `fundAgent` | Anyone (permissionless) |
| `updateAgentMetadata` | Owner, approved, or designated updater |
| `updateLearning` | Owner or designated learning updater |

Implementations MAY use any access control pattern: OpenZeppelin's `Ownable`, `AccessControl`, custom role mappings, multi-sig governance, etc.

### 3.9 ERC-165 Interface Detection

Implementations MUST support ERC-165 and MUST return `true` for the `INFA1Core` interface ID:

```solidity
function supportsInterface(bytes4 interfaceId) external view returns (bool);
```

The `INFA1Core` interface ID is the XOR of all function selectors defined in the interface.

### 3.10 Implementation Notes — BAP-578 BEP Draft Alignment

> NFA-1 is **based on** the BAP-578 BEP Draft ([`bnb-chain/BEPs/BAPs/BAP-578.md`](https://github.com/bnb-chain/BEPs/blob/master/BAPs/BAP-578.md)), the official BNB Chain specification for Non-Fungible Agents. This section documents how the standard aligns with the BEP draft and where deliberate design choices differ.

**Core alignment**: INFA1Core implements the BAP-578 BEP draft's `IBAP578` interface. The Status enum (`Active, Paused, Terminated`), State struct, AgentMetadata struct, lifecycle functions (`pause/unpause/terminate`), `executeAction()`, `fundAgent()`, `setLogicAddress()`, and learning system all follow the BEP draft specification.

**Event indexing**: The BEP draft uses `address indexed agent` in most events (assuming one contract per agent). NFA-1 uses `uint256 indexed tokenId` (following the ERC-721 multi-token pattern). This is deliberate — the BEP draft itself is inconsistent (`MetadataUpdated` uses `tokenId` while other events use `address`). NFA-1 standardizes on `tokenId` for all events, which is more natural for ERC-721 collections.

**Learning system architecture**: The BEP draft separates learning into a standalone `ILearningModule` interface. NFA-1 includes basic learning state and queries in the core interface (INFA1Core) for simpler adoption, and provides `INFA1LearningModules` as an optional extension for advanced Merkle proof verification, matching the BEP draft's `ILearningModule.verifyLearning()` concept.

**Withdrawal placement**: The BEP draft's reference implementation includes `withdrawFromAgent()` in the core contract. NFA-1 moves it to the optional `INFA1Payment` extension because:
- `fundAgent()` is permissionless (anyone can fund) — this belongs in core
- `withdrawFromAgent()` is owner-only with payment semantics — this fits the Payment extension
- Keeping the core minimal improves Tier 1 adoption

**Upgrade mechanism neutrality**: The BEP draft's reference implementation uses UUPS (`UUPSUpgradeable`). NFA-1 does not mandate any upgrade mechanism, responding to community feedback. The standard defines interfaces, not architecture.

**Gas limit**: The BEP draft specifies `MAX_GAS_FOR_DELEGATECALL = 3,000,000`. NFA-1 recommends 500,000 as a conservative default. Implementations MAY override this value based on their delegated call complexity.

**BEP draft features not in NFA-1**: `IMemoryModuleRegistry` (pluggable memory modules), `IVaultPermissionManager` (off-chain data access control), and `IAgentTemplate` (factory templates) are not included. These are deployment infrastructure rather than agent interface behavior, and may be added as future extensions.

---

## Section 4: Optional Extensions

NFA-1 defines eight optional extension interfaces. Implementations MAY support any combination.

### 4.1 INFA1Lineage — Lineage and Fusion

**Status**: MAY implement

Enables agent breeding, generational tracking, and fusion mechanics.

```solidity
interface INFA1Lineage {
    struct Lineage {
        uint256 parent1;      // 0 for genesis
        uint256 parent2;      // 0 for genesis
        uint256 generation;   // 0 for genesis
        bool isSealed;        // Used in fusion
    }

    event OffspringCreated(uint256 indexed offspringId, uint256 indexed parent1, uint256 indexed parent2, uint256 generation);
    event AgentSealed(uint256 indexed tokenId);
    event AgentBurned(uint256 indexed tokenId);

    function getLineage(uint256 tokenId) external view returns (Lineage memory);
    function getGeneration(uint256 tokenId) external view returns (uint256);
    function isSealed(uint256 tokenId) external view returns (bool);
}
```

**Implementation notes**:
- Fusion SHOULD use a commit-reveal pattern to prevent frontrunning of trait outcomes
- Parent agents MAY be sealed (locked) or burned upon fusion, depending on the implementation's economy design
- Generation is calculated as `max(parent1.generation, parent2.generation) + 1`

### 4.2 INFA1Payment — X402 Payment Compatibility

**Status**: MAY implement

Enables agents to participate in the [X402 payment protocol](https://x402.org) ecosystem for autonomous machine-to-machine payments.

```solidity
interface INFA1Payment {
    event PaymentProcessed(uint256 indexed tokenId, address indexed counterparty, uint256 amount, bytes32 paymentRef);

    function withdrawFromAgent(uint256 tokenId, address payable recipient, uint256 amount) external;
    function getAgentBalance(uint256 tokenId) external view returns (uint256);
}
```

**X402 Payment Flow for NFAs:**

```
1. NFA-backed service returns HTTP 402 + payment requirements
2. Client constructs EIP-712 signed payment authorization
3. Payment references the NFA tokenId as service provider identity
4. Facilitator verifies signature, settles payment on-chain
5. NFA contract receives funds via fundAgent()
6. Contract emits PaymentProcessed / AgentFunded events
```

The agent's vault metadata MAY include X402 support indicators:
```json
{
  "x402": {
    "supported": true,
    "paymentAddress": "0x...",
    "acceptedTokens": ["BNB", "USDT"],
    "minPayment": "0.001"
  }
}
```

### 4.3 INFA1Identity — ERC-8004 Identity Bridge

**Status**: MAY implement

Bridges NFAs to the [ERC-8004 Trustless Agents](https://eips.ethereum.org/EIPS/eip-8004) identity registry ecosystem.

```solidity
interface INFA1Identity {
    event IdentityLinked(uint256 indexed tokenId, address indexed registry, uint256 indexed externalAgentId);
    event IdentityUnlinked(uint256 indexed tokenId, address indexed registry);

    function linkIdentity(uint256 tokenId, address registry, uint256 externalAgentId) external;
    function unlinkIdentity(uint256 tokenId, address registry) external;
    function getLinkedIdentity(uint256 tokenId, address registry) external view returns (uint256 externalAgentId);
}
```

**Bidirectional bridge:**
- NFA → ERC-8004: An NFA token can be linked to an Agent Card in an identity registry, making it discoverable
- ERC-8004 → NFA: An ERC-8004 agent can prove it is backed by a verifiable NFA asset with on-chain learning history

The NFA vault metadata SHOULD include an ERC-8004 Agent Card-compatible structure:
```json
{
  "agentCard": {
    "name": "Agent Name",
    "description": "Agent description",
    "capabilities": ["chat", "analysis", "trading"],
    "endpoint": "https://api.example.com/agent/42",
    "version": "1.0.0"
  }
}
```

### 4.4 INFA1Receipts — Receipts and Audit Trail

**Status**: SHOULD implement (RECOMMENDED)

Creates an immutable on-chain audit trail of agent actions. This is critical for trust and accountability in autonomous agent systems.

```solidity
interface INFA1Receipts {
    struct Receipt {
        uint256 tokenId;
        uint256 timestamp;
        bytes4 actionSelector;   // Function selector of the action
        bytes32 inputHash;       // keccak256 of input data (Verifiably On-Chain)
        bytes32 outputHash;      // keccak256 of output data (Verifiably On-Chain)
        bool success;
    }

    event ReceiptCreated(uint256 indexed tokenId, uint256 indexed receiptIndex, bytes4 actionSelector, bytes32 inputHash, bytes32 outputHash, bool success);

    function getReceiptCount(uint256 tokenId) external view returns (uint256);
    function getReceipt(uint256 tokenId, uint256 index) external view returns (Receipt memory);
}
```

**Data classification**: The receipt struct stores hashes on-chain (Tier 2 — Verifiably On-Chain). The actual input/output data is stored off-chain but verifiable via the on-chain hash commitments. This minimizes gas costs while preserving auditability.

### 4.5 INFA1Compliance — Compliance Metadata

**Status**: MAY implement

Supports enterprise and regulatory compliance requirements. Designed for institutional adoption scenarios.

```solidity
interface INFA1Compliance {
    struct ComplianceMetadata {
        bytes32 kycHash;           // Hash of KYC attestation (Verifiably On-Chain)
        uint256 kycTimestamp;
        address kycProvider;
        uint8 complianceLevel;     // 0=none, 1=basic, 2=enhanced, 3=institutional
        bool sanctionsCleared;
    }

    event ComplianceUpdated(uint256 indexed tokenId, address indexed kycProvider, uint8 complianceLevel);

    function getComplianceMetadata(uint256 tokenId) external view returns (ComplianceMetadata memory);
    function updateCompliance(uint256 tokenId, ComplianceMetadata calldata metadata) external;
}
```

**Privacy**: All sensitive KYC data is stored off-chain. Only the hash attestation goes on-chain (Verifiably On-Chain pattern). The `kycProvider` address serves as a trusted third-party attestation anchor.

### 4.6 INFA1LearningModules — Learning Module Registry and Verification

**Status**: MAY implement

Enables pluggable learning strategies, on-chain Merkle proof verification of learning claims, and quantitative learning metrics.

```solidity
interface INFA1LearningModules {
    struct LearningModule {
        address moduleAddress;
        string moduleType;        // "rag", "finetune", "rl", "hybrid"
        bytes32 configHash;
        bool isActive;
    }

    struct LearningMetrics {
        uint256 totalInteractions;    // Total interactions processed
        uint256 learningEvents;       // Learning-relevant events
        uint256 lastUpdateTimestamp;  // Last metrics update
        uint256 confidenceScore;      // 0-10000 basis points
    }

    event LearningModuleRegistered(uint256 indexed tokenId, address indexed moduleAddress, string moduleType);
    event LearningModuleDeactivated(uint256 indexed tokenId, address indexed moduleAddress);
    event LearningMilestone(uint256 indexed tokenId, string milestone, uint256 value);

    function registerLearningModule(uint256 tokenId, LearningModule calldata module) external;
    function deactivateLearningModule(uint256 tokenId, address moduleAddress) external;
    function getLearningModules(uint256 tokenId) external view returns (LearningModule[] memory);

    // Learning verification
    function verifyLearning(uint256 tokenId, bytes32 claim, bytes32[] calldata proof) external view returns (bool);
    function getLearningMetrics(uint256 tokenId) external view returns (LearningMetrics memory);
}
```

**Supported module types:**
| Type | Description |
|------|-------------|
| `rag` | Retrieval-Augmented Generation — agent retrieves from a knowledge base |
| `finetune` | Fine-tuning — agent's base model is periodically retrained |
| `rl` | Reinforcement Learning — agent improves via reward signals |
| `hybrid` | Combination of multiple approaches |

**Learning Verification**: The `verifyLearning()` function enables on-chain Merkle proof verification. Given a leaf hash (`claim`) and a Merkle proof, it verifies the claim against the agent's current `learningRoot` from INFA1Core. This enables trustless verification that a specific piece of learning data exists in the agent's learning tree.

**Learning Metrics**: The `LearningMetrics` struct tracks quantitative learning progress. The `confidenceScore` (0-10000 basis points) provides a standardized measure of learning maturity. Milestones (e.g., "100_interactions", "confidence_90") are emitted as events to mark significant learning achievements.

### 4.7 INFA1CircuitBreaker — Emergency Circuit Breaker

**Status**: SHOULD implement (RECOMMENDED for production deployments)

Provides ecosystem-wide and per-agent emergency pause capability, independent of individual agent lifecycle pause.

```solidity
interface INFA1CircuitBreaker {
    event GlobalPauseUpdated(bool paused);
    event AgentCircuitBreakerUpdated(uint256 indexed tokenId, bool paused);

    function isGloballyPaused() external view returns (bool);
    function isCircuitBroken(uint256 tokenId) external view returns (bool);
    function setGlobalPause(bool paused) external;
    function setAgentCircuitBreaker(uint256 tokenId, bool paused) external;
}
```

**Key distinction from INFA1Core.pause()**:

| Aspect | INFA1Core.pause() | INFA1CircuitBreaker |
|--------|-------------------|---------------------|
| Scope | Single agent | Global or per-agent |
| Authority | Token owner | Governance / emergency multi-sig |
| Purpose | Owner choice | Emergency response |
| Reversibility | Owner can unpause | Governance can restore |

An agent can be Active (lifecycle) but circuit-broken (emergency). When the circuit breaker is active, `executeAction()` SHOULD revert even if the agent's lifecycle status is Active.

**Implementation note**: The official BAP-578 uses a contract-level `paused` flag with `emergencyWithdraw()`. NFA-1 generalizes this into a dedicated circuit breaker extension supporting both global and per-agent granularity.

---

## Section 5: Security Requirements

### 5.1 MUST (Required)

| ID | Requirement |
|----|-------------|
| S-01 | **Least-privilege default**: Agents MUST have no permissions beyond what is explicitly granted |
| S-02 | **Gas limits**: Delegated calls via `executeAction` SHOULD enforce a gas cap to prevent griefing |
| S-03 | **Irreversible termination**: Once Terminated, an agent MUST NOT be reactivable under any code path |
| S-04 | **State gating**: `executeAction` MUST revert if status is not Active |
| S-05 | **Monotonic learning versions**: `learningVersion` MUST only increase; MUST reject same or lower versions |
| S-06 | **Paused transferability**: Paused agents MUST remain transferable via standard ERC-721 functions |
| S-07 | **Learning disabled on termination**: `terminate()` MUST set `learningEnabled = false` |

### 5.2 SHOULD (Recommended)

| ID | Requirement |
|----|-------------|
| S-08 | **Circuit breaker**: Implement the INFA1CircuitBreaker extension for emergency global/per-agent pause |
| S-09 | **Progressive autonomy**: Start agents with limited permissions and expand based on trust |
| S-10 | **Audit trail**: Implement INFA1Receipts extension for action accountability |
| S-11 | **Sandbox execution**: Logic contracts SHOULD be isolated and unable to affect other agents' state |
| S-12 | **Reentrancy protection**: State-modifying functions SHOULD use reentrancy guards |

### 5.3 MAY (Optional)

| ID | Requirement |
|----|-------------|
| S-13 | Multi-signature governance for critical operations |
| S-14 | Time-locked upgrades for logic contract changes |
| S-15 | Spending limits on agent balance withdrawals |
| S-16 | Rate limiting on action execution frequency |
| S-17 | Vault permission management — access control for off-chain vault data to prevent unauthorized reads of sensitive agent data |

---

## Section 6: Upgradeability Statement

> **NFA-1 does not mandate any specific upgrade mechanism.**

This is a deliberate design choice. The standard defines the interfaces and behaviors (the *what*), not the implementation architecture (the *how*). Different applications have different needs:

| Pattern | Use Case |
|---------|----------|
| **Immutable** | Maximum trustlessness; no upgrade possible after deployment |
| **UUPS Proxy** | Lightweight upgradeability; upgrade logic lives in the implementation |
| **Transparent Proxy** | Clear separation between proxy admin and users |
| **Diamond (EIP-2535)** | Modular upgradeability; individual facets can be upgraded |
| **Beacon Proxy** | Multiple proxies sharing the same implementation; single-point upgrades |
| **Create2 Redeployment** | Fresh deployments with deterministic addresses |

Any of the above MAY be used, provided:

1. The deployed contract satisfies the `INFA1Core` interface
2. `terminate()` irreversibility is preserved across upgrades — a Terminated agent MUST remain Terminated after any upgrade
3. `learningVersion` monotonicity is preserved across upgrades — the version counter MUST NOT decrease after any upgrade
4. ERC-165 `supportsInterface` continues to return `true` for `INFA1Core` after any upgrade

Implementations that use upgradeability SHOULD document their upgrade mechanism and governance process.

---

## Section 7: Compliance Tiers

NFA-1 defines four compliance tiers. See the full [NFA-1 Compliance Checklist](../checklist/NFA1-CHECKLIST.md) for detailed item-by-item verification.

### Tier 1 — Minimum Viable NFA (MUST pass all)

The absolute minimum to call a token an NFA. Covers: ERC-721 compliance, Status enum, state transitions, paused transferability, core state queries, vaultHash integrity anchor, lifecycle functions, irreversible termination, core events, and ERC-165.

**12 items (C-01 through C-12)**

### Tier 2 — Learning-Enabled NFA (SHOULD pass all)

Adds the learning system. Covers: LearningState struct, monotonic version enforcement, LearningUpdated events, learning query functions, termination disables learning, documented learning path (A or B), and verification flow.

**7 items (L-01 through L-07)**

### Tier 3 — Autonomous NFA (MAY)

Adds action execution capability. Covers: executeAction, gas limits, setLogicAddress, fundAgent, action events, lastActionTimestamp tracking, and non-Active rejection.

**7 items (A-01 through A-07)**

### Tier 4 — Full-Stack NFA (Optional extensions)

Any combination of the eight optional extensions. Each extension has its own sub-items.

**8 extension groups (E-01 through E-08)**

---

## Section 8: Cross-Protocol Integration

NFA-1 is designed to compose with the emerging AI agent protocol stack:

```
┌─────────────────────────────────────────────────────┐
│                    Application Layer                  │
│         (Agent UIs, Dashboards, Marketplaces)        │
├─────────────────────────────────────────────────────┤
│                   A2A / MCP Layer                     │
│          (Agent-to-Agent Communication)              │
├──────────┬──────────┬──────────┬────────────────────┤
│  NFA-1   │ ERC-8004 │   X402   │    Other Protocols  │
│ (Ownable │ (Agent   │ (Machine │                     │
│  Agents) │ Identity)│ Payments)│                     │
├──────────┴──────────┴──────────┴────────────────────┤
│                    ERC-721 / EVM                      │
│              (Ownership & Transfers)                  │
└─────────────────────────────────────────────────────┘
```

### 8.1 NFA-1 ↔ ERC-8004

| NFA-1 Concept | ERC-8004 Mapping |
|---------------|-----------------|
| tokenId | Agent ID in registry |
| AgentMetadata.persona | Agent Card description |
| AgentMetadata.vaultURI | Agent Card endpoint |
| INFA1Identity.linkIdentity() | Registration in identity registry |

### 8.2 NFA-1 ↔ X402

| NFA-1 Concept | X402 Mapping |
|---------------|-------------|
| tokenId | Service provider identity |
| fundAgent() | Payment settlement |
| INFA1Payment.withdrawFromAgent() | Revenue collection |
| AgentMetadata.vaultURI | Service endpoint (returns 402) |

### 8.3 NFA-1 ↔ A2A

| NFA-1 Concept | A2A Mapping |
|---------------|------------|
| AgentMetadata | Agent Card (discovery) |
| executeAction() | Task execution |
| INFA1Receipts | Action audit trail |
| learningRoot | Capability attestation |

### 8.4 Cross-Chain Considerations

NFA-1 is designed to be EVM-agnostic and deployable on any EVM-compatible chain. For multi-chain deployments:

**Same-chain**: Standard NFA-1 contracts work as-is on any single EVM chain (BNB Chain, Ethereum, Polygon, Arbitrum, etc.).

**Cross-chain agent portability**: For agents that need to operate across multiple chains, implementations MAY integrate with cross-chain messaging protocols:

| Protocol | Use Case |
|----------|----------|
| **Hyperlane** | Permissionless interchain messaging; enables agent state sync across 100+ chains |
| **LayerZero** | Omnichain messaging for cross-chain agent operations |
| **Wormhole** | Cross-chain asset and message transfers |
| **Chainlink CCIP** | Secure cross-chain interoperability |

**Cross-chain design principles:**
- The canonical agent state (ownership, Status, learningRoot) SHOULD live on one "home chain"
- Cross-chain operations SHOULD reference the home chain state via message passing
- Learning updates SHOULD only be accepted on the home chain to preserve monotonic versioning
- The `vaultURI` and `vaultHash` verification architecture naturally supports cross-chain scenarios: the hash is on the home chain, the vault data is accessible from any chain

NFA-1 does not mandate a specific cross-chain solution. This is left to implementations based on their target chain ecosystem.

---

## Section 9: Reference Implementation

### 9.1 Known Compliant Implementations

**KinForge (BNB Chain)**
First known NFA-1 compliant deployment. Implements the full BAP-578 BEP draft specification.

- Contract: `HouseForgeAgent.sol`
- Network: BNB Chain Mainnet
- Compliance: Tier 1 + Tier 2 + Tier 3 + partial Tier 4 (Lineage)
- 1300+ minted agents with active learning system

See [BAP-578 Compliance Mapping](../compliance/BAP578-COMPLIANCE.md) for item-by-item verification.

### 9.2 Minimal Implementation

A minimal Tier 1 reference implementation is provided at [`contracts/examples/MinimalNFA.sol`](../contracts/examples/MinimalNFA.sol). This implementation:

- Satisfies all Tier 1 compliance items (C-01 through C-12)
- Includes Tier 2 (learning) and Tier 3 (action execution) for completeness
- Uses OpenZeppelin ERC-721 as the base
- Is intentionally simple for educational purposes
- Should NOT be used in production without additional security measures

---

## Section 10: Design Rationale

### 10.1 Why Hybrid Storage (On-Chain + Verifiably On-Chain)?

AI agent data is large: conversation histories, model configurations, knowledge bases, and training data can easily exceed megabytes. Storing all of this on-chain would cost thousands of dollars in gas fees and is not economically viable.

The Verifiably On-Chain pattern gives the best of both worlds:
- **Cost**: Off-chain storage (IPFS, Arweave, centralized servers) at off-chain prices
- **Integrity**: On-chain hash commitment means anyone can verify the data hasn't been tampered with
- **Privacy**: Sensitive data stays off-chain; only the hash goes on-chain

### 10.2 Why Monotonic Learning Versions?

The `learningVersion` counter MUST only increase to prevent:
- **Replay attacks**: An attacker cannot revert an agent to a previous (less capable) learning state
- **Version conflicts**: Concurrent updates are serialized by version number
- **Audit integrity**: The version sequence provides a clear, linear history of learning progression

### 10.3 Why Three States (Active/Paused/Terminated)?

Two states (Active/Terminated) would be insufficient because:
- **Paused** enables temporary suspension without permanent consequences (e.g., during maintenance, ownership disputes, or security incidents)
- **Paused with transferability** ensures an agent remains a liquid asset even when suspended

Three states were preferred over more granular states (e.g., Dormant, Restricted) to keep the standard simple and universally applicable.

### 10.4 Why Paused Agents MUST Be Transferable

If paused agents were non-transferable, a malicious implementation could permanently lock assets by pausing them. The transferability requirement ensures:
- Asset liquidity is always preserved
- Owners can always exit their position
- Marketplace compatibility (agents can always be listed/sold)

### 10.5 Why Not Mandate UUPS?

Mandating a specific upgrade mechanism would:
- **Limit adoption**: Projects with different upgrade needs would be non-compliant
- **Mix concerns**: The standard defines behavior, not implementation architecture
- **Reduce trustlessness**: Some use cases (e.g., fully decentralized agents) require immutable contracts

By defining interfaces only, the standard lets builders choose the upgrade mechanism (or none) that fits their application.

### 10.6 Why Separate Action Execution from Learning?

Action execution (`executeAction`) and learning (`updateLearning`) serve fundamentally different purposes:
- **Actions** are synchronous, on-chain, gas-consuming operations with immediate effects
- **Learning** is asynchronous, primarily off-chain, with on-chain state limited to hash commitments

Separating them allows:
- Different authorization models (actions by owner, learning by backend oracle)
- Independent evolution (learning system can be upgraded without affecting action execution)
- Clearer security boundaries (action execution requires tighter controls)

### 10.7 Gas Efficiency Through Hybrid Architecture

The NFA-1 hybrid storage model (On-Chain + Verifiably On-Chain) achieves significant gas savings compared to full on-chain storage:

- **Learning updates**: Only a 32-byte Merkle root is written on-chain per learning update, regardless of how much data was learned off-chain. A single `SSTORE` (≈20,000 gas) anchors potentially megabytes of off-chain data.
- **Vault integrity**: The `vaultHash` (32 bytes) anchors the entire vault JSON (which could be kilobytes to megabytes), avoiding on-chain string storage.
- **Metadata minimization**: Only essential identity fields are stored on-chain; detailed persona data, conversation history, and training configurations live in the vault.

This architecture enables 80-90% gas savings compared to naive full on-chain approaches, while maintaining cryptographic verifiability.

### 10.8 Factory Patterns and Governance

While NFA-1 does not standardize factory or governance contracts, production deployments SHOULD consider:

**Agent Factory**: A factory contract that manages:
- Template approval and versioning for different agent types
- Learning module registration and approval
- Global learning statistics across all agents
- Standardized agent deployment with consistent initialization

**On-chain Governance**: For protocol-level decisions:
- Proposal/voting/execution for parameter changes
- Circuit breaker activation (via INFA1CircuitBreaker)
- Template and module approval

These are implementation concerns, not standard requirements, because their design varies significantly based on the project's governance model and deployment architecture.

---

## Section 11: Security Considerations

### 11.1 Logic Contract Risks

The `executeAction` function delegates calls to an arbitrary `logicAddress`. This is the highest-risk function in the standard:

- **Malicious logic**: A compromised logic contract could drain the agent's balance or perform unauthorized actions
- **Reentrancy**: The delegated call could re-enter the NFA contract
- **Gas griefing**: An unbounded delegated call could consume all available gas

**Mitigations:**
- Implementations SHOULD enforce gas limits on delegated calls
- Implementations SHOULD use reentrancy guards (e.g., OpenZeppelin's `ReentrancyGuard`)
- Logic contract changes SHOULD have a time-lock or multi-sig requirement for high-value agents

### 11.2 Learning System Trust Model

The learning system trusts the designated learning updater to submit accurate learning roots. A compromised updater could:

- Submit incorrect learning roots (data integrity attack)
- Rapidly increment versions (denial of future updates if version space is exhausted)

**Mitigations:**
- Learning updater role should be carefully managed
- Implementations MAY require learning updates to be validated by multiple parties
- The monotonic version requirement prevents rollback attacks

### 11.3 Front-Running in Fusion

For implementations that support the Lineage extension, fusion operations that involve randomness (trait inheritance) are vulnerable to front-running:

- A miner/validator could observe a pending fusion transaction and manipulate block parameters to influence trait outcomes

**Mitigation**: Use a commit-reveal pattern for fusion. The user commits a hash of their choice, waits N blocks, then reveals. This prevents front-running.

### 11.4 Vault URI Availability

The `vaultURI` pointing to off-chain data introduces a centralization risk:

- If the vault hosting provider goes offline, the agent's data becomes inaccessible
- The on-chain `vaultHash` proves what the data *should* be, but doesn't provide access to it

**Mitigations:**
- Use decentralized storage (IPFS, Arweave) for vault data
- Maintain redundant copies across multiple hosting providers
- The `vaultHash` on-chain ensures integrity can always be verified once data is available

### 11.5 Vault Data Access Control

While `vaultHash` ensures integrity, it does not control who can read the vault data. Agents with sensitive data (proprietary training configurations, private conversations) need access control:

- Vault hosting providers SHOULD implement authentication for vault read access
- Implementations MAY use encryption with owner-controlled keys for sensitive vault fields
- A VaultPermissionManager pattern (granting read access to specific addresses) MAY be used for controlled disclosure
- Public vault data (persona, capabilities) SHOULD be separable from private vault data (conversation history, training config)

---

## Section 12: Backwards Compatibility

NFA-1 is fully backwards compatible with ERC-721. Any NFA-1 compliant contract is also a valid ERC-721 contract. This means:

- NFAs are compatible with all existing ERC-721 infrastructure (wallets, marketplaces, explorers)
- Existing ERC-721 tools can transfer, approve, and query NFAs
- The additional NFA-1 functions are additive and do not modify ERC-721 behavior

For implementations building on existing ERC-721 contracts, the NFA-1 functions can be added via:
- Direct inheritance (add INFA1Core to the contract)
- Proxy pattern (add NFA-1 functions in a new implementation)
- Diamond pattern (add NFA-1 as a new facet)

---

## Section 13: Copyright

This specification is released under [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/). To the extent possible under law, the authors have waived all copyright and related or neighboring rights to this work.
