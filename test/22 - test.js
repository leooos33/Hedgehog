const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { utils } = ethers;
const {
    wethAddress,
    osqthAddress,
    usdcAddress,
    _governanceAddress,
    _vaultAuctionAddressV2,
    _vaultMathAddressV2,
    _vaultStorageAddressV2,
    _governanceAddressV2,
    _bigRebalancerV2,
    _hedgehogRebalancerDeployerV2,
} = require("./common");
const {
    mineSomeBlocks,
    resetFork,
    getERC20Balance,
    getUSDC,
    getOSQTH,
    getWETH,
    logBlock,
    getERC20Allowance,
    approveERC20,
    logBalance,
    getETH,
} = require("./helpers");

describe.only("-", function () {
    let tx, receipt, Rebalancer, MyContract;

    it("Should deploy contract", async function () {
        await resetFork(15665637);

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [_governanceAddressV2],
        });

        governance = await ethers.getSigner(_governanceAddressV2);

        await getETH(governance.address, ethers.utils.parseEther("1.0"));

        MyContract = await ethers.getContractFactory("VaultAuction");
        VaultAuction = await MyContract.attach(_vaultAuctionAddressV2);

        MyContract = await ethers.getContractFactory("VaultStorage");
        VaultStorage = await MyContract.attach(_vaultStorageAddressV2);

        MyContract = await ethers.getContractFactory("VaultMath");
        VaultMath = await MyContract.attach(_vaultMathAddressV2);

        //----- choose rebalancer -----

        // MyContract = await ethers.getContractFactory("BigRebalancer");
        // Rebalancer = await MyContract.attach(_bigRebalancerV2);
    });

    it("mine some blocks", async function () {
        this.skip();
        await mineSomeBlocks(1);

        console.log(await VaultMath.isTimeRebalance());
    });

    it("getParams", async function () {
        // this.skip();
        console.log(await logBlock());
        console.log("isTimeRebalance: %s", await VaultMath.isTimeRebalance());
        console.log("PriceMultiplier %s", await VaultMath.getPriceMultiplier(1660598164));
        console.log(await VaultAuction.getParams(1660598164));

        tx = await VaultStorage.connect(governance).setRebalanceTimeThreshold(172800);
        await tx.wait();
        await mineSomeBlocks(112670+300);

        console.log(await logBlock());
        console.log("isTimeRebalance: %s", await VaultMath.isTimeRebalance());
        console.log("PriceMultiplier %s", await VaultMath.getPriceMultiplier(1664888763));
        console.log(await VaultAuction.getParams(1664888763));

    });
});
