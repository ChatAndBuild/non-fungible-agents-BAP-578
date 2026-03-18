# NFA-1 Compliance Checklist

A structured, tiered checklist for verifying NFA-1 standard compliance.
Use this to audit your own implementation or evaluate third-party NFA contracts.

**How to use**: Check each item. All items in a tier must pass to claim that tier.

---

## Tier 1 — Minimum Viable NFA (MUST pass all 12)

> The absolute minimum to call a token an NFA.

| ID | Requirement | Check |
|----|------------|-------|
| **C-01** | Contract implements ERC-721 (balanceOf, ownerOf, transferFrom, safeTransferFrom, approve, getApproved, setApprovalForAll, isApprovedForAll) | [ ] |
| **C-02** | Contract defines `Status` enum with exactly three values: `Active` (0), `Paused` (1), `Terminated` (2) | [ ] |
| **C-03** | State transitions follow the rules: Active↔Paused (reversible), Active/Paused→Terminated (irreversible), Terminated→* (prohibited) | [ ] |
| **C-04** | Paused agents remain transferable via standard ERC-721 transfer functions | [ ] |
| **C-05** | `getState(tokenId)` returns a `State` struct with: balance, status, owner, logicAddress, lastActionTimestamp. The `owner` field MUST reflect the current ERC-721 `ownerOf()` | [ ] |
| **C-06** | `getAgentMetadata(tokenId)` returns an `AgentMetadata` struct with: persona, experience, voiceHash, animationURI, vaultURI, vaultHash | [ ] |
| **C-07** | `vaultHash` (bytes32) is stored on-chain and serves as the integrity anchor for off-chain vault data | [ ] |
| **C-08** | `pause(tokenId)`, `unpause(tokenId)`, and `terminate(tokenId)` are implemented with proper authorization (owner or approved) | [ ] |
| **C-09** | `terminate()` is irreversible — no code path can change status from Terminated to any other state | [ ] |
| **C-10** | All 6 core events are emitted at the correct points: `ActionExecuted`, `LogicUpgraded`, `AgentFunded`, `StatusChanged`, `MetadataUpdated`, `LearningUpdated` | [ ] |
| **C-11** | Contract implements ERC-165 (`supportsInterface`) and returns `true` for the `INFA1Core` interface ID | [ ] |
| **C-12** | `updateAgentMetadata(tokenId, metadata)` reverts if agent is Terminated and emits `MetadataUpdated` | [ ] |

---

## Tier 2 — Learning-Enabled NFA (SHOULD pass all 7)

> Adds the on-chain learning commitment system.

| ID | Requirement | Check |
|----|------------|-------|
| **L-01** | `LearningState` struct is implemented with: learningRoot (bytes32), learningVersion (uint256), lastLearningUpdate (uint256), learningEnabled (bool) | [ ] |
| **L-02** | `updateLearning()` enforces monotonic versioning — reverts if `newVersion <= currentVersion` | [ ] |
| **L-03** | `updateLearning()` emits `LearningUpdated` with old root, new root, and new version | [ ] |
| **L-04** | All learning query functions are implemented: `getLearningRoot()`, `isLearningEnabled()`, `getLearningVersion()`, `getLastLearningUpdate()` | [ ] |
| **L-05** | `terminate()` sets `learningEnabled = false`, preventing post-termination learning updates | [ ] |
| **L-06** | Implementation documents which learning root computation path is used (Path A: JSON Light Memory, or Path B: Merkle Tree Learning) | [ ] |
| **L-07** | Implementation provides a verification flow: given vault data, users can recompute and verify the on-chain learningRoot | [ ] |

---

## Tier 3 — Autonomous NFA (MAY)

> Adds delegated action execution capability.

| ID | Requirement | Check |
|----|------------|-------|
| **A-01** | `executeAction(tokenId, data)` is implemented and delegates calls to the `logicAddress` | [ ] |
| **A-02** | `executeAction()` enforces a gas limit on the delegated call (SHOULD cap at a configurable maximum) | [ ] |
| **A-03** | `setLogicAddress(tokenId, newLogic)` allows updating the logic contract; accepts `address(0)` to disable | [ ] |
| **A-04** | `fundAgent(tokenId)` accepts native currency and increases the agent's internal balance; callable by anyone | [ ] |
| **A-05** | `executeAction()` emits `ActionExecuted`; `setLogicAddress()` emits `LogicUpgraded`; `fundAgent()` emits `AgentFunded` | [ ] |
| **A-06** | `executeAction()` updates `lastActionTimestamp` to `block.timestamp` | [ ] |
| **A-07** | `executeAction()` reverts if agent status is not Active; reverts if `logicAddress == address(0)` | [ ] |

---

## Tier 4 — Full-Stack NFA (Optional Extensions)

> Any combination of the eight optional extension groups. Check the extensions your implementation supports.

### E-01: Lineage and Fusion (INFA1Lineage)

| ID | Requirement | Check |
|----|------------|-------|
| E-01a | `Lineage` struct implemented with: parent1, parent2, generation, isSealed | [ ] |
| E-01b | `getLineage(tokenId)` returns the lineage data | [ ] |
| E-01c | `getGeneration(tokenId)` returns the generation number (0 for genesis) | [ ] |
| E-01d | `isSealed(tokenId)` returns whether the agent has been used in fusion | [ ] |
| E-01e | `OffspringCreated` event emitted when a new agent is created via fusion | [ ] |
| E-01f | Generation is calculated as `max(parent1.generation, parent2.generation) + 1` | [ ] |
| E-01g | Fusion uses commit-reveal pattern to prevent frontrunning (RECOMMENDED) | [ ] |

### E-02: X402 Payment Compatibility (INFA1Payment)

| ID | Requirement | Check |
|----|------------|-------|
| E-02a | `withdrawFromAgent(tokenId, recipient, amount)` allows owner to withdraw funds | [ ] |
| E-02b | `getAgentBalance(tokenId)` returns the agent's current spendable balance | [ ] |
| E-02c | `PaymentProcessed` event emitted for payment operations | [ ] |
| E-02d | Withdrawal reverts if amount exceeds agent balance | [ ] |

### E-03: ERC-8004 Identity Bridge (INFA1Identity)

| ID | Requirement | Check |
|----|------------|-------|
| E-03a | `linkIdentity(tokenId, registry, externalAgentId)` links NFA to an identity registry | [ ] |
| E-03b | `unlinkIdentity(tokenId, registry)` removes a linked identity | [ ] |
| E-03c | `getLinkedIdentity(tokenId, registry)` returns the agent ID for a specific registry | [ ] |
| E-03d | Identity operations are restricted to token owner | [ ] |
| E-03e | `IdentityLinked` and `IdentityUnlinked` events emitted | [ ] |

### E-04: Receipts and Audit Trail (INFA1Receipts) — RECOMMENDED

| ID | Requirement | Check |
|----|------------|-------|
| E-04a | `Receipt` struct implemented with: tokenId, timestamp, actionSelector, inputHash, outputHash, success | [ ] |
| E-04b | `getReceiptCount(tokenId)` returns total receipts for an agent | [ ] |
| E-04c | `getReceipt(tokenId, index)` returns a specific receipt | [ ] |
| E-04d | `ReceiptCreated` event emitted for each receipt | [ ] |
| E-04e | Receipts store hashes only (not raw data) — Verifiably On-Chain pattern | [ ] |

### E-05: Compliance Metadata (INFA1Compliance)

| ID | Requirement | Check |
|----|------------|-------|
| E-05a | `ComplianceMetadata` struct with: kycHash, kycTimestamp, kycProvider, complianceLevel, sanctionsCleared | [ ] |
| E-05b | `getComplianceMetadata(tokenId)` returns compliance data | [ ] |
| E-05c | `updateCompliance(tokenId, metadata)` updates compliance data | [ ] |
| E-05d | `ComplianceUpdated` event emitted | [ ] |
| E-05e | KYC data is stored off-chain; only hash goes on-chain (Verifiably On-Chain) | [ ] |

### E-06: Learning Module Registry (INFA1LearningModules)

| ID | Requirement | Check |
|----|------------|-------|
| E-06a | `LearningModule` struct with: moduleAddress, moduleType, configHash, isActive | [ ] |
| E-06b | `registerLearningModule(tokenId, module)` registers a learning module | [ ] |
| E-06c | `deactivateLearningModule(tokenId, moduleAddress)` deactivates a module | [ ] |
| E-06d | `getLearningModules(tokenId)` returns all registered modules | [ ] |
| E-06e | `LearningModuleRegistered` and `LearningModuleDeactivated` events emitted | [ ] |
| E-06f | `LearningMetrics` struct with: totalInteractions, learningEvents, lastUpdateTimestamp, confidenceScore | [ ] |
| E-06g | `verifyLearning(tokenId, claim, proof)` verifies Merkle proof against learning root | [ ] |
| E-06h | `getLearningMetrics(tokenId)` returns learning metrics | [ ] |
| E-06i | `LearningMilestone` event emitted for significant learning achievements | [ ] |

### E-07: Proof-of-Prompt

| ID | Requirement | Check |
|----|------------|-------|
| E-07a | `proofOfPromptHash` (bytes32) is submitted at mint time | [ ] |
| E-07b | `proofOfPromptHash` is immutable after mint (no setter function) | [ ] |
| E-07c | Off-chain PoP document includes: model, systemPromptHash, configHash, trainingDataHash | [ ] |

### E-08: Circuit Breaker (INFA1CircuitBreaker) — RECOMMENDED

| ID | Requirement | Check |
|----|------------|-------|
| E-08a | `isGloballyPaused()` returns whether the global circuit breaker is active | [ ] |
| E-08b | `isCircuitBroken(tokenId)` returns whether a specific agent is circuit-broken | [ ] |
| E-08c | `setGlobalPause(bool)` activates/deactivates global pause (governance/emergency only) | [ ] |
| E-08d | `setAgentCircuitBreaker(tokenId, bool)` activates/deactivates per-agent circuit breaker | [ ] |
| E-08e | `GlobalPauseUpdated` and `AgentCircuitBreakerUpdated` events emitted | [ ] |

---

## Compliance Summary Template

Use this template to declare your implementation's compliance level:

```
Contract: [Contract Name]
Network:  [Chain Name]
Address:  [0x...]

Tier 1 (Minimum Viable NFA): [PASS / FAIL] ([X]/12 items)
Tier 2 (Learning-Enabled):   [PASS / FAIL] ([X]/7 items)
Tier 3 (Autonomous):         [PASS / FAIL] ([X]/7 items)
Tier 4 Extensions:
  - Lineage (E-01):           [PASS / N/A] ([X]/7 items)
  - Payment (E-02):           [PASS / N/A] ([X]/4 items)
  - Identity (E-03):          [PASS / N/A] ([X]/5 items)
  - Receipts (E-04):          [PASS / N/A] ([X]/5 items)
  - Compliance (E-05):        [PASS / N/A] ([X]/5 items)
  - Learning Modules (E-06):  [PASS / N/A] ([X]/9 items)
  - Proof-of-Prompt (E-07):   [PASS / N/A] ([X]/3 items)
  - Circuit Breaker (E-08):   [PASS / N/A] ([X]/5 items)
```

---

## Version

Checklist version: 1.4 (aligned with NFA-1 Draft Specification v1.4, 2026-02-08)
