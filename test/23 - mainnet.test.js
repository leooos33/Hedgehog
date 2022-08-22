const { ethers } = require("hardhat");
const { utils } = ethers;
const {
    wethAddress,
    osqthAddress,
    usdcAddress,
    _vaultAuctionAddress,
    _governanceAddress,
    _vaultStorageAddress,
} = require("./common");
const { resetFork, getERC20Balance } = require("./helpers");

describe.only("Rebalance test mainnet", function () {
    let tx, receipt, MyContract;
    // let actor;
    // let actorAddress = _governanceAddress;
    let governance;

    it("Should deploy contract", async function () {
        await resetFork(15389324);

        MyContract = await ethers.getContractFactory("VaultAuction");
        VaultAuction = await MyContract.attach(_vaultAuctionAddress);

        MyContract = await ethers.getContractFactory("VaultStorage");
        VaultStorage = await MyContract.attach(_vaultStorageAddress);

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [_governanceAddress],
        });

        governance = await ethers.getSigner(_governanceAddress);
        console.log("governance:", governance.address);

        // const signers = await ethers.getSigners();
        // chad = signers[0];

        // await chad.sendTransaction({
        //     to: governance.address,
        //     value: ethers.utils.parseEther("1.0"),
        // });
    });

    it("rebalance with flash loan", async function () {
        // Comment here to test pause
        tx = await VaultStorage.connect(governance).setPause(false, {
            gasLimit: 40000,
            gasPrice: 11000000000,
        });

        tx = await VaultStorage.connect(governance).setMinPriceMultiplier(0, {
            gasLimit: 40000,
            gasPrice: 11000000000,
        });
        await tx.wait();

        tx = await VaultStorage.connect(governance).setRebalanceThreshold(utils.parseUnits("1", 18), {
            gasLimit: 40000,
            gasPrice: 11000000000,
        });
        await tx.wait();

        console.log("> actor WETH %s", await getERC20Balance(governance.address, wethAddress));
        console.log("> actor USDC %s", await getERC20Balance(governance.address, usdcAddress));
        console.log("> actor oSQTH %s", await getERC20Balance(governance.address, osqthAddress));

        tx = await VaultAuction.connect(governance).timeRebalance(governance.address, 0, 0, 0, {
            gasLimit: 2500000,
            gasPrice: 11000000000,
        });
        receipt = await tx.wait();

        console.log("> Gas used withdraw + fl: %s", receipt.gasUsed);

        console.log("> actor WETH %s", await getERC20Balance(governance.address, wethAddress));
        console.log("> actor USDC %s", await getERC20Balance(governance.address, usdcAddress));
        console.log("> actor oSQTH %s", await getERC20Balance(governance.address, osqthAddress));
    });
});
