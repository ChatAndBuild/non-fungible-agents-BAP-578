const { ethers } = require("hardhat");

async function main() {
  // Replace these with your actual addresses
  const AGENT_TOKEN = "0xYourAgentTokenAddress";
  const GAME_CONTRACT = "0xYourGameContractAddress";

  const GameAgent = await ethers.getContractFactory("GameAgent");
  const gameAgent = await GameAgent.deploy(
    AGENT_TOKEN,
    GAME_CONTRACT
  );
  await gameAgent.deployed();

  console.log("GameAgent deployed to:", gameAgent.address);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});