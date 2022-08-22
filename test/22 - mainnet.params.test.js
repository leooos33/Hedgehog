const { ethers } = require("hardhat");
const {
    wethAddress,
    osqthAddress,
    usdcAddress,
    _vaultAuctionAddress,
    _vaultMathAddress,
    _vaultAddress,
    _governanceAddress,
    _vaultStorageAddress,
} = require("./common");
const { resetFork, getERC20Balance } = require("./helpers");

describe("Rebalance test mainnet", function () {
    let tx, receipt, MyContract;
    let actor, governance;
    let actorAddress = "0xbe74daf0930dfab7d8396eead251a4a21106797d";

    it("Should deploy contract", async function () {
        await resetFork(15382682);

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [actorAddress],
        });

        actor = await ethers.getSigner(actorAddress);
        console.log("actor:", actor.address);

        MyContract = await ethers.getContractFactory("VaultAuction");
        VaultAuction = await MyContract.attach(_vaultAuctionAddress);

        MyContract = await ethers.getContractFactory("VaultMath");
        VaultMath = await MyContract.attach(_vaultMathAddress);

        MyContract = await ethers.getContractFactory("VaultStorage");
        VaultStorage = await MyContract.attach(_vaultStorageAddress);

        MyContract = await ethers.getContractFactory("Vault");
        Vault = await MyContract.attach(_vaultAddress);

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [_governanceAddress],
        });

        governance = await ethers.getSigner(_governanceAddress);
        console.log("governance:", governance.address);
    });

    it("rebalance with flash loan", async function () {
        console.log("> actor WETH %s", await getERC20Balance(actor.address, wethAddress));
        console.log("> actor USDC %s", await getERC20Balance(actor.address, usdcAddress));
        console.log("> actor oSQTH %s", await getERC20Balance(actor.address, osqthAddress));
        console.log("> actor shares %s", await getERC20Balance(actor.address, Vault.address));

        // tx = await VaultStorage.connect(governance).setPause(true, {
        //     gasLimit: 500000,
        //     gasPrice: 4000000000,
        // });
        // receipt = await tx.wait();

        // tx = await Vault.connect(actor).withdraw("1164661693185355246", 0, 0, 0);
        // receipt = await tx.wait();

        // Comment here to test pause
        // tx = await Vault.connect(actor).deposit(4, 4, 4, actor.address, "0", "0", "0");
        // await tx.wait();

        // tx = await VaultAuction.connect(actor).timeRebalance(actor.address, 4, 4, 4);
        // await tx.wait();

        // console.log("> Gas used withdraw + fl: %s", receipt.gasUsed);

        // console.log("> actor WETH %s", await getERC20Balance(actor.address, wethAddress));
        // console.log("> actor USDC %s", await getERC20Balance(actor.address, usdcAddress));
        // console.log("> actor oSQTH %s", await getERC20Balance(actor.address, osqthAddress));
        // console.log("> actor shares %s", await getERC20Balance(actor.address, Vault.address));
    });
});
