# BAP578 - Non-Fungible Agents (NFA)

ERC-721 NFT Smart Contract (BAP578) for AI Agents with structured metadata and built-in features on BNB Chain.

![Non-Fungible Agents](NFA-ReadMe-Header.png)

## Features

- **Contract Name**: BAP578
- **Token Name**: Non-Fungible Agents
- **Symbol**: NFA
- **3 Free Mints Per User** - Every user gets 3 free mints automatically
- **0.01 BNB Fee** - After free mints are exhausted
- **Structured Agent Metadata** - Persona, experience, voice, animations, and vault data
- **Agent Fund Management** - Each agent can hold and manage BNB
- **UUPS Upgradeable** - Future-proof contract architecture
- **Emergency Controls** - Pause functionality and emergency withdrawals

## Quick Start

### Installation
```bash
npm install
```

### Compile Contracts
```bash
npm run compile
```

### Run Tests
```bash
npm test
```

### Deploy

```bash
# Local development
npm run deploy

# BSC Testnet
npm run deploy:testnet

# BSC Mainnet  
npm run deploy:mainnet
```

### Interact with Contract

```bash
# Interactive CLI
npm run interact:testnet
```

### Verify on BSCScan

```bash
# Automatic verification
npm run verify:testnet

# Manual verification guide
npm run verify:manual:testnet
```

## BAP-578 Dev Kit (SkillsHub)

To streamline adapter design, vault safety checks, deployment sequencing, and test scaffolding, this repository includes a SkillsHub-based Dev Kit guide.

- Docs index: `docs/dev-tools/README.md`
- 15-minute onboarding: `docs/dev-tools/getting-started-15-minutes.md`
- Security baseline: `docs/dev-tools/security-checklist.md`

Install commands:

```bash
npx @skillshub/bap578-adapter-blueprint
npx @skillshub/bap578-vault-checklist
npx @skillshub/bap578-deploy-plan
npx @skillshub/bap578-test-template
npx @skillshub/bap578-contract-idea-sprint
```

Optional local skeletons included:

- `contracts/templates/BAP578AdapterBlueprint.sol`
- `test/templates/bap578-adapter.template.test.js`

## Production Showcases

Production-backed case studies showing how BAP-578 NFAs expand beyond base ownership into stateful gameplay, account systems, and AI-facing runtimes.

- [Clawworld Reference Implementation](docs/CLAWORLD-REFERENCE-IMPLEMENTATION.md) — 11 mainnet contracts implementing all four BAP-578 capabilities (Identity, Wallet, Execution, Learning). Includes deployed addresses, codebase scale, and the newest Battle Royale skill.
- [Clawworld Architecture](docs/CLAWORLD-ARCHITECTURE.md) — Explicit BAP-578 four-capability mapping table. Shows how ClawNFA, ClawRouter, skill contracts, and PersonalityEngine map to Identity, Wallet, Execution, and Learning.
- [Clawworld Showcase](docs/CLAWORLD-SHOWCASE.md) — End-to-end user flow: mint → tasks → upkeep → PK → Battle Royale → market. Plus the AI model skill CLI interface.
- [Clawworld Economic Model](docs/CLAWORLD-ECONOMIC-MODEL.md) — Two-layer asset design (external CLW token + per-agent internal balance), treasury flywheel, burn mechanics, and value flow diagram.
- [Clawworld Skill CLI](docs/CLAWORLD-SKILL-CLI.md) — How the OpenClaw skill CLI turns a BAP-578 role unit into a model-operable runtime surface with production command examples.

## Contract Structure

### AgentMetadata
```solidity
struct AgentMetadata {
    string persona;       // JSON traits/style
    string experience;    // Agent's role/expertise
    string voiceHash;     // Voice identifier
    string animationURI;  // Animation resource
    string vaultURI;      // Vault resource
    bytes32 vaultHash;    // Vault identifier
}
```

### Key Functions

- `createAgent()` - Mint new agent NFT (free for first 3, then 0.01 BNB)
- `fundAgent()` - Send BNB to an agent
- `withdrawFromAgent()` - Withdraw BNB from your agent
- `setAgentStatus()` - Activate/deactivate agent
- `setLogicAddress()` - Set agent's logic contract
- `updateAgentMetadata()` - Update agent's metadata

## Environment Setup

Create a `.env` file:

```env
DEPLOYER_PRIVATE_KEY=your_private_key_here
TESTNET_RPC_URL=https://data-seed-prebsc-1-s1.binance.org:8545/
MAINNET_RPC_URL=https://bsc-dataseed.binance.org/
BSCSCAN_API_KEY=your_bscscan_api_key_here
```

## Network Configuration

- **BSC Testnet:** Chain ID 97
- **BSC Mainnet:** Chain ID 56
- **Local:** Hardhat Network

## Available Scripts

| Command | Description |
|---------|-------------|
| `npm test` | Run test suite |
| `npm run compile` | Compile contracts |
| `npm run deploy` | Deploy to local network |
| `npm run deploy:testnet` | Deploy to BSC testnet |
| `npm run deploy:mainnet` | Deploy to BSC mainnet |
| `npm run interact` | Interactive CLI |
| `npm run verify:testnet` | Verify on testnet BSCScan |
| `npm run clean` | Clean artifacts |
| `npm run coverage` | Generate test coverage |

## License

MIT
