const { ethers, upgrades } = require("hardhat");

async function main() {
  // Replace with your deployed BEP007 contract address
  const BEP007_ADDRESS = "0xC252C3469735f9874720eF96f0764CD20dC30da7";

  const VaultPermissionManager = await ethers.getContractFactory("VaultPermissionManager");
  const vaultPermissionManager = await upgrades.deployProxy(
    VaultPermissionManager,
    [BEP007_ADDRESS],
    { initializer: "initialize" }
  );
  await vaultPermissionManager.deployed();

  console.log("VaultPermissionManager deployed to:", vaultPermissionManager.address);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});