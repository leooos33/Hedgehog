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

describe.only("Cheap Rebalancer test mainnet", function () {
    it("Phase 1", async function () {
        await resetFork(15654730 - 1);

        MyContract = await ethers.getContractFactory("VaultStorage");
        VaultStorage = await MyContract.attach(_vaultStorageAddressV2);

        MyContract = await ethers.getContractFactory("BigRebalancer");
        Rebalancer = await MyContract.attach(_bigRebalancerV2);

        MyContract = await ethers.getContractFactory("CheapRebalancer");
        CheapRebalancer = await MyContract.deploy();
        await CheapRebalancer.deployed();

        console.log("Rebalancer.owner:", await Rebalancer.owner());
        console.log("VaultStorage.governance:", await VaultStorage.governance());

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [_governanceAddressV2],
        });

        governanceActor = await ethers.getSigner(_governanceAddressV2);
        await getETH(governanceActor.address, ethers.utils.parseEther("1.0"));

        tx = await VaultStorage.connect(governanceActor).setGovernance(CheapRebalancer.address);
        await tx.wait();

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [_hedgehogRebalancerDeployerV2],
        });

        hedgehogRebalancerActor = await ethers.getSigner(_hedgehogRebalancerDeployerV2);
        await getETH(hedgehogRebalancerActor.address, ethers.utils.parseEther("1.0"));

        tx = await Rebalancer.connect(hedgehogRebalancerActor).transferOwnership(CheapRebalancer.address);
        await tx.wait();

        console.log("Rebalancer.owner:", await Rebalancer.owner());
        console.log("VaultStorage.governance:", await VaultStorage.governance());
    });

    it("Phase 2", async function () {
        tx = await CheapRebalancer.rebalance(100, 0);
        await tx.wait();
    });

    it("Phase 3", async function () {
        tx = await CheapRebalancer.returnOwner(_hedgehogRebalancerDeployerV2);
        await tx.wait();

        tx = await CheapRebalancer.returnGovernance(_governanceAddressV2);
        await tx.wait();

        console.log("Rebalancer.owner:", await Rebalancer.owner());
        console.log("VaultStorage.governance:", await VaultStorage.governance());
    });
});
