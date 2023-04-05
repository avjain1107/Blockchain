const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const provider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:8545");
describe("ERC20 token contract", function () {
  async function deployTokenFixture() {
    const Token = await ethers.getContractFactory("ERC20");
    const [owner, user1, user2] = await ethers.getSigners();
    const hardhatToken = await Token.deploy("Avinash", "AJ");
    await hardhatToken.deployed();
    const zero_address = "0x0000000000000000000000000000000000000000";
    const zero_user = new ethers.VoidSigner(zero_address, provider);
    return {
      hardhatToken,
      owner,
      user1,
      user2,
      zero_user,
    };
  }
  describe("Deployment", function () {
    it("should set the right owner", async function () {
      const { hardhatToken, owner } = await loadFixture(deployTokenFixture);
      expect(await hardhatToken.owner()).to.equal(owner.address);
    });
    it("assign total supply to owner", async function () {
      const { hardhatToken, owner } = await loadFixture(deployTokenFixture);
      const ownerBalance = await hardhatToken.balanceOf(owner.address);
      expect(await hardhatToken.totalSupply()).to.equal(ownerBalance);
    });
    it("Token name", async function () {
      const { hardhatToken } = await loadFixture(deployTokenFixture);
      expect(await hardhatToken.name()).to.equal("Avinash");
    });
    it("Token symbool", async function () {
      const { hardhatToken } = await loadFixture(deployTokenFixture);
      expect(await hardhatToken.symbol()).to.equal("AJ");
    });
    it("Token decimal", async function () {
      const { hardhatToken } = await loadFixture(deployTokenFixture);
      expect(await hardhatToken.decimal()).to.equal(18);
    });
  });
  describe("Transaction", function () {
    it("transfer tokens between account", async function () {
      const { hardhatToken, owner, user1, user2 } = await loadFixture(
        deployTokenFixture
      );
      expect(
        await hardhatToken.transfer(user1.address, 100)
      ).to.changeTokenBalance(hardhatToken, [owner, user1], [-100, 100]);
      expect(
        await hardhatToken.connect(user1).transfer(user2.address, 50)
      ).to.changeTokenBalance(hardhatToken, [user1, user2], [-50, 50]);
    });
    it("should emit transfers events", async function () {
      const { hardhatToken, owner, user1, user2 } = await loadFixture(
        deployTokenFixture
      );
      await expect(hardhatToken.transfer(user1.address, 100))
        .to.emit(hardhatToken, "Transfer")
        .withArgs(owner.address, user1.address, 100);
      await expect(hardhatToken.connect(user1).transfer(user2.address, 50))
        .to.emit(hardhatToken, "Transfer")
        .withArgs(user1.address, user2.address, 50);
    });
    it("should fail if sender doesn't have enough token", async function () {
      const { hardhatToken, owner, user1 } = await loadFixture(
        deployTokenFixture
      );
      const initialOwnerBalance = await hardhatToken.balanceOf(owner.address);
      await expect(
        hardhatToken.connect(user1).transfer(owner.address, 1)
      ).to.be.revertedWith("Not sufficient balance");
      expect(await hardhatToken.balanceOf(owner.address)).to.equal(
        initialOwnerBalance
      );
    });
  });
  describe("Approve", function () {
    it("approve spender some allowance", async function () {
      const { hardhatToken, owner, user1 } = await loadFixture(
        deployTokenFixture
      );
      await hardhatToken.approve(user1.address, 200);
      expect(
        await hardhatToken.allowance(owner.address, user1.address)
      ).to.equal(200);
    });
    it("should emit Approval event", async function () {
      const { hardhatToken, owner, user1 } = await loadFixture(
        deployTokenFixture
      );
      expect(await hardhatToken.approve(user1.address, 200))
        .to.emit(hardhatToken, "Approval")
        .withArgs(owner.address, user1.address, 200);
    });

    it("invalid owner address", async function () {
      const { hardhatToken, owner, zero_user } = await loadFixture(
        deployTokenFixture
      );
      // console.log(zero_user);
      await expect(
        hardhatToken.connect(owner).approve(zero_user.address, 1)
      ).to.be.revertedWith("Invalid spender address");
    });
  });
  describe("minter function", function () {
    it("mint token to user1", async function () {
      const { hardhatToken, owner, user1 } = await loadFixture(
        deployTokenFixture
      );
      await hardhatToken.mint(user1.address, 100);
      expect(await hardhatToken.mint(user1.address, 100)).to.changeTokenBalance(
        hardhatToken,
        [owner, user1],
        [0, 100]
      );
    });
    it("only owner can mint", async function () {
      const { hardhatToken, user1, user2 } = await loadFixture(
        deployTokenFixture
      );
      // console.log(user1);
      await expect(
        hardhatToken.connect(user1).mint(user2.address, 100)
      ).to.be.revertedWith("Only onwer can mint");
    });
  });
  describe("tranfer from function", function () {
    it("transfer from owner to user2 via user1", async function () {
      const { hardhatToken, owner, user1, user2 } = await loadFixture(
        deployTokenFixture
      );

      await hardhatToken.approve(user1.address, 100);
      expect(
        await hardhatToken
          .connect(user1)
          .transferFrom(owner.address, user2.address, 100)
      ).to.changeTokenBalance(hardhatToken, [owner, user2], [-100, 100]);
    });
    it("not enough allowance to transfer", async function () {
      const { hardhatToken, owner, user1, user2 } = await loadFixture(
        deployTokenFixture
      );

      await hardhatToken.approve(user1.address, 100);
      await expect(
        hardhatToken
          .connect(user1)
          .transferFrom(owner.address, user2.address, 200)
      ).to.be.revertedWith("Spender do not have enough balance approval");
    });
    it("not enough balance to transfer", async function () {
      const { hardhatToken, owner, user1, user2 } = await loadFixture(
        deployTokenFixture
      );

      await hardhatToken.connect(user1).approve(user2.address, 1000);
      await expect(
        hardhatToken
          .connect(user2)
          .transferFrom(user1.address, owner.address, 10000)
      ).to.be.revertedWith("Owner account do not have enough balance");
    });
  });
});
