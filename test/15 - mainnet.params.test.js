const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
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
const { _governanceAddress, _rebalancerAddressOld, _vaultAuctionAddress, _vaultMathAddress } = require("./common");

const ownable = require("./helpers/abi/ownable");

describe.skip("Test with real mainnet contracts", function () {
    let governance;
    it("Should set actors", async function () {
        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [_governanceAddress],
        });

        governance = await ethers.getSigner(_governanceAddress);
        console.log("governance:", governance.address);

        await resetFork(15262729);
    });

    it("check update", async function () {
        // const rebalancer = ethers.getContractAt(ownable, _rebalancerAddressOld");

        const MyContract = await ethers.getContractFactory("Rebalancer");
        const rebalancer = await MyContract.attach(_rebalancerAddressOld);

        console.log("owner:", await rebalancer.owner());
        // console.log("addressAuction:", await rebalancer.addressAuction());

        const tx = await rebalancer.connect(governance).setContracts(_vaultAuctionAddress, _vaultMathAddress);
        let receipt = await tx.wait();
        console.log("> Gas used:", receipt.gasUsed.toString());

        // const arbTx = await rebalancer.rebalance(0);
        // await arbTx.wait();
    });
});
