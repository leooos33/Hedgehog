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
const { hardhatInitializeDeploed } = require("./deploy");
const { BigNumber } = require("ethers");

describe("Test with real mainnet contracts", function () {
    let swaper, depositor1, depositor2, depositor3, keeper, governance, swapAmount;
    it("Should set actors", async function () {
        const signers = await ethers.getSigners();
        governance = signers[0];
        depositor1 = signers[7];
        keeper = signers[8];
        swaper = signers[9];
        depositor2 = signers[10];
        depositor3 = signers[11];
    });

    let Vault, VaultAuction, VaultMath, VaultTreasury, VaultStorage, tx;
    it("Should deploy contract", async function () {
        await resetFork(15249791);
        [Vault, VaultAuction, VaultMath, VaultTreasury, VaultStorage] = await hardhatInitializeDeploed();
        await logBlock();

        const ContractHelper = await ethers.getContractFactory("V3Helper");
        contractHelper = await ContractHelper.deploy();
        await contractHelper.deployed();
    });

    const presets = {
        depositor1: {
            wethInput: "19987318809022169042",
            usdcInput: "15374822619",
            osqthInput: "113434930214010428403",
        },
        depositor2: {
            wethInput: "29987318809025550479",
            usdcInput: "23067111297",
            osqthInput: "170188380388050211866",
        },
        depositor3: {
            wethInput: "25443723573225622250",
            usdcInput: "11532228170",
            osqthInput: "194008074778513958331",
        },
        keeper: {
            wethInput: BigNumber.from("46420453093069060030").add(BigNumber.from("7611641957027153635")).toString(),
            usdcInput: BigNumber.from("35170786530").add(BigNumber.from("6086663569")).toString(),
            osqthInput: BigNumber.from("226662623566831825098").add(BigNumber.from("38536032101104376335")).toString(),
        },
    };
    it("preset", async function () {
        await getAndApprove2(
            keeper,
            VaultAuction.address,
            presets.keeper.wethInput,
            presets.keeper.usdcInput,
            presets.keeper.osqthInput
        );
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
        await getAndApprove2(
            depositor3,
            Vault.address,
            presets.depositor3.wethInput,
            presets.depositor3.usdcInput,
            presets.depositor3.osqthInput
        );
    });

    it("deposit1", async function () {
        tx = await Vault.connect(depositor1).deposit(
            "12630456391863397407",
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

    it("swap", async function () {
        await mineSomeBlocks(2216);

        swapAmount = utils.parseUnits("100", 18).toString();
        await getWETH(swapAmount, contractHelper.address);
        console.log("> WETH before swap:", await getERC20Balance(contractHelper.address, wethAddress));
        console.log("> USDC before swap:", await getERC20Balance(contractHelper.address, usdcAddress));
        tx = await contractHelper.connect(swaper).swapWETH_USDC(swapAmount);
        await tx.wait();
        console.log("> WETH after swap:", await getERC20Balance(contractHelper.address, wethAddress));
        console.log("> USDC after swap:", await getERC20Balance(contractHelper.address, usdcAddress));

        await mineSomeBlocks(554);

        swapAmount = utils.parseUnits("40", 18).toString();
        await getOSQTH(swapAmount, contractHelper.address, "0x5d296b8de19a3c134efafde57beedad4a1b76334");
        console.log("> OSQTH before swap:", await getERC20Balance(contractHelper.address, osqthAddress));
        console.log("> WETH before swap:", await getERC20Balance(contractHelper.address, wethAddress));
        tx = await contractHelper.connect(swaper).swapOSQTH_WETH(swapAmount);
        await tx.wait();
        console.log("> OSQTH before swap:", await getERC20Balance(contractHelper.address, osqthAddress));
        console.log("> WETH before swap:", await getERC20Balance(contractHelper.address, wethAddress));

        await mineSomeBlocks(83622);
    });

    it("rebalance with flash loan", async function () {
        const Rebalancer = await ethers.getContractFactory("Rebalancer");
        rebalancer = await Rebalancer.deploy();
        await rebalancer.deployed();

        await mineSomeBlocks(83069);

        const tx = await rebalancer.setContracts(
            "0xA9a68eA2746793F43af0f827EC3DbBb049359067",
            "0xfbcf638ea33a5f87d1e39509e7def653958fa9c4"
        );
        await tx.wait();

        const arbTx = await rebalancer.rebalance();
        await arbTx.wait();
    });
});