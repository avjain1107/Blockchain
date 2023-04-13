const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const helpers = require("@nomicfoundation/hardhat-network-helpers");
describe("Liquidity Locker Contract", function () {
  async function deployTokenFixture() {
    const ERC20Token = await ethers.getContractFactory("ERC20Token");
    const LiquidityLocker = await ethers.getContractFactory("LiquidityLocker");
    const hardhatERC20Token = await ERC20Token.deploy();
    const hardhatLiquidityLocker = await LiquidityLocker.deploy(
      hardhatERC20Token.address,
      5,
      3,
      25,
      2
    );
    const [owner, user1, user2] = await ethers.getSigners();
    await hardhatERC20Token.deployed();
    await hardhatLiquidityLocker.deployed();

    const zero_address = "0x0000000000000000000000000000000000000000";
    return {
      hardhatERC20Token,
      hardhatLiquidityLocker,
      owner,
      user1,
      user2,
      zero_address,
    };
  }
  describe("scheduleVesting function", function () {
    it("only owner can call this function", async function () {
      const { hardhatLiquidityLocker, user1 } = await loadFixture(
        deployTokenFixture
      );
      await expect(
        hardhatLiquidityLocker.connect(user1).scheduleVesting(30, 10, 10, 10)
      ).to.be.revertedWith("LiquidityLocker: Only owner can Schedule Vesting");
    });
    it("Cliff duration not greater than end Timestamp", async function () {
      const { hardhatLiquidityLocker, owner } = await loadFixture(
        deployTokenFixture
      );
      await expect(
        hardhatLiquidityLocker.scheduleVesting(10, 30, 10, 10)
      ).to.be.revertedWith(
        "LiquidityLocker: Cliff Duration cannot be greater than End timestamp"
      );
    });

    it("should emit VestingScheduled event", async function () {
      const { hardhatLiquidityLocker } = await loadFixture(deployTokenFixture);
      await expect(hardhatLiquidityLocker.scheduleVesting(30, 10, 10, 10))
        .to.emit(hardhatLiquidityLocker, "VestingScheduled")
        .withArgs(1, 30, 10);
    });
  });
  describe("vestAssests function", function () {
    it("schedule does not exist", async function () {
      const { hardhatERC20Token, hardhatLiquidityLocker, owner, user1 } =
        await loadFixture(deployTokenFixture);
      await expect(
        hardhatLiquidityLocker.connect(user1).vestAssests(1000, 1)
      ).to.be.revertedWith("LiquidityLocker: This schedule does not exist");
    });
    it("already a benefitter", async function () {
      const { hardhatERC20Token, hardhatLiquidityLocker } = await loadFixture(
        deployTokenFixture
      );
      await hardhatLiquidityLocker.scheduleVesting(60, 30, 10, 10);
      await hardhatERC20Token.approve(hardhatLiquidityLocker.address, 1000);
      await hardhatLiquidityLocker.vestAssests(500, 1);
      expect(hardhatLiquidityLocker.vestAssests(500, 1)).to.be.revertedWith(
        "LiquidityLocker: sender already have assests vested in contract."
      );
    });
    it("only non zero assests can be vested", async function () {
      const { hardhatERC20Token, hardhatLiquidityLocker } = await loadFixture(
        deployTokenFixture
      );
      await hardhatLiquidityLocker.scheduleVesting(60, 30, 10, 10);
      await hardhatERC20Token.approve(hardhatLiquidityLocker.address, 1000);
      await expect(hardhatLiquidityLocker.vestAssests(0, 1)).to.be.revertedWith(
        "LiquidityLocker: No of token should be greater than zero."
      );
    });
    it("Vesting by a refered address", async function () {
      const { hardhatERC20Token, hardhatLiquidityLocker, user1, owner } =
        await loadFixture(deployTokenFixture);
      await hardhatLiquidityLocker.connect(user1).refer(owner.address);
      await hardhatLiquidityLocker.scheduleVesting(60, 30, 10, 10);
      await hardhatERC20Token.transfer(hardhatLiquidityLocker.address, 100);
      await hardhatERC20Token.approve(hardhatLiquidityLocker.address, 1000);
      await hardhatLiquidityLocker.vestAssests(1000, 1);
      expect(await hardhatERC20Token.balanceOf(user1.address)).to.equal(7);
    });
  });
  describe("withdraw Function", function () {
    it("only benefiter can withdraw assests", async function () {
      const { hardhatLiquidityLocker } = await loadFixture(deployTokenFixture);
      await expect(
        hardhatLiquidityLocker.withdrawToken(100)
      ).to.be.revertedWith(
        "LiquidityLocker: only benefiters can withdraw or add vested token"
      );
    });
    it("Not enough token to withdraw", async function () {
      const { hardhatERC20Token, hardhatLiquidityLocker } = await loadFixture(
        deployTokenFixture
      );
      await hardhatERC20Token.approve(hardhatLiquidityLocker.address, 100);
      await hardhatLiquidityLocker.scheduleVesting(60, 30, 10, 10);
      await hardhatLiquidityLocker.vestAssests(100, 1);
      await expect(
        hardhatLiquidityLocker.withdrawToken(150)
      ).to.be.revertedWith("LiquidityLocker: Not enough token vested");
    });
    it("Cliff duration have not yet passed", async function () {
      const { hardhatERC20Token, hardhatLiquidityLocker } = await loadFixture(
        deployTokenFixture
      );
      await hardhatERC20Token.approve(hardhatLiquidityLocker.address, 100);
      await hardhatLiquidityLocker.scheduleVesting(60, 30, 10, 10);
      await hardhatLiquidityLocker.vestAssests(100, 1);
      await expect(hardhatLiquidityLocker.withdrawToken(50)).to.be.revertedWith(
        "LiquidityLocker: cliff duration have not passed"
      );
    });
    it("Successful withdrawal", async function () {
      const { hardhatERC20Token, hardhatLiquidityLocker } = await loadFixture(
        deployTokenFixture
      );
      await hardhatERC20Token.approve(hardhatLiquidityLocker.address, 100);
      await hardhatLiquidityLocker.scheduleVesting(60, 30, 10, 10);
      await hardhatLiquidityLocker.vestAssests(100, 1);
      await helpers.time.increase(40);
      await hardhatLiquidityLocker.withdrawToken(50);
      expect(
        await hardhatERC20Token.balanceOf(hardhatLiquidityLocker.address)
      ).to.equal(50);
    });
  });
  describe("dropAllAssests", function () {
    it("Only user with vested Assessts can drop", async function () {
      const { hardhatLiquidityLocker } = await loadFixture(deployTokenFixture);
      await expect(hardhatLiquidityLocker.dropAllAssests()).to.be.revertedWith(
        "LiquidityLocker: only benefiters can withdraw or add vested token"
      );
    });
    it("Vested assests have not reached maturity", async function () {
      const { hardhatERC20Token, hardhatLiquidityLocker } = await loadFixture(
        deployTokenFixture
      );
      await hardhatERC20Token.approve(hardhatLiquidityLocker.address, 100);
      await hardhatLiquidityLocker.scheduleVesting(60, 30, 10, 10);
      await hardhatLiquidityLocker.vestAssests(100, 1);
      await expect(hardhatLiquidityLocker.dropAllAssests()).to.be.revertedWith(
        "LiquidityLocker: Vested assests have not reached their maturity."
      );
    });
    it("Successfully dropped all assests", async function () {
      const { hardhatERC20Token, hardhatLiquidityLocker } = await loadFixture(
        deployTokenFixture
      );
      await hardhatERC20Token.approve(hardhatLiquidityLocker.address, 1000);
      await hardhatERC20Token.transfer(hardhatLiquidityLocker.address, 100);
      await hardhatLiquidityLocker.scheduleVesting(60, 30, 10, 10);
      await hardhatLiquidityLocker.vestAssests(1000, 1);
      await helpers.time.increase(60);
      await hardhatLiquidityLocker.dropAllAssests();
      expect(
        await hardhatERC20Token.balanceOf(hardhatLiquidityLocker.address)
      ).to.equal(33);
    });
  });
  describe("refer function", function () {
    it("Invalid address to refer", async function () {
      const { hardhatLiquidityLocker, zero_address } = await loadFixture(
        deployTokenFixture
      );
      await expect(
        hardhatLiquidityLocker.refer(zero_address)
      ).to.be.revertedWith("LiquidityLocker: Invalid address");
    });
    it("Address already refered", async function () {
      const { hardhatLiquidityLocker, user1 } = await loadFixture(
        deployTokenFixture
      );
      await hardhatLiquidityLocker.refer(user1.address);
      await expect(
        hardhatLiquidityLocker.refer(user1.address)
      ).to.be.revertedWith(
        "LiquidityLocker: This user address is already refered."
      );
    });
    it("Address cannot refer himself", async function () {
      const { hardhatLiquidityLocker, owner } = await loadFixture(
        deployTokenFixture
      );

      await expect(
        hardhatLiquidityLocker.refer(owner.address)
      ).to.be.revertedWith(
        "LiquidityLocker: Msg Sender cannot approve himself."
      );
    });
    it("Two address cannot refer one another", async function () {
      const { hardhatLiquidityLocker, owner, user1 } = await loadFixture(
        deployTokenFixture
      );
      await hardhatLiquidityLocker.refer(user1.address);
      await expect(
        hardhatLiquidityLocker.connect(user1).refer(owner.address)
      ).to.be.revertedWith(
        "LiquidityLocker: Two addresses cannot refer each other."
      );
    });
  });
  describe("addAssests function", function () {
    it("Only user with vested Assessts can Add", async function () {
      const { hardhatLiquidityLocker } = await loadFixture(deployTokenFixture);
      await expect(hardhatLiquidityLocker.addAssests(100)).to.be.revertedWith(
        "LiquidityLocker: only benefiters can withdraw or add vested token"
      );
    });
    it("Need atleast 20% of vested of assests to be added", async function () {
      const { hardhatERC20Token, hardhatLiquidityLocker } = await loadFixture(
        deployTokenFixture
      );
      await hardhatERC20Token.approve(hardhatLiquidityLocker.address, 1000);
      await hardhatLiquidityLocker.scheduleVesting(60, 30, 10, 10);
      await hardhatLiquidityLocker.vestAssests(1000, 1);
      await expect(hardhatLiquidityLocker.addAssests(100)).to.be.revertedWith(
        "LiquidityLocker: add atleast 20% of already vested assests"
      );
    });
    it("cannot add assests after cliff duration", async function () {
      const { hardhatERC20Token, hardhatLiquidityLocker } = await loadFixture(
        deployTokenFixture
      );
      await hardhatERC20Token.approve(hardhatLiquidityLocker.address, 1000);
      await hardhatLiquidityLocker.scheduleVesting(60, 30, 10, 10);
      await hardhatLiquidityLocker.vestAssests(1000, 1);
      await helpers.time.increase(60);
      await expect(hardhatLiquidityLocker.addAssests(300)).to.be.revertedWith(
        "LiquidityLocker: cannot add assest after cliffDuration."
      );
    });
    it("consecutive addAssests() should have a proper time interval in between", async function () {
      const { hardhatERC20Token, hardhatLiquidityLocker } = await loadFixture(
        deployTokenFixture
      );
      await hardhatERC20Token.approve(hardhatLiquidityLocker.address, 1000);
      // await hardhatERC20Token.transfer(hardhatLiquidityLocker.address, 100);
      await hardhatLiquidityLocker.scheduleVesting(60, 30, 10, 10);
      await hardhatLiquidityLocker.vestAssests(1000, 1);
      // await helpers.time.increase(60);
      await expect(hardhatLiquidityLocker.addAssests(300)).to.be.revertedWith(
        "LiquidityLocker: Duration between adding assests have not elapsed. "
      );
    });
    it("Succesful in adding Assests", async function () {
      const { hardhatERC20Token, hardhatLiquidityLocker } = await loadFixture(
        deployTokenFixture
      );
      await hardhatERC20Token.approve(hardhatLiquidityLocker.address, 1300);
      await hardhatLiquidityLocker.scheduleVesting(60, 30, 10, 10);
      await hardhatLiquidityLocker.vestAssests(1000, 1);
      await helpers.time.increase(10);
      await hardhatLiquidityLocker.addAssests(300);
      await expect(
        await hardhatERC20Token.balanceOf(hardhatLiquidityLocker.address)
      ).to.be.equal(1300);
    });
  });
});
