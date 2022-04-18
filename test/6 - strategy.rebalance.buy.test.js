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

        const Library = await ethers.getContractFactory("PrbMathCalculus");
        library = await Library.deploy();
        await library.deployed();

        console.log(await library.getPriceFromTick("162714639867323407420353073371"));
        console.log(library.address);

        const Contract = await ethers.getContractFactory("Vault");
        contract = await Contract.deploy(
            utils.parseUnits("4000000000000", 18),
            10,
            utils.parseUnits("0.05", 18),
            "10",
            "900000000000000000",
            "1100000000000000000",
            "500000000000000000",
            "262210246107746000",
            "237789753892254000",
            library.address
        );
        await contract.deployed();

        // console.log(contract.address);
    });

    it("Should deploy V3Helper", async function () {
        const Contract = await ethers.getContractFactory("V3Helper");
        contractHelper = await Contract.deploy();
        await contractHelper.deployed();
    });

    const wethInputR = "9484856548040530";
    const usdcInputR = "628710074";
    const osqthInputR = "687672060565542821";
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

        const wethInput = "18410690015258689749";
        const usdcInput = "32743712092";
        const osqthInput = "32849750909396941650";

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

        expect(await getERC20Balance(rebalancer.address, wethAddress)).to.equal("0");
        expect(await getERC20Balance(rebalancer.address, usdcAddress)).to.equal("1257420148");
        expect(await getERC20Balance(rebalancer.address, osqthAddress)).to.equal("0");

        // const amount = await contract._getTotalAmounts();
        // console.log(">>", amount);
    });

    // it("_position", async function () {
    //     // console.log(await contract.orderEthUsdcLower());
    //     // console.log(await contract.orderEthUsdcUpper());
    //     // console.log(await contract.orderOsqthEthLower());
    //     // console.log(await contract.orderOsqthEthUpper());
    //     amount = await contract._position(
    //         poolEthOsqth,
    //         "12180",
    //         "14280"
    //     );
    //     console.log(amount);

    //     amount = await contract._position(
    //         poolEthUsdc,
    //         "193800",
    //         "195900",
    //     );
    //     console.log(amount);

    //     // assert(amount[0].toString() == "0", `test_sute: sub 1`);
    //     // assert(amount[1].toString() == "0", `test_sute: sub 2`);
    //     // assert(amount[2].toString() == "0", `test_sute: sub 3`);
    //     // assert(amount[3].toString() == "0", `test_sute: sub 4`);
    // });

    // it("_amountsForLiquidity", async function () {
    //     amount = await contract._amountsForLiquidity(
    //         poolEthUsdc,
    //         "193800",
    //         "195900",
    //         "36578863"
    //     );
    //     console.log(amount);

    //     amount = await contract._amountsForLiquidity(
    //         poolEthOsqth,
    //         "12180",
    //         "14280",
    //         "340709549703421612825"
    //     );
    //     console.log(amount);
    //     // assert(amount[0].toString() == "0", `test_sute: sub 1`);
    //     // assert(amount[1].toString() == "0", `test_sute: sub 2`);
    //     // assert(amount[2].toString() == "0", `test_sute: sub 3`);
    //     // assert(amount[3].toString() == "0", `test_sute: sub 4`);
    // });

});