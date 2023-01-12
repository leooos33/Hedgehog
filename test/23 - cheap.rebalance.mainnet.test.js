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

describe.skip("Cheap Rebalancer test mainnet", function () {
    it("Phase 0", async function () {
        await resetFork(16354557);

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [_hedgehogRebalancerDeployerV2],
        });

        hedgehogRebalancerActor = await ethers.getSigner(_hedgehogRebalancerDeployerV2);
        await getETH(hedgehogRebalancerActor.address, ethers.utils.parseEther("3.0"));
    });
    it("Phase 1 A", async function () {
        // this.skip();
        MyContract = await ethers.getContractFactory("VaultStorage");
        VaultStorage = await MyContract.attach(_vaultStorageAddressV2);

        MyContract = await ethers.getContractFactory("BigRebalancer");
        RebalanceModule = await MyContract.attach(_rebalanceModuleV2);

        MyContract = await ethers.getContractFactory("CheapRebalancer");
        CheapRebalancer = await MyContract.attach(_cheapRebalancerV2);

        console.log("RebalanceModule.owner:", (await RebalanceModule.owner()) == _cheapRebalancerV2);
        console.log("CheapRebalancer.owner:", (await CheapRebalancer.owner()) == hedgehogRebalancerActor.address);
        console.log("VaultStorage.governance:", (await VaultStorage.governance()) == _cheapRebalancerV2);
        console.log("VaultStorage.keeper:", (await VaultStorage.keeper()) == _rebalanceModuleV2);
    });

    it("Phase 1 B", async function () {
        this.skip();
        MyContract = await ethers.getContractFactory("VaultStorage");
        VaultStorage = await MyContract.attach(_vaultStorageAddressV2);

        CheapRebalancer = await deployContract("CheapRebalancer", [], false);
        tx = await CheapRebalancer.transferOwnership(hedgehogRebalancerActor.address);
        await tx.wait();

        RebalanceModule = await deployContract("Rebalancer", [], false);
        tx = await RebalanceModule.transferOwnership(hedgehogRebalancerActor.address);
        await tx.wait();

        //?

        MyContract = await ethers.getContractFactory("BigRebalancer");
        m_RebalanceModule = await MyContract.attach(_rebalanceModuleV2);

        MyContract = await ethers.getContractFactory("CheapRebalancer");
        m_CheapRebalancer = await MyContract.attach(_cheapRebalancerV2);

        tx = await m_CheapRebalancer.connect(hedgehogRebalancerActor).returnOwner(hedgehogRebalancerActor.address);
        await tx.wait();

        tx = await m_CheapRebalancer.connect(hedgehogRebalancerActor).returnGovernance(hedgehogRebalancerActor.address);
        await tx.wait();

        tx = await m_RebalanceModule.connect(hedgehogRebalancerActor).setKeeper(hedgehogRebalancerActor.address);
        await tx.wait();

        //?

        tx = await VaultStorage.connect(hedgehogRebalancerActor).setGovernance(CheapRebalancer.address);
        await tx.wait();

        tx = await VaultStorage.connect(hedgehogRebalancerActor).setKeeper(RebalanceModule.address);
        await tx.wait();

        tx = await RebalanceModule.connect(hedgehogRebalancerActor).transferOwnership(CheapRebalancer.address);
        await tx.wait();

        console.log("RebalanceModule.owner:", (await RebalanceModule.owner()) == CheapRebalancer.address);
        console.log("CheapRebalancer.owner:", (await CheapRebalancer.owner()) == hedgehogRebalancerActor.address);
        console.log("VaultStorage.governance:", (await VaultStorage.governance()) == CheapRebalancer.address);
        console.log("VaultStorage.keeper:", (await VaultStorage.keeper()) == RebalanceModule.address);
        console.log(await VaultStorage.keeper());
        console.log(RebalanceModule.address);
    });

    it("Phase 2", async function () {
        await logBalance(_vaultTreasuryAddressV2, "Treasury before");
        await logBalance(RebalanceModule.address, "RebalanceModule before");
        await logBalance(hedgehogRebalancerActor.address, "hedgehogRebalancerActor.address before");

        tx = await CheapRebalancer.connect(hedgehogRebalancerActor).rebalance("0", "950000000000000000");
        recipt = await tx.wait();
        console.log("Gas used", recipt.gasUsed.toString());

        // tx = await CheapRebalancer.connect(hedgehogRebalancerActor).collectProtocol(
        //     "98636306506939157",
        //     0,
        //     0,
        //     _vaultTreasuryAddressV2
        // );
        // await tx.wait();

        await logBalance(_vaultTreasuryAddressV2, "Treasury after");
        await logBalance(RebalanceModule.address, "RebalanceModule after");
    });

    return;
    it("Phase 3", async function () {
        this.skip();
        tx = await CheapRebalancer.connect(hedgehogRebalancerActor).returnOwner(_hedgehogRebalancerDeployerV2);
        await tx.wait();

        tx = await CheapRebalancer.connect(hedgehogRebalancerActor).returnGovernance(_governanceAddressV2);
        await tx.wait();

        console.log("Rebalancer.owner:", await Rebalancer.owner());
        console.log("VaultStorage.governance:", await VaultStorage.governance());
    });
});
