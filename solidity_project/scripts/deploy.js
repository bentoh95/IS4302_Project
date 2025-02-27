const hre = require("hardhat");

async function main() {
  // dice contract deployment reference
//   const Dice = await hre.ethers.getContractFactory("Dice");
//   const dice = await Dice.deploy();
//   await dice.waitForDeployment();
//   console.log("Dice deployed to: ", await dice.getAddress());

//   const DiceMarket = await hre.ethers.getContractFactory("DiceMarket");
//   const diceMarket = await DiceMarket.deploy(
//     await dice.getAddress(),
//     "100000000000000000000000"
//   );
//   await diceMarket.waitForDeployment();
//   console.log("DiceMarket deployed to:", await diceMarket.getAddress());

//   const DiceBattle = await hre.ethers.getContractFactory("DiceBattle");
//   const diceBattle = await DiceBattle.deploy(await dice.getAddress()); 
//   await diceBattle.waitForDeployment();
//   console.log("DiceBattle deployed to:", await diceBattle.getAddress());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
