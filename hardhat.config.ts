import * as dotenv from "dotenv";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-waffle";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-deploy";
import { HardhatUserConfig } from "hardhat/config";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.6",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1
      }
    }
  },
  networks: {
    hardhat: {
      forking: {
        url: "https://rpc.ankr.com/arbitrum",
        blockNumber: 71465399,
      },
      blockGasLimit: 0x1fffffffffff,
      gasPrice: 0,
      initialBaseFeePerGas: 0,
      allowUnlimitedContractSize: true,
    },
    arbitrum: {
      url: process.env.ARBITRUM_URL || "",
      accounts: [
        process.env.PRIVATE_KEY!,
        process.env.PRIVATE_KEY_TWO!,
        process.env.PRIVATE_KEY_THREE!
      ],
    },
    arbitrum_test: {
      url: `https://goerli-rollup.arbitrum.io/rpc`,
      accounts: [
        process.env.PRIVATE_KEY!,
        process.env.PRIVATE_KEY_TWO!,
        process.env.PRIVATE_KEY_THREE!
      ],
    }
  },
  mocha: {
    timeout: 300000,
  }
};

export default config;
