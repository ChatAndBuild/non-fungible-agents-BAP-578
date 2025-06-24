require('@nomiclabs/hardhat-waffle');
require('@nomiclabs/hardhat-ethers');
require("@openzeppelin/hardhat-upgrades");
require('dotenv').config();

// Load environment variables
const TESTNET_RPC_URL =
  process.env.TESTNET_RPC_URL || 'https://data-seed-prebsc-1-s1.binance.org:8545/';
const MAINNET_RPC_URL = process.env.MAINNET_RPC_URL || 'https://bsc-dataseed.binance.org/';
const DEPLOYER_PRIVATE_KEY =
  process.env.DEPLOYER_PRIVATE_KEY ||
  '0000000000000000000000000000000000000000000000000000000000000000';
const BSCSCAN_API_KEY = process.env.BSCSCAN_API_KEY || '';

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: '0.8.17',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
    },
  },
  networks: {
    hardhat: {
      chainId: 31337,
    },
    testnet: {
      url: TESTNET_RPC_URL,
      accounts: [DEPLOYER_PRIVATE_KEY],
      chainId: 97,
      gasPrice: 10000000000,
    },
    mainnet: {
      url: MAINNET_RPC_URL,
      accounts: [DEPLOYER_PRIVATE_KEY],
      chainId: 56,
      gasPrice: 5000000000,
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
  etherscan: {
    apiKey: BSCSCAN_API_KEY,
  },
};
