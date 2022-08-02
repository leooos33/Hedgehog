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

describe("Test with real mainnet contracts", function () {
    let governance;
    it("Should set actors", async function () {
        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: ["0x42B1299fCcA091A83C08C24915Be6E6d63906b1a"],
        });

        governance = await ethers.getSigner("0x42B1299fCcA091A83C08C24915Be6E6d63906b1a");
        console.log("governance:", governance.address);

        await resetFork(15262729);
    });

    it("check update", async function () {
        // const rebalancer = ethers.getContractAt(ownable, "0xD3ed5915AAA27dB7a3646bf926dB6C98243d5c40");

        const MyContract = await ethers.getContractFactory("Rebalancer");
        const rebalancer = await MyContract.attach("0xD3ed5915AAA27dB7a3646bf926dB6C98243d5c40");

        console.log("owner:", await rebalancer.owner());
        // console.log("addressAuction:", await rebalancer.addressAuction());

        const tx = await rebalancer
            .connect(governance)
            .setContracts("0xA9a68eA2746793F43af0f827EC3DbBb049359067", "0xfbcf638ea33a5f87d1e39509e7def653958fa9c4");
        let receipt = await tx.wait();
        console.log("> Gas used:", receipt.gasUsed.toString());

        // const arbTx = await rebalancer.rebalance(0);
        // await arbTx.wait();
    });
});
