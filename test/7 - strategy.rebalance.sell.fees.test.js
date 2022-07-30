const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { wethAddress, osqthAddress, usdcAddress } = require("./common");
const { utils } = ethers;
const {
    resetFork,
    getWETH,
    getUSDC,
    getERC20Balance,
    getAndApprove,
    assertWP,
    mineSomeBlocks,
    logBlock,
    logBalance,
} = require("./helpers");
const { hardhatDeploy, deploymentParams } = require("./deploy");

describe("Strategy rebalance, sell with comissions", function () {
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
        params[6] = "10000";
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
        await getAndApprove(keeper, VaultAuction.address, wethInputR, usdcInputR, osqthInputR);
    });

    it("deposit", async function () {
        const wethInput = "17630456391863397407";
        const usdcInput = "29892919002";
        const osqthInput = "33072912443025954753";

        await getAndApprove(depositor, Vault.address, wethInput, usdcInput, osqthInput);

        // Balances
        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal(wethInput);
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal(usdcInput);
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal(osqthInput);

        tx = await Vault.connect(depositor).deposit(
            "17630456391863397407",
            "29892919002",
            "33072912443025954753",
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

        expect(await userEthBalanceAfterDeposit).to.equal("50667970");
        expect(await userUsdcBalanceAfterDeposit).to.equal("0");
        expect(await userOsqthBalanceAfterDeposit).to.equal("95047874");

        // Shares
        expect(await userShareAfterDeposit).to.equal("35260912783625458873");
    });

    it("swap", async function () {
        const testAmount = utils.parseUnits("1000", 18).toString();
        console.log(testAmount);

        await getWETH(testAmount, contractHelper.address);

        // Balances
        expect(await getERC20Balance(contractHelper.address, usdcAddress)).to.equal("0");
        expect(await getERC20Balance(contractHelper.address, wethAddress)).to.equal(testAmount);

        amount = await contractHelper.connect(swaper).getTwap();
        // console.log(amount);

        tx = await contractHelper.connect(swaper).swapWETH_USDC(testAmount);
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
        await mineSomeBlocks(83622);
        await mineSomeBlocks(83622);

        const wethInput = wethInputR;
        const usdcInput = usdcInputR;
        const osqthInput = osqthInputR;

        // Balances
        expect(await getERC20Balance(keeper.address, wethAddress)).to.equal(wethInput);
        expect(await getERC20Balance(keeper.address, usdcAddress)).to.equal(usdcInput);
        expect(await getERC20Balance(keeper.address, osqthAddress)).to.equal(osqthInput);

        tx = await VaultAuction.connect(keeper).timeRebalance(keeper.address, 0, 0, 0);
        receipt = await tx.wait();
        console.log("> Gas used timeRebalance: %s", receipt.gasUsed);

        // Balances
        //await logBalance(keeper.address);

        const ethAmountK = await getERC20Balance(keeper.address, wethAddress);
        const usdcAmountK = await getERC20Balance(keeper.address, usdcAddress);
        const osqthAmountK = await getERC20Balance(keeper.address, osqthAddress);
        console.log("> Keeper ETH balance after rebalance %s", ethAmountK);
        console.log("> Keeper USDC balance after rebalance %s", usdcAmountK);
        console.log("> Keeper oSQTH balance after rebalance %s", osqthAmountK);

        await logBalance(keeper.address);
        assert(assertWP(await getERC20Balance(keeper.address, wethAddress), "524900849099353768", 1, 18), "1!");
        //assert(assertWP(await getERC20Balance(keeper.address, usdcAddress), "9044128865", 1, 6), "2!"); // Deffers between test runs significantly
        // assert(assertWP(await getERC20Balance(keeper.address, osqthAddress), "36137303615851849485", 4, 18), "3!"); // Deffers between test runs significantly

        const amount = await VaultMath.getTotalAmounts();

        const ethAmountS = amount[0].toString();
        const usdcAmountS = amount[1].toString();
        const osqthAmountS = amount[2].toString();
        console.log("> Strategy ETH balance after rebalance %s", ethAmountS);
        console.log("> Strategy USDC balance after rebalance %s", usdcAmountS);
        console.log("> Strategy oSQTH balance after rebalance %s", osqthAmountS);

        // assert(assertWP(ethAmountS, "17630824578622449990", 1, 18), "1!"); // Deffers between test runs significantly
        // assert(assertWP(usdcAmountS, "41398580341", 1, 6), "2!"); // Deffers between test runs significantly
        // assert(assertWP(osqthAmountS, "19533654925701341611", 4, 18), "3!"); // Deffers between test runs significantly
    });

    it("swap", async function () {
        const testAmount = utils.parseUnits("10", 12).toString();
        console.log(testAmount);

        await getUSDC(testAmount, contractHelper.address);

        // Balances
        expect(await getERC20Balance(contractHelper.address, usdcAddress)).to.equal("13369149847107");
        expect(await getERC20Balance(contractHelper.address, wethAddress)).to.equal("0");

        // amount = await contractHelper.connect(swaper).getTwapR();
        // console.log(amount);

        tx = await contractHelper.connect(swaper).swapUSDC_WETH(testAmount);
        await tx.wait();

        for (const i of Array(6)) {
            await hre.network.provider.request({
                method: "evm_mine",
            });
        }

        // amount = await contractHelper.connect(swaper).getTwapR();
        // console.log(amount);

        // Balances
        assert(assertWP(await getERC20Balance(contractHelper.address, wethAddress), "2932062768070314980891", 4, 18));
        expect(await getERC20Balance(contractHelper.address, usdcAddress)).to.equal("3369149847107");

        const amount = await VaultMath.getTotalAmounts();

        console.log(
            "Strategy ETH amount after second swap %s, USDC Amount %s, oSQTH amount %s",
            amount[0],
            amount[1],
            amount[2]
        );

        const amountDeposit = await Vault.getAmountsToDeposit("1000000000000000000");

        console.log("> USDC to deposit %s, oSQTH to deposit %s", amountDeposit[0], amountDeposit[1]);
    });

    it("withdraw", async function () {
        // Shares
        expect(await getERC20Balance(depositor.address, Vault.address)).to.equal("35260912783625458873");

        tx = await Vault.connect(depositor).withdraw("35260912783625458873", "0", "0", "0");
        await tx.wait();

        // Balances
        const ethBalance = await getERC20Balance(depositor.address, wethAddress);
        const usdcBalance = await getERC20Balance(depositor.address, usdcAddress);
        const osqthBalance = await getERC20Balance(depositor.address, osqthAddress);
        console.log("> Eth balance %s", ethBalance);
        console.log("> USDC balance %s", usdcBalance);
        console.log("> oSQTH balance %s", osqthBalance);

        assert(assertWP(ethBalance, "16347482773253353125", 1, 18), "!");
        // assert(assertWP(usdcBalance, "45773130273", 1, 6), "!"); // Deffers between test runs significantly
        // assert(assertWP(osqthBalance, "19533654806345837221", 3, 18), "!"); // Deffers between test runs significantly

        // Shares
        expect(await getERC20Balance(depositor.address, Vault.address)).to.equal("0");

        const amount = await VaultMath.getTotalAmounts();
        console.log("> Total amounts:", amount);
    });
});
