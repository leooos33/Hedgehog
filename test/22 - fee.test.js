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

describe.only("Fee test", function () {
    let tx, receipt, Rebalancer, MyContract;

    it("Should deploy contract", async function () {
        await resetFork(15683124);

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [_governanceAddressV2],
        });

        governance = await ethers.getSigner(_governanceAddressV2);

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [_hedgehogRebalancerDeployerV2],
        });

        hedgehogRebalancerDeployerV2 = await ethers.getSigner(_hedgehogRebalancerDeployerV2);

        MyContract = await ethers.getContractFactory("VaultAuction");
        VaultAuction = await MyContract.attach(_vaultAuctionAddressV2);

        MyContract = await ethers.getContractFactory("VaultStorage");
        VaultStorage = await MyContract.attach(_vaultStorageAddressV2);

        MyContract = await ethers.getContractFactory("VaultMath");
        VaultMath = await MyContract.attach(_vaultMathAddressV2);

        MyContract = await ethers.getContractFactory("BigRebalancer");
        Rebalancer = await MyContract.attach(_bigRebalancerV2);
    });

    it("mine some blocks", async function () {
        // this.skip();
        await mineSomeBlocks(1);

        console.log(await VaultMath.isTimeRebalance());
    });

    it("getParams", async function () {
        // this.skip();

        await getETH(hedgehogRebalancerDeployerV2.address, ethers.utils.parseEther("2.0"));
        await getETH(governance.address, ethers.utils.parseEther("1.0"));

        tx = await Rebalancer.connect(hedgehogRebalancerDeployerV2).setKeeper(governance.address);
        await tx.wait();

        // tx = await VaultStorage.connect(governance).setRebalanceTimeThreshold(1);
        // await tx.wait();

        console.log(await logBlock());
        let _isTimeRebalance = await VaultMath.isTimeRebalance();
        console.log("isTimeRebalance: %s", _isTimeRebalance);
        console.log("PriceMultiplier %s", await VaultMath.getPriceMultiplier(_isTimeRebalance[1]));
        console.log("getParams:", await VaultAuction.getParams(_isTimeRebalance[1]));

        // await mineSomeBlocks(112670 + 300);
    });
});
