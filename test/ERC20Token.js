const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
describe("Test for ERC20 Token Contract", function () {
  async function deployTokenFixture() {
    const ERC20Token = await ethers.getContractFactory("ERC20Token");
    const hardhatERC20 = await ERC20Token.deploy();
    const [onwer, user1, user2] = await ethers.getSigners();
    await hardhatERC20.initialize();
    return {
      hardhatERC20,
      onwer,
      user1,
      user2,
    };
  }
  describe("Test for initialize function.", function () {
    it("Initialize function can only be initialized once.", async function () {
      const { hardhatERC20 } = await loadFixture(deployTokenFixture);
      await expect(hardhatERC20.initialize()).to.be.revertedWith(
        "Initializable: contract is already initialized"
      );
    });
  });
  describe("ERC20 token.", function () {
    it("Token name of this contract.", async function () {
      const { hardhatERC20 } = await loadFixture(deployTokenFixture);
      await expect(await hardhatERC20.name()).to.equal("MyToken");
    });
    it("Token symbol of this contract.", async function () {
        const { hardhatERC20 } = await loadFixture(deployTokenFixture);
        await expect(await hardhatERC20.symbol()).to.equal("MTK");
      });
  });
});
