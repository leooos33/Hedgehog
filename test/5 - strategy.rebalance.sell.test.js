const { expect, assert } = require("chai");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");
const { poolEthUsdc, poolEthOsqth, wethAddress, osqthAddress, usdcAddress } = require("./common");
const { utils } = ethers;
const { resetFork, getWETH, getUSDC, getOSQTH, getERC20Balance, approveERC20 } = require('./helpers');

describe.only("Strategy rebalance", function () {
    let contract, library, contractHelper, tx, amount, rebalancer;
    it("Should deploy contract", async function () {
        await resetFork();

        const Library = await ethers.getContractFactory("UniswapAdaptor");
        library = await Library.deploy();
        await library.deployed();

        // console.log(await library.getPriceFromTick("162714639867323407420353073371"));

        const Contract = await ethers.getContractFactory("Vault");
        contract = await Contract.deploy(
            utils.parseUnits("4000000000000", 18),
            10,
            utils.parseUnits("0.05", 18),
            "10",
            "900000000000000000",
            "1100000000000000000",
            library.address
        );
        await contract.deployed();
    });

    it("Should deploy V3Helper", async function () {
        const Contract = await ethers.getContractFactory("V3Helper");
        contractHelper = await Contract.deploy();
        await contractHelper.deployed();
    });

    const wethInputR = "800805084661562875";
    const usdcInputR = "14063089446";
    const osqthInputR = "13135992616194200980";
    it("preset", async function () {
        rebalancer = (await ethers.getSigners())[5];

        tx = await contract.connect(rebalancer).setTimeAtLastRebalance(1648646662);
        await tx.wait();

        tx = await contract.connect(rebalancer).setEthPriceAtLastRebalance("3391393578000000000000");
        await tx.wait();
        
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

        const wethInputS = "18410690015258689749";
        const usdcInputS = "32743712092";
        const osqthInputS = "32849750909396941650";

        const wethInput =  "18702467669294407718";
        const usdcInput = "30408472505";
        const osqthInput = "34338464355414022257";

        await getWETH(wethInput, depositor.address);
        await getUSDC(usdcInput, depositor.address);
        await getOSQTH(osqthInput, depositor.address);

        await approveERC20(depositor, contract.address, wethInput, wethAddress);
        await approveERC20(depositor, contract.address, usdcInput, usdcAddress);
        await approveERC20(depositor, contract.address, osqthInput, osqthAddress);

        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal(wethInput);
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal(usdcInput);
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal(osqthInput);

        tx = await contract.connect(depositor).deposit(
            wethInputS,
            usdcInputS,
            osqthInputS,
            depositor.address,
            '0',
            '0',
            '0',
        );
        await tx.wait();

        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal("0");
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal("0");
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal("0");

        // Shares
        expect(await getERC20Balance(depositor.address, contract.address)).to.equal("124875791768051387725881");
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

        tx = await contractHelper.connect(seller).swap(
            testAmount
        );
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

        tx = await contract.connect(rebalancer).timeRebalance(
            wethInput,
            usdcInput,
            osqthInput
        );
        await tx.wait();

        expect(await getERC20Balance(rebalancer.address, wethAddress)).to.equal("0");
        expect(await getERC20Balance(rebalancer.address, usdcAddress)).to.equal("0");
        expect(await getERC20Balance(rebalancer.address, osqthAddress)).to.equal("26271985232388401950");

        const amount = await contract._getTotalAmounts();
        expect(amount[0].toString()).to.equal("19503272753955970591");
        expect(amount[1].toString()).to.equal("44471561950");
        expect(amount[2].toString()).to.equal("21202471739219821286");
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

        tx = await contractHelper.connect(seller).swapR(
            testAmount
        );
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

        expect(await getERC20Balance(contractHelper.address, wethAddress)).to.equal("2932067220206984462645");
        expect(await getERC20Balance(contractHelper.address, usdcAddress)).to.equal("3369149847107");
    });

    it("withdraw", async function () {
        const depositor = (await ethers.getSigners())[4];

        // Shares
        expect(await getERC20Balance(depositor.address, contract.address)).to.equal("124875791768051387725881");

        tx = await contract.connect(depositor).withdraw(
            "124875791768051387725881",
            '0',
            '0',
            '0',
        );
        await tx.wait();

        // Shares
        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal("17729813229394221103");
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal("50516957965");
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal("21202471739219821285");

        const amount = await contract._getTotalAmounts();
        expect(amount[0].toString()).to.equal("338");
        expect(amount[1].toString()).to.equal("2");
        expect(amount[2].toString()).to.equal("1");
    });
});