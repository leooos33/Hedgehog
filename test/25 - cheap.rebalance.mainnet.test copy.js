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

const { deployContract } = require("./deploy/index");
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
    it("Phase 0", async function () {
        await resetFork(16241222);

        hedgehogRebalancer = _hedgehogRebalancerDeployerV2;
        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [hedgehogRebalancer],
        });

        hedgehogRebalancerActor = await ethers.getSigner(hedgehogRebalancer);
        await getETH(hedgehogRebalancerActor.address, ethers.utils.parseEther("3.0"));

        const signers = await ethers.getSigners();
        hucker = signers[2];
        trash = signers[3];
    });
    it("Phase 1", async function () {
        // this.skip();
        MyContract = await ethers.getContractFactory("VaultStorage");
        VaultStorage = await MyContract.attach(_vaultStorageAddressV2);

        MyContract = await ethers.getContractFactory("BigRebalancer");
        Rebalancer = await MyContract.attach(_bigRebalancerV2);

        MyContract = await ethers.getContractFactory("CheapRebalancer");
        CheapRebalancer = await MyContract.attach(_cheapRebalancerV2);

        v3Helper = await deployContract("V3Helper", [], false);

        console.log("Rebalancer.owner:", (await Rebalancer.owner()) == _cheapRebalancerV2);
        console.log("CheapRebalancer.owner:", (await CheapRebalancer.owner()) == hedgehogRebalancer);
        console.log("VaultStorage.governance:", (await VaultStorage.governance()) == _cheapRebalancerV2);
        console.log("VaultStorage.keeper:", (await VaultStorage.keeper()) == _bigRebalancerV2);

        tx = await CheapRebalancer.connect(hedgehogRebalancerActor).collectProtocol(
            "487626799805538458",
            "0",
            "0",
            trash.address
        );
        await tx.wait();
    });

    it("Phase 2 A (noraml timeRebalance)", async function () {
        this.skip();

        await logBalance(_vaultTreasuryAddressV2, "Treasury before");
        await logBalance(Rebalancer.address, "Rebalancer before");

        tx = await CheapRebalancer.connect(hedgehogRebalancerActor).rebalance("0", "950000000000000000");
        recipt = await tx.wait();
        console.log("Gas used", recipt.gasUsed.toString());

        await logBalance(_vaultTreasuryAddressV2, "Treasury after");
        await logBalance(Rebalancer.address, "Rebalancer after");
    });

    it("Phase 2 A (hucked timeRebalance)", async function () {
        // this.skip();

        // Moving the price of ETH/USDC  'DOWN'
        let swapAmount = utils.parseUnits("50000", 18); // WETH, 86k in the pool;
        await getWETH(swapAmount, v3Helper.address);
        await logBalance(v3Helper.address, "v3Helper - 1");

        tx = await v3Helper.swapWETH_USDC(swapAmount);
        await tx.wait();

        // Do reb
        tx = await CheapRebalancer.connect(hedgehogRebalancerActor).rebalance("0", "950000000000000000");
        recipt = await tx.wait();

        tx = await CheapRebalancer.connect(hedgehogRebalancerActor).collectProtocol(
            await getERC20Balance(Rebalancer.address, wethAddress),
            "0",
            "0",
            v3Helper.address
        );
        await tx.wait();

        await logBalance(v3Helper.address, "v3Helper - 3");

        swapAmount = swapAmount.sub(await getERC20Balance(v3Helper.address, wethAddress));
        console.log(swapAmount.toString());
        tx = await v3Helper.swapUSDC_WETH_v2(swapAmount);
        await tx.wait();

        await logBalance(v3Helper.address, "v3Helper - 4");
    });
});
