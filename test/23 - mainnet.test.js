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
    _rebalancerBigAddress,
} = require("./common");
const { resetFork, getERC20Balance, getERC20Allowance, approveERC20 } = require("./helpers");

describe.only("Rebalance test mainnet", function () {
    let tx, receipt, MyContract, governance, Rebalancer;

    it("Should deploy contract", async function () {
        await resetFork(15389324);

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

        // const signers = await ethers.getSigners();
        // chad = signers[0];
        // await chad.sendTransaction({
        //     to: governance.address,
        //     value: ethers.utils.parseEther("5.0"),
        // });
    });

    it("rebalance with flash loan", async function () {
        // Comment here to test pause
        tx = await VaultStorage.connect(governance).setPause(false, {
            gasLimit: 40000,
            gasPrice: 11000000000,
        });

        // tx = await VaultStorage.connect(governance).setMinPriceMultiplier(utils.parseUnits("1", 16), {
        //     gasLimit: 40000,
        //     gasPrice: 11000000000,
        // });
        // await tx.wait();

        tx = await VaultStorage.connect(governance).setRebalanceThreshold(utils.parseUnits("1", 18), {
            gasLimit: 40000,
            gasPrice: 11000000000,
        });
        await tx.wait();

        //  tx = await VaultStorage.connect(governance).setBaseThreshold(100000, {
        //      gasLimit: 40000,
        //      gasPrice: 11000000000,
        //  });
        //  await tx.wait();

        tx = await VaultStorage.connect(governance).setProtocolFee(1, {
            gasLimit: 50000,
            gasPrice: 11000000000,
        });
        await tx.wait();

        console.log("> actor WETH %s", await getERC20Balance(governance.address, wethAddress));
        console.log("> actor USDC %s", await getERC20Balance(governance.address, usdcAddress));
        console.log("> actor oSQTH %s", await getERC20Balance(governance.address, osqthAddress));

        // await approveERC20(governance, _vaultAuctionAddress, maxUint256, wethAddress);
        // await approveERC20(governance, _vaultAuctionAddress, maxUint256, usdcAddress);
        // await approveERC20(governance, _vaultAuctionAddress, maxUint256, osqthAddress);

        // console.log("> actor WETH %s", await getERC20Allowance(governance.address, _vaultAuctionAddress, wethAddress));
        // console.log("> actor USDC %s", await getERC20Allowance(governance.address, _vaultAuctionAddress, usdcAddress));
        // console.log("> actor oSQT %s", await getERC20Allowance(governance.address, _vaultAuctionAddress, osqthAddress));

        console.log("params %s", await VaultAuction.getAuctionParams(1661070257));

        tx = await Rebalancer.connect(governance).rebalance(0, {
            gasLimit: 3000000,
            // gas: 1800000,
            gasPrice: 23000000000,
        });
        receipt = await tx.wait();

        // tx = await VaultAuction.connect(governance).timeRebalance(governance.address, 0, 0, 0, {
        //     gasLimit: 2500000,
        //     gasPrice: 11000000000,
        // });
        // receipt = await tx.wait();

        console.log("> Gas used withdraw + fl: %s", receipt.gasUsed);

        console.log("> actor WETH %s", await getERC20Balance(governance.address, wethAddress));
        console.log("> actor USDC %s", await getERC20Balance(governance.address, usdcAddress));
        console.log("> actor oSQTH %s", await getERC20Balance(governance.address, osqthAddress));
    });
});
