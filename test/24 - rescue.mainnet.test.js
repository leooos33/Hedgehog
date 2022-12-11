const { ethers } = require("hardhat");
const { BigNumber } = ethers;
const {
    _governanceAddress,
    _rescueAddress,
    _rebalancerBigAddress,
    _vaultStorageAddress,
    _hedgehogRebalancerDeployerV2,
    _bigRebalancerV2,
} = require("./common");
const { resetFork, logBalance, getETH, getWETH, getOSQTH, getUSDC, mineSomeBlocks } = require("./helpers");

describe.skip("Rescue test mainnet", function () {
    let tx, receipt, MyContract, governance, RescueTeam;

    let gas = BigNumber.from(0);
    it("Should deploy contract", async function () {
        await resetFork(16046113);

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [_governanceAddress],
        });

        governance = await ethers.getSigner(_governanceAddress);
        console.log("governance:", governance.address);

        const Contract = await ethers.getContractFactory("RescueTeam");
        RescueTeam = await Contract.attach(_rescueAddress);

        // MyContract = await ethers.getContractFactory("VaultStorage");
        // VaultStorage = await MyContract.attach(_vaultStorageAddress);

        // MyContract = await ethers.getContractFactory("BigRebalancer");
        // BigRebalancer = await MyContract.attach(_rebalancerBigAddress);

        //!
        //! Change ownership
        //!

        await getETH(governance.address, ethers.utils.parseEther("1.0"));

        // tx = await BigRebalancer.connect(governance).transferOwnership(RescueTeam.address);
        // await tx.wait();

        // console.log("VaultStorage.governance", await VaultStorage.governance());
        // console.log("BigRebalancer.owner", await BigRebalancer.owner());
    });

    it("rebalance with flash loan", async function () {
        // await getWETH(ethers.utils.parseEther("0.00001"), RescueTeam.address);
        // await getUSDC("1000000", RescueTeam.address);
        // await getOSQTH("1000000000000000000", RescueTeam.address);

        // await logBalance(_rebalancerBigAddress, "> Rebalancer before");
        // await logBalance(_rescueAddress, "> Rescue before");

        // tx = await RescueTeam.connect(governance).timeRebalance();
        // gas = gas.add((await tx.wait()).gasUsed);

        // await logBalance(_rebalancerBigAddress, "> Rebalancer after");
        // await logBalance(_rescueAddress, "> Rescue after");

        // await mineSomeBlocks(3);
        // tx = await RescueTeam.connect(governance).timeRebalance();
        // gas = gas.add((await tx.wait()).gasUsed);

        // await logBalance(_rescueAddress, "> Rescue after 2");

        // await mineSomeBlocks(3);
        // tx = await RescueTeam.connect(governance).timeRebalance();
        // gas = gas.add((await tx.wait()).gasUsed);

        await logBalance(_bigRebalancerV2, "> Rescue after 3");
        console.log("Total Gas:", gas.toString());
    });
});
