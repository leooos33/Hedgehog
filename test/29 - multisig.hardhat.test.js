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
        await resetFork(16455860);

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

        _CheapRebalancer = await ethers.getContractAt("ICheapRebalancerOld", _cheapRebalancerV2);

        CheapRebalancer = await deployContract("CheapRebalancer", [], false);
        tx = await CheapRebalancer.transferOwnership(hedgehogRebalancerActor.address);
        await tx.wait();

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

    it("Transfer to new contracts", async function () {
        // this.skip();

        tx = await _CheapRebalancer.connect(hedgehogRebalancerActor).setContracts(BigRebalancerEuler2.address);
        await tx.wait();
        tx = await _CheapRebalancer.connect(hedgehogRebalancerActor).returnOwner(hedgehogRebalancerActor.address);
        await tx.wait();

        tx = await _CheapRebalancer.connect(hedgehogRebalancerActor).returnGovernance(MultisigWallet.address);
        await tx.wait();
        tx = await BigRebalancerEuler2.connect(hedgehogRebalancerActor).setKeeper(MultisigWallet.address);
        await tx.wait();

        tx = await BigRebalancer.connect(hedgehogRebalancerActor).transferOwnership(CheapRebalancer.address);
        await tx.wait();
        tx = await BigRebalancerEuler.connect(hedgehogRebalancerActor).transferOwnership(CheapRebalancer.address);
        await tx.wait();
        tx = await BigRebalancerEuler2.connect(hedgehogRebalancerActor).transferOwnership(CheapRebalancer.address);
        await tx.wait();

        tx = await CheapRebalancer.connect(hedgehogRebalancerActor).transferOwnership(MultisigWallet.address);
        await tx.wait();

        console.log("CheapRebalancer.owner:", (await CheapRebalancer.owner()) == MultisigWallet.address);
        console.log("BigRebalancer.owner:", (await BigRebalancer.owner()) == CheapRebalancer.address);
        console.log("BigRebalancerEuler.owner:", (await BigRebalancerEuler.owner()) == CheapRebalancer.address);
        console.log("BigRebalancerEuler2.owner:", (await BigRebalancerEuler2.owner()) == CheapRebalancer.address);
        console.log("VaultStorage.governance:", (await VaultStorage.governance()) == MultisigWallet.address);
        console.log("VaultStorage.keeper:", (await VaultStorage.keeper()) == MultisigWallet.address);
    });

    const nullAddress = "0x0000000000000000000000000000000000000000";
    it("Check if could return", async function () {
        this.skip();

        //? setGovernance
        inface = new ethers.utils.Interface(["function setGovernance(address _governance)"]);
        data = inface.encodeFunctionData("setGovernance", [hedgehogRebalancerActor.address]);
        tx = await MultisigWallet.connect(owner1).submitTransaction(
            VaultStorage.address,
            0,
            data,
            nullAddress,
            nullAddress,
            nullAddress
        );
        await tx.wait();
        tx = await MultisigWallet.connect(owner1).confirmTransaction(0);
        await tx.wait();
        tx = await MultisigWallet.connect(owner2).confirmTransaction(0);
        await tx.wait();
        tx = await MultisigWallet.connect(owner1).executeTransaction(0);
        await tx.wait();

        //?setKeeper
        inface = new ethers.utils.Interface(["function setKeeper(address _keeper)"]);
        data = inface.encodeFunctionData("setKeeper", [hedgehogRebalancerActor.address]);
        tx = await MultisigWallet.connect(owner1).submitTransaction(
            VaultStorage.address,
            0,
            data,
            nullAddress,
            nullAddress,
            nullAddress
        );
        await tx.wait();
        tx = await MultisigWallet.connect(owner1).confirmTransaction(1);
        await tx.wait();
        tx = await MultisigWallet.connect(owner2).confirmTransaction(1);
        await tx.wait();
        tx = await MultisigWallet.connect(owner1).executeTransaction(1);
        await tx.wait();

        //?transferOwnership
        inface = new ethers.utils.Interface(["function transferOwnership(address newOwner)"]);
        data = inface.encodeFunctionData("transferOwnership", [hedgehogRebalancerActor.address]);
        tx = await MultisigWallet.connect(owner1).submitTransaction(
            CheapRebalancer.address,
            0,
            data,
            nullAddress,
            nullAddress,
            nullAddress
        );
        await tx.wait();
        tx = await MultisigWallet.connect(owner1).confirmTransaction(2);
        await tx.wait();
        tx = await MultisigWallet.connect(owner2).confirmTransaction(2);
        await tx.wait();
        tx = await MultisigWallet.connect(owner1).executeTransaction(2);
        await tx.wait();

        tx = await CheapRebalancer.connect(hedgehogRebalancerActor).returnOwner(
            hedgehogRebalancerActor.address,
            BigRebalancer.address
        );
        await tx.wait();
        tx = await CheapRebalancer.connect(hedgehogRebalancerActor).returnOwner(
            hedgehogRebalancerActor.address,
            BigRebalancerEuler.address
        );
        await tx.wait();
        tx = await CheapRebalancer.connect(hedgehogRebalancerActor).returnOwner(
            hedgehogRebalancerActor.address,
            BigRebalancerEuler2.address
        );
        await tx.wait();

        console.log("CheapRebalancer.owner:", (await CheapRebalancer.owner()) == hedgehogRebalancerActor.address);
        console.log("BigRebalancer.owner:", (await BigRebalancer.owner()) == hedgehogRebalancerActor.address);
        console.log("BigRebalancerEuler.owner:", (await BigRebalancerEuler.owner()) == hedgehogRebalancerActor.address);
        console.log(
            "BigRebalancerEuler2.owner:",
            (await BigRebalancerEuler2.owner()) == hedgehogRebalancerActor.address
        );
        console.log("VaultStorage.governance:", (await VaultStorage.governance()) == hedgehogRebalancerActor.address);
        console.log("VaultStorage.keeper:", (await VaultStorage.keeper()) == hedgehogRebalancerActor.address);
    });
    return;

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
