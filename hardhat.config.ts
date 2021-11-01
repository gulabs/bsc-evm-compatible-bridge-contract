import * as dotenv from "dotenv";

import { HardhatUserConfig, task } from "hardhat/config";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";
import '@openzeppelin/hardhat-upgrades';
import 'hardhat-deploy';

dotenv.config();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  networks: {
    ropsten: {
      url: process.env.ROPSTEN_URL || "",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    chain1: {
      chainId: 1000,
      url: 'http://localhost:19545',
      accounts: [process.env.LOCAL_PRIVATE_KEY_1 || '']
    },
    chain2: {
      chainId: 2000,
      url: 'http://localhost:19546',
      accounts: [process.env.LOCAL_PRIVATE_KEY_1 || '']
    },
    hardhat: {
      chainId: 31337,
      gas: 12000000,
      blockGasLimit: 0x1fffffffffffff,
      allowUnlimitedContractSize: true,
      loggingEnabled: true,
      mining: {
        auto: false,
        interval: 10000
      },
      accounts: [{
        privateKey: process.env.LOCAL_PRIVATE_KEY_1 || '',
        balance: "10000000000000000000000",
      }, {
        privateKey: process.env.LOCAL_PRIVATE_KEY_2 || '',
        balance: "10000000000000000000000",
      }, {
        privateKey: process.env.LOCAL_PRIVATE_KEY_3 || '',
        balance: "10000000000000000000000",
      }],
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};

export default config;
