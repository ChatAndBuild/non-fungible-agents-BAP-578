const { ethers, upgrades } = require("hardhat");

async function main() {
  const NAME = "BEP007 NFA";
  const SYMBOL = "NFA";
  const GOVERNANCE_ADDRESS = "0x0000000000000000000000000000000000000000"; // Replace with your governance address


  const BEP007Factory = await ethers.getContractFactory("BEP007");

  const bep007 = await upgrades.deployProxy(
    BEP007Factory,
    [NAME, SYMBOL, GOVERNANCE_ADDRESS],
    { initializer: "initialize", kind: "uups" }
  );
  await bep007.deployed();

  console.log("BEP007 deployed to:", bep007.address);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

/*
 * NOTE:
 * Your BEP007 contract is marked as 'abstract', so you must create a concrete implementation
 * (e.g., contract BEP007Test is BEP007 {}) and deploy that instead.
 * Replace "BEP007Test" above with the name of your concrete contract.
 */