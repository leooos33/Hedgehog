const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { wethAddress, osqthAddress, usdcAddress } = require("./common");
const { utils } = ethers;
const { resetFork, getWETH, getUSDC, getERC20Balance, getAndApprove, assertWP, logBlock, logBalance } = require("./helpers");
const { hardhatDeploy, deploymentParams } = require("./deploy");

describe("Strategy rebalance sell", function () {
    let swaper, depositor, keeper, governance;
    it("Should set actors", async function () {
        const signers = await ethers.getSigners();
        governance = signers[0];
        depositor = signers[7];
        keeper = signers[8];
        swaper = signers[9];
    });

    let Vault, VaultAuction, VaultMath, VaultTreasury, VaultStorage, tx, receipt;
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

    const wethInputR = "525269035909074323";
    const usdcInputR = "20549790205";
    const osqthInputR = "22598046098622284218";
    it("preset", async function () {
        tx = await VaultStorage.setTimeAtLastRebalance(1648646662);
        await tx.wait();

        tx = await VaultStorage.setEthPriceAtLastRebalance("3391393578000000000000");
        await tx.wait();

        tx = await VaultStorage.setIvAtLastRebalance("614682673158336601")
        await tx.wait();

        await getAndApprove(keeper, VaultAuction.address, wethInputR, usdcInputR, osqthInputR);
    });

    it("deposit", async function () {
        const wethInput = "17630456391812729437";
        const usdcInput = "29892919002";
        const osqthInput = "33072912442930906879";

        await getAndApprove(depositor, Vault.address, wethInput, usdcInput, osqthInput);

        // Balances
        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal(wethInput);
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal(usdcInput);
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal(osqthInput);

        tx = await Vault.connect(depositor).deposit(
            wethInput,
            usdcInput,
            osqthInput,
            depositor.address,
            "0",
            "0",
            "0"
        );
        receipt = await tx.wait();
        console.log("Gas used deposit: %s", receipt.gasUsed);

        // Balances
        const userEthBalanceAfterDeposit = await getERC20Balance(depositor.address, wethAddress);
        const userUsdcBalanceAfterDeposit = await getERC20Balance(depositor.address, usdcAddress);
        const userOsqthBalanceAfterDeposit = await getERC20Balance(depositor.address, osqthAddress);
        const userShareAfterDeposit = await getERC20Balance(depositor.address, Vault.address);

        console.log("userEthBalanceAfterDeposit %s", userEthBalanceAfterDeposit);
        console.log("userUsdcBalanceAfterDeposit %s", userUsdcBalanceAfterDeposit);
        console.log("userOsqthBalanceAfterDeposit %s", userOsqthBalanceAfterDeposit);
        console.log("userShareAfterDeposit", userShareAfterDeposit);

        expect(await userEthBalanceAfterDeposit).to.equal("38000978");
        expect(await userUsdcBalanceAfterDeposit).to.equal("0");
        expect(await userOsqthBalanceAfterDeposit).to.equal("71285904");

        // Shares
        expect(await userShareAfterDeposit).to.equal("35260912783549456917");
    });

    it("swap_before_rebalance", async function () {
        const testAmount = utils.parseUnits("1000", 18).toString();
        console.log("Swap %s ETH for USDC", testAmount/1e18);

        await getWETH(testAmount, contractHelper.address);

        // Balances
        expect(await getERC20Balance(contractHelper.address, usdcAddress)).to.equal("0");
        expect(await getERC20Balance(contractHelper.address, wethAddress)).to.equal(testAmount);

        amount = await contractHelper.connect(swaper).getTwap();

        tx = await contractHelper.connect(swaper).swap(testAmount);
        await tx.wait();

        for (const i of Array(6)) {
            await hre.network.provider.request({
                method: "evm_mine",
            });
        }

        amount = await contractHelper.connect(swaper).getTwap();
        // console.log(amount);

        // Balances
        expect(await getERC20Balance(contractHelper.address, wethAddress)).to.equal("0");
        expect(await getERC20Balance(contractHelper.address, usdcAddress)).to.equal("3369149847107");
    });

    it("rebalance", async function () {
        const wethInput = wethInputR;
        const usdcInput = usdcInputR;
        const osqthInput = osqthInputR;

        // Balances
        const keeperEthBalanceBeforeRebalance = await getERC20Balance(keeper.address, wethAddress);
        const keeperUsdcBalanceBeforeRebalance = await getERC20Balance(keeper.address, usdcAddress);
        const keeperOsqthBalanceBeforeRebalance = await getERC20Balance(keeper.address, osqthAddress);

        expect(keeperEthBalanceBeforeRebalance).to.equal(wethInput);
        expect(keeperUsdcBalanceBeforeRebalance).to.equal(usdcInput);
        expect(keeperOsqthBalanceBeforeRebalance).to.equal(osqthInput);

        console.log("Keeper ETH balance before rebalance %s", keeperEthBalanceBeforeRebalance);
        console.log("Keeper USDC balance before rebalance %s", keeperUsdcBalanceBeforeRebalance);
        console.log("Keeper oSQTH balance before rebalance %s", keeperOsqthBalanceBeforeRebalance);

        tx = await VaultAuction.connect(keeper).timeRebalance(keeper.address, wethInput, usdcInput, osqthInput);
        receipt = await tx.wait();
        console.log("Gas used rebalance: %s", receipt.gasUsed);

        // Balances
        await logBalance(keeper.address);

        const ethAmountK = await getERC20Balance(keeper.address, wethAddress);
        const usdcAmountK = await getERC20Balance(keeper.address, usdcAddress);
        const osqthAmountK = await getERC20Balance(keeper.address, osqthAddress);
        console.log("Keeper ETH balance after rebalance %s", ethAmountK);
        console.log("Keeper USDC balance after rebalance %s", usdcAmountK);
        console.log("Keeper oSQTH balance after rebalance %s", osqthAmountK);

        expect(await getERC20Balance(keeper.address, wethAddress)).to.equal("417630541706741813");
        expect(await getERC20Balance(keeper.address, usdcAddress)).to.equal("24665117273");
        expect(await getERC20Balance(keeper.address, osqthAddress)).to.equal("18417246424007566079");

        const amount = await VaultMath.connect(Vault.address).getTotalAmounts();
       
        const ethAmountS = amount[0].toString();
        const usdcAmountS = amount[1].toString();
        const osqthAmountS = amount[2].toString();
        console.log("Strategy ETH balance after rebalance %s", ethAmountS);
        console.log("Strategy USDC balance after rebalance %s", usdcAmountS);
        console.log("Strategy oSQTH balance after rebalance %s", osqthAmountS);

        expect(amount[0].toString()).to.equal("17738094000000000008");
        expect(amount[1].toString()).to.equal("25777591933");
        expect(amount[2].toString()).to.equal("37253712000000000009");

    });

    it("swap_after_rebalance_USDC_to_ETH", async function () {
        const testAmount = utils.parseUnits("10", 12).toString();
        console.log("Swap %s USDC to ETH", testAmount/1e6);

        await getUSDC(testAmount, contractHelper.address);

        // Balances
        expect(await getERC20Balance(contractHelper.address, usdcAddress)).to.equal("13369149847107");
        expect(await getERC20Balance(contractHelper.address, wethAddress)).to.equal("0");

        // amount = await contractHelper.connect(swaper).getTwapR();
        // console.log(amount);

        tx = await contractHelper.connect(swaper).swapR(testAmount);
        receipt = await tx.wait();
        console.log("Gas used:", receipt.gasUsed.toString());

        for (const i of Array(6)) {
            await hre.network.provider.request({
                method: "evm_mine",
            });
        }

        // amount = await contractHelper.connect(swaper).getTwapR();
        // console.log(amount);

        // Balances
        expect(await getERC20Balance(contractHelper.address, wethAddress)).to.equal("2932061295511850885804");
        expect(await getERC20Balance(contractHelper.address, usdcAddress)).to.equal("3369149847107");
    });

    it("withdraw", async function () {
        // Shares
        expect(await getERC20Balance(depositor.address, Vault.address)).to.equal("35260912783549456917");

        tx = await Vault.connect(depositor).withdraw("35260912783549456917", "0", "0", "0");
        receipt = await tx.wait();
        console.log("Gas used:", receipt.gasUsed.toString());

        // Balances
        //await logBalance(depositor.address);

        assert(assertWP(await getERC20Balance(depositor.address, wethAddress), "16616861176168954947", 16, 18), "1!");
        assert(assertWP(await getERC20Balance(depositor.address, usdcAddress), "29599677414", 4, 6), "2!");
        assert(assertWP(await getERC20Balance(depositor.address, osqthAddress), "37253712117545625008", 16, 18), "3!");

        // Shares
        //console.log("Shares after withdraw %s", await getERC20Balance(depositor.address, Vault.address));
        expect(await getERC20Balance(depositor.address, Vault.address)).to.equal("0");

        //TODO
         const amount = await VaultMath.connect(Vault.address).getTotalAmounts();
         console.log("Total amounts:", amount);
         expect(amount[0].toString()).to.equal("8");
         expect(amount[1].toString()).to.equal("9");
         expect(amount[2].toString()).to.equal("9");
    });
});
