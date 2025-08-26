# GitHub Actions Workflows

This directory contains GitHub Actions workflows for the BAP-578 Non-Fungible Agents project. These workflows automate testing, deployment, and maintenance tasks.

## Workflows Overview

### 1. Smart Contract Tests (`test.yml`)
**Trigger:** Push to `main` or `develop` branches, Pull Requests

**Purpose:** Comprehensive testing suite for smart contracts

**Jobs:**
- **test**: Runs Hardhat tests and generates coverage reports
- **lint**: Checks Solidity code style and formatting
- **security**: Runs Slither static analysis for security vulnerabilities
- **gas-report**: Generates gas usage reports for contract functions

### 2. Continuous Integration (`ci.yml`)
**Trigger:** Push to any branch except `main`, Pull Requests

**Purpose:** Ensures code quality on every change

**Features:**
- Smart change detection (only runs relevant jobs)
- Contract compilation with size checks
- Cached artifacts for faster builds
- Comprehensive linting and formatting checks
- Security analysis with SARIF reports

### 3. Deploy Smart Contracts (`deploy.yml`)
**Trigger:** Manual workflow dispatch

**Purpose:** Automated deployment to testnet or mainnet

**Inputs:**
- `network`: Choose between `testnet` or `mainnet`
- `environment`: Choose between `staging` or `production`

**Required Secrets:**
- `DEPLOYER_PRIVATE_KEY`: Private key for deployment account
- `BSC_TESTNET_RPC_URL`: BSC Testnet RPC endpoint
- `BSC_MAINNET_RPC_URL`: BSC Mainnet RPC endpoint
- `BSCSCAN_API_KEY`: API key for contract verification

### 4. Dependency Security Check (`dependency-check.yml`)
**Trigger:** Weekly schedule, changes to package files, manual dispatch

**Purpose:** Maintains dependency security and updates

**Features:**
- Weekly security audits
- Automated dependency updates via PR
- License compliance checking
- Snyk integration for vulnerability scanning

## Setup Instructions

### Required Repository Secrets

1. **For Deployment:**
   ```
   DEPLOYER_PRIVATE_KEY    # Private key of deployment account
   BSC_TESTNET_RPC_URL     # e.g., https://data-seed-prebsc-1-s1.binance.org:8545/
   BSC_MAINNET_RPC_URL     # e.g., https://bsc-dataseed.binance.org/
   BSCSCAN_API_KEY         # From https://bscscan.com/myapikey
   ```

2. **For Security Scanning (Optional):**
   ```
   SNYK_TOKEN              # From https://app.snyk.io/account
   ```

### Environment Setup

1. Create environments in repository settings:
   - `staging`: For testnet deployments
   - `production`: For mainnet deployments (add protection rules)

2. Configure branch protection rules:
   - Require PR reviews before merging to `main`
   - Require status checks to pass (CI workflow)
   - Dismiss stale PR approvals when new commits are pushed

## Usage Examples

### Manual Deployment

1. Go to Actions tab in GitHub
2. Select "Deploy Smart Contracts" workflow
3. Click "Run workflow"
4. Select network and environment
5. Click "Run workflow" button

### Running Tests Locally

To replicate CI tests locally:

```bash
# Install dependencies
npm ci

# Compile contracts
npm run compile

# Run tests
npm test

# Run linter
npm run lint

# Check formatting
npx prettier --check 'contracts/**/*.sol'

# Generate gas report
REPORT_GAS=true npm test
```

## Workflow Badges

Add these badges to your README.md:

```markdown
![Tests](https://github.com/[owner]/[repo]/workflows/Smart%20Contract%20Tests/badge.svg)
![CI](https://github.com/[owner]/[repo]/workflows/Continuous%20Integration/badge.svg)
![Security](https://github.com/[owner]/[repo]/workflows/Dependency%20Security%20Check/badge.svg)
```

## Troubleshooting

### Common Issues

1. **Compilation fails in CI but works locally**
   - Clear cache: Delete `artifacts/` and `cache/` directories
   - Ensure `hardhat.config.js` is committed

2. **Deployment fails with "insufficient funds"**
   - Check deployer account balance
   - Verify RPC URL is correct

3. **Security scan timeouts**
   - Slither analysis can be slow for large contracts
   - Consider increasing timeout or using `continue-on-error`

### Debugging Workflows

1. Enable debug logging:
   - Add secret `ACTIONS_STEP_DEBUG` with value `true`
   - Add secret `ACTIONS_RUNNER_DEBUG` with value `true`

2. Check workflow run logs in Actions tab

3. Use `act` tool to run workflows locally:
   ```bash
   act -j test
   ```

## Contributing

When adding new workflows:

1. Test locally using `act` when possible
2. Use semantic commit messages
3. Document any new secrets required
4. Update this README with workflow details
5. Consider workflow performance and caching

## Security Considerations

- Never commit sensitive data (private keys, API keys)
- Use GitHub Secrets for all credentials
- Regularly rotate deployment keys
- Review dependency updates before merging
- Enable Dependabot alerts in repository settings

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Hardhat Testing Guide](https://hardhat.org/tutorial/testing-contracts)
- [Slither Documentation](https://github.com/crytic/slither)
- [BSC Deployment Guide](https://docs.bnbchain.org/docs/hardhat-new/)
