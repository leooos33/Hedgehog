const { ethers } = require("hardhat");
const { utils } = ethers;
const { expect, assert } = require("chai");
const {
    wethAddress,
    osqthAddress,
    usdcAddress,
    _governanceAddress,
    _oneClickDepositAddress,
    _vaultAddress,
    _biggestOSqthHolder,
    maxUint256,
    _oneClickDepositAddressV2,
    _oneClickWithdrawAddressV2,
} = require("./common");
const {
    resetFork,
    getERC20Balance,
    approveERC20,
    getERC20Allowance,
    getUSDC,
    getWETH,
    getOSQTH,
    logBalance,
} = require("./helpers");
const { deployContract } = require("./deploy");
const { BigNumber } = require("ethers");

describe.skip("One Click deposit Withdraw", function () {
    let tx, receipt, OneClickDeposit;
    let actor;
    let actorAddress = "0x42B1299fCcA091A83C08C24915Be6E6d63906b1a";

    it("Should set actors", async function () {
        await resetFork(15659425);

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [actorAddress],
        });

        actor = await ethers.getSigner(actorAddress);
        console.log("actor:", actor.address);

        MyContract = await ethers.getContractFactory("OneClickWithdraw");
        OneClickWithdraw = await MyContract.attach(_oneClickWithdrawAddressV2);
    });

    it("flash deposit real (mode = 0)", async function () {
        tx = await OneClickWithdraw.connect(actor).withdraw(actor.address, "1000000000000000", "0", "0", "0", {
            gasLimit: 800000,
        });

        receipt = await tx.wait();
        console.log("> deposit()");
        console.log("> Gas used: %s", receipt.gasUsed);

        await logBalance(actor.address, "> user");
    });
});
