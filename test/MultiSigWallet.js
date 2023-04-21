const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { any } = require("hardhat/internal/core/params/argumentTypes");
const { user } = require("pg/lib/defaults");
describe("Tests for Multi Sig Wallet Contract", function () {
  async function deployTokenFixture() {
    const ERC20Token = await ethers.getContractFactory("ERC20Token");
    const MultiSigWallet = await ethers.getContractFactory("MultiSigWallet");
    const hardhatERC20 = await ERC20Token.deploy();
    const hardhatMultiSigWallet = await MultiSigWallet.deploy();
    const [owner, user1, user2, user3] = await ethers.getSigners();
    const zero_address = "0x0000000000000000000000000000000000000000";
    await hardhatMultiSigWallet.initialize(3, hardhatERC20.address);
    const amountWei = ethers.utils.parseUnits("100", "wei");
    return {
      hardhatERC20,
      hardhatMultiSigWallet,
      owner,
      user1,
      user2,
      user3,
      zero_address,
      amountWei,
    };
  }
  describe("Test for initialize function", function () {
    it("Initialize function can only be initialized once", async function () {
      const { hardhatMultiSigWallet, hardhatERC20, user1, user2 } =
        await loadFixture(deployTokenFixture);
      await expect(
        hardhatMultiSigWallet.initialize(2, hardhatERC20.address)
      ).to.be.revertedWith("Initializable: contract is already initialized");
    });
  });
  describe("Test for submit transaction function.", function () {
    it("Only Approved owners can submit a transaction.", async function () {
      const { hardhatMultiSigWallet, hardhatERC20, user1, user2 } =
        await loadFixture(deployTokenFixture);
      await expect(
        hardhatMultiSigWallet
          .connect(user1)
          .submitTransaction(user2.address, 100, 1)
      ).to.be.revertedWith(
        "MultiSigWallet: Only Approved owners can perform this operation."
      );
    });
    it("Reciever's address while submitting transaction should be valid.", async function () {
      const { hardhatMultiSigWallet, zero_address, user1 } = await loadFixture(
        deployTokenFixture
      );
      await expect(
        hardhatMultiSigWallet.submitTransaction(zero_address, 100, 1)
      ).to.be.revertedWith("MultiSigWallet: Invalid address");
    });
    it("Amount given while submitting transaction must be greater than zero.", async function () {
      const { hardhatMultiSigWallet, user1 } = await loadFixture(
        deployTokenFixture
      );
      await expect(
        hardhatMultiSigWallet.submitTransaction(user1.address, 0, 1)
      ).to.be.revertedWith(
        "MultiSigWallet: Amount to transfer should not be zero."
      );
    });
    it("Transaction is successfully submitted by a approved owner.", async function () {
      const { hardhatMultiSigWallet, user1, owner } = await loadFixture(
        deployTokenFixture
      );
      await expect(
        hardhatMultiSigWallet.submitTransaction(user1.address, 100, 1)
      )
        .to.emit(hardhatMultiSigWallet, "SubmitTransaction")
        .withArgs(owner.address, 1);
    });
  });
  describe("Test for approveTransaction function.", function () {
    it("Only Approved owners can approve submitted transaction.", async function () {
      const { hardhatMultiSigWallet, user1, user2 } = await loadFixture(
        deployTokenFixture
      );
      await hardhatMultiSigWallet.submitTransaction(user2.address, 100, 1);
      await expect(
        hardhatMultiSigWallet.connect(user1).approveTransaction(1)
      ).to.be.revertedWith(
        "MultiSigWallet: Only Approved owners can perform this operation."
      );
    });
    it("Transaction to approve must exist.", async function () {
      const { hardhatMultiSigWallet, user1, user2 } = await loadFixture(
        deployTokenFixture
      );
      await hardhatMultiSigWallet.addOwner(user1.address);
      await expect(
        hardhatMultiSigWallet.connect(user1).approveTransaction(1)
      ).to.be.revertedWith("MultiSigWallet: Transaction does not exist");
    });
    it("Transaction to approve is already executed.", async function () {
      const { hardhatMultiSigWallet, user1, user2, user3, amountWei } =
        await loadFixture(deployTokenFixture);

      await hardhatMultiSigWallet.submitTransaction(user2.address, 100, 0);
      await hardhatMultiSigWallet.addOwner(user1.address);
      await hardhatMultiSigWallet.addOwner(user2.address);
      await hardhatMultiSigWallet.addOwner(user3.address);
      await hardhatMultiSigWallet.connect(user1).approveTransaction(1);
      await hardhatMultiSigWallet.connect(user2).approveTransaction(1);
      await hardhatMultiSigWallet
        .connect(user2)
        .executeTransaction({ value: amountWei });
      await expect(
        hardhatMultiSigWallet.connect(user2).approveTransaction(1)
      ).to.be.revertedWith("MultiSigWallet: Transaction already executed");
    });
    it("Owner have already approved the transaction.", async function () {
      const { hardhatMultiSigWallet, user1 } = await loadFixture(
        deployTokenFixture
      );
      await hardhatMultiSigWallet.submitTransaction(user1.address, 100, 1);
      await expect(
        hardhatMultiSigWallet.approveTransaction(1)
      ).to.be.revertedWith(
        "MultiSigWallet: Transaction already approved by owner."
      );
    });
    it("Transaction is successfully approved by the approved owner.", async function () {
      const { hardhatMultiSigWallet, user1, user2 } = await loadFixture(
        deployTokenFixture
      );
      await hardhatMultiSigWallet.submitTransaction(user2.address, 100, 1);
      await hardhatMultiSigWallet.addOwner(user1.address);
      await expect(hardhatMultiSigWallet.connect(user1).approveTransaction(1))
        .to.emit(hardhatMultiSigWallet, "ApproveTransaction")
        .withArgs(user1.address, 1);
    });
    it("A transaction recieve enough approval to be executed.", async function () {
      const { hardhatMultiSigWallet, user1, user2, user3 } = await loadFixture(
        deployTokenFixture
      );
      const arraySize = await hardhatMultiSigWallet.readyToExecuteTransaction();
      await hardhatMultiSigWallet.submitTransaction(user3.address, 100, 1);
      await hardhatMultiSigWallet.addOwner(user1.address);
      await hardhatMultiSigWallet.addOwner(user2.address);
      await hardhatMultiSigWallet.connect(user1).approveTransaction(1);
      await hardhatMultiSigWallet.connect(user2).approveTransaction(1);
      await expect(
        await hardhatMultiSigWallet.readyToExecuteTransaction()
      ).to.equal(arraySize + 1);
    });
  });
  describe("Test for revokeTransaction function.", function () {
    it("Only Approved Owner can revoke transaction.", async function () {
      const { hardhatMultiSigWallet, user1, user2, user3 } = await loadFixture(
        deployTokenFixture
      );
      await hardhatMultiSigWallet.submitTransaction(user2.address, 100, 1);
      await expect(
        hardhatMultiSigWallet.connect(user1).revokeTransaction(1)
      ).to.be.revertedWith(
        "MultiSigWallet: Only Approved owners can perform this operation."
      );
    });
    it("Transaction to revoke must exist.", async function () {
      const { hardhatMultiSigWallet, user1, user2 } = await loadFixture(
        deployTokenFixture
      );
      await hardhatMultiSigWallet.addOwner(user1.address);
      await expect(
        hardhatMultiSigWallet.connect(user1).revokeTransaction(1)
      ).to.be.revertedWith("MultiSigWallet: Transaction does not exist");
    });
    it("Transaction to revoke must not have executed.", async function () {
      const { hardhatMultiSigWallet, user1, user2, user3, amountWei } =
        await loadFixture(deployTokenFixture);

      await hardhatMultiSigWallet.submitTransaction(user2.address, 100, 0);
      await hardhatMultiSigWallet.addOwner(user1.address);
      await hardhatMultiSigWallet.addOwner(user2.address);
      await hardhatMultiSigWallet.connect(user1).approveTransaction(1);
      await hardhatMultiSigWallet.connect(user2).approveTransaction(1);
      await hardhatMultiSigWallet
        .connect(user3)
        .executeTransaction({ value: amountWei });
      await expect(
        hardhatMultiSigWallet.connect(user2).revokeTransaction(1)
      ).to.be.revertedWith("MultiSigWallet: Transaction already executed");
    });
    it("Transaction to revoke must need to be approved by the onwer.", async function () {
      const { hardhatMultiSigWallet, user1, user2 } = await loadFixture(
        deployTokenFixture
      );
      await hardhatMultiSigWallet.submitTransaction(user2.address, 100, 1);
      await hardhatMultiSigWallet.revokeTransaction(1);
      await expect(
        hardhatMultiSigWallet.revokeTransaction(1)
      ).to.be.revertedWith(
        "MultiSigWallet: Transaction not approved by owner."
      );
    });
    it("On revoking the approval, transaction is not longer ready to execute.", async function () {
      const { hardhatMultiSigWallet, user1, user2, user3 } = await loadFixture(
        deployTokenFixture
      );
      await hardhatMultiSigWallet.submitTransaction(user3.address, 100, 1);
      await hardhatMultiSigWallet.submitTransaction(user3.address, 100, 1);
      await hardhatMultiSigWallet.addOwner(user1.address);
      await hardhatMultiSigWallet.addOwner(user2.address);
      await hardhatMultiSigWallet.connect(user1).approveTransaction(1);
      await hardhatMultiSigWallet.connect(user2).approveTransaction(1);
      await hardhatMultiSigWallet.connect(user1).approveTransaction(2);
      await hardhatMultiSigWallet.connect(user2).approveTransaction(2);
      const arraySize = await hardhatMultiSigWallet.readyToExecuteTransaction();
      await hardhatMultiSigWallet.connect(user2).revokeTransaction(2);
      await expect(
        await hardhatMultiSigWallet.readyToExecuteTransaction()
      ).to.equal(arraySize - 1);
    });
  });
  describe("Test for executeTransaction function.", function () {
    it("There should be atleast one transaction ready to execute", async function () {
      const { hardhatMultiSigWallet, user1, user2 } = await loadFixture(
        deployTokenFixture
      );
      await hardhatMultiSigWallet.submitTransaction(user2.address, 100, 1);
      await expect(
        hardhatMultiSigWallet.connect(user1).executeTransaction()
      ).to.be.revertedWith(
        "MultiSigWallet: No transaction is yet ready to execute"
      );
    });
    it("Successfully Execute token transfer transaction with enough approval.", async function () {
      const { hardhatMultiSigWallet, user1, user2, owner, hardhatERC20 } =
        await loadFixture(deployTokenFixture);
      await hardhatERC20.approve(hardhatMultiSigWallet.address, 100);
      await hardhatMultiSigWallet.submitTransaction(user2.address, 100, 1);

      await hardhatMultiSigWallet.addOwner(user1.address);
      await hardhatMultiSigWallet.addOwner(user2.address);
      await hardhatMultiSigWallet.connect(user1).approveTransaction(1);
      await hardhatMultiSigWallet.connect(user2).approveTransaction(1);
      const arraySize = await hardhatMultiSigWallet.readyToExecuteTransaction();
      tokenTransfer = await hardhatMultiSigWallet.executeTransaction();
      await expect(tokenTransfer)
        .to.emit(hardhatMultiSigWallet, "ExecuteTransaction")
        .withArgs(owner.address, 1, user2.address, 100);
      expect(await hardhatMultiSigWallet.readyToExecuteTransaction()).to.equal(
        arraySize - 1
      );
      await expect(tokenTransfer).to.changeTokenBalance(
        hardhatERC20,
        owner,
        -100
      );
      await expect(tokenTransfer).to.changeTokenBalance(
        hardhatERC20,
        user2,
        100
      );
    });
    it("Successfully Execute ether transfer transaction with enough approval.", async function () {
      const { hardhatMultiSigWallet, user1, user2, amountWei } =
        await loadFixture(deployTokenFixture);

      await hardhatMultiSigWallet.submitTransaction(user2.address, 100, 0);
      await hardhatMultiSigWallet.addOwner(user1.address);
      await hardhatMultiSigWallet.addOwner(user2.address);
      await hardhatMultiSigWallet.connect(user1).approveTransaction(1);
      await hardhatMultiSigWallet.connect(user2).approveTransaction(1);
      etherTransfer = await hardhatMultiSigWallet
        .connect(user1)
        .executeTransaction({ value: amountWei });

      await expect(etherTransfer)
        .to.emit(hardhatMultiSigWallet, "ExecuteTransaction")
        .withArgs(user1.address, 1, user2.address, 100);
      await expect(etherTransfer).to.changeEtherBalance(user2, amountWei);
      await expect(etherTransfer).to.changeEtherBalance(user1, -amountWei);
    });
  });
  describe("Test for batchExecuteTransaction function.", function () {
    it("Only Approved Owner can execute batch transaction.", async function () {
      const { hardhatMultiSigWallet, user1 } = await loadFixture(
        deployTokenFixture
      );
      await hardhatMultiSigWallet.submitTransaction(user1.address, 100, 0);
      await expect(
        hardhatMultiSigWallet.connect(user1).batchExecuteTransaction()
      ).to.be.revertedWith(
        "MultiSigWallet: Only Approved owners can perform this operation."
      );
    });
    it("There should be atleast one transaction ready to execute", async function () {
      const { hardhatMultiSigWallet, user1, user2 } = await loadFixture(
        deployTokenFixture
      );
      await hardhatMultiSigWallet.submitTransaction(user2.address, 100, 0);
      await hardhatMultiSigWallet.addOwner(user1.address);
      await expect(
        hardhatMultiSigWallet.connect(user1).batchExecuteTransaction()
      ).to.be.revertedWith(
        "MultiSigWallet: No transaction is yet ready to execute"
      );
    });
    it("Successfully Execute Ether transaction with enough approval.", async function () {
      const { hardhatMultiSigWallet, user1, user2, amountWei } =
        await loadFixture(deployTokenFixture);

      await hardhatMultiSigWallet.submitTransaction(user2.address, 100, 0);
      await hardhatMultiSigWallet.addOwner(user1.address);
      await hardhatMultiSigWallet.addOwner(user2.address);
      await hardhatMultiSigWallet.connect(user1).approveTransaction(1);
      await hardhatMultiSigWallet.connect(user2).approveTransaction(1);
      await expect(
        hardhatMultiSigWallet
          .connect(user1)
          .batchExecuteTransaction({ value: amountWei })
      )
        .to.emit(hardhatMultiSigWallet, "ExecuteTransaction")
        .withArgs(user1.address, 1, user2.address, 100);
      expect(await hardhatMultiSigWallet.readyToExecuteTransaction()).to.equal(
        0
      );
    });
    it("After batch execution number of transaction ready to execute becomes zero.", async function () {
      const { hardhatMultiSigWallet, user1, user2, owner, hardhatERC20 } =
        await loadFixture(deployTokenFixture);
      await hardhatERC20.approve(hardhatMultiSigWallet.address, 100);
      await hardhatMultiSigWallet.submitTransaction(user2.address, 100, 1);

      await hardhatMultiSigWallet.addOwner(user1.address);
      await hardhatMultiSigWallet.addOwner(user2.address);
      await hardhatMultiSigWallet.connect(user1).approveTransaction(1);
      await hardhatMultiSigWallet.connect(user2).approveTransaction(1);
      await hardhatMultiSigWallet.batchExecuteTransaction();
      await expect(
        await hardhatMultiSigWallet.readyToExecuteTransaction()
      ).to.equal(0);
      expect(await hardhatERC20.balanceOf(user2.address)).to.equal(100);
    });
  });
  describe("Test for addOwner function.", function () {
    it("Only approved owners can add owner", async function () {
      const { hardhatMultiSigWallet, user1, user2 } = await loadFixture(
        deployTokenFixture
      );
      await expect(
        hardhatMultiSigWallet.connect(user1).addOwner(user2.address)
      ).to.be.revertedWith(
        "MultiSigWallet: Only Approved owners can perform this operation."
      );
    });
    it("Owner to approve must be a valid address.", async function () {
      const { hardhatMultiSigWallet, zero_address } = await loadFixture(
        deployTokenFixture
      );
      await expect(
        hardhatMultiSigWallet.addOwner(zero_address)
      ).to.be.revertedWith("MultiSigWallet: Invalid address");
    });
    it("Address to approve must not be already approved.", async function () {
      const { hardhatMultiSigWallet, user1 } = await loadFixture(
        deployTokenFixture
      );
      await hardhatMultiSigWallet.addOwner(user1.address);
      await expect(
        hardhatMultiSigWallet.addOwner(user1.address)
      ).to.be.revertedWith("MultiSigWallet: Already approved owner");
    });
  });
  describe("Test for getTransactionApprovalCount function.", function () {
    it("Transaction whose approval count is required must exist.", async function () {
      const { hardhatMultiSigWallet } = await loadFixture(deployTokenFixture);
      await expect(
        hardhatMultiSigWallet.getTransactionApprovalCount(1)
      ).to.be.revertedWith("MultiSigWallet: Transaction does not exist");
    });
    it("Returns the number of approval a transaction have recieved so far.", async function () {
      const { hardhatMultiSigWallet, user1 } = await loadFixture(
        deployTokenFixture
      );
      await hardhatMultiSigWallet.addOwner(user1.address);
      await hardhatMultiSigWallet.submitTransaction(user1.address, 100, 1);
      await hardhatMultiSigWallet.connect(user1).approveTransaction(1);
      await expect(
        await hardhatMultiSigWallet.getTransactionApprovalCount(1)
      ).to.equal(2);
    });
  });
});
