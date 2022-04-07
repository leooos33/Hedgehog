const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { poolEthUsdc, poolEthOsqth, wethAddress, osqthAddress, usdcAddress } = require("./common");
const { utils } = ethers;
const { assertWP, getWETH, getUSDC, getOSQTH, getERC20Balance, approveERC20 } = require('./helpers');

describe("Strategy", function () {
    let contract, tx;
    it("Should deploy contract", async function () {
        const Contract = await ethers.getContractFactory("Vault");
        contract = await Contract.deploy(
            utils.parseUnits("4000000000000", 18),
            1000,
            utils.parseUnits("0.05", 18),
            "1000000000000000000000",
            "900000000000000000",
            "1100000000000000000",
            "500000000000000000",
            "262210246107746000",
            "237789753892254000",
        );
        await contract.deployed();
    });

    it("deposit", async function () {
        const depositor = (await ethers.getSigners())[3];

        const amount = await contract.connect(depositor).calcSharesAndAmounts(
            "19855700000000000000",
            "41326682043",
            "17933300000000000000",
        );
        console.log(amount)

        const wethInput = amount[1].toString();
        const usdcInput = amount[2].toString();
        const osqthInput = amount[3].toString();

        await getWETH(wethInput, depositor.address);
        await getUSDC(usdcInput, depositor.address);
        await getOSQTH(osqthInput, depositor.address);

        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal(wethInput);
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal(usdcInput);
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal(osqthInput);

        await approveERC20(depositor, contract.address, wethInput, wethAddress);
        await approveERC20(depositor, contract.address, usdcInput, usdcAddress);
        await approveERC20(depositor, contract.address, osqthInput, osqthAddress);

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

        // Balances
        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal("0");
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal("0");
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal("0");

        expect(await getERC20Balance(contract.address, wethAddress)).to.equal(wethInput);
        expect(await getERC20Balance(contract.address, usdcAddress)).to.equal(usdcInput);
        expect(await getERC20Balance(contract.address, osqthAddress)).to.equal(osqthInput);

        // Shares
        expect(await getERC20Balance(depositor.address, contract.address)).to.equal("124875791768051387725783");
    });

    it("withdraw", async function () {
        const depositor = (await ethers.getSigners())[3];

        // Shares
        expect(await getERC20Balance(depositor.address, contract.address)).to.equal("124875791768051387725783");

        // Balances
        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal("0");
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal("0");
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal("0");

        expect(await getERC20Balance(contract.address, wethAddress)).to.equal("18410690015258689749");
        expect(await getERC20Balance(contract.address, usdcAddress)).to.equal("32743712092");
        expect(await getERC20Balance(contract.address, osqthAddress)).to.equal("32849750909396941650");

        tx = await contract.connect(depositor).withdraw(
            "124875791768051387725783",
            '0',
            '0',
            '0',
        );
        await tx.wait();

        // Balances
        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal("18410690015258689749");
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal("32743712092");
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal("32849750909396941650");

        // Shares
        expect(await getERC20Balance(depositor.address, contract.address)).to.equal("0");
    });

    const wethInput = "18410690015258689749";
    const usdcInput = "32743712092";
    const osqthInput = "32849750909396941650";
    it("deposit2", async function () {
        const depositor = (await ethers.getSigners())[3];

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

    it("withdraw 2", async function () {
        const depositor = (await ethers.getSigners())[3];

        // Shares
        expect(await getERC20Balance(depositor.address, contract.address)).to.equal("124875791768051387725783");

        tx = await contract.connect(depositor).withdraw(
            "24875791768051387725783",
            '0',
            '0',
            '0',
        );
        await tx.wait();

        // Shares
        expect(await getERC20Balance(depositor.address, contract.address)).to.equal("100000000000000000000000");
    });

    it("withdraw 3", async function () {
        const depositor = (await ethers.getSigners())[3];

        // Shares
        expect(await getERC20Balance(depositor.address, contract.address)).to.equal("100000000000000000000000");

        tx = await contract.connect(depositor).withdraw(
            "100000000000000000000000",
            '0',
            '0',
            '0',
        );
        await tx.wait();

        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal(wethInput);
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal(usdcInput);
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal(osqthInput);

        // Shares
        expect(await getERC20Balance(depositor.address, contract.address)).to.equal("0");
    });
});