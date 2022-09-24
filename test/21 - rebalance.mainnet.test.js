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

describe.skip("Rebalance mainnet", function () {
    let tx, receipt, Rebalancer, MyContract;
    let actor;
    let actorAddress = "0x42b1299fcca091a83c08c24915be6e6d63906b1a";

    it("Should deploy contract", async function () {
        await resetFork(15382421);

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

        MyContract = await ethers.getContractFactory("BigRebalancer");
        Rebalancer = await MyContract.attach(_rebalancerBigAddress);

        // MyContract = await ethers.getContractFactory("Rebalancer");
        // Rebalancer = await MyContract.attach("0x09b1937d89646b7745377f0fcc8604c179c06af5");

        // MyContract = await ethers.getContractFactory("BigRebalancer");
        // Rebalancer = await MyContract.deploy();
        // await Rebalancer.deployed();

        //----- choose rebalancer -----

        console.log("Owner:", await Rebalancer.owner());
        console.log("addressAuction:", await Rebalancer.addressAuction());
        console.log("addressMath:", await Rebalancer.addressMath());
    });

    it("mine some blocks", async function () {
        // 1661070257 <- targetrebalance time

        //? Smth crazy
        // await logBlock();
        // let timestampBefore;
        // do {
        //     const blockNumBefore = await ethers.provider.getBlockNumber();
        //     const blockBefore = await ethers.provider.getBlock(blockNumBefore);
        //     timestampBefore = blockBefore.timestamp;
        //     let blocksToMine = 100;
        //     await hre.network.provider.send("hardhat_mine", [`0x${blocksToMine.toString(16)}`]);
        //     console.log("+", blocksToMine);
        // } while (timestampBefore <= 1661070257);
        // await logBlock();

        await mineSomeBlocks(6400);
    });

    it("calculations and approves", async function () {
        this.skip();
        console.log(await VaultMath.isTimeRebalance());
        // return;
        console.log(await VaultAuction.getParams("1660983213"));
        // return;

        //----- Approves -----

        const swapRouter = "0xE592427A0AEce92De3Edee1F18E0157C05861564";
        const euler = "0x27182842E098f60e3D576794A5bFFb0777E025d3";
        const addressAuction = "0x399dD7Fd6EF179Af39b67cE38821107d36678b5D";
        const addressMath = "0xDF374d19021831E785212F00837B5709820AA769";

        // Rebalancer.address -> swapRouter (+)
        // Rebalancer.address -> euler (+)
        // Rebalancer.address -> addressAuction (+)

        console.log(await getERC20Allowance(Rebalancer.address, addressMath, wethAddress));
        console.log(await getERC20Allowance(Rebalancer.address, addressMath, osqthAddress));
        console.log(await getERC20Allowance(Rebalancer.address, addressMath, usdcAddress));
    });

    it("rebalance with flash loan", async function () {
        //? Smazka
        // await getWETH(utils.parseUnits("50", 18), Rebalancer.address, "0x7946b98660c04a19475148c25c6d3bb3bf7417e2");
        // await getUSDC(utils.parseUnits("500", 6), Rebalancer.address, "0x94c96dfe7d81628446bebf068461b4f728ed8670");
        // await getOSQTH(utils.parseUnits("6", 18), Rebalancer.address, "0xf9f613bdec2703ede176cc98a2276fa1f618a1b1");
        // await getUSDC("10000000", Rebalancer.address, "0x94c96dfe7d81628446bebf068461b4f728ed8670");
        // await getOSQTH("1000", Rebalancer.address, "0xf9f613bdec2703ede176cc98a2276fa1f618a1b1");

        tx = await VaultMath.getPrices();
        console.log("VaultMath.getPrices:", tx);

        console.log("> Rebalancer WETH %s", await getERC20Balance(Rebalancer.address, wethAddress));
        console.log("> Rebalancer USDC %s", await getERC20Balance(Rebalancer.address, usdcAddress));
        console.log("> Rebalancer oSQTH %s", await getERC20Balance(Rebalancer.address, osqthAddress));

        console.log("> actor WETH %s", await getERC20Balance(actor.address, wethAddress));
        console.log("> actor USDC %s", await getERC20Balance(actor.address, usdcAddress));
        console.log("> actor oSQTH %s", await getERC20Balance(actor.address, osqthAddress));

        // tx = await Rebalancer.connect(actor).rebalance(0, {
        //     gasLimit: 3000000,
        //     // gas: 1800000,
        //     gasPrice: 23000000000,
        // });
        tx = await VaultAuction.connect(actor).timeRebalance(actor.address, 0, 0, 0);
        receipt = await tx.wait();

        console.log("> Gas used rebalance + fl: %s", receipt.gasUsed);

        console.log("> Rebalancer WETH %s", await getERC20Balance(Rebalancer.address, wethAddress));
        console.log("> Rebalancer USDC %s", await getERC20Balance(Rebalancer.address, usdcAddress));
        console.log("> Rebalancer oSQTH %s", await getERC20Balance(Rebalancer.address, osqthAddress));

        console.log("> actor WETH %s", await getERC20Balance(actor.address, wethAddress));
        console.log("> actor USDC %s", await getERC20Balance(actor.address, usdcAddress));
        console.log("> actor oSQTH %s", await getERC20Balance(actor.address, osqthAddress));
    });

    it("rebalance manual from hamster", async function () {
        this.skip();
        await mineSomeBlocks(3407);

        //? Deposit for rebalance
        // await getWETH(utils.parseUnits("50", 18), actor.address, "0x7946b98660c04a19475148c25c6d3bb3bf7417e2");
        // await getUSDC(utils.parseUnits("500", 6), actor.address, "0x94c96dfe7d81628446bebf068461b4f728ed8670");
        // await getOSQTH(utils.parseUnits("50", 18), actor.address, "0xf9f613bdec2703ede176cc98a2276fa1f618a1b1");

        console.log("> actor WETH %s", await getERC20Balance(actor.address, wethAddress));
        console.log("> actor USDC %s", await getERC20Balance(actor.address, usdcAddress));
        console.log("> actor oSQTH %s", await getERC20Balance(actor.address, osqthAddress));

        tx = await VaultMath.isTimeRebalance();
        console.log(tx);

        tx = await VaultMath.getPrices();
        console.log(tx);

        tx = await VaultAuction.connect(actor).timeRebalance(actor.address, 0, 0, 0);
        receipt = await tx.wait();
        console.log("> Gas used rebalance + fl: %s", receipt.gasUsed);

        tx = await VaultMath.isTimeRebalance();
        console.log(tx);

        console.log("> actor WETH %s", await getERC20Balance(actor.address, wethAddress));
        console.log("> actor USDC %s", await getERC20Balance(actor.address, usdcAddress));
        console.log("> actor oSQTH %s", await getERC20Balance(actor.address, osqthAddress));
    });
});
