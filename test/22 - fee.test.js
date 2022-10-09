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
    _vaultTreasuryAddressV2,
    _cheapRebalancerV2,
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
        await resetFork(15708864);

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

        MyContract = await ethers.getContractFactory("CheapRebalancer");
        CheapRebalancer = await MyContract.attach(_cheapRebalancerV2);

        await getETH(hedgehogRebalancerDeployerV2.address, ethers.utils.parseEther("2.0"));

        tx = await CheapRebalancer.connect(hedgehogRebalancerDeployerV2).returnGovernance(governance.address);
        await tx.wait();

        tx = await CheapRebalancer.connect(hedgehogRebalancerDeployerV2).returnOwner(
            hedgehogRebalancerDeployerV2.address
        );
        await tx.wait();

        MyContract = await ethers.getContractFactory("VaultAuction");
        VaultAuction = await MyContract.attach(_vaultAuctionAddressV2);

        MyContract = await ethers.getContractFactory("VaultStorage");
        VaultStorage = await MyContract.attach(_vaultStorageAddressV2);

        MyContract = await ethers.getContractFactory("VaultMath");
        VaultMath = await MyContract.attach(_vaultMathAddressV2);

        MyContract = await ethers.getContractFactory("BigRebalancer");
        Rebalancer = await MyContract.attach(_bigRebalancerV2);

        MyContract = await ethers.getContractFactory("VaultTreasury");
        Treasury = await MyContract.attach(_vaultTreasuryAddressV2);
    });

    it("getParams", async function () {
        // this.skip();

        await getETH(hedgehogRebalancerDeployerV2.address, ethers.utils.parseEther("2.0"));
        await getETH(governance.address, ethers.utils.parseEther("2.0"));

        tx = await Rebalancer.connect(hedgehogRebalancerDeployerV2).setKeeper(governance.address);
        await tx.wait();

        const amounts0 = await VaultMath.getTotalAmounts();

        tx = await Treasury.connect(governance).externalPoke();
        await tx.wait();

        const amounts1 = await VaultMath.getTotalAmounts();

        const ethDiff = (amounts1[0] - amounts0[0]).toString();
        const usdcDiff = (amounts1[1] - amounts0[1]).toString();
        const osqthDiff = (amounts1[2] - amounts0[2]).toString();

        const prices = await VaultMath.getPrices();
        const feeValue = await VaultMath.getValue(ethDiff, usdcDiff, osqthDiff, prices[0], prices[1]);
        console.log("accrude fee in USD %s", (feeValue * prices[0]) / 1e36);
    });
});
