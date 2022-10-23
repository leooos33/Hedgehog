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

describe.only("Cheap Rebalancer test mainnet", function () {
    it("Phase 1", async function () {
        await resetFork(15810319);

        MyContract = await ethers.getContractFactory("VaultStorage");
        VaultStorage = await MyContract.attach(_vaultStorageAddressV2);

        MyContract = await ethers.getContractFactory("BigRebalancer");
        Rebalancer = await MyContract.attach(_bigRebalancerV2);

        MyContract = await ethers.getContractFactory("CheapRebalancer");
        CheapRebalancer = await MyContract.attach(_cheapRebalancerV2);

        //? All ownership is already transferred

        // console.log("Rebalancer.owner:", await Rebalancer.owner());
        // console.log("VaultStorage.governance:", await VaultStorage.governance());

        // await hre.network.provider.request({
        //     method: "hardhat_impersonateAccount",
        //     params: [_governanceAddressV2],
        // });

        // governanceActor = await ethers.getSigner(_governanceAddressV2);
        // await getETH(governanceActor.address, ethers.utils.parseEther("2.0"));

        // tx = await VaultStorage.connect(governanceActor).setGovernance(CheapRebalancer.address);
        // await tx.wait();

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [_hedgehogRebalancerDeployerV2],
        });

        hedgehogRebalancerActor = await ethers.getSigner(_hedgehogRebalancerDeployerV2);
        await getETH(hedgehogRebalancerActor.address, ethers.utils.parseEther("2.0"));

        // tx = await Rebalancer.connect(hedgehogRebalancerActor).transferOwnership(CheapRebalancer.address);
        // await tx.wait();

        console.log("Rebalancer.owner:", await Rebalancer.owner());
        console.log("VaultStorage.governance:", await VaultStorage.governance());
    });

    it("Phase 2", async function () {
        // tx = await CheapRebalancer.connect(hedgehogRebalancerActor).returnGovernance(hedgehogRebalancerActor.address);
        // await tx.wait();

        // tx = await VaultStorage.connect(hedgehogRebalancerActor).setRebalanceTimeThreshold(604800);
        // await tx.wait();

        // tx = await VaultStorage.connect(hedgehogRebalancerActor).setGovernance(CheapRebalancer.address);
        // await tx.wait();

        // await getWETH("1000000000000000000", _bigRebalancerV2);
        // await getUSDC("1000000000000", _bigRebalancerV2);
        // await getOSQTH("1000000000000000000", _bigRebalancerV2, "0x8d5acf995dae10bdbbada2044c7217ac99edf5bf");

        await logBalance(_vaultTreasuryAddressV2, "Treasury before");
        await logBalance(Rebalancer.address, "Rebalancer before");

        tx = await CheapRebalancer.connect(hedgehogRebalancerActor).rebalance("0", "996500000000000000");
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
        await logBalance(Rebalancer.address, "Rebalancer after");
    });

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
