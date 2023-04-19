const { ethers, upgrades } = require("hardhat");
async function main() {
  const MultiSigWallet = await ethers.getContractFactory("MultiSigWallet");
  console.log("MultiSigWallet contract is deploying......");
  const MultiSig = await upgrades.deployProxy(MultiSigWallet, [3], {
    initializer: "initialize",
  });
  await MultiSig.deployed();
  console.log("First contract is deployed on address", MultiSig.address);
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
