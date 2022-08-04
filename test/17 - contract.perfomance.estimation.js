const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { utils } = ethers;
const { wethAddress, osqthAddress, usdcAddress } = require("./common");
const {
    mineSomeBlocks,
    resetFork,
    logBlock,
    getAndApprove2,
    getERC20Balance,
    getWETH,
    getOSQTH,
    getUSDC,
} = require("./helpers");
const { hardhatInitializeDeploed } = require("./deploy");
const { BigNumber } = require("ethers");

const ownable = require("./helpers/abi/ownable");

describe.only("Mainnet Infrustructure Test", function () {
    it("1 test", async function () {
        await resetFork(15278550);

        let MyContract = await ethers.getContractFactory("Rebalancer");
        const rebalancer = await MyContract.attach("0x09b1937D89646b7745377f0fcc8604c179c06aF5");

        console.log("> userEth %s", await getERC20Balance(rebalancer.address, wethAddress));
        console.log("> userUsdc %s", await getERC20Balance(rebalancer.address, usdcAddress));
        console.log("> userOsqth %s", await getERC20Balance(rebalancer.address, osqthAddress));

        await resetFork(15278554);

        console.log("> userEth %s", await getERC20Balance(rebalancer.address, wethAddress));
        console.log("> userUsdc %s", await getERC20Balance(rebalancer.address, usdcAddress));
        console.log("> userOsqth %s", await getERC20Balance(rebalancer.address, osqthAddress));

        console.log(0.000023504084671461 * 1600);
    });
});
