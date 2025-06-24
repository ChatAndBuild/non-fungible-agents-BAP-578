const { ethers, upgrades } = require("hardhat");

async function main() {
  // Replace these with your actual addresses
  const GOVERNANCE = "0xa2d6b96D1D0A4966546B8D4c5EaA050bc27778ad";
  const AGENT_FACTORY = "0xYourAgentFactoryAddress";
  const FOUNDATION_WALLET = "0xd27dbd7b311A2f8607737d0cb8d1Defbe4B3A9ca";
  const TREASURY_WALLET = "0xd27dbd7b311A2f8607737d0cb8d1Defbe4B3A9ca";
  const STAKING_POOL_WALLET = "0xd27dbd7b311A2f8607737d0cb8d1Defbe4B3A9ca";

  const Treasury = await ethers.getContractFactory("BEP007Treasury");
  const treasury = await upgrades.deployProxy(
    Treasury,
    [
      GOVERNANCE,
      AGENT_FACTORY,
      FOUNDATION_WALLET,
      TREASURY_WALLET,
      STAKING_POOL_WALLET
    ],
    { initializer: "initialize", kind: "uups" }
  );
  await treasury.deployed();

  console.log("BEP007Treasury deployed to:", treasury.address);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});