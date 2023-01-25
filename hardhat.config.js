require("dotenv").config();
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");
require('@openzeppelin/hardhat-upgrades');
require("hardhat-deploy");
require("hardhat/config");
require("./deploy/deploy_token");
require("./deploy/deploy_superapp");
require("./deploy/upgrade_superapp");

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  paths: {
    sources: "./src",
  },
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      }
    }
  },
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545/",
      chainId: 31337,
    },
    mumbai: {
      url: process.env.MUMBAI_URL || "",
      accounts:
          process.env.MUMBAI_PRIVATE_KEY !== undefined ? [process.env.MUMBAI_PRIVATE_KEY] : [],
    },
  },

  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};
