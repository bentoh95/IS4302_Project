const { ethers } = require("hardhat");

async function main() {
  // Get the contract factory
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  Will = await ethers.getContractFactory("Will");
  will = await Will.connect(deployer).deploy();
  await will.waitForDeployment();

  const tx = await will.emitTestEvent();
  const receipt = await tx.wait();

  // Log the full receipt
  console.log("Full receipt:", receipt);

  // Log just the logs array
  console.log("Event logs:", receipt.logs);

  // Try to decode the first log event
  if (receipt.logs && receipt.logs.length > 0) {
    const event = will.interface.parseLog(receipt.logs[0]);
    console.log("Decoded event:", {
      name: event.name,
      args: event.args,
    });
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
