const { ethers, upgrades } = require("hardhat");

async function main() {
  // Replace with your actual deployed contract addresses and parameters
  const BEP007_TOKEN_ADDRESS = "0xC252C3469735f9874720eF96f0764CD20dC30da7"; // deployed BEP007 token address
  const OWNER_ADDRESS = "0xd27dbd7b311A2f8607737d0cb8d1Defbe4B3A9ca";        // owner address
  const VOTING_PERIOD = 7;              // in days
  const QUORUM_PERCENTAGE = 10;         // e.g., 10%
  const EXECUTION_DELAY = 2;            // in days

  const Governance = await ethers.getContractFactory("BEP007Governance");
  const governance = await upgrades.deployProxy(
    Governance,
    [
      "BEP007 Governance",           // name
      BEP007_TOKEN_ADDRESS,
      OWNER_ADDRESS,
      VOTING_PERIOD,
      QUORUM_PERCENTAGE,
      EXECUTION_DELAY
    ],
    { initializer: "initialize" }
  );
  await governance.deployed();
  console.log("BEP007Governance deployed to:", governance.address);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});