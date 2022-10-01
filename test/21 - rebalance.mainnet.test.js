const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { utils } = ethers;
const {
    wethAddress,
    osqthAddress,
    usdcAddress,
    _governanceAddress,
    _vaultAuctionAddressV2,
    _vaultMathAddressV2,
    _vaultStorageAddressV2,
    _governanceAddressV2,
    _keeperAddressV2,
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
    approveERC20,
    logBalance,
} = require("./helpers");

describe.only("Rebalance test mainnet", function () {
    let tx, receipt, Rebalancer, MyContract;
    let actor;
    let actorAddress = _governanceAddress;

    it("Should deploy contract", async function () {
        await resetFork(15651395);

        const signers = await ethers.getSigners();
        deployer = signers[0];

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [actorAddress],
        });

        actor = await ethers.getSigner(actorAddress);

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [_governanceAddressV2],
        });
        governance = await ethers.getSigner(_governanceAddressV2);

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [_keeperAddressV2],
        });
        keeper = await ethers.getSigner(_keeperAddressV2);

        MyContract = await ethers.getContractFactory("VaultAuction");
        VaultAuction = await MyContract.attach(_vaultAuctionAddressV2);

        MyContract = await ethers.getContractFactory("VaultStorage");
        VaultStorage = await MyContract.attach(_vaultStorageAddressV2);

        MyContract = await ethers.getContractFactory("VaultMath");
        VaultMath = await MyContract.attach(_vaultMathAddressV2);

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

        await getETH(governance.address, ethers.utils.parseEther("1.0"));

        await VaultStorage.connect(governance).setRebalanceTimeThreshold(1);

        await getETH(keeper.address, ethers.utils.parseEther("1.0"));

        await VaultStorage.connect(keeper).setKeeper(Rebalancer.address);

        // await getETH(actor.address, ethers.utils.parseEther("1.0"));
    });

    it("mine some blocks", async function () {
        this.skip();
        await mineSomeBlocks(1);

        console.log(await VaultMath.isTimeRebalance());
    });

    it("aditional actions", async function () {
        this.skip();

        // console.log(await VaultAuction.getParams("1660983213"));
        // return;

        //----- Approves -----

        // const swapRouter = "0xE592427A0AEce92De3Edee1F18E0157C05861564";
        // const euler = "0x27182842E098f60e3D576794A5bFFb0777E025d3";
        // const addressAuction = "0x399dD7Fd6EF179Af39b67cE38821107d36678b5D";
        // const addressMath = "0xDF374d19021831E785212F00837B5709820AA769";

        // console.log(await getERC20Allowance(Rebalancer.address, addressMath, wethAddress));
        // console.log(await getERC20Allowance(Rebalancer.address, addressMath, osqthAddress));
        // console.log(await getERC20Allowance(Rebalancer.address, addressMath, usdcAddress));
    });

    it("rebalance with BigRebalancer", async function () {
        // this.skip();

        //-- clean contracts
        // const [owner, randomChad] = await ethers.getSigners();
        // await owner.sendTransaction({
        //     to: actor.address,
        //     value: ethers.utils.parseEther("1.0"),
        // });

        // tx = await Rebalancer.connect(actor).collectProtocol(
        //     await getERC20Balance(Rebalancer.address, wethAddress),
        //     await getERC20Balance(Rebalancer.address, usdcAddress),
        //     await getERC20Balance(Rebalancer.address, osqthAddress),
        //     actor.address
        // );
        // await tx.wait();

        // await transferAll(actor, randomChad.address, wethAddress);
        // await transferAll(actor, randomChad.address, usdcAddress);
        // await transferAll(actor, randomChad.address, osqthAddress);

        //-- clean contracts

        // await getUSDC(3007733 + 10 + 1041, Rebalancer.address);

        await logBalance(Rebalancer.address, "> Rebalancer ");
        await logBalance(deployer.address, "> actor ");

        tx = await Rebalancer.connect(deployer).rebalance(0, 0);

        receipt = await tx.wait();
        console.log("> Gas used rebalance + fl: %s", receipt.gasUsed);

        await logBalance(Rebalancer.address, "> Rebalancer ");
        await logBalance(deployer.address, "> actor ");
    });

    it("rebalance manual using private liquidity", async function () {
        this.skip();

        //-- clean contracts
        const [owner, randomChad] = await ethers.getSigners();
        await owner.sendTransaction({
            to: actor.address,
            value: ethers.utils.parseEther("1.0"),
        });

        tx = await Rebalancer.connect(actor).collectProtocol(
            await getERC20Balance(Rebalancer.address, wethAddress),
            await getERC20Balance(Rebalancer.address, usdcAddress),
            await getERC20Balance(Rebalancer.address, osqthAddress),
            actor.address
        );
        await tx.wait();

        await transferAll(actor, randomChad.address, wethAddress);
        await transferAll(actor, randomChad.address, usdcAddress);
        await transferAll(actor, randomChad.address, osqthAddress);

        //? Deposit liquidity for rebalance
        const amount = 3007733 + 2000;
        await getUSDC(amount, actor.address, "0x94c96dfe7d81628446bebf068461b4f728ed8670");

        await approveERC20(actor, VaultAuction.address, amount, usdcAddress);

        res = await VaultMath.connect(actor).isTimeRebalance();
        // console.log(">", res);
        res = await VaultAuction.getParams(1660598164);
        console.log(">", res[0].sub(res[3]).toString());
        console.log(">", res[1].sub(res[4]).toString());
        console.log(">", res[2].sub(res[5]).toString());

        console.log("> actor WETH %s", await getERC20Balance(actor.address, wethAddress));
        console.log("> actor USDC %s", await getERC20Balance(actor.address, usdcAddress));
        console.log("> actor USDC %s", await getERC20Allowance(actor.address, VaultAuction.address, usdcAddress));
        console.log("> actor oSQTH %s", await getERC20Balance(actor.address, osqthAddress));

        tx = await VaultAuction.connect(actor).timeRebalance(actor.address, 0, 0, 0);
        await tx.wait();

        console.log("> actor WETH %s", await getERC20Balance(actor.address, wethAddress));
        console.log("> actor USDC %s", await getERC20Balance(actor.address, usdcAddress));
        console.log("> actor oSQTH %s", await getERC20Balance(actor.address, osqthAddress));
    });

    const transferAll = async (from, to, token) => {
        const ERC20 = await ethers.getContractAt("IWETH", token);
        await ERC20.connect(from).transfer(to, await getERC20Balance(from.address, token));
    };

    const getETH = async (toAddress, eth) => {
        const [owner, randomChad] = await ethers.getSigners();
        await owner.sendTransaction({
            to: toAddress,
            value: eth,
        });
    };
});
