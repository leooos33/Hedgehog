const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { wethAddress, osqthAddress, usdcAddress } = require("./common");
const { utils } = ethers;
const { assertWP, getWETH, getUSDC, getOSQTH, getERC20Balance, approveERC20, resetFork } = require("./helpers");

describe("Strategy deposit", function () {
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
            "0"
        );
        await contract.deployed();
    });

    it("deposit", async function () {
        const depositor = (await ethers.getSigners())[3];

        const amount = await contract
            .connect(depositor)
            .calcSharesAndAmounts("19855700000000000000", "41326682043", "17933300000000000000");
        console.log(amount);

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

        tx = await contract
            .connect(depositor)
            .deposit(wethInput, usdcInput, osqthInput, depositor.address, "0", "0", "0");
        await tx.wait();

        // Balances
        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal("85300624");
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal("0");
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal("156615292");

        assert(assertWP(await getERC20Balance(contract.address, wethAddress), wethInput, 8, 18), "test");
        assert(assertWP(await getERC20Balance(contract.address, usdcAddress), usdcInput, 6, 6), "test");
        assert(assertWP(await getERC20Balance(contract.address, osqthAddress), osqthInput, 8, 18), "test");

        // Shares
        expect(await getERC20Balance(depositor.address, contract.address)).to.equal("124867437697927036272825");
    });

    it("withdraw", async function () {
        const depositor = (await ethers.getSigners())[3];

        // Shares
        expect(await getERC20Balance(depositor.address, contract.address)).to.equal("124867437697927036272825");

        // Balances
        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal("85300624");
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal("0");
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal("156615292");

        expect(await getERC20Balance(contract.address, wethAddress)).to.equal("18703086612656391443");
        expect(await getERC20Balance(contract.address, usdcAddress)).to.equal("30406438208");
        expect(await getERC20Balance(contract.address, osqthAddress)).to.equal("34339600759708327238");

        tx = await contract.connect(depositor).withdraw("124867437697927036272825", "0", "0", "0");
        await tx.wait();

        // Balances
        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal("18703086612741692067");
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal("30406438207");
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal("34339600759864942530");

        // Shares
        expect(await getERC20Balance(depositor.address, contract.address)).to.equal("0");
    });
});
