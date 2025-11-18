# 🚀 BSC Mainnet Deployment Guide

Simple step-by-step guide to deploy your BAP578 NFT contract to Binance Smart Chain Mainnet.

## 📋 Prerequisites

Before starting, ensure you have:
- ✅ **Node.js version 22** installed ([Download here](https://nodejs.org/))
- ✅ **0.10 - 0.15 BNB** in your deployment wallet
- ✅ **Private key** of your deployment wallet
- ✅ **BSCScan API key** (free from [bscscan.com](https://bscscan.com))

---

## Step 1: Setup Project Environment 🔧

### 1.1 Install Node.js v22
Check your Node version:
```bash
node --version
```
Should show: `v22.x.x`

If not v22, download from: https://nodejs.org/en/download/

### 1.2 Open Project Directory
Navigate to the project folder in terminal:
```bash
cd path/to/non-fungible-agents-BAP-578
```

### 1.3 Install Dependencies
```bash
npm install
```
This will take 2-5 minutes.

---

## Step 2: Configure Environment Variables 🔐

### 2.1 Create Environment File
Copy the example file:
```bash
cp .env.example .env
```

### 2.2 Edit .env File
Open `.env` in any text editor and add:

```env
# Your wallet's private key (64 characters, no 0x prefix)
DEPLOYER_PRIVATE_KEY=your_private_key_here

# BSC Mainnet RPC URL (use default or your own)
MAINNET_RPC_URL=https://bsc-dataseed.binance.org/

# BSCScan API Key for verification
BSCSCAN_API_KEY=your_bscscan_api_key_here
```

### 2.3 Get BSCScan API Key
1. Visit https://bscscan.com
2. Sign up/Login
3. Go to **API Keys** → **Add** 
4. Copy API key to `.env`

---

## Step 3: Configure Treasury Address 💰

### 3.1 Open Deploy Script
Edit `scripts/deploy.js` in text editor

### 3.2 Set Treasury Address
Find line ~12:
```javascript
const treasuryAddress = deployer.address;
```

Options:
- **Keep as is**: Treasury = deployer wallet
- **Change it**: Replace with your treasury address:
  ```javascript
  const treasuryAddress = "0xYourTreasuryAddressHere";
  ```

**Treasury receives**: Minting fees after free mints are used

---

## Step 4: Deploy Contract 🚀

### 4.1 Test Configuration
First, verify everything is set up correctly:
```bash
npx hardhat compile
```

### 4.2 Deploy to Mainnet
Run deployment:
```bash
npm run deploy:mainnet
```

### 4.3 Expected Output
```
🚀 Deploying BAP578 NFT Contract...

📍 Deploying with account: 0x...
💰 Account balance: 0.15 BNB
🏦 Treasury address: 0x...

📝 Deploying upgradeable contract...
✅ Proxy deployed to: 0xABC123...        ← YOUR CONTRACT ADDRESS
✅ Implementation deployed to: 0xDEF456...

🔍 Verifying deployment...
- Name: Non-Fungible Agents
- Symbol: NFA
- Owner: 0x...
- Treasury: 0x...
- Mint Fee: 0.01 BNB

💾 Deployment info saved to: ./deployments/mainnet_deployment.json
```

### 📌 SAVE THESE ADDRESSES!
- **Proxy Address**: Your main contract (share this)
- **Implementation**: For future upgrades
- Save the entire output for records

---

## Step 5: Verify Contract on BSCScan ✅

### 5.1 Automatic Verification
```bash
npm run verify:mainnet
```

If successful, you'll see:
```
Successfully verified contract BAP578 on Etherscan.
https://bscscan.com/address/0xYourContractAddress#code
```

### 5.2 Manual Verification (if auto fails)
```bash
npm run verify:manual:mainnet
```
Follow the prompts.

### 5.3 Check Verification
1. Go to BSCScan: `https://bscscan.com/address/YOUR_CONTRACT_ADDRESS`
2. Look for green checkmark ✓
3. Click "Contract" tab → "Read Contract"

---

## Step 6: Interact With Your Contract 🎮

### 6.1 Using CLI Tool
```bash
npm run interact:mainnet
```

**Menu Options:**
```
📋 Choose an action:
1. Create new agent      ← Mint NFT (first 3 free!)
2. View my agents        ← See your NFTs
3. View agent details    ← Check specific NFT
4. Fund an agent        ← Add BNB to NFT
5. Withdraw from agent  ← Remove BNB from NFT
6. Update agent status  ← Enable/disable
7. Update logic address ← Change logic contract
8. Update metadata      ← Change NFT metadata
9. View contract info   ← Contract details
10. Admin functions     ← Owner only
0. Exit
```

### 6.2 First Actions
1. Select **9** to view contract info
2. Select **1** to create your first agent (free!)
3. Select **2** to view your agents

### 6.3 Using BSCScan
After verification:
1. Go to your contract on BSCScan
2. Click "Write Contract" 
3. Connect wallet (Web3)
4. Use functions directly

---

## 📊 Gas Costs Reference

| Action | Gas Used | BNB Cost @ 5 gwei | USD @ $600/BNB |
|--------|----------|-------------------|----------------|
| Deploy Contract | ~4.5M | 0.0225 BNB | $13.50 |
| Verify Contract | ~100k | 0.0005 BNB | $0.30 |
| Mint NFT (after free) | ~300k | 0.0015 BNB | $0.90 |
| Update Metadata | ~150k | 0.00075 BNB | $0.45 |

**Total Deployment Cost: ~0.025 BNB** (~$15)

---

## 🆘 Troubleshooting

### Node.js Issues
```
Error: Unsupported engine
```
**Solution**: Install Node.js v22

### Compilation Errors
```
Error: Cannot find module
```
**Solution**: 
```bash
rm -rf node_modules package-lock.json
npm install
```

### Insufficient Funds
```
Error: insufficient funds for gas
```
**Solution**: Add more BNB to wallet (need 0.05+ BNB)

### Wrong Network
```
Error: Network mismatch
```
**Solution**: Ensure using BSC Mainnet (chainId: 56)

### Private Key Error
```
Error: Invalid private key
```
**Solution**: 
- Remove quotes from key in `.env`
- Ensure 64 characters (no 0x prefix)
- No spaces or line breaks

### Verification Failed
```
Error: Failed to verify contract
```
**Solution**:
- Wait 1 minute after deployment
- Try manual verification
- Check BSCSCAN_API_KEY is correct

---

## 📝 Post-Deployment Checklist

After successful deployment:

- [ ] Save contract addresses in secure location
- [ ] Save deployment transaction hash
- [ ] Verify contract on BSCScan
- [ ] Test minting an NFT
- [ ] Set up monitoring on BSCScan
- [ ] Share proxy address with team/community
- [ ] Document deployment date and costs

### Important Addresses to Save:
```
=== DEPLOYMENT RECORD ===
Date: [Today's Date]
Network: BSC Mainnet (Chain ID: 56)
Proxy Contract: 0x...
Implementation: 0x...
Deployer: 0x...
Treasury: 0x...
Transaction: 0x...
Total Cost: X.XXX BNB
BSCScan: https://bscscan.com/address/[PROXY_ADDRESS]
=======================
```

---

## 🚀 Quick Commands Reference

```bash
# Compile contracts
npx hardhat compile

# Deploy to mainnet
npm run deploy:mainnet

# Verify on BSCScan
npm run verify:mainnet

# Interact with contract
npm run interact:mainnet

# Check deployment info
cat deployments/mainnet_deployment.json

# Run tests (before deployment)
npm test
```

---

## 🔒 Security Notes

1. **Private Key Safety**
   - Never share your private key
   - Use separate wallet for deployment
   - Store key offline after deployment

2. **Contract Ownership**
   - You are the owner after deployment
   - Can transfer ownership if needed
   - Owner can pause/unpause contract

3. **Treasury Management**
   - Treasury receives mint fees
   - Can be updated by owner
   - Consider using multisig wallet

4. **Upgradability**
   - Contract uses UUPS pattern
   - Only owner can upgrade
   - Test upgrades on testnet first

---

## ✨ Next Steps After Deployment

1. **Mint First NFTs**
   - Test with free mints
   - Verify metadata displays correctly
   - Check BSCScan shows NFTs

2. **Set Up Operations**
   - Configure treasury if different

---

## 📞 Getting Help

If you encounter issues:

1. **Check error message** carefully
2. **Review this guide** for solutions
3. **Verify all addresses** are correct
4. **Ensure sufficient BNB** in wallet
5. **Check BSCScan** for transaction status

Common issues are usually:
- Wrong Node.js version (need v22)
- Insufficient BNB balance
- Incorrect private key format
- Network configuration errors

---

## 🎉 Success!

- After free mints: 0.01 BNB per mint
- Full agent metadata support
- Upgradeable for future features

**Congratulations on your deployment! 🚀**
