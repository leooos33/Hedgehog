const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { wethAddress, osqthAddress, usdcAddress } = require("./common");
const { resetFork, assertWP, getAndApprove, getERC20Balance, logBlock, logBalance } = require("./helpers");
const { hardhatDeploy, deploymentParams } = require("./deploy");

describe("Strategy deposit", function () {
    let depositor, governance;
    it("Should set actors", async function () {
        const signers = await ethers.getSigners();
        governance = signers[0];
        depositor = signers[7];
    });

    let Vault, VaultMath, VaultTreasury, tx;
    it("Should deploy contract", async function () {
        await resetFork();

        const params = [...deploymentParams];
        [Vault, _, VaultMath, VaultTreasury] = await hardhatDeploy(governance, params);
        await logBlock();
        //14487789 1648646654
    });

    it("deposit", async function () {
        const amount = await Vault.connect(depositor).calcSharesAndAmounts(
            "18411299302474150889",
            "31216859424",
            "34537692970562685403",
            "0"
        );
        console.log("> amount", amount);

        const wethInput = amount[1].toString();
        const usdcInput = amount[2].toString();
        const osqthInput = amount[3].toString();

        console.log("> wethInput %s", wethInput);

        await getAndApprove(depositor, Vault.address, wethInput, usdcInput, osqthInput);

        // Balances
        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal(wethInput);
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal(usdcInput);
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal(osqthInput);

        tx = await Vault.connect(depositor).deposit(wethInput, usdcInput, osqthInput, depositor.address, "0", "0", "0");
        await tx.wait();

        // Balances
        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal("69019707");
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal("0");
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal("129473829");

        // Balances
        expect(await getERC20Balance(VaultTreasury.address, wethAddress)).to.equal("18411299302313104906");
        expect(await getERC20Balance(VaultTreasury.address, usdcAddress)).to.equal("31216859424");
        expect(await getERC20Balance(VaultTreasury.address, osqthAddress)).to.equal("34537692970260579800");

        // Shares
        expect(await getERC20Balance(depositor.address, Vault.address)).to.equal("36822598604626209811");
    });

    it("withdraw: with `No liquidity`", async function () {
        await expect(Vault.connect(depositor).withdraw("36822598604626209811", "0", "0", "0")).to.be.revertedWith(
            "No liquidity"
        );

        // await logBalance(VaultTreasury.address);
        expect(await getERC20Balance(VaultTreasury.address, wethAddress)).to.equal("18411299302313104906");
        expect(await getERC20Balance(VaultTreasury.address, usdcAddress)).to.equal("31216859424");
        expect(await getERC20Balance(VaultTreasury.address, osqthAddress)).to.equal("34537692970260579800");

        // await logBalance(depositor.address);
        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal("69019707");
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal("0");
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal("129473829");

        // Shares
        expect(await getERC20Balance(depositor.address, Vault.address)).to.equal("36822598604626209811");
    });
});
