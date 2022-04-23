const { expect } = require("chai");
const { ethers } = require("hardhat");
const { wethAddress, osqthAddress, usdcAddress } = require("./common");
const { utils } = ethers;
const { resetFork, getWETH, getUSDC, getOSQTH, getERC20Balance, approveERC20 } = require("./helpers");

describe("Strategy rebalance buy", function () {
    let contract, library, contractHelper, tx;
    it("Should deploy contract", async function () {
        await resetFork();

        const Library = await ethers.getContractFactory("UniswapAdaptor");
        library = await Library.deploy();
        await library.deployed();

        const Contract = await ethers.getContractFactory("Vault");
        contract = await Contract.deploy(
            utils.parseUnits("4000000000000", 18),
            10,
            utils.parseUnits("0.05", 18),
            "10",
            "900000000000000000",
            "1100000000000000000",
            "0"
        );
        await contract.deployed();

        const ContractHelper = await ethers.getContractFactory("V3Helper");
        contractHelper = await ContractHelper.deploy();
        await contractHelper.deployed();
    });

    let swaper, depositor, keeper;
    it("Should set actors", async function () {
        const signers = await ethers.getSigners();
        depositor = signers[4];
        keeper = signers[5];
        swaper = signers[6];
    });

    const wethInputR = "1355494073418907206";
    const usdcInputR = "10744100746";
    const osqthInputR = "11265817624593139053";
    it("preset", async function () {
        tx = await contract.connect(keeper).setTimeAtLastRebalance(1648646662);
        await tx.wait();

        tx = await contract.connect(keeper).setEthPriceAtLastRebalance("3391393578000000000000");
        await tx.wait();

        const _wethInput = wethInputR;
        const _usdcInput = usdcInputR;
        const _osqthInput = osqthInputR;

        await getWETH(_wethInput, keeper.address);
        await getUSDC(_usdcInput, keeper.address);
        await getOSQTH(_osqthInput, keeper.address);

        await approveERC20(keeper, contract.address, _wethInput, wethAddress);
        await approveERC20(keeper, contract.address, _usdcInput, usdcAddress);
        await approveERC20(keeper, contract.address, _osqthInput, osqthAddress);
    });

    it("deposit", async function () {
        const wethInput = "18702958066838460455";
        const usdcInput = "30406229225";
        const osqthInput = "34339364744543638154";

        await getWETH(wethInput, depositor.address);
        await getUSDC(usdcInput, depositor.address);
        await getOSQTH(osqthInput, depositor.address);

        await approveERC20(depositor, contract.address, wethInput, wethAddress);
        await approveERC20(depositor, contract.address, usdcInput, usdcAddress);
        await approveERC20(depositor, contract.address, osqthInput, osqthAddress);

        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal(wethInput);
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal(usdcInput);
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal(osqthInput);

        tx = await contract
            .connect(depositor)
            .deposit("18410690015258689749", "32743712092", "32849750909396941650", depositor.address, "0", "0", "0");
        await tx.wait();

        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal("0");
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal("0");
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal("0");

        // Shares
        expect(await getERC20Balance(depositor.address, contract.address)).to.equal("124866579487341572537626");
    });

    it("swap", async function () {
        const testAmount = utils.parseUnits("10", 12).toString();
        console.log(testAmount);

        await getUSDC(testAmount, contractHelper.address);

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

        expect(await getERC20Balance(contractHelper.address, wethAddress)).to.equal("2914653369323031873696");
        expect(await getERC20Balance(contractHelper.address, usdcAddress)).to.equal("0");
    });

    it("rebalance", async function () {
        const wethInput = wethInputR;
        const usdcInput = usdcInputR;
        const osqthInput = osqthInputR;

        expect(await getERC20Balance(keeper.address, wethAddress)).to.equal(wethInput);
        expect(await getERC20Balance(keeper.address, usdcAddress)).to.equal(usdcInput);
        expect(await getERC20Balance(keeper.address, osqthAddress)).to.equal(osqthInput);

        tx = await contract.connect(keeper).timeRebalance(keeper.address, wethInput, usdcInput, osqthInput);
        await tx.wait();

        expect(await getERC20Balance(keeper.address, wethAddress)).to.equal("2711440602151882055");
        expect(await getERC20Balance(keeper.address, usdcAddress)).to.equal("21485915191");
        expect(await getERC20Balance(keeper.address, osqthAddress)).to.equal("800641000891357");

        const amount = await contract._getTotalAmounts();
        // console.log(amount);
        expect(amount[0].toString()).to.equal("17347011000000000008");
        expect(amount[1].toString()).to.equal("19664414779");
        expect(amount[2].toString()).to.equal("45604382000000000009");
    });

    it("swap", async function () {
        const testAmount = utils.parseUnits("10", 12).toString();
        console.log(testAmount);

        await getUSDC(testAmount, contractHelper.address);

        expect(await getERC20Balance(contractHelper.address, usdcAddress)).to.equal(testAmount);
        expect(await getERC20Balance(contractHelper.address, wethAddress)).to.equal("2914653369323031873696");

        // amount = await contractHelper.connect(swaper).getTwapR();
        // console.log(amount);

        tx = await contractHelper.connect(swaper).swapR(testAmount);
        await tx.wait();

        await hre.network.provider.request({
            method: "evm_mine",
        });

        await hre.network.provider.request({
            method: "evm_mine",
        });

        await hre.network.provider.request({
            method: "evm_mine",
        });

        await hre.network.provider.request({
            method: "evm_mine",
        });

        await hre.network.provider.request({
            method: "evm_mine",
        });

        await hre.network.provider.request({
            method: "evm_mine",
        });

        // amount = await contractHelper.connect(swaper).getTwapR();
        // console.log(amount);

        expect(await getERC20Balance(contractHelper.address, wethAddress)).to.equal("5775701272137382293192");
        expect(await getERC20Balance(contractHelper.address, usdcAddress)).to.equal("0");
    });

    it("withdraw", async function () {
        // Shares
        expect(await getERC20Balance(depositor.address, contract.address)).to.equal("124866579487341572537626");

        tx = await contract.connect(depositor).withdraw("124866579487341572537626", "0", "0", "0");
        await tx.wait();

        // Shares
        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal("15471554935575394495");
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal("26219960557");
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal("45604381728135885848");

        const amount = await contract._getTotalAmounts();
        console.log(amount);
        expect(amount[0].toString()).to.equal("0");
        expect(amount[1].toString()).to.equal("2");
        expect(amount[2].toString()).to.equal("1");
    });
});
