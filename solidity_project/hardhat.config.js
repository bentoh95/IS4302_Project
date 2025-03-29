require("dotenv").config();
require("@nomicfoundation/hardhat-toolbox");
require("hardhat-abi-exporter");

module.exports = {
  abiExporter: {
    path: "artifacts/abis",
    runOnCompile: true,
    clear: true,
    flat: true,
    spacing: 2,
  },
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200, // Number of runs the optimizer should try for
      },
    },
  },
  networks: {
    dev: {
      url: process.env.PROVIDER_URL || "http://127.0.0.1:8545", // Ensure default value
    },
  },
};
