const { ethers } = require("hardhat");
const { utils, BigNumber } = ethers;
const {
    wethAddress,
    osqthAddress,
    usdcAddress,
    _vaultAuctionAddress,
    _governanceAddress,
    _vaultStorageAddress,
    _rebalancerBigAddress,
    _vaultTreasuryAddress,
} = require("./common");
const { resetFork, getERC20Balance, mineSomeBlocks, getSnapshot } = require("./helpers");

describe.only("Rebalance test mainnet", function () {
    let tx, receipt, MyContract, governance, Rebalancer;

    let gas = BigNumber.from(0);
    it("Should deploy contract", async function () {
        await resetFork(15398419);

        MyContract = await ethers.getContractFactory("VaultAuction");
        VaultAuction = await MyContract.attach(_vaultAuctionAddress);

        MyContract = await ethers.getContractFactory("VaultStorage");
        VaultStorage = await MyContract.attach(_vaultStorageAddress);

        MyContract = await ethers.getContractFactory("BigRebalancer");
        Rebalancer = await MyContract.attach(_rebalancerBigAddress);

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [_governanceAddress],
        });

        governance = await ethers.getSigner(_governanceAddress);
        console.log("governance:", governance.address);
        console.log("auction:", VaultAuction.address);
        console.log("rebalancer %s", Rebalancer.address);

        const signers = await ethers.getSigners();
        chad = signers[0];
        await chad.sendTransaction({
            to: governance.address,
            value: ethers.utils.parseEther("5.0"),
        });
    });

    it("rebalance with flash loan", async function () {
        govBefore = await getSnapshot(governance.address);
        rebBefore = await getSnapshot(Rebalancer.address);

        tx = await VaultStorage.connect(governance).setMinPriceMultiplier(utils.parseUnits("69", 16), {});

        gas = gas.add((await tx.wait()).gasUsed);

        tx = await VaultStorage.connect(governance).setRebalanceThreshold(utils.parseUnits("1", 18), {});
        gas = gas.add((await tx.wait()).gasUsed);

        tx = await VaultStorage.connect(governance).setPause(false, {});
        gas = gas.add((await tx.wait()).gasUsed);
        tx = await Rebalancer.connect(governance).rebalance(0, {});
        gas = gas.add((await tx.wait()).gasUsed);
        tx = await VaultStorage.connect(governance).setPause(true, {});
        gas = gas.add((await tx.wait()).gasUsed);

        tx = await VaultStorage.connect(governance).setAuctionTime(1, {});
        gas = gas.add((await tx.wait()).gasUsed);

        tx = await VaultStorage.connect(governance).setRebalanceTimeThreshold(1, {});
        gas = gas.add((await tx.wait()).gasUsed);

        await mineSomeBlocks(3);

        for (let times = 0; times < 8; times++) {
            tx = await VaultStorage.connect(governance).setPause(false, {});
            gas = gas.add((await tx.wait()).gasUsed);
            tx = await VaultAuction.connect(governance).timeRebalance(governance.address, 0, 0, 0, {});
            gas = gas.add((await tx.wait()).gasUsed);
            tx = await VaultStorage.connect(governance).setPause(true, {});
            gas = gas.add((await tx.wait()).gasUsed);

            await mineSomeBlocks(3);
        }

        console.log("> treasury WETH %s", await getERC20Balance(_vaultTreasuryAddress, wethAddress));
        console.log("> treasury USDC %s", await getERC20Balance(_vaultTreasuryAddress, usdcAddress));
        console.log("> treasury oSQTH %s", await getERC20Balance(_vaultTreasuryAddress, osqthAddress));

        govAfter = await getSnapshot(governance.address);
        rebAfter = await getSnapshot(Rebalancer.address);
        logDif("Rebalancer", rebAfter, rebBefore);
        logDif("governance", govAfter, govBefore);

        console.log("Gas:", gas.toString());
    });

    const logDif = (name, a, b) => {
        console.log("%s WETH %s", name, utils.formatUnits(BigNumber.from(String(a.WETH - b.WETH)), 18));
        console.log("%s USDC %s", name, utils.formatUnits(BigNumber.from(String(a.USDC - b.USDC)), 6));
        console.log("%s oSQTH %s", name, utils.formatUnits(BigNumber.from(String(a.oSQTH - b.oSQTH)), 18));
        // console.log("%s ETH %s", name, utils.formatUnits(BigNumber.from(String(a.ETH - b.ETH)), 18));
    };
});
