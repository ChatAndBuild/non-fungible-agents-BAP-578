require('@nomiclabs/hardhat-ethers');
require('@nomicfoundation/hardhat-verify');
require('@nomicfoundation/hardhat-chai-matchers');
require('@openzeppelin/hardhat-upgrades');
require('dotenv').config();

// Load environment variables
const TESTNET_RPC_URL =
  process.env.TESTNET_RPC_URL || 'https://data-seed-prebsc-1-s1.binance.org:8545/';
const MAINNET_RPC_URL = process.env.MAINNET_RPC_URL || 'https://bsc-dataseed.binance.org/';
const DEPLOYER_PRIVATE_KEY =
  process.env.DEPLOYER_PRIVATE_KEY ||
  '0000000000000000000000000000000000000000000000000000000000000000';
const BSCSCAN_API_KEY = process.env.BSCSCAN_API_KEY || '';

if (DEPLOYER_PRIVATE_KEY === '0000000000000000000000000000000000000000000000000000000000000000') {
  console.error('⚠️  DEPLOYER_PRIVATE_KEY not set. Only localhost network available.');
}

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: '0.8.28', // any version you want
    settings: {
      viaIR: true,
      optimizer: {
        enabled: true,
        details: {
          yulDetails: {
            optimizerSteps: 'u',
          },
        },
        runs: 8888,
      },
    },
  },
  networks: {
    testnet: {
      url: TESTNET_RPC_URL,
      accounts: [DEPLOYER_PRIVATE_KEY],
      chainId: 97,
    },
    mainnet: {
      url: MAINNET_RPC_URL,
      accounts: [DEPLOYER_PRIVATE_KEY],
      chainId: 56,
    },
  },
  paths: {
    sources: './contracts',
    tests: './test',
    cache: './cache',
    artifacts: './artifacts',
  },
  mocha: {
    timeout: 40000,
  },
  sourcify: {
    enabled: true,
  },
  etherscan: {
    apiKey: {
      bsc: BSCSCAN_API_KEY,
      testnet: BSCSCAN_API_KEY,
      bscTestnet: BSCSCAN_API_KEY,
    },
    customChains: [
      {
        network: 'testnet',
        chainId: 97,
        urls: {
          apiURL: 'https://api-testnet.bscscan.com/api',
          browserURL: 'https://testnet.bscscan.com',
        },
      },
    ],
  },
};
