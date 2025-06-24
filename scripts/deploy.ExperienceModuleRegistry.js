const { ethers, upgrades } = require("hardhat");

async function main() {
  const ExperienceModuleRegistry = await ethers.getContractFactory("ExperienceModuleRegistry");

  // Supply your BEP007 token address here
  const bep007Address = "0xC252C3469735f9874720eF96f0764CD20dC30da7";

  const registry = await upgrades.deployProxy(ExperienceModuleRegistry, [bep007Address], {
    initializer: "initialize",
  });

  await registry.deployed();

  console.log("ExperienceModuleRegistry deployed to:", registry.address);
}

main();
