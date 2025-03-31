const { expect } = require("chai");
const { ethers } = require("hardhat");

const { Web3 } = require("web3");
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
  const ONE_YEAR_IN_SECS = BigInt(365 * 24 * 60 * 60); // Convert to BigInt
  const latestBlock = await web3.eth.getBlock("latest");
  const unlockTime = (
    BigInt(latestBlock.timestamp) + ONE_YEAR_IN_SECS
  ).toString(); // Convert to string before sending
  return unlockTime;
};

const web3ProviderUrl = process.env.PROVIDER_URL;
const contractAddress = process.env.CONTRACT_ADDRESS;
const contractABIPath = path.resolve(
  __dirname,
  "../artifacts/contracts/Will.sol/Will.json"
);
const contractJSON = JSON.parse(fs.readFileSync(contractABIPath, "utf-8"));
const contractABI = contractJSON.abi;

const web3 = new Web3(web3ProviderUrl);
const contract = new web3.eth.Contract(contractABI, contractAddress);

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
    residualBeneficiary1,
    residualBeneficiary2,
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
      residualBeneficiary1,
      residualBeneficiary2,
      ...others
    ] = await ethers.getSigners();

    const AssetToken = await ethers.getContractFactory("AssetToken");
    assetToken = await AssetToken.deploy();
    await assetToken.waitForDeployment();

    const AssetRegistry = await ethers.getContractFactory("AssetRegistry");
    assetRegistry = await AssetRegistry.deploy(await assetToken.getAddress());
    await assetRegistry.waitForDeployment();

    Will = await ethers.getContractFactory("Will");
    will = await Will.connect(owner).deploy(await assetRegistry.getAddress());
    await will.waitForDeployment();
  });

  it("Should create a will successfully", async function () {
    await will.createWill(owner.address);
    const willData = await will.getWillData(owner.address);
    expect(willData.owner).to.equal(owner.address);
    expect(willData.beneficiaries).to.be.an("array").that.is.empty;
    expect(willData.digitalAssets).to.equal(0);
    expect(willData.state).to.equal(0); // WillState.InCreation
    expect(willData.residualBeneficiary).to.equal(ethers.ZeroAddress);
  });

  /* it("Should add a beneficiary successfully", async function () {
      await will.createWill(owner.address);

      // Add beneficiary with an allocation of 100
      await will.addBeneficiary(owner.address, beneficiary1.address, 100);

      // Await the result of getBeneficiaryAllocationPercentage to get the actual allocation
      const allocation = await will.getBeneficiaryAllocationPercentage(owner.address, beneficiary1.address);

      // Assert that the allocation is 100
      expect(allocation).to.equal(100);
  }); */

  it("Should allow owner to set residual beneficiary", async function () {
    await will.createWill(owner.address);
    await will.setResidualBeneficiary(
      owner.address,
      residualBeneficiary1.address
    );
    const willData = await will.getWillData(owner.address);
    expect(willData.residualBeneficiary).to.equal(residualBeneficiary1.address);
  });

  it("Should prevent adding beneficiaries before setting residual beneficiary", async function () {
    // Create will without setting residual beneficiary
    await will.createWill(owner.address);

    // Attempt to add beneficiaries should revert
    const beneficiaries = [beneficiary1.address, beneficiary2.address];
    const allocations = [20, 80];

    await expect(
      will.addBeneficiaries(owner.address, beneficiaries, allocations)
    ).to.be.revertedWith("Residual beneficiary not set");
  });

  it("Should add beneficiaries successfully", async function () {
    await will.createWill(owner.address);
    await will.setResidualBeneficiary(
      owner.address,
      residualBeneficiary1.address
    );
    // Add multiple beneficiaries with their allocations
    const beneficiaries = [beneficiary1.address, beneficiary2.address];
    const allocations = [20, 80];
    await will.addBeneficiaries(owner.address, beneficiaries, allocations);
    // Check if the allocations are set correctly
    const allocation1 = await will.getBeneficiaryAllocationPercentage(
      owner.address,
      beneficiary1.address
    );
    const allocation2 = await will.getBeneficiaryAllocationPercentage(
      owner.address,
      beneficiary2.address
    );
    expect(allocation1).to.equal(20);
    expect(allocation2).to.equal(80);
    console.log(allocation1);
  });

  it("Should add to residual beneficiary successfully", async function () {
    await will.createWill(owner.address);
    await will.setResidualBeneficiary(
      owner.address,
      residualBeneficiary1.address
    );
    // Add multiple beneficiaries with their allocations
    const beneficiaries = [beneficiary1.address, beneficiary2.address];
    const allocations = [20, 70];
    await will.addBeneficiaries(owner.address, beneficiaries, allocations);
    // Check if the allocations are set correctly
    const allocation1 = await will.getBeneficiaryAllocationPercentage(
      owner.address,
      beneficiary1.address
    );
    const allocation2 = await will.getBeneficiaryAllocationPercentage(
      owner.address,
      beneficiary2.address
    );
    const allocation3 = await will.getBeneficiaryAllocationPercentage(
      owner.address,
      residualBeneficiary1.address
    );
    expect(allocation1).to.equal(20);
    expect(allocation2).to.equal(70);
    expect(allocation3).to.equal(10);
  });

  it("Should add to existing residual beneficiary successfully", async function () {
    await will.createWill(owner.address);
    await will.setResidualBeneficiary(owner.address, beneficiary2.address);
    // Add multiple beneficiaries with their allocations
    const beneficiaries = [beneficiary1.address, beneficiary2.address];
    const allocations = [20, 70];
    await will.addBeneficiaries(owner.address, beneficiaries, allocations);
    // Check if the allocations are set correctly
    const allocation1 = await will.getBeneficiaryAllocationPercentage(
      owner.address,
      beneficiary1.address
    );
    const allocation2 = await will.getBeneficiaryAllocationPercentage(
      owner.address,
      beneficiary2.address
    );
    const allocation3 = await will.getBeneficiaryAllocationPercentage(
      owner.address,
      residualBeneficiary1.address
    );
    expect(allocation1).to.equal(20);
    expect(allocation2).to.equal(80); //gets the remaining 10 person
  });

  it("Should not exceed 100% after adding beneficiary", async function () {
    await will.createWill(owner.address);
    await will.setResidualBeneficiary(owner.address, beneficiary2.address);
    // Add multiple beneficiaries with their allocations
    const beneficiaries = [beneficiary1.address, beneficiary2.address];
    const allocations = [20, 100];
    await expect(
      will.addBeneficiaries(owner.address, beneficiaries, allocations)
    ).to.be.revertedWith("Total allocation exceeds 100%");
  });

  /* it("Should update the allocation for a beneficiary", async function () { 
      // Create a will for the owner 
      await will.createWill(owner.address); 
      // Add a beneficiary with an initial allocation 
      const initialAllocation = 100; await will.addBeneficiary(owner.address, beneficiary1.address, initialAllocation); 
      // Update the allocation for the beneficiary 
      const updatedAllocation = 200; await will.updateAllocation(owner.address, beneficiary1.address, updatedAllocation); 
      const allocation = await will.getBeneficiaryAllocationPercentage(owner.address, beneficiary1.address);
      expect(allocation).to.equal(200);
  }); */

  it("Should update the allocation for a beneficiary successfully", async function () {
    // Create a will for the owner
    await will.createWill(owner.address);
    await will.setResidualBeneficiary(
      owner.address,
      residualBeneficiary1.address
    );
    // Add a beneficiary with an initial allocation
    const beneficiaries = [beneficiary1.address, beneficiary2.address];
    const initialAllocations = [40, 60];
    const updatedAllocations = [30, 70];
    await will.addBeneficiaries(
      owner.address,
      beneficiaries,
      initialAllocations
    );
    //bene1, bene2
    //40, 60

    // Update allocations
    await will.updateAllocations(
      owner.address,
      beneficiaries,
      updatedAllocations
    );
    //bene1, bene2
    //30, 70

    const allocation1 = await will.getBeneficiaryAllocationPercentage(
      owner.address,
      beneficiary1.address
    );
    const allocation2 = await will.getBeneficiaryAllocationPercentage(
      owner.address,
      beneficiary2.address
    );
    expect(allocation1).to.equal(30);
    expect(allocation2).to.equal(70);
  });

  it("Should update the allocation for a beneficiary and give remaining to new residual", async function () {
    // Create a will for the owner
    await will.createWill(owner.address);
    await will.setResidualBeneficiary(
      owner.address,
      residualBeneficiary1.address
    );
    // Add a beneficiary with an initial allocation
    const beneficiaries = [beneficiary1.address, beneficiary2.address];
    const initialAllocations = [40, 60];
    const updatedAllocations = [30, 50];
    await will.addBeneficiaries(
      owner.address,
      beneficiaries,
      initialAllocations
    );
    //bene1, bene2
    //40, 60

    // Update allocations
    await will.updateAllocations(
      owner.address,
      beneficiaries,
      updatedAllocations
    );
    //bene1, bene2, resi1
    //30, 50, 20

    const allocation1 = await will.getBeneficiaryAllocationPercentage(
      owner.address,
      beneficiary1.address
    );
    const allocation2 = await will.getBeneficiaryAllocationPercentage(
      owner.address,
      beneficiary2.address
    );
    const allocation3 = await will.getBeneficiaryAllocationPercentage(
      owner.address,
      residualBeneficiary1.address
    );
    expect(allocation1).to.equal(30);
    expect(allocation2).to.equal(50);
    expect(allocation3).to.equal(20);
  });

  it("Should update the allocation for a beneficiary and give remaining to existing residual", async function () {
    // Create a will for the owner
    await will.createWill(owner.address);
    await will.setResidualBeneficiary(
      owner.address,
      residualBeneficiary1.address
    );
    // Add a beneficiary with an initial allocation
    const beneficiaries = [beneficiary1.address, beneficiary2.address];
    const initialAllocations = [20, 60];
    const updatedAllocations = [10, 50];
    await will.addBeneficiaries(
      owner.address,
      beneficiaries,
      initialAllocations
    );
    //bene1, bene2, resi
    //20, 60, 20

    // Update allocations
    await will.updateAllocations(
      owner.address,
      beneficiaries,
      updatedAllocations
    );
    //bene1, bene2, resi1
    //10, 50, 40

    const allocation1 = await will.getBeneficiaryAllocationPercentage(
      owner.address,
      beneficiary1.address
    );
    const allocation2 = await will.getBeneficiaryAllocationPercentage(
      owner.address,
      beneficiary2.address
    );
    const allocation3 = await will.getBeneficiaryAllocationPercentage(
      owner.address,
      residualBeneficiary1.address
    );
    expect(allocation1).to.equal(10);
    expect(allocation2).to.equal(50);
    expect(allocation3).to.equal(40);
  });

  it("Should not update the allocation for a beneficiary if it exceeds 100 (w/o residual)", async function () {
    // Create a will for the owner
    await will.createWill(owner.address);
    await will.setResidualBeneficiary(
      owner.address,
      residualBeneficiary1.address
    );
    // Add a beneficiary with an initial allocation
    const beneficiaries = [beneficiary1.address, beneficiary2.address];
    const initialAllocations = [40, 60];
    const updatedAllocations = [20, 100];
    await will.addBeneficiaries(
      owner.address,
      beneficiaries,
      initialAllocations
    );
    //bene1, bene2
    //40, 60
    await will.setResidualBeneficiary(
      owner.address,
      residualBeneficiary2.address
    );
    await expect(
      will.updateAllocations(owner.address, beneficiaries, updatedAllocations)
    ).to.be.revertedWith("Total allocation exceeds 100%");
    //bene1, bene2
    //20, 100
  });

  it("Should not update the allocation for a beneficiary if it exceeds 100", async function () {
    // Create a will for the owner
    await will.createWill(owner.address);
    await will.setResidualBeneficiary(
      owner.address,
      residualBeneficiary1.address
    );
    // Add a beneficiary with an initial allocation
    const beneficiaries = [beneficiary1.address, beneficiary2.address];
    const initialAllocations = [10, 60];
    const updatedAllocations = [20, 70];
    await will.addBeneficiaries(
      owner.address,
      beneficiaries,
      initialAllocations
    );
    //bene1, bene2, resi1
    //10, 60, 30
    await will.setResidualBeneficiary(
      owner.address,
      residualBeneficiary2.address
    );
    await expect(
      will.updateAllocations(owner.address, beneficiaries, updatedAllocations)
    ).to.be.revertedWith("Total allocation exceeds 100%");
    //bene1, bene2, resi1
    //20, 70, 30
  });

  /* it("Should remove beneficiary", async function () { 
      // Create a will for the owner 
      await will.createWill(owner.address); 
      // Add a beneficiary with an initial allocation 
      const initialAllocation = 100; await will.addBeneficiary(owner.address, beneficiary1.address, initialAllocation); 
      // Remove the beneficiary 
      await will.removeBeneficiary(owner.address, beneficiary1.address);
      const allocation = await will.getBeneficiaryAllocationPercentage(owner.address, beneficiary1.address);
      expect(allocation).to.equal(0); 
  }); */

  it("Should revert if removing residual beneficiary", async function () {
    // Create the will and set the residual beneficiary
    await will.createWill(owner.address);
    await will.setResidualBeneficiary(
      owner.address,
      residualBeneficiary1.address
    );

    // Add some beneficiaries
    await will.addBeneficiaries(
      owner.address,
      [beneficiary1.address, beneficiary2.address],
      [30, 40]
    );
    // Attempt to remove the residual beneficiary (should fail)
    await expect(
      will.removeBeneficiaries(owner.address, [residualBeneficiary1.address])
    ).to.be.revertedWith("Cannot remove the residual beneficiary");
  });

  it("Should remove beneficiary and new residuary gets remaining", async function () {
    await will.createWill(owner.address);
    await will.setResidualBeneficiary(
      owner.address,
      residualBeneficiary1.address
    );
    // Add multiple beneficiaries with their allocations
    const beneficiaries = [beneficiary1.address, beneficiary2.address];
    const allocations = [10, 50]; //residualBeneficiary will get 40
    await will.addBeneficiaries(owner.address, beneficiaries, allocations);
    //bene1, bene2, resi1
    //10, 50, 40

    // Remove one beneficiary
    const beneficiariesToRemove = [beneficiary1.address];
    await will.setResidualBeneficiary(
      owner.address,
      residualBeneficiary2.address
    );
    await will.removeBeneficiaries(owner.address, beneficiariesToRemove);
    //bene2, resi1, resi2
    //50, 40, 10

    const allocation1 = await will.getBeneficiaryAllocationPercentage(
      owner.address,
      beneficiary1.address
    );
    const allocation2 = await will.getBeneficiaryAllocationPercentage(
      owner.address,
      beneficiary2.address
    );
    const allocation3 = await will.getBeneficiaryAllocationPercentage(
      owner.address,
      residualBeneficiary1.address
    );
    const allocation4 = await will.getBeneficiaryAllocationPercentage(
      owner.address,
      residualBeneficiary2.address
    );
    console.log(allocation1);
    expect(allocation1).to.equal(0);
    expect(allocation2).to.equal(50); // Beneficiary2 should be unaffected
    expect(allocation3).to.equal(40); // Residual1 gets what has been removed from beneficiary1
    expect(allocation4).to.equal(10); // Residual2 gets what has been removed from beneficiary1
  });

  it("Should remove beneficiary and existing residuary gets remaining", async function () {
    await will.createWill(owner.address);
    await will.setResidualBeneficiary(
      owner.address,
      residualBeneficiary1.address
    );
    // Add multiple beneficiaries with their allocations
    const beneficiaries = [beneficiary1.address, beneficiary2.address];
    const allocations = [10, 50]; //residualBeneficiary will get 40
    await will.addBeneficiaries(owner.address, beneficiaries, allocations);
    //bene1, bene2, resi1
    //10, 50, 40

    // Remove one beneficiary
    const beneficiariesToRemove = [beneficiary1.address];
    await will.setResidualBeneficiary(owner.address, beneficiary2.address);
    await will.removeBeneficiaries(owner.address, beneficiariesToRemove);
    //bene2, resi1
    //60, 40
    const allocation1 = await will.getBeneficiaryAllocationPercentage(
      owner.address,
      beneficiary1.address
    );
    const allocation2 = await will.getBeneficiaryAllocationPercentage(
      owner.address,
      beneficiary2.address
    );
    const allocation3 = await will.getBeneficiaryAllocationPercentage(
      owner.address,
      residualBeneficiary1.address
    );
    console.log(allocation1);
    expect(allocation1).to.equal(0);
    expect(allocation2).to.equal(60); // Bene12 gets what has been removed from bene1
    expect(allocation3).to.equal(40); // Resi1 remains unchanged
  });

  it("Should fund will successfully", async function () {
    await will.createWill(owner.address);
    await will.setResidualBeneficiary(
      owner.address,
      residualBeneficiary1.address
    );
    await will.fundWill(owner.address, { value: 100 });
    const digitalAssets = await will.getDigitalAssets(owner.address);
    expect(digitalAssets).to.equal(100);
  });

  // I have no idea how to check payments without running into errors
  it("Should distribute assets correctly and make payments", async function () {
    console.log("=== Starting distributeAssets test ===");
    // Create will
    await will.createWill(owner.address);
    await will.setResidualBeneficiary(
      owner.address,
      residualBeneficiary1.address
    );

    // Add beneficiaries and their allocations
    const beneficiaries = [beneficiary1.address, beneficiary2.address];
    const allocations = [20, 80]; // Allocations as percentages
    console.log("Beneficiaries:", beneficiaries); // Log beneficiaries' addresses

    await will.addBeneficiaries(owner.address, beneficiaries, allocations);

    // Fund the will with 100 units
    const fundAmount = ethers.parseEther("1.0");
    await will.fundWill(owner.address, { value: fundAmount });

    // Check that the assets have been funded correctly
    const digitalAssets = await will.getDigitalAssets(owner.address);
    expect(digitalAssets).to.equal(
      fundAmount,
      "The fund amount was not set correctly."
    );

    // Calculate expected amounts
    const expectedAmount1 = (fundAmount * 20n) / 100n;
    const expectedAmount2 = (fundAmount * 80n) / 100n;
    const expectedRemaining = fundAmount - expectedAmount1 - expectedAmount2;

    // Log expected amounts
    console.log(
      "Expected Amounts:",
      expectedAmount1,
      expectedAmount2,
      expectedRemaining
    );

    // Log the contract balance before distribution
    const contractBalanceBefore = await ethers.provider.getBalance(
      await will.getAddress()
    );
    console.log(
      "Contract balance before distribution:",
      contractBalanceBefore.toString()
    );

    // Initial balances (in terms of units)
    const initialBalance1 = await ethers.provider.getBalance(
      beneficiary1.address
    );
    const initialBalance2 = await ethers.provider.getBalance(
      beneficiary2.address
    );

    // Log initial balances
    console.log("Initial Balances:", initialBalance1, initialBalance2);

    // Distribute assets
    const tx = await will.distributeAssets(owner.address);
    const receipt = await tx.wait(); // Wait for the transaction to be mined

    // Log the contract balance after distribution
    const contractBalanceAfter = await ethers.provider.getBalance(
      await will.getAddress()
    );
    console.log(
      "Contract balance after distribution:",
      contractBalanceAfter.toString()
    );

    // Final balances after distribution
    const finalBalance1 = await ethers.provider.getBalance(
      beneficiary1.address
    );
    const finalBalance2 = await ethers.provider.getBalance(
      beneficiary2.address
    );

    // Log final balances after distribution
    console.log("Final Balances:", finalBalance1, finalBalance2);

    // Calculate received amounts as regular numbers
    const receivedAmount1 = finalBalance1 - initialBalance1;
    const receivedAmount2 = finalBalance2 - initialBalance2;

    // Log the received amounts
    console.log(`Beneficiary1 received: ${receivedAmount1} units`);
    console.log(`Beneficiary2 received: ${receivedAmount2} units`);

    // Verify that the received amounts are correct
    // expect(receivedAmount1).to.be.closeTo(expectedAmount1, 1);
    // expect(receivedAmount2).to.be.closeTo(expectedAmount2, 1);
    expect(receivedAmount1).to.equal(expectedAmount1);
    expect(receivedAmount2).to.equal(expectedAmount2);

    // Check remaining assets in the will after distribution
    const remainingAssets = await will.getDigitalAssets(owner.address);
    expect(remainingAssets).to.equal(expectedRemaining);

    // Log the remaining assets for verification
    console.log(`Remaining assets: ${remainingAssets} units`);
    console.log("=== Ending distributeAssets test ===");
  });

  /* it("Should return correct will details", async function () {
      await will.createWill(owner.address);
      // Sample setup: Add beneficiaries and allocations
      await will.addBeneficiary(owner.address, beneficiary1.address, 100);
      await will.addBeneficiary(owner.address, beneficiary2.address, 50);
  
      // Call viewWill function to get the will string
      const willString = await will.viewWill(owner.address);
  
      // Construct the expected string based on your logic
      const expectedWill = `Beneficiaries & Allocations:\n- ${beneficiary1.address.toLowerCase().substring(2)} -> 100\n- ${beneficiary2.address.toLowerCase().substring(2)} -> 50\n`; 
      console.log(willString);          
      // Check if the returned string matches the expected string exactly
      expect(willString).to.equal(expectedWill);
  }); */

  it("Should return correct will details", async function () {
    console.log("=== Starting Should return correct will details test ===");

    await will.createWill(owner.address);
    await will.setResidualBeneficiary(
      owner.address,
      residualBeneficiary1.address
    );

    // Add digital asset beneficiaries
    const beneficiaries = [beneficiary1.address, beneficiary2.address];
    const allocations = [70, 30];
    await will.addBeneficiaries(owner.address, beneficiaries, allocations);

    // Fund digital assets
    await will.fundWill(owner.address, { value: 100 });

    // Create a physical asset
    const assetDescription = "House on 123 Street";
    const assetValue = 1000;
    const certificationUrl = "ipfs://hash";
    const physicalAssetAllocations = [60, 40];

    await will.createAsset(
      owner.address,
      assetDescription,
      assetValue,
      certificationUrl,
      beneficiaries,
      physicalAssetAllocations
    );

    // Get the formatted will view
    const willString = await will.viewWill(owner.address);

    // Manually build the expected output
    const addr = (a) => a.toLowerCase().substring(2);

    const expectedWill = `=== DIGITAL ASSETS ===
Beneficiaries & Allocations:
- ${addr(beneficiary1.address)} -> 70%
- ${addr(beneficiary2.address)} -> 30%
Total Digital Assets (Wei): 100

=== PHYSICAL ASSETS ===
Asset ID: 1
Description: ${assetDescription}
Value: ${assetValue}
- ${addr(beneficiary1.address)} -> 60%
- ${addr(beneficiary2.address)} -> 40%\n
`;

    console.log(willString);
    expect(willString).to.equal(expectedWill);
  });

  it("Should add an editor successfully", async function () {
    await will.createWill(owner.address);
    await will.setResidualBeneficiary(
      owner.address,
      residualBeneficiary1.address
    );
    await will.addEditor(owner.address, editor1.address);
    const editorExists = await will.isAuthorisedEditorExist(
      owner.address,
      editor1.address
    );
    expect(editorExists).to.equal(true);
  });

  it("Should remove an editor successfully", async function () {
    await will.createWill(owner.address);
    await will.setResidualBeneficiary(
      owner.address,
      residualBeneficiary1.address
    );
    await will.addEditor(owner.address, editor1.address);
    await will.removeEditor(owner.address, editor1.address);
    const editorExists = await will.isAuthorisedEditorExist(
      owner.address,
      editor1.address
    );
    expect(editorExists).to.equal(false);
  });

  it("Should revert if adding the same editor twice", async function () {
    await will.createWill(owner.address);
    await will.setResidualBeneficiary(
      owner.address,
      residualBeneficiary1.address
    );
    await will.addEditor(owner.address, editor1.address);
    await expect(
      will.addEditor(owner.address, editor1.address)
    ).to.be.revertedWith("Editor already exists");
  });

  it("Should revert if trying to remove an editor who does not exist", async function () {
    await will.createWill(owner.address);
    await will.setResidualBeneficiary(
      owner.address,
      residualBeneficiary1.address
    );
    await expect(
      will.removeEditor(owner.address, editor1.address)
    ).to.be.revertedWith("Editor not found");
  });

  it("Should revert if a non-owner tries to remove an editor", async function () {
    await will.createWill(owner.address);
    await will.setResidualBeneficiary(
      owner.address,
      residualBeneficiary1.address
    );
    await will.addEditor(owner.address, editor1.address);
    await expect(
      will.connect(nonOwner).removeEditor(owner.address, editor1.address)
    ).to.be.revertedWith("Not the owner");
  });

  it("Should revert if adding invalid editor address", async function () {
    await will.createWill(owner.address);
    const zeroAddress = ethers.ZeroAddress;
    await expect(will.addEditor(owner.address, zeroAddress)).to.be.revertedWith(
      "Invalid editor address"
    );
  });

  it("Should not allow unauthorised editor to add beneficiaries", async function () {
    await will.createWill(owner.address);
    await will.setResidualBeneficiary(
      owner.address,
      residualBeneficiary1.address
    );
    await will.addEditor(owner.address, editor1.address);
    const beneficiaries = [beneficiary1.address, beneficiary2.address];
    const initialAllocations = [30, 70];
    await expect(
      will
        .connect(nonOwner)
        .addBeneficiaries(owner.address, beneficiaries, initialAllocations)
    ).to.be.revertedWith("Not authorized");
  });

  it("Should allow authorised editor to add beneficiaries", async function () {
    await will.createWill(owner.address);
    await will.setResidualBeneficiary(
      owner.address,
      residualBeneficiary1.address
    );
    await will.addEditor(owner.address, editor1.address);
    const beneficiaries = [beneficiary1.address, beneficiary2.address];
    const initialAllocations = [30, 70];
    await will
      .connect(editor1)
      .addBeneficiaries(owner.address, beneficiaries, initialAllocations);
    const allocation1 = await will.getBeneficiaryAllocationPercentage(
      owner.address,
      beneficiary1.address
    );
    const allocation2 = await will.getBeneficiaryAllocationPercentage(
      owner.address,
      beneficiary2.address
    );
    expect(allocation1).to.equal(30);
    expect(allocation2).to.equal(70);
  });

  it("Should not allow unauthorised editor to remove beneficiaries", async function () {
    await will.createWill(owner.address);
    await will.setResidualBeneficiary(
      owner.address,
      residualBeneficiary1.address
    );
    await will.addEditor(owner.address, editor1.address);
    const beneficiaries = [beneficiary1.address, beneficiary2.address];
    const initialAllocations = [30, 70];
    const beneficiariesToRemove = [beneficiary1.address];
    await will.addBeneficiaries(
      owner.address,
      beneficiaries,
      initialAllocations
    );
    await expect(
      will
        .connect(nonOwner)
        .removeBeneficiaries(owner.address, beneficiariesToRemove)
    ).to.be.revertedWith("Not authorized");
  });

  it("Should allow authorised editor to remove beneficiaries", async function () {
    await will.createWill(owner.address);
    await will.setResidualBeneficiary(
      owner.address,
      residualBeneficiary1.address
    );
    await will.addEditor(owner.address, editor1.address);
    const beneficiaries = [beneficiary1.address, beneficiary2.address];
    const initialAllocations = [30, 70];
    const beneficiariesToRemove = [beneficiary1.address];
    await will.addBeneficiaries(
      owner.address,
      beneficiaries,
      initialAllocations
    );
    await will
      .connect(editor1)
      .removeBeneficiaries(owner.address, beneficiariesToRemove);
    const allocation1 = await will.getBeneficiaryAllocationPercentage(
      owner.address,
      beneficiary2.address
    );
    const allocation2 = await will.getBeneficiaryAllocationPercentage(
      owner.address,
      residualBeneficiary1.address
    );
    const allocation3 = await will.getBeneficiaryAllocationPercentage(
      owner.address,
      beneficiary1.address
    );
    expect(allocation1).to.equal(70);
    expect(allocation2).to.equal(30);
    expect(allocation3).to.equal(0);
  });

  it("Should not allow unauthorised editor to update allocations", async function () {
    await will.createWill(owner.address);
    await will.setResidualBeneficiary(
      owner.address,
      residualBeneficiary1.address
    );
    await will.addEditor(owner.address, editor1.address);
    const beneficiaries = [beneficiary1.address, beneficiary2.address];
    const initialAllocations = [30, 70];
    const updatedAllocations = [20, 80];
    await will.addBeneficiaries(
      owner.address,
      beneficiaries,
      initialAllocations
    );
    await expect(
      will
        .connect(nonOwner)
        .updateAllocations(owner.address, beneficiaries, updatedAllocations)
    ).to.be.revertedWith("Not authorized");
  });

  it("Should allow authorised editor to update allocations", async function () {
    await will.createWill(owner.address);
    await will.setResidualBeneficiary(
      owner.address,
      residualBeneficiary1.address
    );
    await will.addEditor(owner.address, editor1.address);
    const beneficiaries = [beneficiary1.address, beneficiary2.address];
    const initialAllocations = [30, 70];
    const updatedAllocations = [20, 80];
    await will.addBeneficiaries(
      owner.address,
      beneficiaries,
      initialAllocations
    );
    await will
      .connect(editor1)
      .updateAllocations(owner.address, beneficiaries, updatedAllocations);
    const allocation1 = await will.getBeneficiaryAllocationPercentage(
      owner.address,
      beneficiary1.address
    );
    const allocation2 = await will.getBeneficiaryAllocationPercentage(
      owner.address,
      beneficiary2.address
    );
    expect(allocation1).to.equal(20);
    expect(allocation2).to.equal(80);
  });

  it("Should add a viewer successfully", async function () {
    await will.createWill(owner.address);
    await will.addViewer(owner.address, viewer1.address);
    const viewerExists = await will.isAuthorisedViewer(
      owner.address,
      viewer1.address
    );
    expect(viewerExists).to.equal(true);
  });

  it("Should remove a viewer successfully", async function () {
    await will.createWill(owner.address);
    await will.addViewer(owner.address, viewer1.address);
    await will.removeViewer(owner.address, viewer1.address);
    const viewerExists = await will.isAuthorisedViewer(
      owner.address,
      viewer1.address
    );
    expect(viewerExists).to.equal(false);
  });

  it("Should revert if adding the same viewer twice", async function () {
    await will.createWill(owner.address);
    await will.addViewer(owner.address, viewer1.address);
    await expect(
      will.addViewer(owner.address, viewer1.address)
    ).to.be.revertedWith("Viewer already exists");
  });

  it("Should revert if trying to remove an viewer who does not exist", async function () {
    await will.createWill(owner.address);
    await expect(
      will.removeViewer(owner.address, viewer1.address)
    ).to.be.revertedWith("Viewer not found");
  });

  it("Should allow the viewer with permission to call WillViewForBeneficiaries if will is InCreation (owner check)", async function () {
    await will.createWill(owner.address);
    await will.setResidualBeneficiary(
      owner.address,
      residualBeneficiary1.address
    );
    await will.addViewer(owner.address, viewer1.address);
    const beneficiaries = [beneficiary1.address, beneficiary2.address];
    const allocations = [20, 50];
    await will.addBeneficiaries(owner.address, beneficiaries, allocations);

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
    await will.createWill(owner.address);
    await expect(
      will.connect(viewer2).WillViewForBeneficiaries(owner.address)
    ).to.be.revertedWith("Not authorized to view this will (InCreation)");
  });

  it("test", async function () {
    const unlockTime = await getUnlockTime(web3);

    await advanceTime(web3, unlockTime);
    await disableAutomine(web3);
    await setMiningInterval(web3, 5000);

    const accounts = await web3.eth.getAccounts();
    /* 
    const deployedContract = await Contract.deploy().send({ from: accounts[0] });
    console.log("Contract deployed at:", deployedContract.options.address);
    */
    //  const tx = await deployedContract.methods
    const tx = await contract.methods
      .emitTestEvent()
      .send({ from: accounts[0] });
    console.log(tx);
  });
});
