const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { poolEthUsdc, poolEthOsqth, wethAddress, osqthAddress, usdcAddress } = require("./common");
const { utils } = ethers;
const { assertWP, getWETH, getUSDC, getOSQTH, getERC20Balance, approveERC20 } = require('./helpers');

describe.only("Strategy", function () {
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

    //   it("Should withdraw", async function () {
    //     const depositor = (await ethers.getSigners())[3];
    //     const sharesInput = utils.parseUnits("2", 18).toString();

    //     tx = await contract.connect(depositor).withdraw(sharesInput, 0, 1, 1);
    //     await tx.wait();

    //     // Balances
    //     expect(await getERC20Balance(depositor.address, wethAddress)).to.equal("0", "test 1");
    //     expect(await getERC20Balance(contract.address, wethAddress)).to.equal("0", "test 2");

    //     // Shares
    //     expect(await getERC20Balance(depositor.address, contract.address)).to.equal("0", "test 3");

    //     // Meta
    //     expect(await contract.totalEthDeposited()).to.equal("2000000000000000000", "test 4");
    //   });
});