require("@nomicfoundation/hardhat-toolbox");
require("solidity-coverage");
require("hardhat-deploy");
require("@nomiclabs/hardhat-ethers");
require("dotenv").config();
const { INFURA_API_KEY, SEPOLIA_PRIVATE_KEY } = process.env;
/** @type import('hardhat/config').HardhatUserConfig */

module.exports = {
  solidity: "0.8.18",
  nameAccounts: {
    deployer: {
      default: 0,
    },
  },
  // networks: {
  //   sepolia: {
  //     url: `https://sepolia.infura.io/v3/${INFURA_API_KEY}`,
  //     accounts: [SEPOLIA_PRIVATE_KEY],
  //   },
  // },
};