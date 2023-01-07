const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { utils } = ethers;
const {
    _rescueAddress,
    _rebalancerAddress,
    _rebalancerBigAddress,
    _governanceAddress,
    _vaultAuctionAddressV2,
    _vaultMathAddressV2,
    _vaultStorageAddressV2,
    _governanceAddressV2,
    _rebalanceModuleV2,
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
const { deployContract } = require("./deploy");

describe.only("Cheap Rebalancer test mainnet", function () {
    it("Phase 0", async function () {
        await resetFork(16354557);

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [_hedgehogRebalancerDeployerV2],
        });

        hedgehogRebalancerActor = await ethers.getSigner(_hedgehogRebalancerDeployerV2);

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [_governanceAddress],
        });
        hhv1Governance = await ethers.getSigner(_governanceAddress);
        await getETH(hedgehogRebalancerActor.address, ethers.utils.parseEther("3.0"));
        await getETH(hhv1Governance.address, ethers.utils.parseEther("3.0"));
    });
    it("Deploy and setup", async function () {
        MyContract = await ethers.getContractFactory("VaultStorage");
        VaultStorage = await MyContract.attach(_vaultStorageAddressV2);

        MyContract = await ethers.getContractFactory("Rebalancer");
        RebalanceModuleV1 = await MyContract.attach(_rebalancerBigAddress);

        // MyContract = await ethers.getContractFactory("Rebalancer");
        // RebalanceModuleV1 = await MyContract.attach(_rebalancerAddress);

        MyContract = await ethers.getContractFactory("BigRebalancer");
        RebalanceModuleV2 = await MyContract.attach(_rebalanceModuleV2);

        MyContract = await ethers.getContractFactory("CheapRebalancer");
        CheapRebalancer = await MyContract.attach(_cheapRebalancerV2);

        MyContract = await ethers.getContractFactory("RescueTeam");
        Rescue = await MyContract.attach(_rescueAddress);

        //? Deploy

        CheapRebalancerUpdatable = await deployContract("CheapRebalancerUpdatable", [], false);
        tx = await CheapRebalancerUpdatable.transferOwnership(hedgehogRebalancerActor.address);
        await tx.wait();

        //? Configure

        tx = await CheapRebalancerUpdatable.connect(hedgehogRebalancerActor).addModule(RebalanceModuleV1.address);
        await tx.wait();

        tx = await CheapRebalancerUpdatable.connect(hedgehogRebalancerActor).addModule(RebalanceModuleV2.address);
        await tx.wait();

        tx = await CheapRebalancer.connect(hedgehogRebalancerActor).returnOwner(hedgehogRebalancerActor.address);
        await tx.wait();

        // console.log(await Rescue.owner());
        // console.log(hhv1Governance.address);
        // console.log(await RebalanceModuleV1.owner());
        // console.log(await RebalanceModuleV0.owner());
        // tx = await Rescue.connect(hhv1Governance).returnGovernance();
        // await tx.wait();

        tx = await RebalanceModuleV1.connect(hhv1Governance).transferOwnership(CheapRebalancerUpdatable.address);
        await tx.wait();

        tx = await RebalanceModuleV2.connect(hedgehogRebalancerActor).setKeeper(CheapRebalancerUpdatable.address);
        await tx.wait();

        tx = await RebalanceModuleV2.connect(hedgehogRebalancerActor).transferOwnership(
            CheapRebalancerUpdatable.address
        );
        await tx.wait();

        tx = await CheapRebalancer.connect(hedgehogRebalancerActor).returnGovernance(CheapRebalancerUpdatable.address);
        await tx.wait();

        // //? Check

        console.log(
            "CheapRebalancerUpdatable.owner:",
            (await CheapRebalancerUpdatable.owner()) == hedgehogRebalancerActor.address
        );
        console.log("RebalanceModuleV1.owner:", (await RebalanceModuleV1.owner()) == CheapRebalancerUpdatable.address);
        console.log("RebalanceModuleV2.owner:", (await RebalanceModuleV2.owner()) == CheapRebalancerUpdatable.address);
        console.log("VaultStorage.governance:", (await VaultStorage.governance()) == CheapRebalancerUpdatable.address);
        console.log("VaultStorage.keeper:", (await VaultStorage.keeper()) == CheapRebalancerUpdatable.address);
    });

    it("Phase Do rebalance", async function () {
        await logBalance(_vaultTreasuryAddressV2, "Treasury before");
        await logBalance(RebalanceModuleV1.address, "RebalanceModuleV1 before");
        await logBalance(hedgehogRebalancerActor.address, "hedgehogRebalancerActor.address before");

        tx = await CheapRebalancerUpdatable.connect(hedgehogRebalancerActor).rebalanceInstant(
            "2",
            "0",
            "950000000000000000",
            "604800"
        );
        recipt = await tx.wait();
        console.log("Gas used", recipt.gasUsed.toString());

        await logBalance(_vaultTreasuryAddressV2, "Treasury after");
        await logBalance(RebalanceModuleV1.address, "RebalanceModuleV1 after");
    });

    return;
    it("Check transfers", async function () {
        this.skip();
        tx = await CheapRebalancer.connect(hedgehogRebalancerActor).returnOwner(_hedgehogRebalancerDeployerV2);
        await tx.wait();

        tx = await CheapRebalancer.connect(hedgehogRebalancerActor).returnGovernance(_governanceAddressV2);
        await tx.wait();

        console.log("Rebalancer.owner:", await Rebalancer.owner());
        console.log("VaultStorage.governance:", await VaultStorage.governance());
    });
});
