const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { wethAddress, osqthAddress, usdcAddress } = require("./common");
const { utils } = ethers;
const {
    resetFork,
    getUSDC,
    getERC20Balance,
    getAndApprove,
    logBlock,
    logBalance,
    mineSomeBlocks,
    assertWP,
} = require("./helpers");
const { hardhatDeploy, deploymentParams } = require("./deploy");

describe("Strategy rebalance buy", function () {
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

    const wethInputR = "0";
    const usdcInputR = "686851794";
    const osqthInputR = "0";
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

        tx = await Vault.connect(depositor).deposit(wethInput, usdcInput, osqthInput, depositor.address, "0", "0", "0");
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

    it("swap_before_rebalance_USDC_to_ETH", async function () {
        const testAmount = utils.parseUnits("10", 12).toString();
        console.log("> Swap %s USDC for ETH", testAmount);

        await getUSDC(testAmount, contractHelper.address);

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
        expect(await getERC20Balance(contractHelper.address, wethAddress)).to.equal("2914653369323031873696");
        expect(await getERC20Balance(contractHelper.address, usdcAddress)).to.equal("0");
    });

    it("rebalance", async function () {
        await mineSomeBlocks(83622);
        await mineSomeBlocks(83622);
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

        console.log("> Keeper ETH balance before rebalance %s", keeperEthBalanceBeforeRebalance);
        console.log("> Keeper USDC balance before rebalance %s", keeperUsdcBalanceBeforeRebalance);
        console.log("> Keeper oSQTH balance before rebalance %s", keeperOsqthBalanceBeforeRebalance);

        tx = await VaultAuction.connect(keeper).timeRebalance(keeper.address, 0, 0, 0);
        await tx.wait();

        // Balances
        await logBalance(keeper.address);

        const ethAmountK = await getERC20Balance(keeper.address, wethAddress);
        const usdcAmountK = await getERC20Balance(keeper.address, usdcAddress);
        const osqthAmountK = await getERC20Balance(keeper.address, osqthAddress);
        console.log("> Keeper ETH balance after rebalance %s", ethAmountK);
        console.log("> Keeper USDC balance after rebalance %s", usdcAmountK);
        console.log("> Keeper oSQTH balance after rebalance %s", osqthAmountK);

        assert(assertWP(await getERC20Balance(keeper.address, wethAddress), "1344690635026081974", 3, 18), "1!");
        // assert(assertWP(await getERC20Balance(keeper.address, usdcAddress), "99684", 2, 6), "2!");
        assert(assertWP(await getERC20Balance(keeper.address, osqthAddress), "2287996609233353372", 3, 18), "3!");

        const amount = await VaultMath.getTotalAmounts();
        console.log("> Total amounts:", amount);
    });

    it("swap", async function () {
        const testAmount = utils.parseUnits("10", 12).toString();
        console.log(testAmount);

        await getUSDC(testAmount, contractHelper.address);

        // Balances
        expect(await getERC20Balance(contractHelper.address, usdcAddress)).to.equal(testAmount);
        expect(await getERC20Balance(contractHelper.address, wethAddress)).to.equal("2914653369323031873696");

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
        assert(assertWP(await getERC20Balance(contractHelper.address, wethAddress), "5775701145177843499710", 6, 18));
        assert(assertWP(await getERC20Balance(contractHelper.address, usdcAddress), "0", 2, 6));
    });

    it("withdraw", async function () {
        // Shares
        expect(await getERC20Balance(depositor.address, Vault.address)).to.equal("35260912783625458873");

        tx = await Vault.connect(depositor).withdraw("35260912783625458873", "0", "0", "0");
        await tx.wait();

        // Balances
        await logBalance(depositor.address);
        assert(assertWP(await getERC20Balance(depositor.address, wethAddress), "14422921638375998597", 3, 18));
        // assert(assertWP(await getERC20Balance(depositor.address, usdcAddress), "37071596620", 1, 6)); // Deffers between test runs significantly //18809731500
        assert(assertWP(await getERC20Balance(depositor.address, osqthAddress), "30784915833792601371", 3, 18));

        // Shares
        expect(await getERC20Balance(depositor.address, Vault.address)).to.equal("0");

        const amount = await VaultMath.getTotalAmounts();
        console.log("> Total amounts:", amount);
    });
});
