const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { utils } = ethers;
const {
    wethAddress,
    osqthAddress,
    usdcAddress,
    _biggestOSqthHolder,
    _vaultAuctionAddressHardhat,
    _vaultMathAddressHardhat,
} = require("./common");
const { mineSomeBlocks, resetFork, getERC20Balance, getUSDC, getOSQTH, getWETH } = require("./helpers");

describe.only("Rebalance test mainnet", function () {
    let tx, receipt, Rebalancer;
    let actor;
    let actorAddress = "0x42b1299fcca091a83c08c24915be6e6d63906b1a";

    it("Should deploy contract", async function () {
        await resetFork(15373161);

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [actorAddress],
        });

        actor = await ethers.getSigner(actorAddress);
        console.log("actor:", actor.address);

        MyContract = await ethers.getContractFactory("BigRebalancer");
        Rebalancer = await MyContract.attach("0x412afcc7a3ee9589bdc883cb8f2dee7e41cf0b14");
        console.log("Owner:", await Rebalancer.owner());
    });

    it("rebalance with flash loan", async function () {
        await getWETH("1000", Rebalancer.address);
        await getUSDC("1000", Rebalancer.address, "0x94c96dfe7d81628446bebf068461b4f728ed8670");
        await getOSQTH("1000", Rebalancer.address, "0xf9f613bdec2703ede176cc98a2276fa1f618a1b1");

        console.log("> Rebalancer WETH %s", await getERC20Balance(Rebalancer.address, wethAddress));
        console.log("> Rebalancer USDC %s", await getERC20Balance(Rebalancer.address, usdcAddress));
        console.log("> Rebalancer oSQTH %s", await getERC20Balance(Rebalancer.address, osqthAddress));

        // return;
        console.log("> actor WETH %s", await getERC20Balance(actor.address, wethAddress));
        console.log("> actor USDC %s", await getERC20Balance(actor.address, usdcAddress));
        console.log("> actor oSQTH %s", await getERC20Balance(actor.address, osqthAddress));

        const arbTx = await Rebalancer.connect(actor).rebalance(0, {
            gasLimit: 3000000,
            // gas: 1800000,
            gasPrice: 23000000000,
        });
        receipt = await arbTx.wait();
        console.log("> Gas used rebalance + fl: %s", receipt.gasUsed);

        console.log("> Rebalancer WETH %s", await getERC20Balance(Rebalancer.address, wethAddress));
        console.log("> Rebalancer USDC %s", await getERC20Balance(Rebalancer.address, usdcAddress));
        console.log("> Rebalancer oSQTH %s", await getERC20Balance(Rebalancer.address, osqthAddress));

        console.log("> actor WETH %s", await getERC20Balance(actor.address, wethAddress));
        console.log("> actor USDC %s", await getERC20Balance(actor.address, usdcAddress));
        console.log("> actor oSQTH %s", await getERC20Balance(actor.address, osqthAddress));
    });
});
