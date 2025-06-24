const { ethers, upgrades } = require("hardhat");

async function main() {
  // Replace these with your actual addresses
  const BEP007_ENHANCED_IMPLEMENTATION = "0x9349DdF05A89569B8fAD3a2020BaF83eD9783756";
  const GOVERNANCE = "0xa2d6b96D1D0A4966546B8D4c5EaA050bc27778ad";
  const DEFAULT_LEARNING_MODULE = "0x13781bF8AA0E0BA55465a2DA21C0DB935769Dce3";

  const AgentFactory = await ethers.getContractFactory("AgentFactory");
  const agentFactory = await upgrades.deployProxy(
    AgentFactory,
    [
      BEP007_ENHANCED_IMPLEMENTATION,
      GOVERNANCE,
      DEFAULT_LEARNING_MODULE
    ],
    { initializer: "initialize", kind: "uups" }
  );
  await agentFactory.deployed();

  console.log("AgentFactory deployed to:", agentFactory.address);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});