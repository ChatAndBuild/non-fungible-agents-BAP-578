const { ethers } = require("hardhat");

async function main() {
  const GOVERNANCE = "0xa2d6b96D1D0A4966546B8D4c5EaA050bc27778ad";
  const BEP007EnhancedImpl = await ethers.getContractFactory("BEP007EnhancedImpl");
  const bep007EnhancedImpl = await BEP007EnhancedImpl.deploy();
  await bep007EnhancedImpl.deployed();
  console.log("BEP007EnhancedImpl deployed to:", bep007EnhancedImpl.address);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});