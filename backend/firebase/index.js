require("dotenv").config();

const EthereumEventProcessor = require("ethereum-event-processor");
const Web3 = require("web3");
const fs = require("fs");
const govDeathSimulationRoutes = require("../routes/govDeathSimulationRoute.js");
const express = require("express");
const http = require("http");
const bodyParser = require("body-parser");
//const cors = require("cors");
const db = require("./firebaseAdmin.js"); // Correctly import the Firestore instance
const op = require("./firestoreOperations.js");
const { ethers } = require("ethers");
const path = require("path");

const truthy = ["TRUE", "true", "True", "1"];

const govDeathSimulationService = require("../services/govDeathSimulationService.js");
const grantOfProbateSimulationService = require("../services/grantOfProbateSimulationService.js");

/*app.use(
  cors({
    credentials: true,
  })
);*/

async function database() {
  if (truthy.includes(process.env.RESET_DB || "")) {
    await op.clearDatabase();
    console.log("Database resetted!!");
    await op.createDatabase();
    console.log("Database recreated!");
  } else {
    console.log("Database left untouched!");
  }
}

database();

const app = express();

app.use(bodyParser.json());
//app.use("/img", express.static("img"));
app.use("/pdf", express.static("pdf"));

app.use((req, res, next) => {
  console.log(req.path, req.method);
  next();
});

app.get("/", (req, res) => {
  res.send("HELLO)s");
});

// Example route to check Firebase connection
app.get("/test-firebase", async (req, res) => {
  try {
    // Example Firebase interaction
    const snapshot = await db.collection("death_certificate").get();
    if (snapshot.empty) {
      res.status(404).send("No documents found!");
      return;
    }
    res.status(200).send("Successfully connected to Firebase!");
  } catch (error) {
    console.error("Error connecting to Firebase:", error);
    res.status(500).send("Error connecting to Firebase.");
  }
});

console.log(process.env.CONTRACT_ABI_PATH);

const web3ProviderUrl = process.env.PROVIDER_WEBSOCKET_URL;
const contractAddress = process.env.CONTRACT_ADDRESS;

const contractABIPath = path.resolve(
  __dirname,
  "../../solidity_project/artifacts/contracts/Will.sol/Will.json"
);
console.log(contractABIPath);
const contractJSON = JSON.parse(fs.readFileSync(contractABIPath, "utf-8"));
const contractABI = contractJSON.abi;
console.log(contractABI); // Log to ensure it's correctly loaded

const eventOptions = {
  pollingInterval: parseInt(process.env.EVENT_POOL_INTERVAL),
  startBlock: 0,
  blocksToWait: parseInt(process.env.EVENT_BLOCKS_TO_WAIT),
  blocksToRead: parseInt(process.env.EVENT_BLOCKS_TO_READ),
};

const web3 = new Web3(new Web3.providers.WebsocketProvider(web3ProviderUrl));

async function startEventListener() {
  const latestBlock = await web3.eth.getBlock("latest");
  eventOptions.startBlock = latestBlock.number;

  const eventListener = new EthereumEventProcessor(
    web3,
    contractAddress,
    contractABI,
    eventOptions
  );

  eventListener.on("Test", async (event) => {
    console.log("Event Captured: ", event);
    console.log("Event Return Values: ", event.returnValues);

    const value = "ma";
    await sendProcessedData(value);
  });

  eventListener.on("DataReceived", async (event) => {
    console.log("Event Captured: ", event);
    console.log("Event Return Values: ", event.returnValues);
  });

  eventListener.on("DeathToday", async (event) => {
    console.log("Event Captured: ", event);
    const result = await govDeathSimulationService.getAllDeathNRICToday();

    await sendProcessedDeathToday(result);
  });

  eventListener.on("GrantOfProbateToday", async (event) => {
    console.log("Event Captured: ", event);
    const result =
      await grantOfProbateSimulationService.getAllGrantOfProbateNRICToday();

    await sendProcessedProbateToday(result);
  });

  eventListener.on("DeathUpdated", async (event) => {
    console.log("Event Captured: ", event);
    console.log("Successfully updated death");
  });

  eventListener.on("ProbateUpdated", async (event) => {
    console.log("Event Captured: ", event);
    console.log("Successfully updated probate");
  });

  eventListener.listen();

  console.log("Event listener started");
}

async function sendProcessedData(processedValue) {
  const accounts = await web3.eth.getAccounts();
  const contract = new web3.eth.Contract(contractABI, contractAddress);

  await contract.methods.receiveProcessedData(processedValue).send({
    from: accounts[0], // Use the first account
    gas: 300000,
  });

  console.log("Processed data sent back to contract!");
}

async function sendProcessedDeathToday(processedValue) {
  const accounts = await web3.eth.getAccounts();
  const contract = new web3.eth.Contract(contractABI, contractAddress);

  await contract.methods.updateWillStateToDeathConfirmed(processedValue).send({
    from: accounts[0], // Use the first account
    gas: 300000,
  });

  console.log("Processed data sent back to contract!");
}

async function sendProcessedProbateToday(processedValue) {
  const accounts = await web3.eth.getAccounts();
  const contract = new web3.eth.Contract(contractABI, contractAddress);

  await contract.methods
    .updateWillStateToGrantOfProbateConfirmed(processedValue)
    .send({
      from: accounts[0], // Use the first account
      gas: 300000,
    });

  console.log("Processed data sent back to contract!");
}

// Call the async function
startEventListener();

// triggerEvent();
// Set up HTTP server
const server = http.createServer(app);
server.listen(3000, () => {
  console.log("Server is running on http://localhost:3000");
});

app.use("/api/govDeathSimulation/", govDeathSimulationRoutes);
