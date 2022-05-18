const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { wethAddress, osqthAddress, usdcAddress } = require("./common");
const { assertWP, getAndApprove, getERC20Balance, resetFork, logBlock, logBalance } = require("./helpers");
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
            "19855700000000000000",
            "41326682043",
            "17933300000000000000",
            "0"
        );
        console.log(amount);

        const wethInput = amount[1].toString();
        const usdcInput = amount[2].toString();
        const osqthInput = amount[3].toString();

        await getAndApprove(depositor, Vault.address, wethInput, usdcInput, osqthInput);

        // Balances
        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal(wethInput);
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal(usdcInput);
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal(osqthInput);

        tx = await Vault.connect(depositor).deposit(wethInput, usdcInput, osqthInput, depositor.address, "0", "0", "0");
        await tx.wait();

        // Balances
        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal("65053297");
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal("0");
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal("124327483");

        // Balances
        assert(assertWP(await getERC20Balance(VaultTreasury.address, wethAddress), wethInput, 8, 18), "test");
        assert(assertWP(await getERC20Balance(VaultTreasury.address, usdcAddress), usdcInput, 6, 6), "test");
        assert(assertWP(await getERC20Balance(VaultTreasury.address, osqthAddress), osqthInput, 8, 18), "test");

        // Shares
        expect(await getERC20Balance(depositor.address, Vault.address)).to.equal("36822598604818195184");                         
    });

    it("withdraw", async function () {
        // Shares
        expect(await getERC20Balance(depositor.address, Vault.address)).to.equal("36822598604818195184");

        // Balances
        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal("65053297");
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal("0");
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal("124327483");

        // Balances
        expect(await getERC20Balance(VaultTreasury.address, wethAddress)).to.equal("18411299302409097592");
        expect(await getERC20Balance(VaultTreasury.address, usdcAddress)).to.equal("30629982467");
        expect(await getERC20Balance(VaultTreasury.address, osqthAddress)).to.equal("35187001598284936408");

        tx = await Vault.connect(depositor).withdraw("36822598604818195184", "0", "0", "0");
        await tx.wait();

        // Balances
        await logBalance(depositor.address);
        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal("18411299302474150888");
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal("30629982467");
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal("35187001598409263891");

        // Shares
        expect(await getERC20Balance(depositor.address, Vault.address)).to.equal("0");
    });
});
