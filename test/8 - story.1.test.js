const { expect, assert } = require("chai");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");
const { wethAddress, osqthAddress, usdcAddress } = require("./common");
const { utils } = ethers;
const { resetFork, getUSDC, getERC20Balance, getAndApprove, assertWP, logBlock } = require("./helpers");
const { hardhatDeploy, deploymentParams } = require("./deploy");

describe("Story about several swaps id 1", function () {
    let swaper, depositor, keeper, governance;
    it("Should set actors", async function () {
        const signers = await ethers.getSigners();
        governance = signers[0];
        depositor = signers[7];
        keeper = signers[8];
        swaper = signers[9];
    });

    let Vault, VaultAuction, VaultMath, VaultTreasury, VaultStorage, tx;
    it("Should deploy contract", async function () {
        await resetFork();

        const params = [...deploymentParams];
        [Vault, VaultAuction, VaultMath, VaultTreasury, VaultStorage] = await hardhatDeploy(governance, params);
        await logBlock();
        //14487789 1648646654

        const ContractHelper = await ethers.getContractFactory("V3Helper");
        contractHelper = await ContractHelper.deploy();
        await contractHelper.deployed();
    });

    const wethInputR = "800348675119972960";
    const usdcInputR = "14065410226";
    const osqthInputR = "13136856056157859843";
    it("Should preset all values here", async function () {
        tx = await VaultStorage.connect(governance).setTimeAtLastRebalance(1648646662);
        await tx.wait();

        tx = await VaultStorage.connect(governance).setEthPriceAtLastRebalance("3391393578000000000000");
        await tx.wait();

        await getAndApprove(keeper, VaultAuction.address, wethInputR, usdcInputR, osqthInputR);
    });

    it("deposit", async function () {
        const wethInput = "18702958066838460455";
        const usdcInput = "30406229225";
        const osqthInput = "34339364744543638154";

        await getAndApprove(depositor, Vault.address, wethInput, usdcInput, osqthInput);

        tx = await Vault.connect(depositor).deposit(
            "18410690015258689749",
            "32743712092",
            "32849750909396941650",
            depositor.address,
            "0",
            "0",
            "0"
        );
        await tx.wait();

        // Balances
        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal("0");
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal("0");
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal("0");

        // Shares
        expect(await getERC20Balance(depositor.address, Vault.address)).to.equal("124866579487341572537626");
    });

    it("swap 10 000 000 USDC to ETH", async function () {
        const testAmount = utils.parseUnits("10", 12).toString();
        await getUSDC(testAmount, contractHelper.address);

        tx = await contractHelper.connect(swaper).swapR(testAmount);
        await tx.wait();

        for (const i of Array(6)) {
            await hre.network.provider.request({
                method: "evm_mine",
            });
        }
    });

    it("rebalance", async function () {
        expect(await getERC20Balance(keeper.address, wethAddress)).to.equal(wethInputR);
        expect(await getERC20Balance(keeper.address, usdcAddress)).to.equal(usdcInputR);
        expect(await getERC20Balance(keeper.address, osqthAddress)).to.equal(osqthInputR);

        tx = await VaultAuction.connect(keeper).timeRebalance(keeper.address, wethInputR, usdcInputR, osqthInputR);
        await tx.wait();

        expect(await getERC20Balance(keeper.address, wethAddress)).to.equal("2156295203852947809");
        expect(await getERC20Balance(keeper.address, usdcAddress)).to.equal("24807224671");
        expect(await getERC20Balance(keeper.address, osqthAddress)).to.equal("1871839072565612147");

        const amount = await VaultMath.connect(Vault.address).getTotalAmounts();
        console.log("Total amounts:", amount);
    });

    it("swap halth ETH to USDC", async function () {
        const _amountWETH = await getERC20Balance(contractHelper.address, wethAddress);
        const amountWETH = BigNumber.from(_amountWETH).div(2);

        tx = await contractHelper.connect(swaper).swap(amountWETH);
        await tx.wait();

        for (const i of Array(6)) {
            await hre.network.provider.request({
                method: "evm_mine",
            });
        }
    });

    it("withdraw", async function () {
        // Shares
        expect(await getERC20Balance(depositor.address, Vault.address)).to.equal("124866579487341572537626");

        tx = await Vault.connect(depositor).withdraw("124866579487341572537626", "0", "0", "0");
        await tx.wait();

        assert(assertWP(await getERC20Balance(depositor.address, wethAddress), "18140334459804562490", 16), "test");
        assert(assertWP(await getERC20Balance(depositor.address, usdcAddress), "16947270611", 4, 6), "test");
        assert(assertWP(await getERC20Balance(depositor.address, osqthAddress), "45604381728135885848", 16), "test");

        // Shares
        expect(await getERC20Balance(depositor.address, Vault.address)).to.equal("0");

        const amount = await VaultMath.connect(Vault.address).getTotalAmounts();
        console.log("Total amounts:", amount);
    });
});
