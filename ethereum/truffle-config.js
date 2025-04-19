require('dotenv').config();
const HDWalletProvider = require('@truffle/hdwallet-provider');

const mnemonic = process.env.MNEMONIC;
const infuraApiKey = process.env.INFURA_API_KEY;

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "*"
    },
    sepolia: {
      provider: () => new HDWalletProvider(
        mnemonic, 
        `https://sepolia.infura.io/v3/${infuraApiKey}`
      ) ,
      network_id: 11155111,
      gas: 5500000,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    base_sepolia: {
      provider: () => new HDWalletProvider(
        mnemonic,
        `https://sepolia.base.org`
      ) ,
      network_id: 84532,
      gas: 5500000,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    bsc_testnet: {
      provider: () => new HDWalletProvider(
        mnemonic,
        `https://data-seed-prebsc-1-s1.binance.org:8545`
      ) ,
      network_id: 97,
      gas: 5500000,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true
    }
  },
  compilers: {
    solc: {
      version: "0.8.17",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        }
      }
    }
  }
};
