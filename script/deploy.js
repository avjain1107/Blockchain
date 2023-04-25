const { ethers, upgrades } = require("hardhat");
async function main() {
  const ERC20Token = await ethers.getContractFactory("ERC20Token");
  console.log("ERC20 contract using UUPS proxy is deploying......");
  const ERC20 = await upgrades.deployProxy(ERC20Token, { kind: "uups" });
  await ERC20.deployed();
  console.log("First contract is deployed on address", ERC20.address);
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
