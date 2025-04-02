require("dotenv").config();
require("@nomicfoundation/hardhat-toolbox");
require("hardhat-abi-exporter");
require("dotenv").config();

module.exports = {
  abiExporter: {
    path: process.env.CONTRACT_ABI_PATH,
    runOnCompile: true,
    clear: true,
    flat: true,
    spacing: 2,
  },
  solidity: "0.8.28",
  networks: {
    dev: {
      url: process.env.PROVIDER_URL,
    },
    localhost: {
      url: "http://127.0.0.1:8545",
    },
  },
};
