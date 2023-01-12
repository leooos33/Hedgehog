const { ethers } = require("hardhat");
const {
    _rebalanceModuleV2,
    _bigRebalancerEuler,
    _hedgehogRebalancerDeployerV2,
    _vaultTreasuryAddressV2,
    _cheapRebalancerV2,
} = require("./common");
const { resetFork, logBalance, getETH } = require("./helpers");

describe.only("Rebalancer mainnet test", function () {
    it("Phase 0", async function () {
        await resetFork(16390400);

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [_hedgehogRebalancerDeployerV2],
        });

        hedgehogRebalancerActor = await ethers.getSigner(_hedgehogRebalancerDeployerV2);

        await getETH(hedgehogRebalancerActor.address, ethers.utils.parseEther("3.0"));

        MyContract = await ethers.getContractFactory("CheapRebalancer");
        CheapRebalancer = await MyContract.attach(_cheapRebalancerV2);

        MyContract = await ethers.getContractFactory("BigRebalancer");
        BigRebalancer = await MyContract.attach(_rebalanceModuleV2);

        MyContract = await ethers.getContractFactory("BigRebalancerEuler");
        BigRebalancerEuler = await MyContract.attach(_bigRebalancerEuler);
    });

    // const mul = "1100000000000000000";
    // const mul = "1000000000000000000";
    // const mul = "999900000000000000";
    // const mul = "999600000000000000";
    // const mul = "999000000000000000";
    // const mul = "998500000000000000";
    const mul = "998000000000000000";
    // const mul = "997500000000000000";
    // const mul = "997000000000000000";
    // const mul = "995000000000000000";
    // const mul = "990000000000000000";
    // const mul = "950000000000000000";

    it("Rebalance current", async function () {
        this.skip();
        await logBalance(_vaultTreasuryAddressV2, "Treasury before");
        await logBalance(BigRebalancerEuler.address, "BigRebalancerEuler before");

        tx = await CheapRebalancer.connect(hedgehogRebalancerActor).rebalance("0", mul);
        recipt = await tx.wait();
        console.log("Gas used", recipt.gasUsed.toString());

        await logBalance(_vaultTreasuryAddressV2, "Treasury after");
        await logBalance(BigRebalancerEuler.address, "BigRebalancerEuler after");
    });

    it("Change & run", async function () {
        // this.skip();

        tx = await BigRebalancer.connect(hedgehogRebalancerActor).transferOwnership(CheapRebalancer.address);
        await tx.wait();

        tx = await CheapRebalancer.connect(hedgehogRebalancerActor).returnOwner(hedgehogRebalancerActor.address);
        await tx.wait();

        tx = await BigRebalancerEuler.connect(hedgehogRebalancerActor).setKeeper(BigRebalancer.address);
        await tx.wait();

        tx = await CheapRebalancer.connect(hedgehogRebalancerActor).setContracts(BigRebalancer.address);
        await tx.wait();

        await logBalance(_vaultTreasuryAddressV2, "Treasury before");
        await logBalance(BigRebalancer.address, "BigRebalancer before");

        tx = await CheapRebalancer.connect(hedgehogRebalancerActor).rebalance("0", mul);
        recipt = await tx.wait();
        console.log("Gas used", recipt.gasUsed.toString());

        await logBalance(_vaultTreasuryAddressV2, "Treasury after");
        await logBalance(BigRebalancer.address, "BigRebalancer after");
    });

    it("Change & run 2", async function () {
        this.skip();

        //TODO: check it

        tx = await BigRebalancerEuler.connect(hedgehogRebalancerActor).transferOwnership(CheapRebalancer.address);
        await tx.wait();

        tx = await CheapRebalancer.connect(hedgehogRebalancerActor).returnOwner(hedgehogRebalancerActor.address);
        await tx.wait();

        tx = await BigRebalancer.connect(hedgehogRebalancerActor).setKeeper(BigRebalancerEuler.address);
        await tx.wait();

        tx = await CheapRebalancer.connect(hedgehogRebalancerActor).setContracts(BigRebalancerEuler.address);
        await tx.wait();

        await logBalance(_vaultTreasuryAddressV2, "Treasury before");
        await logBalance(BigRebalancerEuler.address, "BigRebalancerEuler before");

        tx = await CheapRebalancer.connect(hedgehogRebalancerActor).rebalance("0", mul);
        recipt = await tx.wait();
        console.log("Gas used", recipt.gasUsed.toString());

        await logBalance(_vaultTreasuryAddressV2, "Treasury after");
        await logBalance(BigRebalancerEuler.address, "BigRebalancerEuler after");
    });
});
