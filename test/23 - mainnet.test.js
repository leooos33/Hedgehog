const { ethers } = require("hardhat");
const { utils } = ethers;
const {
    wethAddress,
    osqthAddress,
    usdcAddress,
    _vaultAuctionAddress,
    _governanceAddress,
    _vaultStorageAddress,
    maxUint256,
} = require("./common");
const { resetFork, getERC20Balance, getERC20Allowance, approveERC20 } = require("./helpers");
const { BigNumber } = require("ethers");

describe.only("Rebalance test mainnet", function () {
    let tx, receipt, MyContract, governance;
    // let actor;
    // let actorAddress = _governanceAddress;

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
        console.log("auction:", VaultAuction.address);

        const signers = await ethers.getSigners();
        chad = signers[0];

        await chad.sendTransaction({
            to: governance.address,
            value: ethers.utils.parseEther("5.0"),
        });
    });

    it("rebalance with flash loan", async function () {
        let governanceAddress = _governanceAddress;
        governance = await ethers.getSigner(governanceAddress);

        // Comment here to test pause
        tx = await VaultStorage.connect(governance).setPause(false, {
            gasLimit: 40000,
            gasPrice: 11000000000,
        });

        tx = await VaultStorage.connect(governance).setMinPriceMultiplier(utils.parseUnits("1", 16), {
            gasLimit: 40000,
            gasPrice: 11000000000,
        });
        await tx.wait();

        tx = await VaultStorage.connect(governance).setRebalanceThreshold(utils.parseUnits("1", 18), {
            gasLimit: 40000,
            gasPrice: 11000000000,
        });
        await tx.wait();

        tx = await VaultStorage.connect(governance).setBaseThreshold(100000, {
            gasLimit: 40000,
            gasPrice: 11000000000,
        });
        await tx.wait();

        console.log("> actor WETH %s", await getERC20Balance(governance.address, wethAddress));
        console.log("> actor USDC %s", await getERC20Balance(governance.address, usdcAddress));
        console.log("> actor oSQTH %s", await getERC20Balance(governance.address, osqthAddress));

        await approveERC20(governance, _vaultAuctionAddress, maxUint256, wethAddress);
        await approveERC20(governance, _vaultAuctionAddress, maxUint256, usdcAddress);
        await approveERC20(governance, _vaultAuctionAddress, maxUint256, osqthAddress);

        console.log("> actor WETH %s", await getERC20Allowance(governance.address, _vaultAuctionAddress, wethAddress));
        console.log("> actor USDC %s", await getERC20Allowance(governance.address, _vaultAuctionAddress, usdcAddress));
        console.log("> actor oSQT %s", await getERC20Allowance(governance.address, _vaultAuctionAddress, osqthAddress));

        console.log("params %s", await VaultAuction.getAuctionParams(1661070257));

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
