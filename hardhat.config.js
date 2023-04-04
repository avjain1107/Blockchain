require("@nomicfoundation/hardhat-toolbox");
require("solidity-coverage");
/** @type import('hardhat/config').HardhatUserConfig */
const INFURA_API_KEY = "0b56c8e153e6499d8f9d567092ec32fe";
const SEPOLIA_PRIVATE_KEY =
  "0x9d8276f0e5585e1cd5fbdf047cebac1ce86daf6ee03998d06d21f427a241d371";
module.exports = {
  solidity: "0.8.18",

  networks: {
    sepolia: {
      url: `https://sepolia.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [SEPOLIA_PRIVATE_KEY],
    },
  },
};
