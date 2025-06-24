const { ethers } = require("hardhat");

async function main() {
  // Replace these with your actual addresses
  const AGENT_TOKEN = "0xYourAgentTokenAddress";
  const DEX_ROUTER = "0xYourDexRouterAddress";
  const TREASURY = "0xYourTreasuryAddress";
  const PRICE_ORACLE = "0xYourPriceOracleAddress";

  const DeFiAgent = await ethers.getContractFactory("DeFiAgent");
  const defiAgent = await DeFiAgent.deploy(
    AGENT_TOKEN,
    DEX_ROUTER,
    TREASURY,
    PRICE_ORACLE
  );
  await defiAgent.deployed();

  console.log("DeFiAgent deployed to:", defiAgent.address);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});