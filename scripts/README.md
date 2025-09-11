# BEP007 Deployment Scripts

This directory contains comprehensive deployment scripts for the BEP007 Non-Fungible Agents (NFA) project.

## 📁 Available Scripts

### Core Deployment Scripts

- **`deploy.js`** - Main deployment script (updated for current contracts)
- **`deploy-dev.js`** - Simplified deployment for development/testing
- **`deploy-full.js`** - Full production deployment with upgradeable proxies
- **`verify-contracts.js`** - Contract verification on block explorers
- **`interact.js`** - Contract interaction and testing utility

## 🚀 Quick Start

### 1. Development Deployment (Local/Testnet)

```bash
# Deploy to local hardhat network
npm run deploy:dev

# Deploy to testnet
npm run deploy:dev -- --network testnet
```

### 2. Production Deployment

```bash
# Deploy to testnet with full setup
npm run deploy:full:testnet

# Deploy to mainnet with full setup
npm run deploy:full:mainnet
```

### 3. Verify Contracts

```bash
# Verify on testnet
npm run verify:testnet

# Verify on mainnet
npm run verify:mainnet
```

### 4. Interact with Contracts

```bash
# Interact with deployed contracts
npm run interact

# Interact on specific network
npm run interact:testnet
```

## 📋 Script Details

### `deploy.js` - Main Deployment

**Purpose**: Standard deployment script for most use cases

**Deploys**:
- CircuitBreaker (emergency controls)
- BEP007 (main NFT contract)
- MerkleTreeLearning (learning module)
- AgentFactory (agent creation)
- BEP007Governance (governance system)
- CreatorAgent (template contract)

**Features**:
- Simple deployment (no proxies)
- Basic configuration setup
- Clear logging and error handling

### `deploy-dev.js` - Development Deployment

**Purpose**: Quick deployment for development and testing

**Features**:
- Minimal setup
- Fast deployment
- Includes test commands
- Perfect for local development

### `deploy-full.js` - Production Deployment

**Purpose**: Full production deployment with all features

**Features**:
- Upgradeable proxy contracts
- Complete configuration
- Deployment tracking
- Gas optimization
- Comprehensive logging
- Saves deployment data to JSON

**Additional Setup**:
- Creates deployments directory
- Saves contract addresses
- Includes upgrade capabilities

### `verify-contracts.js` - Contract Verification

**Purpose**: Verify deployed contracts on block explorers

**Features**:
- Automatic deployment file detection
- Batch verification
- Error handling for already verified contracts
- Support for constructor arguments
- Uses modern `@nomicfoundation/hardhat-verify` plugin

**Important**: Verification uses a separate config file (`hardhat.verify.config.js`) to avoid plugin conflicts with OpenZeppelin upgrades.

### `interact.js` - Contract Interaction

**Purpose**: Test and interact with deployed contracts

**Features**:
- Contract state inspection
- Demo agent creation
- Useful command examples
- Interactive testing

## 🔧 Configuration

### Environment Variables

Create a `.env` file with:

```env
# Network Configuration
TESTNET_RPC_URL=https://data-seed-prebsc-1-s1.binance.org:8545/
MAINNET_RPC_URL=https://bsc-dataseed.binance.org/

# Deployment Account
DEPLOYER_PRIVATE_KEY=your_private_key_here

# Block Explorer API Key (for verification)
BSCSCAN_API_KEY=your_api_key_here
```

### Network Configuration

The scripts support these networks (configured in `hardhat.config.js`):

- **hardhat** - Local development network
- **testnet** - BSC Testnet (Chain ID: 97)
- **mainnet** - BSC Mainnet (Chain ID: 56)

## 📊 Deployment Flow

### Standard Flow

1. **CircuitBreaker** - Emergency controls (deployed first)
2. **BEP007** - Main NFT contract
3. **MerkleTreeLearning** - Learning module
4. **AgentFactory** - Agent creation factory
5. **BEP007Governance** - Governance system
6. **CreatorAgent** - Template contract
7. **Configuration** - Link contracts together

### Dependencies

```
CircuitBreaker (independent)
    ↓
BEP007 (depends on CircuitBreaker)
    ↓
MerkleTreeLearning (independent)
    ↓
AgentFactory (depends on BEP007, MerkleTreeLearning)
    ↓
BEP007Governance (depends on BEP007)
    ↓
CreatorAgent (depends on BEP007)
```

## 🛠 Usage Examples

### Deploy to Local Network

```bash
# Start local hardhat node
npx hardhat node

# In another terminal, deploy
npm run deploy:dev
```

### Deploy to Testnet

```bash
# Make sure you have testnet BNB for gas
npm run deploy:testnet

# Verify contracts
npm run verify:testnet

# Test interaction
npm run interact:testnet
```

### Deploy to Mainnet

```bash
# Use full deployment for mainnet
npm run deploy:full:mainnet

# Verify contracts
npm run verify:mainnet

# Test interaction (be careful!)
npm run interact:mainnet
```

## 📁 Output Files

### Deployment Data

Full deployments create JSON files in `deployments/` directory:

```json
{
  "network": "testnet",
  "chainId": 97,
  "deployer": "0x...",
  "timestamp": "2025-01-30T...",
  "contracts": {
    "CircuitBreaker": "0x...",
    "BEP007": "0x...",
    "AgentFactory": "0x...",
    ...
  }
}
```

## 🔍 Troubleshooting

### Common Issues

1. **Insufficient Gas**
   ```bash
   # Check account balance
   npm run interact
   ```

2. **Network Connection**
   ```bash
   # Test network connection
   npx hardhat console --network testnet
   ```

3. **Contract Verification Failed**
   ```bash
   # Manual verification
   npx hardhat verify --network testnet CONTRACT_ADDRESS
   ```

### Gas Optimization

- Use `deploy-dev.js` for testing (no proxies)
- Use `deploy-full.js` for production (with proxies)
- Monitor gas prices before mainnet deployment

## 🔐 Security Considerations

### Mainnet Deployment

1. **Use a hardware wallet** for mainnet deployments
2. **Test thoroughly** on testnet first
3. **Verify all contracts** after deployment
4. **Set up monitoring** for deployed contracts
5. **Use multi-sig** for governance operations

### Private Key Management

- Never commit private keys to git
- Use environment variables
- Consider using hardware wallets
- Use different keys for different networks

## 📚 Additional Resources

- [Hardhat Documentation](https://hardhat.org/docs)
- [OpenZeppelin Upgrades](https://docs.openzeppelin.com/upgrades-plugins/1.x/)
- [BSC Documentation](https://docs.bnbchain.org/)
- [BEP007 Specification](../README.md)

## 🤝 Contributing

When adding new deployment scripts:

1. Follow the existing naming convention
2. Include comprehensive logging
3. Add error handling
4. Update this README
5. Test on testnet first
