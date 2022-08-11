const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { utils } = ethers;
const { wethAddress, osqthAddress, usdcAddress } = require("./common");
const {
    mineSomeBlocks,
    resetFork,
    logBlock,
    getAndApprove2,
    getERC20Balance,
    getWETH,
    getOSQTH,
    getUSDC,
} = require("./helpers");
const { deploymentParams, deployContract, hardhatDeploy } = require("./deploy");

describe("Mainnet Infrustructure Test", function () {
    let swaper, depositor1, depositor2, depositor3, keeper, governance, swapAmount;
    let Vault, VaultAuction, VaultMath, VaultTreasury, VaultStorage, tx, receipt, FlashDeposit;

    const presets = {
        depositor1: {
            wethInput: "19987318809022169042",
            usdcInput: "15374822619",
            osqthInput: "113434930214010428403",
        },
        depositor2: {
            wethInput: utils.parseUnits("1", 18),
            usdcInput: 0,
            osqthInput: 0,
        },
    };
    it("Should set actors", async function () {
        await resetFork(15173789);
        const signers = await ethers.getSigners();
        governance = signers[0];
        depositor1 = signers[7];

        const params = [...deploymentParams];
        deploymentParams[6] = "10000";
        [Vault, VaultAuction, VaultMath, VaultTreasury, VaultStorage] = await hardhatDeploy(governance, params);

        FlashDeposit = await deployContract("FlashDeposit", [], false);

        tx = await FlashDeposit.setContracts(Vault.address);
        await tx.wait();

        await getAndApprove2(
            depositor1,
            Vault.address,
            presets.depositor1.wethInput,
            presets.depositor1.usdcInput,
            presets.depositor1.osqthInput
        );
        await getAndApprove2(
            depositor2,
            Vault.address,
            presets.depositor2.wethInput,
            presets.depositor2.usdcInput,
            presets.depositor2.osqthInput
        );

        console.log("> userEthBalanceAfterDeposit %s", await getERC20Balance(depositor1.address, wethAddress));
        console.log("> userUsdcBalanceAfterDeposit %s", await getERC20Balance(depositor1.address, usdcAddress));
        console.log("> userOsqthBalanceAfterDeposit %s", await getERC20Balance(depositor1.address, osqthAddress));
        console.log("> userShareAfterDeposit", await getERC20Balance(depositor1.address, Vault.address));
    });

    it("deposit1", async function () {
        tx = await Vault.connect(depositor1).deposit(
            "17630456391863397407",
            "29892919002",
            "33072912443025954753",
            depositor1.address,
            "0",
            "0",
            "0"
        );
        await tx.wait();

        // State
        const userEthBalanceAfterDeposit = await getERC20Balance(depositor1.address, wethAddress);
        const userUsdcBalanceAfterDeposit = await getERC20Balance(depositor1.address, usdcAddress);
        const userOsqthBalanceAfterDeposit = await getERC20Balance(depositor1.address, osqthAddress);
        const userShareAfterDeposit = await getERC20Balance(depositor1.address, Vault.address);

        console.log("> userEthBalanceAfterDeposit %s", userEthBalanceAfterDeposit);
        console.log("> userUsdcBalanceAfterDeposit %s", userUsdcBalanceAfterDeposit);
        console.log("> userOsqthBalanceAfterDeposit %s", userOsqthBalanceAfterDeposit);
        console.log("> userShareAfterDeposit", userShareAfterDeposit);
    });

    it("deposit2", async function () {
        tx = await FlashDeposit.connect(depositor1).deposit(
            utils.parseUnits("1", 18),
            depositor1.address,
            "0",
            "0",
            "0"
        );
        receipt = await tx.wait();
        console.log("> Gas used flashDepsoit: %s", receipt.gasUsed);

        // State
        console.log("> userEthBalanceAfterDeposit %s", await getERC20Balance(depositor1.address, wethAddress));
        console.log("> userUsdcBalanceAfterDeposit %s", await getERC20Balance(depositor1.address, usdcAddress));
        console.log("> userOsqthBalanceAfterDeposit %s", await getERC20Balance(depositor1.address, osqthAddress));
        console.log("> userShareAfterDeposit", await getERC20Balance(depositor1.address, Vault.address));
    });
});
