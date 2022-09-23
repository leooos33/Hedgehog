const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { wethAddress, osqthAddress, usdcAddress, _biggestOSqthHolder } = require("./common");
const { utils } = ethers;
const { BigNumber } = require("ethers");
const {
    resetFork,
    getUSDC,
    getERC20Balance,
    getAndApprove,
    getAndApprove2,
    logBlock,
    logBalance,
    mineSomeBlocks,
    getOSQTH,
    getWETH,
    approveERC20,
} = require("./helpers");
const { hardhatDeploy, deploymentParams } = require("./deploy");

describe.only("The example of miscalculation after the second rebalance", function () {
    let swaper, depositor, keeper, governance;
    it("Should set actors", async function () {
        const signers = await ethers.getSigners();
        governance = signers[0];
        depositor = signers[7];
        keeper = signers[8];
        swaper = signers[9];
        actor = signers[10];
    });

    let Vault, VaultAuction, tx, rebalanceCall;
    it("Should deploy contract", async function () {
        await resetFork(15373344 - 10);

        const params = [...deploymentParams];
        [Vault, VaultAuction, VaultMath, VaultTreasury, VaultStorage] = await hardhatDeploy(governance, params);
        await logBlock();

        const ContractHelper = await ethers.getContractFactory("V3Helper");
        contractHelper = await ContractHelper.deploy();
        await contractHelper.deployed();

        RebalanceCall = await ethers.getContractFactory("RebalanceCall");
        rebalanceCall = await RebalanceCall.deploy();
        await rebalanceCall.deployed();
    });

    const presets = {
        depositor: {
            wethInput: "6858439455065022070",
            usdcInput: "5839283612",
            osqthInput: "38092307872538870173",
        },
        keeper: {
            wethInput: "0",
            usdcInput: "0",
            osqthInput: "14084247333853336664",
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
            depositor,
            Vault.address,
            presets.depositor.wethInput,
            presets.depositor.usdcInput,
            presets.depositor.osqthInput
        );
    });

    it("deposit", async function () {
        // Balances
        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal(presets.depositor.wethInput);
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal(presets.depositor.usdcInput);
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal(presets.depositor.osqthInput);

        tx = await Vault.connect(depositor).deposit(
            "7630456391863397407",
            "9892919002",
            "3072912443025954753",
            depositor.address,
            "0",
            "0",
            "0"
        );
        await tx.wait();

        // Balances
        const userEthBalanceAfterDeposit = await getERC20Balance(depositor.address, wethAddress);
        const userUsdcBalanceAfterDeposit = await getERC20Balance(depositor.address, usdcAddress);
        const userOsqthBalanceAfterDeposit = await getERC20Balance(depositor.address, osqthAddress);
        const userShareAfterDeposit = await getERC20Balance(depositor.address, Vault.address);

        console.log("> userEthBalanceAfterDeposit %s", userEthBalanceAfterDeposit);
        console.log("> userUsdcBalanceAfterDeposit %s", userUsdcBalanceAfterDeposit);
        console.log("> userOsqthBalanceAfterDeposit %s", userOsqthBalanceAfterDeposit);
        console.log("> userShareAfterDeposit", userShareAfterDeposit);

        expect(await userEthBalanceAfterDeposit).to.equal("0");
        expect(await userUsdcBalanceAfterDeposit).to.equal("0");
        expect(await userOsqthBalanceAfterDeposit).to.equal("0");

        // Shares
        expect(await userShareAfterDeposit).to.equal("13716878910130044140");
    });

    it("swap_before_rebalance_USDC_to_WETH", async function () {
        const testAmount = utils.parseUnits("10", 12).toString();
        console.log("> Swap %s USDC for ETH", testAmount);

        await getUSDC(testAmount, contractHelper.address, "0xf885bdd59e5652fe4940ca6b8c6ebb88e85a5a40");

        // Balances
        expect(await getERC20Balance(contractHelper.address, usdcAddress)).to.equal(testAmount);
        expect(await getERC20Balance(contractHelper.address, wethAddress)).to.equal("0");

        amount = await contractHelper.connect(swaper).getTwapR();
        // console.log(amount);

        tx = await contractHelper.connect(swaper).swapUSDC_WETH(testAmount);
        await tx.wait();

        for (const i of Array(6)) {
            await hre.network.provider.request({
                method: "evm_mine",
            });
        }

        amount = await contractHelper.connect(swaper).getTwapR();
        // console.log(amount);

        // Balances
        expect(await getERC20Balance(contractHelper.address, wethAddress)).to.equal("5744087421662935943069");
        expect(await getERC20Balance(contractHelper.address, usdcAddress)).to.equal("0");
    });

    it("rebalance", async function () {
        await mineSomeBlocks(83622);
        await mineSomeBlocks(83622);

        const amount = BigNumber.from("14084248435469732911").add(10).toString();

        await getOSQTH(amount, rebalanceCall.address, _biggestOSqthHolder);

        await logBalance(rebalanceCall.address, "> rebalanceCall before");

        tx = await rebalanceCall.call();
        await tx.wait();

        await logBalance(rebalanceCall.address, "> rebalanceCall after");
    });

    it("swap_before_rebalance_WETH_OSQTH one more time", async function () {
        const testAmount = utils.parseUnits("10", 18).toString();
        console.log(">", testAmount);

        await getWETH(testAmount, rebalanceCall.address, "0x06920c9fc643de77b99cb7670a944ad31eaaa260");

        tx = await contractHelper.connect(swaper).swapWETH_OSQTH(testAmount);
        await tx.wait();

        for (const i of Array(6)) {
            await hre.network.provider.request({
                method: "evm_mine",
            });
        }

        tx = await rebalanceCall.collectProtocol(
            await getERC20Balance(rebalanceCall.address, wethAddress),
            await getERC20Balance(rebalanceCall.address, usdcAddress),
            await getERC20Balance(rebalanceCall.address, osqthAddress),
            actor.address
        );
        await tx.wait();
    });

    it("rebalance2", async function () {
        await mineSomeBlocks(83622);
        await mineSomeBlocks(83622);

        // const amount1 = BigNumber.from("672091313476078904").toString();
        const amount2 = BigNumber.from("5176873160").toString();

        // await getWETH(amount1, rebalanceCall.address, "0x06920c9fc643de77b99cb7670a944ad31eaaa260");
        await getUSDC(amount2, rebalanceCall.address, "0xf885bdd59e5652fe4940ca6b8c6ebb88e85a5a40");

        await logBalance(rebalanceCall.address, "> rebalanceCall2 before");

        tx = await rebalanceCall.call2();
        await tx.wait();

        await logBalance(rebalanceCall.address, "> rebalanceCall2 after");
    });
});
