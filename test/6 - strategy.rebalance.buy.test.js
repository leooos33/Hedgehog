const { expect } = require("chai");
const { ethers } = require("hardhat");
const { wethAddress, osqthAddress, usdcAddress } = require("./common");
const { utils } = ethers;
const { resetFork, getUSDC, getERC20Balance, getAndApprove, logBlock } = require("./helpers");
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

    const wethInputR = "1355494073418907206";
    const usdcInputR = "10744100746";
    const osqthInputR = "11265817624593139053";
    it("preset", async function () {
        tx = await VaultStorage.connect(keeper).setTimeAtLastRebalance(1648646662);
        await tx.wait();

        tx = await VaultStorage.connect(keeper).setEthPriceAtLastRebalance("3391393578000000000000");
        await tx.wait();

        await getAndApprove(keeper, VaultAuction.address, wethInputR, usdcInputR, osqthInputR);
    });

    it("deposit", async function () {
        const wethInput = "18702958066838460455";
        const usdcInput = "30406229225";
        const osqthInput = "34339364744543638154";

        await getAndApprove(depositor, Vault.address, wethInput, usdcInput, osqthInput);

        // Balances
        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal(wethInput);
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal(usdcInput);
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal(osqthInput);

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

    it("swap", async function () {
        const testAmount = utils.parseUnits("10", 12).toString();
        console.log(testAmount);

        await getUSDC(testAmount, contractHelper.address);

        // Balances
        expect(await getERC20Balance(contractHelper.address, usdcAddress)).to.equal(testAmount);
        expect(await getERC20Balance(contractHelper.address, wethAddress)).to.equal("0");

        amount = await contractHelper.connect(swaper).getTwapR();
        // console.log(amount);

        tx = await contractHelper.connect(swaper).swapR(testAmount);
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
        const wethInput = wethInputR;
        const usdcInput = usdcInputR;
        const osqthInput = osqthInputR;

        // Balances
        expect(await getERC20Balance(keeper.address, wethAddress)).to.equal(wethInput);
        expect(await getERC20Balance(keeper.address, usdcAddress)).to.equal(usdcInput);
        expect(await getERC20Balance(keeper.address, osqthAddress)).to.equal(osqthInput);

        tx = await VaultAuction.connect(keeper).timeRebalance(keeper.address, wethInput, usdcInput, osqthInput);
        await tx.wait();

        // Balances
        expect(await getERC20Balance(keeper.address, wethAddress)).to.equal("2711440602151882055");
        expect(await getERC20Balance(keeper.address, usdcAddress)).to.equal("21485915191");
        expect(await getERC20Balance(keeper.address, osqthAddress)).to.equal("800641000891357");

        const amount = await VaultMath.connect(Vault.address).getTotalAmounts();
        console.log("Total amounts:", amount);
        expect(amount[0].toString()).to.equal("17347011000000000008");
        expect(amount[1].toString()).to.equal("19664414779");
        expect(amount[2].toString()).to.equal("45604382000000000009");
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

        tx = await contractHelper.connect(swaper).swapR(testAmount);
        await tx.wait();

        for (const i of Array(6)) {
            await hre.network.provider.request({
                method: "evm_mine",
            });
        }

        // amount = await contractHelper.connect(swaper).getTwapR();
        // console.log(amount);

        // Balances
        expect(await getERC20Balance(contractHelper.address, wethAddress)).to.equal("5775701272137382293192");
        expect(await getERC20Balance(contractHelper.address, usdcAddress)).to.equal("0");
    });

    it("withdraw", async function () {
        // Shares
        expect(await getERC20Balance(depositor.address, Vault.address)).to.equal("124866579487341572537626");

        tx = await Vault.connect(depositor).withdraw("124866579487341572537626", "0", "0", "0");
        await tx.wait();

        // Balances
        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal("15471554935575394495");
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal("26219960557");
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal("45604381728135885848");

        // Shares
        expect(await getERC20Balance(depositor.address, Vault.address)).to.equal("0");

        const amount = await VaultMath.connect(Vault.address).getTotalAmounts();
        console.log("Total amounts:", amount);
        expect(amount[0].toString()).to.equal("0");
        expect(amount[1].toString()).to.equal("2");
        expect(amount[2].toString()).to.equal("1");
    });
});
