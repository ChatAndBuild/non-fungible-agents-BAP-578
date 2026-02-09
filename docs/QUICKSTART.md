# NFA-1 Quick Start Guide

Build your first NFA-1 compliant Non-Fungible Agent in under 10 minutes.

> **Note**: This guide uses the [Foundry](https://book.getfoundry.sh/) framework. The full reference implementation (MinimalNFA, tests, deployment scripts) is available at [KinForgeLab/NFA-1](https://github.com/KinForgeLab/NFA-1). The Solidity interfaces in this repo (`contracts/interfaces/`) are framework-agnostic and work with both Hardhat and Foundry.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (forge, cast, anvil)
- Git

## 1. Clone & Install

```bash
git clone https://github.com/KinForgeLab/NFA-1.git
cd NFA-1
forge install
forge build
```

## 2. Run Tests

```bash
# All tests (130 tests: unit + fuzz + invariant + gas + verifier)
forge test

# Gas report
forge test --match-contract MinimalNFAGasTest --gas-report

# Specific tier
forge test --match-test "test_C"   # Tier 1 (Core)
forge test --match-test "test_L"   # Tier 2 (Learning)
forge test --match-test "test_A"   # Tier 3 (Actions)
```

## 3. Understand the Architecture

```
Your NFA Contract
├── ERC-721 (ownership, transfers, approvals)
├── INFA1Core (required interface)
│   ├── State      — balance, status, owner, logicAddress, lastActionTimestamp
│   ├── AgentMetadata — persona, experience, voiceHash, animationURI, vaultURI, vaultHash
│   ├── LearningState — learningRoot, learningVersion, lastLearningUpdate, learningEnabled
│   ├── Lifecycle   — pause(), unpause(), terminate()
│   ├── Actions     — executeAction(), setLogicAddress()
│   ├── Funding     — fundAgent()
│   └── Learning    — updateLearning(), getLearningRoot(), ...
└── Optional Extensions (INFA1Lineage, INFA1Payment, etc.)
```

## 4. Build Your Own NFA

### Option A: Use the MyAgent template (fastest — recommended)

Edit `contracts/examples/MyAgent.sol` — search for `TODO` comments and customize:

```solidity
contract MyAgent is MinimalNFA, Ownable {

    // ====================== TODO: CUSTOMIZE THESE ======================

    string private constant NAME = "My NFA Collection";  // TODO: Change this
    string private constant SYMBOL = "MNFA";              // TODO: Change this
    uint256 public constant MAX_SUPPLY = 10_000;          // TODO: Change this
    uint256 public constant MINT_PRICE = 0.01 ether;      // TODO: Change this
    uint256 public constant MAX_PER_WALLET = 5;            // TODO: Change this

    // ... publicMint, ownerMint, withdraw already included
}
```

That's it. The template inherits MinimalNFA (Tier 1-3 compliant) and adds:
- Ownable access control
- Public mint with price, supply cap, and per-wallet limit
- Owner mint (free, for airdrops/team)
- Withdraw function
- Mint toggle (open/close)

### Option B: Use the upgradeable template (recommended for production)

If you need to upgrade your contract after deployment (fix bugs, add features),
use `MyAgentUpgradeable.sol` instead — same TODO markers, but with UUPS proxy:

```solidity
contract MyAgentUpgradeable is MinimalNFAUpgradeable {
    // Same TODO markers as MyAgent.sol
    // Deployed via ERC1967Proxy — owner can upgrade later
}
```

Deploy with the upgradeable script:

```bash
forge script script/DeployUpgradeable.s.sol --rpc-url <RPC> --broadcast
```

To upgrade later:
1. Deploy new implementation: `forge create MyAgentUpgradeableV2 ...`
2. Call proxy: `cast send <PROXY> "upgradeToAndCall(address,bytes)" <NEW_IMPL> 0x ...`

### Option C: Extend MinimalNFA directly

For more control, inherit MinimalNFA and add your own logic:

```solidity
import "./MinimalNFA.sol";

contract CustomAgent is MinimalNFA {
    // Add your own minting, access control, extensions, etc.
}
```

### Option D: Implement INFA1Core from scratch

```solidity
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../interfaces/INFA1Core.sol";

contract ProductionNFA is ERC721, INFA1Core {
    // Implement all 15 INFA1Core functions
    // See MinimalNFA.sol for reference implementation
}
```

### Required functions (15 total):

| Function | Category | Notes |
|----------|----------|-------|
| `executeAction(uint256,bytes)` | Action | Forward calls to logic contract |
| `setLogicAddress(uint256,address)` | Action | Owner/approved only |
| `fundAgent(uint256)` | Funding | Permissionless, payable |
| `pause(uint256)` | Lifecycle | Active → Paused |
| `unpause(uint256)` | Lifecycle | Paused → Active |
| `terminate(uint256)` | Lifecycle | → Terminated (irreversible) |
| `getState(uint256)` | Query | Returns State struct |
| `getAgentMetadata(uint256)` | Query | Returns AgentMetadata struct |
| `getLearningState(uint256)` | Query | Returns LearningState struct |
| `updateAgentMetadata(uint256,AgentMetadata)` | Metadata | Owner/approved only |
| `updateLearning(uint256,string,bytes32,bytes32,uint256)` | Learning | Version must increase |
| `getLearningRoot(uint256)` | Learning | Merkle root query |
| `isLearningEnabled(uint256)` | Learning | Boolean query |
| `getLearningVersion(uint256)` | Learning | Version query |
| `getLastLearningUpdate(uint256)` | Learning | Timestamp query |

## 5. Key Rules (Don't Break These)

1. **Terminate is IRREVERSIBLE** — Once terminated, the agent can never be unpaused or reactivated
2. **Paused agents MUST be transferable** — Don't add transfer restrictions for paused agents
3. **Version MUST increase** — `updateLearning` rejects same or lower version numbers
4. **ERC-165 MUST report INFA1Core** — `supportsInterface(type(INFA1Core).interfaceId)` must return true
5. **fundAgent is permissionless** — Anyone can fund any agent (don't add auth)
6. **Cap gas on executeAction** — Always limit gas forwarded to logic contracts (default: 500,000)

## 6. Deploy

```bash
# Start local node
anvil

# Deploy (in another terminal)
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

The deploy script automatically:
1. Deploys your MyAgent contract + NFA1Verifier
2. Runs a self-verification check (must pass Tier 3)
3. Opens minting (remove `nfa.setMintOpen(true)` in Deploy.s.sol if you want to open later)

## 7. Verify Compliance

After deploying, verify your contract on-chain:

```bash
# Quick check (is it NFA-1? what tier?)
cast call <VERIFIER_ADDRESS> "quickCheck(address)(bool,uint8)" <YOUR_NFA_ADDRESS> --rpc-url <RPC>

# Full audit report
cast call <VERIFIER_ADDRESS> "fullAudit(address)" <YOUR_NFA_ADDRESS> --rpc-url <RPC>
```

Or use the off-chain audit tool:

```bash
node tools/nfa1-audit.js --rpc <RPC_URL> --address <YOUR_NFA_ADDRESS>
```

## 8. Compliance Tiers

| Tier | Requirements | Items |
|------|-------------|-------|
| **Tier 1** (Core) | ERC-721, Status enum, State/Metadata structs, lifecycle, ERC-165 | C-01 to C-12 |
| **Tier 2** (Learning) | LearningState, version monotonicity, learning queries | L-01 to L-07 |
| **Tier 3** (Actions) | executeAction, gas capping, setLogicAddress, fundAgent | A-01 to A-07 |
| **Tier 4** (Extensions) | Optional: Lineage, Payment, Identity, Receipts, Compliance, LearningModules, PoP, CircuitBreaker | E-01 to E-08 |

MinimalNFA.sol implements Tiers 1-3 out of the box.

## 9. Project Structure

```
nfa-standard/
├── contracts/
│   ├── interfaces/          # 8 Solidity interfaces
│   │   ├── INFA1Core.sol    # Required core interface
│   │   ├── INFA1Lineage.sol # Optional: breeding/fusion
│   │   ├── INFA1Payment.sol # Optional: withdrawals
│   │   └── ...              # 5 more optional extensions
│   ├── examples/
│   │   ├── MinimalNFA.sol   # Reference implementation (Tier 1-3)
│   │   └── MyAgent.sol      # Deployment template (fork this!)
│   └── tools/
│       └── NFA1Verifier.sol # On-chain compliance checker
├── test/                    # Foundry tests (130 total)
├── spec/                    # NFA-1 specification (EN + 中文)
├── checklist/               # Compliance checklist
├── tools/
│   └── nfa1-audit.js        # Off-chain audit script
├── script/
│   └── Deploy.s.sol         # Deployment script
└── QUICKSTART.md            # This file
```

## 10. Getting Help

- Spec (English): [`spec/NFA-1.md`](spec/NFA-1.md)
- Spec (中文): [`spec/NFA-1_zh.md`](spec/NFA-1_zh.md)
- Compliance checklist: [`checklist/NFA1-CHECKLIST.md`](checklist/NFA1-CHECKLIST.md)
- BAP-578 BEP Draft: https://github.com/bnb-chain/BEPs/blob/master/BAPs/BAP-578.md

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Blocking transfers when paused | Remove transfer restriction for paused status |
| Making terminate reversible | Never add unpause/reactivate path from Terminated |
| Allowing version to stay same | Use strict `>` not `>=` in updateLearning |
| Missing supportsInterface | Override and return true for `type(INFA1Core).interfaceId` |
| No gas cap on executeAction | Always use gas limit (recommend 500K) |
| Auth on fundAgent | fundAgent MUST be callable by anyone |
