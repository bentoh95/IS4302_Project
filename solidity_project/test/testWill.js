const { expect } = require("chai");
const { ethers } = require("hardhat");

const Web3 = require("web3");
const fs = require("fs");
require("dotenv").config();
const path = require("path");
const EthereumEventProcessor = require("ethereum-event-processor");

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
  const ONE_YEAR_IN_SECS = BigInt(365 * 24 * 60 * 60); // Convert to BigInt
  const latestBlock = await web3.eth.getBlock("latest");
  const unlockTime = (
    BigInt(latestBlock.timestamp) + ONE_YEAR_IN_SECS
  ).toString(); // Convert to string before sending
  return unlockTime;
};

const web3ProviderUrl = process.env.PROVIDER_WEBSOCKET_URL;
const contractAddress = process.env.CONTRACT_ADDRESS;
const contractABIPath = path.resolve(__dirname, process.env.CONTRACT_ABI_PATH);
const contractJSON = JSON.parse(fs.readFileSync(contractABIPath, "utf-8"));
const contractABI = contractJSON.abi;

const web3 = new Web3(new Web3.providers.WebsocketProvider(web3ProviderUrl));
const contract = new web3.eth.Contract(contractABI, contractAddress);

const eventOptions = {
  pollingInterval: parseInt(process.env.EVENT_POOL_INTERVAL),
  startBlock: 0,
  blocksToWait: parseInt(process.env.EVENT_BLOCKS_TO_WAIT),
  blocksToRead: parseInt(process.env.EVENT_BLOCKS_TO_READ),
};

describe("Will", function () {
  let Will;
  let will;
  let owner,
    beneficiary1,
    beneficiary2,
    editor1,
    editor2,
    viewer1,
    viewer2,
    nonOwner,
    others;

  // Deploy Will
  beforeEach(async function () {
    [
      owner,
      beneficiary1,
      beneficiary2,
      editor1,
      editor2,
      viewer1,
      viewer2,
      nonOwner,
      ...others
    ] = await ethers.getSigners();

    Will = await ethers.getContractFactory("Will");
    will = await Will.connect(owner).deploy();
    await will.waitForDeployment();
  });

  it("Should create a will successfully", async function () {
    await will.createWill(owner.address, "S7654321B");
    const willData = await will.getWillData(owner.address);
    expect(willData.owner).to.equal(owner.address);
    expect(willData.beneficiaries).to.be.an("array").that.is.empty;
    expect(willData.state).to.equal(0); // WillState.InCreation
  });

  it("Should add a beneficiary successfully", async function () {
    await will.createWill(owner.address, "S7654321B");
    // Add beneficiary with an allocation of 100
    await will.addBeneficiary(owner.address, beneficiary1.address, 100);

    // Await the result of getBeneficiaryAllocation to get the actual allocation
    const allocation = await will.getBeneficiaryAllocation(
      owner.address,
      beneficiary1.address
    );

    // Assert that the allocation is 100
    expect(allocation).to.equal(100);
  });

  it("Should update the allocation for a beneficiary", async function () {
    // Create a will for the owner
    await will.createWill(owner.address, "S7654321B");
    // Add a beneficiary with an initial allocation
    const initialAllocation = 100;
    await will.addBeneficiary(
      owner.address,
      beneficiary1.address,
      initialAllocation
    );
    // Update the allocation for the beneficiary
    const updatedAllocation = 200;
    await will.updateAllocation(
      owner.address,
      beneficiary1.address,
      updatedAllocation
    );
    const allocation = await will.getBeneficiaryAllocation(
      owner.address,
      beneficiary1.address
    );
    expect(allocation).to.equal(200);
  });

  it("Should remove beneficiary", async function () {
    // Create a will for the owner
    await will.createWill(owner.address, "S7654321B");
    // Add a beneficiary with an initial allocation
    const initialAllocation = 100;
    await will.addBeneficiary(
      owner.address,
      beneficiary1.address,
      initialAllocation
    );
    // Remove the beneficiary
    await will.removeBeneficiary(owner.address, beneficiary1.address);
    const allocation = await will.getBeneficiaryAllocation(
      owner.address,
      beneficiary1.address
    );
    expect(allocation).to.equal(0);
  });

  it("Should return correct will details", async function () {
    await will.createWill(owner.address, "S7654321B");
    // Sample setup: Add beneficiaries and allocations
    await will.addBeneficiary(owner.address, beneficiary1.address, 100);
    await will.addBeneficiary(owner.address, beneficiary2.address, 50);

    // Call viewWill function to get the will string
    const willString = await will.viewWill(owner.address);

    // Construct the expected string based on your logic
    const expectedWill = `Beneficiaries & Allocations:\n- ${beneficiary1.address
      .toLowerCase()
      .substring(2)} -> 100\n- ${beneficiary2.address
      .toLowerCase()
      .substring(2)} -> 50\n`;
    console.log(willString);
    // Check if the returned string matches the expected string exactly
    expect(willString).to.equal(expectedWill);
  });

  it("Should add an editor successfully", async function () {
    await will.createWill(owner.address, "S7654321B");
    await will.addEditor(owner.address, editor1.address);
    const editorExists = await will.isAuthorisedEditorExist(
      owner.address,
      editor1.address
    );
    expect(editorExists).to.equal(true);
  });

  it("Should remove an editor successfully", async function () {
    await will.createWill(owner.address, "S7654321B");
    await will.addEditor(owner.address, editor1.address);
    await will.removeEditor(owner.address, editor1.address);
    const editorExists = await will.isAuthorisedEditorExist(
      owner.address,
      editor1.address
    );
    expect(editorExists).to.equal(false);
  });

  it("Should revert if adding the same editor twice", async function () {
    await will.createWill(owner.address, "S7654321B");
    await will.addEditor(owner.address, editor1.address);
    await expect(
      will.addEditor(owner.address, editor1.address)
    ).to.be.revertedWith("Editor already exists");
  });

  it("Should revert if trying to remove an editor who does not exist", async function () {
    await will.createWill(owner.address, "S7654321B");
    await expect(
      will.removeEditor(owner.address, editor1.address)
    ).to.be.revertedWith("Editor not found");
  });

  it("Should revert if a non-owner tries to remove an editor", async function () {
    await will.createWill(owner.address, "S7654321B");
    await will.addEditor(owner.address, editor1.address);
    await expect(
      will.connect(nonOwner).removeEditor(owner.address, editor1.address)
    ).to.be.revertedWith("Not the owner");
  });

  it("should revert if adding invalid editor address", async function () {
    await will.createWill(owner.address, "S7654321B");
    const zeroAddress = ethers.ZeroAddress;
    await expect(will.addEditor(owner.address, zeroAddress)).to.be.revertedWith(
      "Invalid editor address"
    );
  });

  it("Should add a viewer successfully", async function () {
    await will.createWill(owner.address, "S7654321B");
    await will.addViewer(owner.address, viewer1.address);
    const viewerExists = await will.isAuthorisedViewer(
      owner.address,
      viewer1.address
    );
    expect(viewerExists).to.equal(true);
  });

  it("Should remove a viewer successfully", async function () {
    await will.createWill(owner.address, "S7654321B");
    await will.addViewer(owner.address, viewer1.address);
    await will.removeViewer(owner.address, viewer1.address);
    const viewerExists = await will.isAuthorisedViewer(
      owner.address,
      viewer1.address
    );
    expect(viewerExists).to.equal(false);
  });

  it("Should revert if adding the same viewer twice", async function () {
    await will.createWill(owner.address, "S7654321B");
    await will.addViewer(owner.address, viewer1.address);
    await expect(
      will.addViewer(owner.address, viewer1.address)
    ).to.be.revertedWith("Viewer already exists");
  });

  it("Should revert if trying to remove an viewer who does not exist", async function () {
    await will.createWill(owner.address, "S7654321B");
    await expect(
      will.removeViewer(owner.address, viewer1.address)
    ).to.be.revertedWith("Viewer not found");
  });

  it("Should allow the viewer with permission to call WillViewForBeneficiaries if will is InCreation (owner check)", async function () {
    await will.createWill(owner.address, "S7654321B");
    await will.addViewer(owner.address, viewer1.address);
    await will.addBeneficiary(owner.address, beneficiary1.address, 100);
    await will.addBeneficiary(owner.address, beneficiary2.address, 50);

    const viewerExists = await will.isAuthorisedViewer(
      owner.address,
      viewer1.address
    );
    expect(viewerExists).to.equal(true);

    const result = await will
      .connect(viewer1)
      .WillViewForBeneficiaries(owner.address);
    expect(result).to.include("Beneficiaries & Allocations:");
  });

  it("Should not allow the viewer without permission to call WillViewForBeneficiaries if will is InCreation (owner check)", async function () {
    await will.createWill(owner.address, "S7654321B");
    await expect(
      will.connect(viewer2).WillViewForBeneficiaries(owner.address)
    ).to.be.revertedWith("Not authorized to view this will (InCreation)");
  });

  //Test confirmDeath and GrantofProbateConfirmed state update
  it("Should change will state to confirmDeath when we call government death registry and the corresponding NRIC has been posted", async function () {
    await will.createWill(owner.address, "S7654321B");
    //S7654321B was posted today in Death Registry
    await will.callDeathRegistryToday();
    expect(await will.getWillState(owner.address)).to.equal("InCreation");
    await will.updateWillStateToDeathConfirmed();
    expect(await will.getWillState(owner.address)).to.equal("DeathConfirmed");
  });

  it("Should not change will state to confirmDeath when we call government death registry and the corresponding NRIC has not been posted", async function () {
    await will.createWill(owner.address, "T1234567J");
    //T1234567J was not posted today in Death Registry
    await will.callDeathRegistryToday();
    expect(await will.getWillState(owner.address)).to.equal("InCreation");
    await will.updateWillStateToDeathConfirmed();
    //T1234567J was not posted today so the will state did not get updated to confirmDeath
    expect(await will.getWillState(owner.address)).to.equal("InCreation");
  });

  it("Should change will state to GrantOfProbateConfirmed when state is in confirmDeath and the corresponding NRIC has been posted to the government Grant of Probate registry", async function () {
    await will.createWill(owner.address, "S7654321B");
    //S7654321B was posted today in Death Registry
    await will.callDeathRegistryToday();
    expect(await will.getWillState(owner.address)).to.equal("InCreation");
    await will.updateWillStateToDeathConfirmed();
    expect(await will.getWillState(owner.address)).to.equal("DeathConfirmed");
    //S7654321B was posted today in Grant of Probate Registry
    await will.callGrantOfProbateToday();
    await will.updateWillStateToGrantOfProbateConfirmed();
    expect(await will.getWillState(owner.address)).to.equal("GrantOfProbateConfirmed");
  });

  it("Should not change will state to GrantOfProbateConfirmed when state is not confirmDeath", async function () {
    await will.createWill(owner.address, "S7654321B");
    //S7654321B was posted today
    await will.callGrantOfProbateToday();
    await will.updateWillStateToGrantOfProbateConfirmed();
    expect(await will.getWillState(owner.address)).to.equal("InCreation");
  });

  it("test", async function () {
    const unlockTime = await getUnlockTime(web3);

    await advanceTime(web3, unlockTime);
    await disableAutomine(web3);
    await setMiningInterval(web3, 5000);

    const accounts = await web3.eth.getAccounts();

    const tx = await contract.methods
      .emitTestEvent()
      .send({ from: accounts[0] });

    console.log(tx);

    const latestBlock = await web3.eth.getBlock("latest");
    eventOptions.startBlock = latestBlock.number;

    const eventPromise = new Promise((resolve, reject) => {
      const eventListener = new EthereumEventProcessor(
        web3,
        contractAddress,
        contractABI,
        eventOptions
      );

      // Listen for the DataReceived event
      eventListener.on("DataReceived", (event) => {
        console.log("Event received:", event.returnValues);
        resolve(event); // Resolve the promise when the event is captured
      });

      // Start listening for the event
      eventListener.listen();
    });

    // Set a timeout for 1 minute
    const timeoutPromise = new Promise((_, reject) =>
      setTimeout(
        () =>
          reject(new Error("Timeout: DataReceived event not received in time")),
        60000
      )
    );

    // Wait for either the event or the timeout (whichever happens first)
    try {
      const event = await Promise.race([eventPromise, timeoutPromise]);
      console.log("Event successfully received:", event);
    } catch (error) {
      console.error("Error or timeout:", error.message);
    }
  });
});
