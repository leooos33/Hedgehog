const { assert } = require("chai");
const { ethers } = require("hardhat");
const { poolEthUsdc, poolEthOsqth, wethAddress, osqthAddress, usdcAddress } = require("./common");
const { utils } = ethers;
const { assertWP, getWETH, getUSDC, getOSQTH, getERC20Balance } = require('./helpers');

describe("VaultMath", function () {
    let contract, tx;
    it("Should deploy contract", async function () {
        const Contract = await ethers.getContractFactory("VaultMath");
        contract = await Contract.deploy(
            utils.parseUnits("40", 18),
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

    it("_floor", async function () {

        const test_sute = [
            "195031",
            "60"
        ];
        console.log(test_sute);

        const amount = await contract._floor(
            ...test_sute,
        );
        console.log(">>", amount);

        assert(amount.toString() == "195000", `should not fail`);
    });


    it("_floor", async function () {

        const test_sute = [
            "13223",
            "60"
        ];
        console.log(test_sute);

        const amount = await contract._floor(
            ...test_sute,
        );
        console.log(">>", amount);

        assert(amount.toString() == "13200", `should not fail`);
    });


    it("getTick", async function () {

        const amount = await contract.getTick(poolEthUsdc);
        console.log(">>", amount);

        assert(amount.toString() == "195031", `should not fail`);
    });

    it("getTick", async function () {

        const amount = await contract.getTick(poolEthOsqth);
        console.log(">>", amount);

        assert(amount.toString() == "13223", `should not fail`);
    });

    it("_getBoundaries", async function () {

        const amount = await contract._getBoundaries();
        console.log(">>", amount);

        assert(amount[0].toString() == "193980", `test_sute: sub 1`);
        assert(amount[1].toString() == "196080", `test_sute: sub 2`);
        assert(amount[2].toString() == "12180", `test_sute: sub 3`);
        assert(amount[3].toString() == "14280", `test_sute: sub 4`);
    });

    it("_liquidityForAmounts", async function () {

        const amount = await contract._liquidityForAmounts(
            poolEthUsdc,
            "193980",
            "196080",
            "24972947409",
            "7380438629950410000"
        );
        console.log(">>", amount);
        assert(assertWP(amount.toString(), "8394376743052387", 0, 6), `should not fail`);
    });

    it("_liquidityForAmounts", async function () {

        const amount = await contract._liquidityForAmounts(
            poolEthOsqth,
            "12180",
            "14280",
            "7364483097017340000",
            "27311612764595500000"
        );
        console.log(">>", amount);

        assert(assertWP(amount.toString(), "277304729505821000000", 0), `should not fail`);
    });

    it("_amountsForLiquidity", async function () {

        const amount = await contract._amountsForLiquidity(
            poolEthUsdc,
            "193980",
            "196080",
            "8394376743052387"
        );
        console.log(">>", amount);
        assert(assertWP(amount[0].toString(), "24972947409", 4, 6), `should not fail`);
        assert(assertWP(amount[1].toString(), "7380438629950410000", 4, 18), `should not fail`);
    });

    it("_amountsForLiquidity", async function () {

        const amount = await contract._amountsForLiquidity(
            poolEthOsqth,
            "12180",
            "14280",
            "277304729505821000000"
        );
        console.log(">>", amount);
        assert(assertWP(amount[0].toString(), "7364483097017340000", 1, 18), `should not fail`);
        assert(assertWP(amount[1].toString(), "27311612764595500000", 1, 18), `should not fail`);
    });

    it("_position", async function () {

        const amount = await contract._position(
            poolEthOsqth,
            "12180",
            "14280"
        );

        assert(amount[0].toString() == "0", `test_sute: sub 1`);
        assert(amount[1].toString() == "0", `test_sute: sub 2`);
        assert(amount[2].toString() == "0", `test_sute: sub 3`);
        assert(amount[3].toString() == "0", `test_sute: sub 4`);
    });

    it("_mintLiquidity", async function () {

        //+1
        await getWETH("7368329871844425587", contract.address);
        //+1
        await getOSQTH("27296229334056607431", contract.address);

        console.log(await getERC20Balance(contract.address, wethAddress));
        console.log(await getERC20Balance(contract.address, osqthAddress));

        await contract._mintLiquidity(
            poolEthOsqth,
            "12180",
            "14280",
            "277304729505821000000"
        );
    });

    it("_position", async function () {
        const amount = await contract._position(
            poolEthOsqth,
            "12180",
            "14280"
        );
        console.log(">>", amount);

        assert(amount[0].toString() == "277304729505821000000", `test_sute: sub 1`);
    });

    it("_mintLiquidity", async function () {

        //+1
        await getWETH("7380438629385777545", contract.address);
        //+1
        await getUSDC("24972947409", contract.address);


        console.log(await getERC20Balance(contract.address, wethAddress));
        console.log(await getERC20Balance(contract.address, usdcAddress));

        await contract._mintLiquidity(
            poolEthUsdc,
            "193980",
            "196080",
            "8394376743052387"
        );
    });

    it("_position", async function () {
        const amount = await contract._position(
            poolEthUsdc,
            "193980",
            "196080",
        );
        console.log(">>", amount);

        assert(amount[0].toString() == "8394376743052387", `test_sute: sub 1`);
    });

    it("getAuctionPrices", async function () {
        const amount = await contract.getAuctionPrices(
            "1632160192",
            "2500000000000000000000",
            "199226590621515000",
            false
        );
        console.log(">>", amount);

        assert(assertWP(amount[0].toString(), "179303931559364000"), `test_sute: sub 1`)
        assert(assertWP(amount[1].toString(), "2250000000000010000000"), `test_sute: sub 2`)
    });

    it("getPositionAmounts", async function () {
        const amount = await contract.getPositionAmounts(
            poolEthUsdc,
            "193980",
            "196080",
        );
        console.log(">>", amount);

        assert(assertWP(amount[0].toString(), "24972947408"), `test_sute: sub 1`)
        assert(assertWP(amount[1].toString(), "7380438629385777544"), `test_sute: sub 2`)
    });

    it("_getTotalAmounts", async function () {
        tx = await contract.setTotalAmountsBoundaries(
            "193980",
            "196080",
            "12180",
            "14280"
        );
        await tx.wait();

        const amount = await contract._getTotalAmounts();
        console.log(">>", amount);

        assert(assertWP(amount[0].toString(), "14744921726967800000", 1), `test_sute: sub 1`)
        assert(assertWP(amount[1].toString(), "24972947409", 4, 6), `test_sute: sub 2`)
        assert(assertWP(amount[2].toString(), "27311612764595500000", 0), `test_sute: sub 3`)
    });

    it("_getDeltas", async function () {
        const amount = await contract._getDeltas(
            "3390997994146850000000",
            "270230787671309000",
            "1648646160",
            false
        );
        console.log(">>", amount);

        assert(assertWP(amount[0].toString(), "51333406548477019722657", 4), `test_sute: sub 1`)
        assert(assertWP(amount[1].toString(), "18423844171", 4, 6), `test_sute: sub 2`)
        assert(assertWP(amount[2].toString(), "19294609072462626762", 4), `test_sute: sub 3`)
    });


    it("calcSharesAndAmounts", async function () {
        const amount = await contract.calcSharesAndAmounts(
            "19855700000000000000",
            "41326682043",
            "17933300000000000000",
        );
        console.log(">>", amount);

        assert(assertWP(amount[0].toString(), "124875791768594084851645"), `test_sute: sub 1`)
        assert(assertWP(amount[1].toString(), "18410690015258689749"), `test_sute: sub 2`)
        assert(assertWP(amount[2].toString(), "32743712092", 0), `test_sute: sub 3`)
        assert(assertWP(amount[3].toString(), "32849750909396941650", 0), `test_sute: sub 4`)
    });

    // it("_getWithdrawAmounts", async function () {
    //     const tx = await contract._getWithdrawAmounts(
    //         "124875791768594084851645",
    //         "124875791768594084851645",
    //     );
    //     await tx.wait()

    //     console.log(await contract.test1());
    //     console.log(await contract.test2());
    //     console.log(await contract.test3());
    //     // assert(assertWP(, "18410690015258689749"), `test_sute: sub 2`)
    //     // assert(assertWP(amount[1].toString(), "32743712092", 0), `test_sute: sub 3`)
    //     // assert(assertWP(amount[2].toString(), "32849750909396941650", 0), `test_sute: sub 4`)
    // });
});