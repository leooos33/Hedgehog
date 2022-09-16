const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { utils } = ethers;
const {
    wethAddress,
    osqthAddress,
    usdcAddress,
    _vaultAuctionAddress,
    _vaultMathAddress,
    _biggestOSqthHolder,
    _governanceAddress,
    _rebalancerBigAddress,
} = require("./common");
const {
    mineSomeBlocks,
    resetFork,
    getERC20Balance,
    getUSDC,
    getOSQTH,
    getWETH,
    logBlock,
    getERC20Allowance,
} = require("./helpers");

describe.only("Smazka test", function () {
    let tx, receipt, Rebalancer, MyContract;
    let actor;
    let actorAddress = _governanceAddress;

    it("Should deploy contract", async function () {
        await resetFork(15376520);

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

        //----- choose rebalancer -----

        // MyContract = await ethers.getContractFactory("BigRebalancer");
        // Rebalancer = await MyContract.attach(_rebalancerBigAddress);

        // MyContract = await ethers.getContractFactory("Rebalancer");
        // Rebalancer = await MyContract.attach("0x09b1937d89646b7745377f0fcc8604c179c06af5");

        MyContract = await ethers.getContractFactory("BigRebalancer");
        Rebalancer = await MyContract.deploy();
        await Rebalancer.deployed();

        //----- choose rebalancer -----

        console.log("Owner:", await Rebalancer.owner());
        console.log("addressAuction:", await Rebalancer.addressAuction());
        console.log("addressMath:", await Rebalancer.addressMath());
    });

    it("mine some blocks", async function () {
        // 1661067308 <- Now
        // 1661070257 <- targetrebalance time
        // await mineSomeBlocks(3000);

        // 1661027039 <- Now
        // 1661026678 <- targetrebalance time
        // don't need to move

        console.log(await VaultMath.isTimeRebalance());

        const signers = await ethers.getSigners();
        chad = signers[0];
        await chad.sendTransaction({
            to: actor.address,
            value: ethers.utils.parseEther("5.0"),
        });
    });

    it("rebalance with flash loan", async function () {
        //? Smazka
        // await getWETH(utils.parseUnits("50", 18), Rebalancer.address, "0x7946b98660c04a19475148c25c6d3bb3bf7417e2");
        // await getUSDC(utils.parseUnits("500", 6), Rebalancer.address, "0x94c96dfe7d81628446bebf068461b4f728ed8670");
        // await getOSQTH(utils.parseUnits("6", 18), Rebalancer.address, "0xf9f613bdec2703ede176cc98a2276fa1f618a1b1");
        // await getOSQTH(utils.parseUnits("6", 18), Rebalancer.address, "0xf9f613bdec2703ede176cc98a2276fa1f618a1b1");

        // tx = await VaultMath.getPrices();
        // console.log("VaultMath.getPrices:", tx);

        console.log("> Rebalancer WETH %s", await getERC20Balance(Rebalancer.address, wethAddress));
        console.log("> Rebalancer USDC %s", await getERC20Balance(Rebalancer.address, usdcAddress));
        console.log("> Rebalancer oSQTH %s", await getERC20Balance(Rebalancer.address, osqthAddress));

        console.log("> actor WETH %s", await getERC20Balance(actor.address, wethAddress));
        console.log("> actor USDC %s", await getERC20Balance(actor.address, usdcAddress));
        console.log("> actor oSQTH %s", await getERC20Balance(actor.address, osqthAddress));

        tx = await Rebalancer.connect(actor).rebalance(0);
        // tx = await VaultAuction.connect(actor).timeRebalance(actor.address, 0, 0, 0);
        receipt = await tx.wait();

        console.log("> Gas used rebalance + fl: %s", receipt.gasUsed);

        console.log("> Rebalancer WETH %s", await getERC20Balance(Rebalancer.address, wethAddress));
        console.log("> Rebalancer USDC %s", await getERC20Balance(Rebalancer.address, usdcAddress));
        console.log("> Rebalancer oSQTH %s", await getERC20Balance(Rebalancer.address, osqthAddress));

        console.log("> actor WETH %s", await getERC20Balance(actor.address, wethAddress));
        console.log("> actor USDC %s", await getERC20Balance(actor.address, usdcAddress));
        console.log("> actor oSQTH %s", await getERC20Balance(actor.address, osqthAddress));
    });
});
