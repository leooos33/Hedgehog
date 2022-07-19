const { expect, assert } = require("chai");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");
const { wethAddress, osqthAddress, usdcAddress } = require("./common");
const { utils } = ethers;
const { resetFork, getUSDC, getERC20Balance, getAndApprove, assertWP, logBlock, logBalance } = require("./helpers");
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

    const wethInputR = "334436074311042669";
    const usdcInputR = "12870285759";
    const osqthInputR = "12740475182198285927";
    it("Should preset all values here", async function () {
        tx = await VaultStorage.connect(governance).setTimeAtLastRebalance(1648646662);
        await tx.wait();

        tx = await VaultStorage.connect(governance).setEthPriceAtLastRebalance("3391393578000000000000");
        await tx.wait();

        tx = await VaultStorage.setIvAtLastRebalance("1214682673158336601");
        await tx.wait();

        await getAndApprove(keeper, VaultAuction.address, wethInputR, usdcInputR, osqthInputR);
    });

    it("deposit", async function () {
        const wethInput = "18411172761982581918";
        const usdcInput = "31216644871";
        const osqthInput = "34537455593690235893";

        await getAndApprove(depositor, Vault.address, wethInput, usdcInput, osqthInput);

        tx = await Vault.connect(depositor).deposit(
            "18411172762018689823",
            "30629771948",
            "35186759758920620435",
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
        expect(await getERC20Balance(depositor.address, Vault.address)).to.equal("36822345523965163836");
    });

    it("swap 10 000 000 USDC to ETH", async function () {
        const testAmount = utils.parseUnits("10", 12).toString();
        await getUSDC(testAmount, contractHelper.address);

        tx = await contractHelper.connect(swaper).swapUSDC_WETH(testAmount);
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

        await logBalance(keeper.address);
        expect(await getERC20Balance(keeper.address, wethAddress)).to.equal("0");
        expect(await getERC20Balance(keeper.address, usdcAddress)).to.equal("25740571518");
        expect(await getERC20Balance(keeper.address, osqthAddress)).to.equal("0");

        const amount = await VaultMath.connect(Vault.address).getTotalAmounts();
        console.log("Total amounts:", amount);
    });

    it("swap halth ETH to USDC", async function () {
        const _amountWETH = await getERC20Balance(contractHelper.address, wethAddress);
        const amountWETH = BigNumber.from(_amountWETH).div(2);

        tx = await contractHelper.connect(swaper).swapWETH_USDC(amountWETH);
        await tx.wait();

        for (const i of Array(6)) {
            await hre.network.provider.request({
                method: "evm_mine",
            });
        }
    });

    it("withdraw", async function () {
        // Shares
        expect(await getERC20Balance(depositor.address, Vault.address)).to.equal("36822345523965163836");

        tx = await Vault.connect(depositor).withdraw("36822345523965163836", "0", "0", "0");
        await tx.wait();

        await logBalance(depositor.address);
        assert(assertWP(await getERC20Balance(depositor.address, wethAddress), "19320365491946918409", 16), "test");
        assert(assertWP(await getERC20Balance(depositor.address, usdcAddress), "16371885782", 4, 6), "test");
        assert(assertWP(await getERC20Balance(depositor.address, osqthAddress), "47277930775888521810", 16), "test");

        // Shares
        expect(await getERC20Balance(depositor.address, Vault.address)).to.equal("0");

        const amount = await VaultMath.connect(Vault.address).getTotalAmounts();
        console.log("Total amounts:", amount);
    });
});
