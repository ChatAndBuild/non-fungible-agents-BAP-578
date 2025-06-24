const { ethers, upgrades } = require("hardhat");

async function main() {
  // Replace with your deployed BEP007 contract address
  const BEP007_ADDRESS = "0xC252C3469735f9874720eF96f0764CD20dC30da7";

  const MerkleTreeLearning = await ethers.getContractFactory("MerkleTreeLearning");
  const merkleTreeLearning = await upgrades.deployProxy(
    MerkleTreeLearning,
    [BEP007_ADDRESS],
    { initializer: "initialize" }
  );
  await merkleTreeLearning.deployed();

  console.log("MerkleTreeLearning deployed to:", merkleTreeLearning.address);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});