const { expect, assert } = require("chai");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");
const { poolEthUsdc, poolEthOsqth, wethAddress, osqthAddress, usdcAddress } = require("./common");
const { utils } = ethers;
const { resetFork, getWETH, getUSDC, getOSQTH, getERC20Balance, approveERC20 } = require('./helpers');

describe("Strategy rebalance", function () {
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

    const wethInputR = "1355494073418907206";
    const usdcInputR = "10744100746";
    const osqthInputR = "11265817624593139053";
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

        const testAmount = utils.parseUnits("10", 12).toString();
        console.log(testAmount);

        await getUSDC(testAmount, contractHelper.address);

        expect(await getERC20Balance(contractHelper.address, usdcAddress)).to.equal(testAmount);
        expect(await getERC20Balance(contractHelper.address, wethAddress)).to.equal("0");

        amount = await contractHelper.connect(seller).getTwapR();
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

        amount = await contractHelper.connect(seller).getTwapR();
        // console.log(amount);

        expect(await getERC20Balance(contractHelper.address, wethAddress)).to.equal("2914653369323031873696");
        expect(await getERC20Balance(contractHelper.address, usdcAddress)).to.equal("0");
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

        expect(await getERC20Balance(rebalancer.address, wethAddress)).to.equal("2710988146837814402");
        expect(await getERC20Balance(rebalancer.address, usdcAddress)).to.equal("21488201482");
        expect(await getERC20Balance(rebalancer.address, osqthAddress)).to.equal("0");

        const amount = await contract._getTotalAmounts();
        expect(amount[0].toString()).to.equal("17346973595875500520");
        expect(amount[1].toString()).to.equal("19664371768");
        expect(amount[2].toString()).to.equal("45604281980007161309");
    });

    it("swap", async function () {
        const seller = (await ethers.getSigners())[6];

        const testAmount = utils.parseUnits("10", 12).toString();
        console.log(testAmount);

        await getUSDC(testAmount, contractHelper.address);

        expect(await getERC20Balance(contractHelper.address, usdcAddress)).to.equal(testAmount);
        expect(await getERC20Balance(contractHelper.address, wethAddress)).to.equal("2914653369323031873696");

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

        expect(await getERC20Balance(contractHelper.address, wethAddress)).to.equal("5775701272096358063362");
        expect(await getERC20Balance(contractHelper.address, usdcAddress)).to.equal("0");
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
        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal("15471521092706281128");
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal("26219903217");
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal("45604281980007161308");

        const amount = await contract._getTotalAmounts();
        expect(amount[0].toString()).to.equal("3");
        expect(amount[1].toString()).to.equal("2");
        expect(amount[2].toString()).to.equal("1");
    });

});