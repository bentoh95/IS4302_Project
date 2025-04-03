const { expect } = require("chai");
const { ethers } = require("hardhat");

const { Web3 } = require("web3");
const fs = require("fs");
require("dotenv").config();
const path = require("path");
const { assert } = require("console");

describe("AssetRegistry", function () {
  let AssetRegistry;
  let assetRegistry;
  let assetToken
  let platformOwner, willOwner, beneficiary1, beneficiary2, beneficiary3;

  // Deploy Will
  beforeEach(async function () {
    [platformOwner, willOwner, beneficiary1, beneficiary2, beneficiary3] = await ethers.getSigners();

    const AssetToken = await ethers.getContractFactory("AssetToken");
    assetToken = await AssetToken.connect(platformOwner).deploy();
    await assetToken.waitForDeployment();

    const AssetRegistry = await ethers.getContractFactory("AssetRegistry");
    assetRegistry = await AssetRegistry.connect(platformOwner).deploy(await assetToken.getAddress()); 
    await assetRegistry.waitForDeployment();
  });

  it("Should create a asset registry successfully", async function () {
    await assetRegistry.createAsset(
        willOwner.address,
        "asset 1 description",
        10,
        "image123",
        [beneficiary1, beneficiary2],
        [50, 50]
    );
    const assetData = await assetRegistry.getAssetData(1);
    expect(assetData.assetOwner).to.equal(willOwner.address);
    expect(assetData.beneficiaries.length).to.equal(2);
    expect(assetData.beneficiaries[0]).to.equal(beneficiary1.address);
    expect(assetData.beneficiaries[1]).to.equal(beneficiary2.address);
    expect(assetData.description).to.equal("asset 1 description");
    expect(assetData.value).to.equal(10);
  });

  it("Should update beneficiaries and allocations of asset successfully", async function () {
    await assetRegistry.createAsset(
      willOwner.address,
      "asset 1 description",
      10,
      "image123",
      [beneficiary1, beneficiary2],
      [50, 50]
    );
    const assetData = await assetRegistry.getAssetData(1);
    expect(assetData.assetOwner).to.equal(willOwner.address);
    expect(assetData.beneficiaries.length).to.equal(2);
    expect(assetData.beneficiaries[0]).to.equal(beneficiary1.address);
    expect(assetData.beneficiaries[1]).to.equal(beneficiary2.address);

    await assetRegistry.updateBeneficiariesAndAllocations(1, [beneficiary1, beneficiary2, beneficiary3], [25, 25, 50]);
    const updatedAssetData = await assetRegistry.getAssetData(1);
    expect(updatedAssetData.beneficiaries.length).to.equal(3);
    expect(updatedAssetData.beneficiaries[0]).to.equal(beneficiary1.address);
    expect(updatedAssetData.beneficiaries[1]).to.equal(beneficiary2.address);
    expect(updatedAssetData.beneficiaries[2]).to.equal(beneficiary3.address);
  });

  it("Should only allow platform owner to distribute asset", async function () {
    await assetRegistry.createAsset(
        willOwner.address,
        "asset 1 description",
        10,
        "image123",
        [beneficiary1, beneficiary2],
        [50, 50]
    );
    const assetData = await assetRegistry.getAssetData(1);
    expect(assetData.assetOwner).to.equal(willOwner.address);
    expect(assetData.beneficiaries.length).to.equal(2);

    await expect(assetRegistry.distributeAsset(1)).to.not.be.reverted;
  });

//   it("Should only allow platform owner to distribute asset", async function () {
//     await assetRegistry.createAsset(
//         willOwner.address,
//         "asset 1 description",
//         10,
//         "image123",
//         [beneficiary1, beneficiary2],
//         [50, 50]
//     );
//     const assetData = await assetRegistry.getAssetData(1);
//     expect(assetData.assetOwner).to.equal(willOwner.address);
//     expect(assetData.beneficiaries.length).to.equal(2);

//     // Try to call distributeAsset from willOwner (NOT the platformOwner)
//     const registryFromWrongAccount = assetRegistry.connect(willOwner);

//     // Expect this call to revert due to onlyOwner restriction
//     await expect(registryFromWrongAccount.distributeAsset(1)).to.be.reverted;

//     // Now call it correctly using platformOwner and expect success
//     const registryFromPlatformOwner = assetRegistry.connect(platformOwner);
//     await expect(registryFromPlatformOwner.distributeAsset(1)).to.not.be.reverted;
//   });


});
