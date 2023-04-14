const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const helpers = require("@nomicfoundation/hardhat-network-helpers");
describe("Tests for Liquidity Locker Contract", function () {
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
  describe("Tests for scheduleVesting function", function () {
    it("Only contract owner can schedule a vest.", async function () {
      const { hardhatLiquidityLocker, user1 } = await loadFixture(
        deployTokenFixture
      );
      await expect(
        hardhatLiquidityLocker.connect(user1).scheduleVesting(30, 10, 10)
      ).to.be.revertedWith(
        "LiquidityLocker: Only owner can Schedule Vesting and approve referer."
      );
    });
    it("Vest's cliff duration should not be greater than its end Timestamp.", async function () {
      const { hardhatLiquidityLocker, owner } = await loadFixture(
        deployTokenFixture
      );
      await expect(
        hardhatLiquidityLocker.scheduleVesting(10, 30, 10)
      ).to.be.revertedWith(
        "LiquidityLocker: Cliff Duration cannot be greater than End timestamp"
      );
    });

    it("On completing of scheduleVesting(), it should emit a VestingScheduled event.", async function () {
      const { hardhatLiquidityLocker } = await loadFixture(deployTokenFixture);
      await expect(hardhatLiquidityLocker.scheduleVesting(30, 10, 10))
        .to.emit(hardhatLiquidityLocker, "VestingScheduled")
        .withArgs(1, 30, 10);
    });
  });
  describe("Tests for vestAssests function", function () {
    it("On adding assests to a vest, that vest should have scheduled by owner.", async function () {
      const { hardhatERC20Token, hardhatLiquidityLocker, owner, user1 } =
        await loadFixture(deployTokenFixture);
      await expect(
        hardhatLiquidityLocker.connect(user1).vestAssests(1000, 1)
      ).to.be.revertedWith("LiquidityLocker: This schedule does not exist");
    });
    it("Existing benefiter cannot create a new vest.", async function () {
      const { hardhatERC20Token, hardhatLiquidityLocker } = await loadFixture(
        deployTokenFixture
      );
      await hardhatLiquidityLocker.scheduleVesting(60, 30, 10);
      await hardhatERC20Token.approve(hardhatLiquidityLocker.address, 1000);
      await hardhatLiquidityLocker.vestAssests(500, 1);
      expect(hardhatLiquidityLocker.vestAssests(500, 1)).to.be.revertedWith(
        "LiquidityLocker: sender already have assests vested in contract."
      );
    });
    it("User should add non zero assests to vest.", async function () {
      const { hardhatERC20Token, hardhatLiquidityLocker } = await loadFixture(
        deployTokenFixture
      );
      await hardhatLiquidityLocker.scheduleVesting(60, 30, 10);
      await hardhatERC20Token.approve(hardhatLiquidityLocker.address, 1000);
      await expect(hardhatLiquidityLocker.vestAssests(0, 1)).to.be.revertedWith(
        "LiquidityLocker: No of token should be greater than zero."
      );
    });
    it("The user is referd by a approved referer.", async function () {
      const { hardhatERC20Token, hardhatLiquidityLocker, user1, owner } =
        await loadFixture(deployTokenFixture);
      await hardhatLiquidityLocker.addReferer(user1.address);
      await hardhatLiquidityLocker.connect(user1).refer(owner.address);
      await hardhatLiquidityLocker.scheduleVesting(60, 30, 10);
      await hardhatERC20Token.transfer(hardhatLiquidityLocker.address, 100);
      await hardhatERC20Token.approve(hardhatLiquidityLocker.address, 1000);
      await hardhatLiquidityLocker.vestAssests(1000, 1);
      expect(await hardhatERC20Token.balanceOf(user1.address)).to.equal(7);
    });
  });
  describe("Tests for withdraw Function", function () {
    it("Users with existing vests only can withdraw assets.", async function () {
      const { hardhatLiquidityLocker } = await loadFixture(deployTokenFixture);
      await expect(
        hardhatLiquidityLocker.withdrawToken(100)
      ).to.be.revertedWith(
        "LiquidityLocker: only benefiters can withdraw or add token from/to vest"
      );
    });
    it("Number of assests to withdraw should not be greater than assests in vest.", async function () {
      const { hardhatERC20Token, hardhatLiquidityLocker } = await loadFixture(
        deployTokenFixture
      );
      await hardhatERC20Token.approve(hardhatLiquidityLocker.address, 100);
      await hardhatLiquidityLocker.scheduleVesting(60, 30, 10);
      await hardhatLiquidityLocker.vestAssests(100, 1);
      await expect(
        hardhatLiquidityLocker.withdrawToken(150)
      ).to.be.revertedWith("LiquidityLocker: Not enough token vested");
    });
    it("To withdraw assests from vest. cliff duration must have elapsed.", async function () {
      const { hardhatERC20Token, hardhatLiquidityLocker } = await loadFixture(
        deployTokenFixture
      );
      await hardhatERC20Token.approve(hardhatLiquidityLocker.address, 100);
      await hardhatLiquidityLocker.scheduleVesting(60, 30, 10);
      await hardhatLiquidityLocker.vestAssests(100, 1);
      await expect(hardhatLiquidityLocker.withdrawToken(50)).to.be.revertedWith(
        "LiquidityLocker: cliff duration have not passed"
      );
    });
    it("On successful withdrawal of assests from vest.", async function () {
      const { hardhatERC20Token, hardhatLiquidityLocker } = await loadFixture(
        deployTokenFixture
      );
      await hardhatERC20Token.approve(hardhatLiquidityLocker.address, 100);
      await hardhatLiquidityLocker.scheduleVesting(60, 30, 10);
      await hardhatLiquidityLocker.vestAssests(100, 1);
      await helpers.time.increase(40);
      await hardhatLiquidityLocker.withdrawToken(50);
      expect(
        await hardhatERC20Token.balanceOf(hardhatLiquidityLocker.address)
      ).to.equal(50);
    });
  });
  describe("Tests for dropAllAssests function", function () {
    it("Only user with existing vest can drop there vest.", async function () {
      const { hardhatLiquidityLocker } = await loadFixture(deployTokenFixture);
      await expect(hardhatLiquidityLocker.dropAllAssests()).to.be.revertedWith(
        "LiquidityLocker: only benefiters can withdraw or add token from/to vest"
      );
    });
    it("User vest should have matured with dropping.", async function () {
      const { hardhatERC20Token, hardhatLiquidityLocker } = await loadFixture(
        deployTokenFixture
      );
      await hardhatERC20Token.approve(hardhatLiquidityLocker.address, 100);
      await hardhatLiquidityLocker.scheduleVesting(60, 30, 10);
      await hardhatLiquidityLocker.vestAssests(100, 1);
      await expect(hardhatLiquidityLocker.dropAllAssests()).to.be.revertedWith(
        "LiquidityLocker: Vested assests have not reached their maturity."
      );
    });
    it("On successful dropping of vest.", async function () {
      const { hardhatERC20Token, hardhatLiquidityLocker } = await loadFixture(
        deployTokenFixture
      );
      await hardhatERC20Token.approve(hardhatLiquidityLocker.address, 1000);
      await hardhatERC20Token.transfer(hardhatLiquidityLocker.address, 100);
      await hardhatLiquidityLocker.scheduleVesting(60, 30, 10);
      await hardhatLiquidityLocker.vestAssests(1000, 1);
      await helpers.time.increase(60);
      await hardhatLiquidityLocker.dropAllAssests();
      expect(
        await hardhatERC20Token.balanceOf(hardhatLiquidityLocker.address)
      ).to.equal(33);
    });
  });
  describe("Tests for refer function", function () {
    it("Only address approved by owner can refer.", async function () {
      const { hardhatLiquidityLocker, user1 } = await loadFixture(
        deployTokenFixture
      );
      await expect(
        hardhatLiquidityLocker.refer(user1.address)
      ).to.be.revertedWith("LiquiityLocker: Only approved referer can refer");
    });
    it("Referer cannot refer a invalid address for referal reward.", async function () {
      const { hardhatLiquidityLocker, zero_address } = await loadFixture(
        deployTokenFixture
      );
      await expect(
        hardhatLiquidityLocker.refer(zero_address)
      ).to.be.revertedWith("LiquidityLocker: Invalid address");
    });
    it("Referer cannnot refer already refered address for referal reward.", async function () {
      const { hardhatLiquidityLocker, user1, owner } = await loadFixture(
        deployTokenFixture
      );
      await hardhatLiquidityLocker.addReferer(owner.address);
      await hardhatLiquidityLocker.refer(user1.address);
      await expect(
        hardhatLiquidityLocker.refer(user1.address)
      ).to.be.revertedWith(
        "LiquidityLocker: This user address is already refered."
      );
    });
    it("Referer cannot refer himself.", async function () {
      const { hardhatLiquidityLocker, owner } = await loadFixture(
        deployTokenFixture
      );
      await hardhatLiquidityLocker.addReferer(owner.address);
      await expect(
        hardhatLiquidityLocker.refer(owner.address)
      ).to.be.revertedWith(
        "LiquidityLocker: Msg Sender cannot approve himself."
      );
    });
    it("Two referer address cannot refer one another", async function () {
      const { hardhatLiquidityLocker, owner, user1 } = await loadFixture(
        deployTokenFixture
      );
      await hardhatLiquidityLocker.addReferer(owner.address);
      await hardhatLiquidityLocker.addReferer(user1.address);

      await hardhatLiquidityLocker.refer(user1.address);
      await expect(
        hardhatLiquidityLocker.connect(user1).refer(owner.address)
      ).to.be.revertedWith(
        "LiquidityLocker: Two addresses cannot refer each other."
      );
    });
  });
  describe("addReferer function", function () {
    it("Only owner can approve address to refer", async function () {
      const { hardhatLiquidityLocker, user1, owner } = await loadFixture(
        deployTokenFixture
      );
      await expect(
        hardhatLiquidityLocker.connect(user1).addReferer(owner.address)
      ).to.be.revertedWith(
        "LiquidityLocker: Only owner can Schedule Vesting and approve referer."
      );
    });
    it("Referer cannot refer zero address user for refer reward.", async function () {
      const { hardhatLiquidityLocker, owner, zero_address } = await loadFixture(
        deployTokenFixture
      );
      await expect(
        hardhatLiquidityLocker.addReferer(zero_address)
      ).to.be.revertedWith("LiquidityLocker: Invalid address");
    });
  });
  describe("addAssests function", function () {
    it("Only user with vested Assessts can Add", async function () {
      const { hardhatLiquidityLocker } = await loadFixture(deployTokenFixture);
      await expect(hardhatLiquidityLocker.addAssests(100)).to.be.revertedWith(
        "LiquidityLocker: only benefiters can withdraw or add token from/to vest"
      );
    });
    it("Benefiter cannot add zero assests in existing vest", async function () {
      const { hardhatERC20Token, hardhatLiquidityLocker } = await loadFixture(
        deployTokenFixture
      );
      await hardhatERC20Token.approve(hardhatLiquidityLocker.address, 1000);
      await hardhatLiquidityLocker.scheduleVesting(60, 30, 10);
      await hardhatLiquidityLocker.vestAssests(1000, 1);
      await expect(hardhatLiquidityLocker.addAssests(0)).to.be.revertedWith(
        "LiquidityLocker: Enter non zero tokens to add."
      );
    });

    it("Adding assests after maturity time have elapsed", async function () {
      const { hardhatERC20Token, hardhatLiquidityLocker } = await loadFixture(
        deployTokenFixture
      );
      await hardhatERC20Token.approve(hardhatLiquidityLocker.address, 1100);
      await hardhatLiquidityLocker.scheduleVesting(30, 10, 10);
      await hardhatLiquidityLocker.vestAssests(1000, 1);
      await helpers.time.increase(30);
      await hardhatLiquidityLocker.addAssests(100);
      await expect(
        await hardhatERC20Token.balanceOf(hardhatLiquidityLocker.address)
      ).to.be.equal(1100);
    });

    it("Succesful addition in vested assests", async function () {
      const { hardhatERC20Token, hardhatLiquidityLocker } = await loadFixture(
        deployTokenFixture
      );
      await hardhatERC20Token.approve(hardhatLiquidityLocker.address, 1300);
      await hardhatLiquidityLocker.scheduleVesting(60, 30, 10);
      await hardhatLiquidityLocker.vestAssests(1000, 1);
      await hardhatLiquidityLocker.addAssests(300);
      await expect(
        await hardhatERC20Token.balanceOf(hardhatLiquidityLocker.address)
      ).to.be.equal(1300);
    });
  });
});
