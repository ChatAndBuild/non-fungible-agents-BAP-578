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
