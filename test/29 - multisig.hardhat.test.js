const { ethers } = require("hardhat");
const {
    _rebalanceModuleV2,
    _bigRebalancerEuler2,
    _bigRebalancerEuler,
    _hedgehogRebalancerDeployerV2,
    _vaultTreasuryAddressV2,
    _cheapRebalancerV2,
    _vaultStorageAddressV2,
} = require("./common");
const { resetFork, logBalance, getETH } = require("./helpers");
const { deployContract } = require("./deploy");

describe.only("Multisig hardhat test", function () {
    it("Phase 0", async function () {
        await resetFork(16434909);

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [_hedgehogRebalancerDeployerV2],
        });

        hedgehogRebalancerActor = await ethers.getSigner(_hedgehogRebalancerDeployerV2);

        const signers = await ethers.getSigners();
        owner1 = signers[2];
        owner2 = signers[3];
        owner3 = signers[4];

        await getETH(hedgehogRebalancerActor.address, ethers.utils.parseEther("3.0"));

        MyContract = await ethers.getContractFactory("CheapRebalancer");
        CheapRebalancer = await MyContract.attach(_cheapRebalancerV2);

        MyContract = await ethers.getContractFactory("BigRebalancer");
        BigRebalancer = await MyContract.attach(_rebalanceModuleV2);

        MyContract = await ethers.getContractFactory("BigRebalancerEuler");
        BigRebalancerEuler = await MyContract.attach(_bigRebalancerEuler);

        MyContract = await ethers.getContractFactory("BigRebalancerEuler");
        BigRebalancerEuler2 = await MyContract.attach(_bigRebalancerEuler2);

        MyContract = await ethers.getContractFactory("VaultStorage");
        VaultStorage = await MyContract.attach(_vaultStorageAddressV2);

        MultisigWallet = await deployContract(
            "MultiSigWallet",
            [[owner1.address, owner2.address, owner3.address]],
            false
        );
    });

    return;
    it("Change 1", async function () {
        this.skip();

        tx = await BigRebalancer.connect(hedgehogRebalancerActor).transferOwnership(CheapRebalancer.address);
        await tx.wait();

        tx = await CheapRebalancer.connect(hedgehogRebalancerActor).returnOwner(hedgehogRebalancerActor.address);
        await tx.wait();

        tx = await BigRebalancerEuler.connect(hedgehogRebalancerActor).setKeeper(BigRebalancer.address);
        await tx.wait();

        tx = await CheapRebalancer.connect(hedgehogRebalancerActor).setContracts(BigRebalancer.address);
        await tx.wait();
    });

    it("Change 2", async function () {
        this.skip();

        tx = await CheapRebalancer.connect(hedgehogRebalancerActor).returnOwner(hedgehogRebalancerActor.address);
        await tx.wait();

        tx = await BigRebalancer.connect(hedgehogRebalancerActor).setKeeper(BigRebalancerEuler.address);
        await tx.wait();

        tx = await CheapRebalancer.connect(hedgehogRebalancerActor).setContracts(BigRebalancerEuler.address);
        await tx.wait();

        tx = await BigRebalancerEuler.connect(hedgehogRebalancerActor).transferOwnership(CheapRebalancer.address);
        await tx.wait();
    });

    it("Change 3", async function () {
        this.skip();

        console.log(await CheapRebalancer.owner());
        tx = await CheapRebalancer.connect(hedgehogRebalancerActor).returnOwner(hedgehogRebalancerActor.address);
        await tx.wait();

        tx = await BigRebalancer.connect(hedgehogRebalancerActor).setKeeper(BigRebalancerEuler2.address);
        await tx.wait();

        tx = await CheapRebalancer.connect(hedgehogRebalancerActor).setContracts(BigRebalancerEuler2.address);
        await tx.wait();

        tx = await BigRebalancerEuler2.connect(hedgehogRebalancerActor).transferOwnership(CheapRebalancer.address);
        await tx.wait();
    });

    it("Rebalance current", async function () {
        const _keeper = await VaultStorage.keeper();
        const _module = await CheapRebalancer.bigRebalancer();
        if (_keeper == BigRebalancerEuler.address && _module == BigRebalancerEuler.address) {
            console.log("> BigRebalancerEuler");
        } else if (_keeper == BigRebalancer.address && _module == BigRebalancer.address) {
            console.log("> BigRebalancer");
        } else if (_keeper == BigRebalancerEuler2.address && _module == BigRebalancerEuler2.address) {
            console.log("> BigRebalancerEuler2");
        }

        await logBalance(_vaultTreasuryAddressV2, "Treasury before");
        await logBalance(_keeper, "Module before");

        tx = await CheapRebalancer.connect(hedgehogRebalancerActor).rebalance("0", mul);
        recipt = await tx.wait();
        console.log("Gas used", recipt.gasUsed.toString());

        await logBalance(_vaultTreasuryAddressV2, "Treasury after");
        await logBalance(_keeper, "Module after");
    });
});
