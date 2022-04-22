const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { wethAddress, osqthAddress, usdcAddress } = require("./common");
const { utils } = ethers;
const { resetFork, getWETH, getUSDC, getOSQTH, getERC20Balance, approveERC20, assertWP } = require("./helpers");

describe("Strategy rebalance, sell with comissions", function () {
    let contract, library, contractHelper, tx, amount, rebalancer;
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
            "100000"
        );
        await contract.deployed();
    });

    it("Should deploy V3Helper", async function () {
        const Contract = await ethers.getContractFactory("V3Helper");
        contractHelper = await Contract.deploy();
        await contractHelper.deployed();
    });

    // deltaEth 1372221087323376193
    // deltaUsdc 20200033241
    // deltaOsqth 19348960827455603626
    const wethInputR = "800348675119972960";
    const usdcInputR = "14065410226";
    const osqthInputR = "13136856056157859843";
    it("preset", async function () {
        rebalancer = (await ethers.getSigners())[5];

        tx = await contract.connect(rebalancer).setTimeAtLastRebalance(1648646662);
        await tx.wait();

        tx = await contract.connect(rebalancer).setEthPriceAtLastRebalance("3391393578000000000000");
        await tx.wait();

        // await contract.setProtocolFee(100000);

        const _wethInput = wethInputR;
        const _usdcInput = usdcInputR;
        const _osqthInput = osqthInputR;

        await getWETH(_wethInput, rebalancer.address);
        await getUSDC(_usdcInput, rebalancer.address);
        await getOSQTH(_osqthInput, rebalancer.address);

        await approveERC20(rebalancer, contract.address, _wethInput, wethAddress);
        await approveERC20(rebalancer, contract.address, _usdcInput, usdcAddress);
        await approveERC20(rebalancer, contract.address, _osqthInput, osqthAddress);
    });

    it("deposit", async function () {
        const depositor = (await ethers.getSigners())[4];

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
        const seller = (await ethers.getSigners())[6];

        const testAmount = utils.parseUnits("1000", 18).toString();
        console.log(testAmount);

        await getWETH(testAmount, contractHelper.address);

        expect(await getERC20Balance(contractHelper.address, usdcAddress)).to.equal("0");
        expect(await getERC20Balance(contractHelper.address, wethAddress)).to.equal(testAmount);

        amount = await contractHelper.connect(seller).getTwap();
        // console.log(amount);

        tx = await contractHelper.connect(seller).swap(testAmount);
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

        amount = await contractHelper.connect(seller).getTwap();
        // console.log(amount);

        expect(await getERC20Balance(contractHelper.address, wethAddress)).to.equal("0");
        expect(await getERC20Balance(contractHelper.address, usdcAddress)).to.equal("3369149847107");
    });

    it("rebalance", async function () {
        const wethInput = wethInputR;
        const usdcInput = usdcInputR;
        const osqthInput = osqthInputR;

        expect(await getERC20Balance(rebalancer.address, wethAddress)).to.equal(wethInput);
        expect(await getERC20Balance(rebalancer.address, usdcAddress)).to.equal(usdcInput);
        expect(await getERC20Balance(rebalancer.address, osqthAddress)).to.equal(osqthInput);

        tx = await contract.connect(rebalancer).timeRebalance(rebalancer.address, wethInput, usdcInput, osqthInput);
        await tx.wait();

        expect(await getERC20Balance(rebalancer.address, wethAddress)).to.equal("0");
        expect(await getERC20Balance(rebalancer.address, usdcAddress)).to.equal("0");
        expect(await getERC20Balance(rebalancer.address, osqthAddress)).to.equal("26273712112315719666");

        const amount = await contract._getTotalAmounts();
        console.log(amount);
        expect(amount[0].toString()).to.equal("17552976000000000008");
        expect(amount[1].toString()).to.equal("40024475506");
        expect(amount[2].toString()).to.equal("19082258000000000009");
    });

    it("swap", async function () {
        const seller = (await ethers.getSigners())[6];

        const testAmount = utils.parseUnits("10", 12).toString();
        console.log(testAmount);

        await getUSDC(testAmount, contractHelper.address);

        expect(await getERC20Balance(contractHelper.address, usdcAddress)).to.equal("13369149847107");
        expect(await getERC20Balance(contractHelper.address, wethAddress)).to.equal("0");

        // amount = await contractHelper.connect(seller).getTwapR();
        // console.log(amount);

        tx = await contractHelper.connect(seller).swapR(testAmount);
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

        // amount = await contractHelper.connect(seller).getTwapR();
        // console.log(amount);

        expect(await getERC20Balance(contractHelper.address, wethAddress)).to.equal("2932067220234871219116");
        expect(await getERC20Balance(contractHelper.address, usdcAddress)).to.equal("3369149847107");
    });

    it("withdraw", async function () {
        const depositor = (await ethers.getSigners())[4];

        // Shares
        expect(await getERC20Balance(depositor.address, contract.address)).to.equal("124866579487341572537626");

        tx = await contract.connect(depositor).withdraw("124866579487341572537626", "0", "0", "0");
        await tx.wait();

        // Shares
        assert(assertWP(await getERC20Balance(depositor.address, wethAddress), "17729844128458954112", 16, 18), "test");
        assert(assertWP(await getERC20Balance(depositor.address, usdcAddress), "50517045994", 4, 6), "test");
        assert(
            assertWP(await getERC20Balance(depositor.address, osqthAddress), "21202508688385778328", 16, 18),
            "test"
        );

        const amount = await contract._getTotalAmounts();
        console.log(amount);
        expect(amount[0].toString()).to.equal("0");
        expect(amount[1].toString()).to.equal("2");
        expect(amount[2].toString()).to.equal("1");
    });
});
