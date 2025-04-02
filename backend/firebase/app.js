const Web3 = require("web3");
const fs = require("fs");
require("dotenv").config();
const path = require("path");

const advanceTime = (web3, time) => {
  return new Promise((resolve, reject) => {
    web3.currentProvider.send(
      {
        jsonrpc: "2.0",
        method: "evm_increaseTime",
        params: [time],
        id: new Date().getTime(),
      },
      (err, result) => {
        if (err) {
          return reject(err);
        }
        return resolve(result);
      }
    );
  });
};

const disableAutomine = (web3) => {
  return new Promise((resolve, reject) => {
    web3.currentProvider.send(
      {
        jsonrpc: "2.0",
        method: "evm_setAutomine",
        params: [false],
        id: new Date().getTime(),
      },
      (err, result) => {
        if (err) {
          return reject(err);
        }
        return resolve(result);
      }
    );
  });
};

const setMiningInterval = (web3, interval) => {
  return new Promise((resolve, reject) => {
    web3.currentProvider.send(
      {
        jsonrpc: "2.0",
        method: "evm_setIntervalMining",
        params: [interval],
        id: new Date().getTime(),
      },
      (err, result) => {
        if (err) {
          return reject(err);
        }
        return resolve(result);
      }
    );
  });
};

const getUnlockTime = async (web3) => {
  const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
  const latestBlock = await web3.eth.getBlock("latest");
  const unlockTime = latestBlock.timestamp + ONE_YEAR_IN_SECS;
  return unlockTime;
};

const web3ProviderUrl = process.env.PROVIDER_URL;
const contractAddress = process.env.CONTRACT_ADDRESS;
const contractABIPath = path.resolve(__dirname, process.env.CONTRACT_ABI_PATH);
const contractJSON = JSON.parse(fs.readFileSync(contractABIPath, "utf-8"));
const contractABI = contractJSON.abi;

const web3 = new Web3(new Web3.providers.HttpProvider(web3ProviderUrl));
const contract = new web3.eth.Contract(contractABI, contractAddress);

async function start() {
  const unlockTime = await getUnlockTime(web3);

  await advanceTime(web3, unlockTime);
  await disableAutomine(web3);
  await setMiningInterval(web3, 5000);

  const accounts = await web3.eth.getAccounts();

  const tx = await contract.methods.emitTestEvent().send({ from: accounts[0] });
  console.log(tx);
}

start();
