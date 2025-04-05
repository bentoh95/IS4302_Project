const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Step 1: Deploy AssetToken
  const AssetToken = await ethers.getContractFactory("contracts/AssetToken.sol:AssetToken");
  const assetToken = await AssetToken.connect(deployer).deploy();
  await assetToken.waitForDeployment();
  const assetTokenAddress = await assetToken.getAddress();
  console.log("✅ AssetToken deployed at:", assetTokenAddress);

  // Step 2: Deploy AssetRegistry with AssetToken address
  const AssetRegistry = await ethers.getContractFactory("contracts/AssetRegistry.sol:AssetRegistry");
  const assetRegistry = await AssetRegistry.connect(deployer).deploy(assetTokenAddress);
  await assetRegistry.waitForDeployment();
  const assetRegistryAddress = await assetRegistry.getAddress();
  console.log("✅ AssetRegistry deployed at:", assetRegistryAddress);

  // Step 3: Deploy Will with AssetRegistry address
  const Will = await ethers.getContractFactory("contracts/Will.sol:Will");
  const will = await Will.connect(deployer).deploy(assetRegistryAddress);
  await will.waitForDeployment();
  const willAddress = await will.getAddress();
  console.log("✅ Will contract deployed at:", willAddress);

  // Step 4: Emit a test event to verify the deployment
  const tx = await will.emitTestEvent();
  const receipt = await tx.wait();

  if (receipt.logs.length > 0) {
    const event = will.interface.parseLog(receipt.logs[0]);
    console.log("📢 Test event decoded:", {
      name: event.name,
      args: event.args,
    });
  } else {
    console.log("⚠️ No logs found in receipt.");
  }

  console.log("\n🎉 Deployment completed successfully!");
}

main().catch((error) => {
  console.error("❌ Error during deployment:", error);
  process.exit(1);
});
