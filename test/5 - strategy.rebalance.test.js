const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { poolEthUsdc, poolEthOsqth, wethAddress, osqthAddress, usdcAddress } = require("./common");
const { utils } = ethers;
const { resetFork, getWETH, getUSDC, getOSQTH, getERC20Balance, approveERC20 } = require('./helpers');

describe("Strategy rebalance", function () {
    let contract, contractHelper, tx, amount;
    it("Should deploy contract", async function () {
        await resetFork();

        const Contract = await ethers.getContractFactory("Vault");
        contract = await Contract.deploy(
            utils.parseUnits("4000000000000", 18),
            4,
            utils.parseUnits("0.05", 18),
            "10",
            "900000000000000000",
            "1100000000000000000",
            "500000000000000000",
            "262210246107746000",
            "237789753892254000",
        );
        await contract.deployed();
    });

    it("Should deploy V3Helper", async function () {
        const Contract = await ethers.getContractFactory("V3Helper");
        contractHelper = await Contract.deploy();
        await contractHelper.deployed();
    });

    const wethInput = "18410690015258689749";
    const usdcInput = "32743712092";
    const osqthInput = "32849750909396941650";
    it("deposit", async function () {
        const depositor = (await ethers.getSigners())[4];

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
            wethInput,
            usdcInput,
            osqthInput,
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
        expect(await getERC20Balance(depositor.address, contract.address)).to.equal("124875791768051387725783");
    });

    it("swap", async function () {
        const seller = (await ethers.getSigners())[6];

        const testAmount = utils.parseUnits("1000", 18).toString();

        await getWETH(testAmount, contractHelper.address);

        expect(await getERC20Balance(contractHelper.address, wethAddress)).to.equal(testAmount);
        expect(await getERC20Balance(contractHelper.address, usdcAddress)).to.equal("0");

        amount = await contractHelper.connect(seller).getTwap();
        // console.log(amount);

        tx = await contractHelper.connect(seller).swap(
            testAmount
        );
        await tx.wait();

        await hre.network.provider.request({
            method: "evm_mine",
        });

        amount = await contractHelper.connect(seller).getTwap();
        // console.log(amount);

        expect(await getERC20Balance(contractHelper.address, wethAddress)).to.equal("0");
        expect(await getERC20Balance(contractHelper.address, usdcAddress)).to.equal("3369149847107");
    });

    // it("rebalance", async function () {
    //     const rebalancer = (await ethers.getSigners())[5];

    //     tx = await contract.connect(rebalancer).setTimeAtLastRebalance(1648646662);
    //     await tx.wait();

    //     tx = await contract.connect(rebalancer).timeRebalance(
    //         false,
    //         "34755542168651400000",
    //         "2140239638",
    //         "1303193662046230000"
    //     );
    //     await tx.wait();
    // });
});