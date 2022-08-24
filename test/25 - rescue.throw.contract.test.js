const { expect } = require("chai");
const { ethers } = require("hardhat");
const { utils, BigNumber } = ethers;
const {
    wethAddress,
    osqthAddress,
    usdcAddress,
    _governanceAddress,
    _vaultStorageAddress,
    _rebalancerBigAddress,
    _vaultTreasuryAddress,
} = require("./common");
const { resetFork, getERC20Balance, mineSomeBlocks, getSnapshot } = require("./helpers");

describe.only("Rebalance test mainnet", function () {
    let tx, receipt, MyContract, governance, RescueTeam;

    let gas = BigNumber.from(0);
    it("Should deploy contract", async function () {
        await resetFork(15398419);

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [_governanceAddress],
        });

        MyContract = await ethers.getContractFactory("VaultStorage");
        VaultStorage = await MyContract.attach(_vaultStorageAddress);

        MyContract = await ethers.getContractFactory("BigRebalancer");
        Rebalancer = await MyContract.attach(_rebalancerBigAddress);

        governance = await ethers.getSigner(_governanceAddress);
        console.log("governance:", governance.address);

        const signers = await ethers.getSigners();
        chad = signers[0];
        await chad.sendTransaction({
            to: governance.address,
            value: ethers.utils.parseEther("5.0"),
        });

        const Contract = await ethers.getContractFactory("RescueTeam");
        RescueTeam = await Contract.connect(governance).deploy();
        await RescueTeam.deployed();
        gas = gas.add(BigNumber.from("1100000"));
    });

    it("first step", async function () {
        govBefore = await getSnapshot(governance.address);
        rebBefore = await getSnapshot(_rebalancerBigAddress);
        rescueBefore = await getSnapshot(RescueTeam.address);

        tx = await VaultStorage.connect(governance).setMinPriceMultiplier(utils.parseUnits("69", 16), {});
        gas = gas.add((await tx.wait()).gasUsed);

        tx = await VaultStorage.connect(governance).setRebalanceThreshold(utils.parseUnits("1", 18), {});
        gas = gas.add((await tx.wait()).gasUsed);

        expect(await VaultStorage.governance()).to.equal(governance.address);
        expect(await Rebalancer.owner()).to.equal(governance.address);

        //!
        //! Change ownership
        //!
        tx = await VaultStorage.connect(governance).setGovernance(RescueTeam.address);
        gas = gas.add((await tx.wait()).gasUsed);

        tx = await Rebalancer.connect(governance).transferOwnership(RescueTeam.address);
        gas = gas.add((await tx.wait()).gasUsed);

        expect(await VaultStorage.governance()).to.equal(RescueTeam.address);
        expect(await Rebalancer.owner()).to.equal(RescueTeam.address);
    });

    it("rebalance with flash loan", async function () {
        tx = await RescueTeam.connect(governance).rebalance();
        gas = gas.add((await tx.wait()).gasUsed);

        tx = await RescueTeam.connect(governance).stepTwo();
        gas = gas.add((await tx.wait()).gasUsed);

        await mineSomeBlocks(3);

        for (let times = 0; times < 8; times++) {
            tx = await RescueTeam.connect(governance).timeRebalance();
            gas = gas.add((await tx.wait()).gasUsed);

            await mineSomeBlocks(3);
        }

        console.log("> treasury WETH %s", await getERC20Balance(_vaultTreasuryAddress, wethAddress));
        console.log("> treasury USDC %s", await getERC20Balance(_vaultTreasuryAddress, usdcAddress));
        console.log("> treasury oSQTH %s", await getERC20Balance(_vaultTreasuryAddress, osqthAddress));

        govAfter = await getSnapshot(governance.address);
        rebAfter = await getSnapshot(_rebalancerBigAddress);
        rescueAfter = await getSnapshot(RescueTeam.address);
        logDif("Rebalancer", rebAfter, rebBefore);
        logDif("governance", govAfter, govBefore);
        logDif("Rescue", rescueAfter, rescueBefore);

        console.log("Gas:", gas.toString());
    });

    it("rebalance with flash loan", async function () {
        //!
        //! Return ownership
        //!
        tx = await RescueTeam.connect(governance).returnGovernance();
        gas = gas.add((await tx.wait()).gasUsed);

        expect(await VaultStorage.governance()).to.equal(governance.address);
        expect(await Rebalancer.owner()).to.equal(governance.address);
    });

    const logDif = (name, a, b) => {
        console.log("%s WETH %s", name, utils.formatUnits(BigNumber.from(String(a.WETH - b.WETH)), 18));
        console.log("%s USDC %s", name, utils.formatUnits(BigNumber.from(String(a.USDC - b.USDC)), 6));
        console.log("%s oSQTH %s", name, utils.formatUnits(BigNumber.from(String(a.oSQTH - b.oSQTH)), 18));
        // console.log("%s ETH %s", name, utils.formatUnits(BigNumber.from(String(a.ETH - b.ETH)), 18));
    };
});
