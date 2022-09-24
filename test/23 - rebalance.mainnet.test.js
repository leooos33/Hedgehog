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
    _vaultTreasuryAddress,
} = require("./common");
const { resetFork, getERC20Balance, getERC20Allowance, approveERC20, mineSomeBlocks } = require("./helpers");

describe.skip("Rebalance mainnet", function () {
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
        console.log("rebalancer %s", Rebalancer.address);

        const signers = await ethers.getSigners();
        chad = signers[0];
        await chad.sendTransaction({
            to: governance.address,
            value: ethers.utils.parseEther("5.0"),
        });
    });

    it("rebalance with flash loan", async function () {
        // Comment here to test pause
        tx = await VaultStorage.connect(governance).setPause(false, {
            gasLimit: 40000,
            gasPrice: 11000000000,
        });

        tx = await VaultStorage.connect(governance).setMinPriceMultiplier(utils.parseUnits("69", 16), {
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

        console.log("params %s", await VaultAuction.getParams(1661070257));

        console.log("> Rebalancer WETH %s", await getERC20Balance(Rebalancer.address, wethAddress));
        console.log("> Rebalancer USDC %s", await getERC20Balance(Rebalancer.address, usdcAddress));
        console.log("> Rebalancer oSQTH %s", await getERC20Balance(Rebalancer.address, osqthAddress));

        tx = await Rebalancer.connect(governance).rebalance("0", {
            gasLimit: 3000000,
            // gas: 1800000,
            gasPrice: 23000000000,
        });
        receipt = await tx.wait();
        console.log("> Gas used withdraw + fl: %s", receipt.gasUsed);

        console.log("> Rebalancer WETH %s", await getERC20Balance(Rebalancer.address, wethAddress));
        console.log("> Rebalancer USDC %s", await getERC20Balance(Rebalancer.address, usdcAddress));
        console.log("> Rebalancer oSQTH %s", await getERC20Balance(Rebalancer.address, osqthAddress));

        tx = await VaultStorage.connect(governance).setAuctionTime(1, {
            gasLimit: 40000,
            gasPrice: 11000000000,
        });
        await tx.wait();

        const auctionTime = await VaultStorage.auctionTime();
        console.log("auctionTime:", auctionTime.toString());

        tx = await VaultStorage.connect(governance).setRebalanceTimeThreshold(1, {
            gasLimit: 40000,
            gasPrice: 11000000000,
        });
        await tx.wait();

        const rebalanceTimeThreshold = await VaultStorage.rebalanceTimeThreshold();
        console.log("rebalanceTimeThreshold:", rebalanceTimeThreshold.toString());

        await mineSomeBlocks(3);

        console.log("params %s", await VaultAuction.getParams(1661070257 + 3));

        console.log("2");
        tx = await VaultAuction.connect(governance).timeRebalance(governance.address, 0, 0, 0, {
            gasLimit: 2500000,
            gasPrice: 11000000000,
        });
        receipt = await tx.wait();
        console.log("> Gas used withdraw: %s", receipt.gasUsed);

        await mineSomeBlocks(3);

        console.log("3");
        console.log("params %s", await VaultAuction.getParams(1661070257 + 3 * 2));

        tx = await VaultAuction.connect(governance).timeRebalance(governance.address, 0, 0, 0, {
            gasLimit: 2500000,
            gasPrice: 11000000000,
        });
        receipt = await tx.wait();
        console.log("> Gas used withdraw: %s", receipt.gasUsed);

        await mineSomeBlocks(3);

        console.log("4");
        console.log("params %s", await VaultAuction.getParams(1661070257 + 3 * 3));

        tx = await VaultAuction.connect(governance).timeRebalance(governance.address, 0, 0, 0, {
            gasLimit: 2500000,
            gasPrice: 11000000000,
        });
        receipt = await tx.wait();
        console.log("> Gas used withdraw: %s", receipt.gasUsed);

        await mineSomeBlocks(3);
        console.log("5");
        console.log("params %s", await VaultAuction.getParams(1661070257 + 3 * 4));

        tx = await VaultAuction.connect(governance).timeRebalance(governance.address, 0, 0, 0, {
            gasLimit: 2500000,
            gasPrice: 11000000000,
        });
        receipt = await tx.wait();
        console.log("> Gas used withdraw: %s", receipt.gasUsed);

        await mineSomeBlocks(3);

        console.log("6");
        console.log("params %s", await VaultAuction.getParams(1661070257 + 3 * 5));

        tx = await VaultAuction.connect(governance).timeRebalance(governance.address, 0, 0, 0, {
            gasLimit: 2500000,
            gasPrice: 11000000000,
        });
        receipt = await tx.wait();
        console.log("> Gas used withdraw: %s", receipt.gasUsed);

        await mineSomeBlocks(3);
        console.log("7");
        console.log("params %s", await VaultAuction.getParams(1661070257 + 3 * 6));

        tx = await VaultAuction.connect(governance).timeRebalance(governance.address, 0, 0, 0, {
            gasLimit: 2500000,
            gasPrice: 11000000000,
        });
        receipt = await tx.wait();
        console.log("> Gas used withdraw: %s", receipt.gasUsed);

        await mineSomeBlocks(3);
        console.log("8");
        console.log("params %s", await VaultAuction.getParams(1661070257 + 3 * 7));

        tx = await VaultAuction.connect(governance).timeRebalance(governance.address, 0, 0, 0, {
            gasLimit: 2500000,
            gasPrice: 11000000000,
        });
        receipt = await tx.wait();
        console.log("> Gas used withdraw: %s", receipt.gasUsed);

        await mineSomeBlocks(3);
        console.log("9");
        console.log("params %s", await VaultAuction.getParams(1661070257 + 3 * 8));

        tx = await VaultAuction.connect(governance).timeRebalance(governance.address, 0, 0, 0, {
            gasLimit: 2500000,
            gasPrice: 11000000000,
        });
        receipt = await tx.wait();
        console.log("> Gas used withdraw: %s", receipt.gasUsed);

        console.log("> actor WETH %s", await getERC20Balance(governance.address, wethAddress));
        console.log("> actor USDC %s", await getERC20Balance(governance.address, usdcAddress));
        console.log("> actor oSQTH %s", await getERC20Balance(governance.address, osqthAddress));

        console.log("10");
        console.log("params %s", await VaultAuction.getParams(1661070257 + 3 * 9));

        const ethPriceAtLastRebalance = await VaultStorage.ethPriceAtLastRebalance();
        console.log("ethPriceAtLastRebalance:", ethPriceAtLastRebalance.toString());

        // tx = await VaultAuction.connect(governance).timeRebalance(governance.address, 0, 0, 0, {
        //     gasLimit: 2500000,
        //     gasPrice: 11000000000,
        // });
        // receipt = await tx.wait();
        // console.log("> Gas used withdraw: %s", receipt.gasUsed);

        console.log("> Rebalancer WETH %s", await getERC20Balance(Rebalancer.address, wethAddress));
        console.log("> Rebalancer USDC %s", await getERC20Balance(Rebalancer.address, usdcAddress));
        console.log("> Rebalancer oSQTH %s", await getERC20Balance(Rebalancer.address, osqthAddress));

        console.log("> treasury WETH %s", await getERC20Balance(_vaultTreasuryAddress, wethAddress));
        console.log("> treasury USDC %s", await getERC20Balance(_vaultTreasuryAddress, usdcAddress));
        console.log("> treasury oSQTH %s", await getERC20Balance(_vaultTreasuryAddress, osqthAddress));
    });
});
