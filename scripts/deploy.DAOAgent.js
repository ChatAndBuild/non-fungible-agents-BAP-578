const { ethers } = require("hardhat");

async function main() {
  // Replace these with your actual addresses
  const AGENT_TOKEN = "0xYourAgentTokenAddress";
  const DAO_CONTRACT = "0xYourDAOContractAddress";

  const DAOAgent = await ethers.getContractFactory("DAOAgent");
  const daoAgent = await DAOAgent.deploy(
    AGENT_TOKEN,
    DAO_CONTRACT
  );
  await daoAgent.deployed();

  console.log("DAOAgent deployed to:", daoAgent.address);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});