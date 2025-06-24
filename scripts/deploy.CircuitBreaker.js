const { ethers, upgrades } = require("hardhat");

async function main() {
  // Replace with your actual governance and emergency multi-sig addresses
  const GOVERNANCE_ADDRESS = "0xa2d6b96D1D0A4966546B8D4c5EaA050bc27778ad"; // governance contract address
  const MULTISIG_ADDRESS = "0xd27dbd7b311A2f8607737d0cb8d1Defbe4B3A9ca";   // emergency multi-sig wallet address

  const CircuitBreaker = await ethers.getContractFactory("CircuitBreaker");
  const circuitBreaker = await upgrades.deployProxy(
    CircuitBreaker,
    [GOVERNANCE_ADDRESS, MULTISIG_ADDRESS],
    { initializer: "initialize" }
  );
  await circuitBreaker.deployed();
  console.log("CircuitBreaker deployed to:", circuitBreaker.address);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});