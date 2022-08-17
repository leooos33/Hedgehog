const { ethers } = require("hardhat");
const { utils } = ethers;
const { expect, assert } = require("chai");
const {
    wethAddress,
    osqthAddress,
    usdcAddress,
    _governanceAddress,
    _flashDepositAddress,
    _vaultAddress,
    _biggestOSqthHolder,
    maxUint256,
} = require("./common");
const {
    resetFork,
    getERC20Balance,
    approveERC20,
    getERC20Allowance,
    getUSDC,
    getWETH,
    getOSQTH,
} = require("./helpers");
const { deployContract } = require("./deploy");
const { BigNumber } = require("ethers");

describe.only("Flash deposit", function () {
    let tx, receipt, FlashDeposit;
    let actor;
    let actorAddress = "0x6c4830e642159be2e6c5cc4c6012bc5a21aa95ce";

    it("Should set actors", async function () {
        await resetFork(15351855);

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [actorAddress],
        });

        actor = await ethers.getSigner(actorAddress);
        console.log("actor:", actor.address);

        // MyContract = await ethers.getContractFactory("FlashDeposit");
        // FlashDeposit = await MyContract.attach(_flashDepositAddress);
        MyContract = await ethers.getContractFactory("Vault");
        Vault = await MyContract.attach(_vaultAddress);
        FlashDeposit = await deployContract("FlashDeposit", [], false);
        // tx = await FlashDeposit.setContracts(Vault.address);
        // await tx.wait();
    });

    it("flash deposit real (mode = 0)", async function () {
        // this.skip();
        // const flashDepositAddress = _flashDepositAddress;
        const flashDepositAddress = FlashDeposit.address;

        const [owner] = await ethers.getSigners();
        await owner.sendTransaction({
            to: actorAddress,
            value: ethers.utils.parseEther("10.0"), // Sends exactly 1.0 ether
        });

        let WETH = await ethers.getContractAt("IWETH", wethAddress);
        tx = await WETH.connect(actor).approve(FlashDeposit.address, BigNumber.from(maxUint256));
        await tx.wait();

        await getWETH(utils.parseUnits("20", 18), actor.address);
        console.log("> user Eth %s", await getERC20Balance(actor.address, wethAddress));

        console.log("> Contract Eth balance %s", await getERC20Balance(FlashDeposit.address, wethAddress));
        console.log("> Contrac Usdc balance %s", await getERC20Balance(FlashDeposit.address, usdcAddress));
        console.log("> Contract Osqth balance %s", await getERC20Balance(FlashDeposit.address, osqthAddress));

        const slippage = "950000000000000000";
        const amountETH = "10000000000000000000";

        console.log("> amount wETH to deposit %s", amountETH);

        tx = await FlashDeposit.connect(actor).deposit(amountETH, slippage, actorAddress, "0" , {
            gasLimit: 1700000,
            gasPrice: 8000000000,
        });

        receipt = await tx.wait();
        console.log("> deposit()");
        console.log("> Gas used: %s", receipt.gasUsed);

        console.log("> user Eth %s", await getERC20Balance(actor.address, wethAddress));
        console.log("> user Usdc %s", await getERC20Balance(actor.address, usdcAddress));
        console.log("> user Osqth %s", await getERC20Balance(actor.address, osqthAddress));

        expect(await getERC20Balance(actor.address, wethAddress)).not.equal("0");
        expect(await getERC20Balance(actor.address, usdcAddress)).to.equal("0");
        expect(await getERC20Balance(actor.address, osqthAddress)).to.equal("0");

        expect(await getERC20Balance(flashDepositAddress, wethAddress)).to.equal("0");
        expect(await getERC20Balance(flashDepositAddress, usdcAddress)).to.equal("0");
        expect(await getERC20Balance(flashDepositAddress, osqthAddress)).to.equal("0");
    });

    it("flash deposit real (mode = 1)", async function () {
        // this.skip();
        // const flashDepositAddress = _flashDepositAddress;
        const flashDepositAddress = FlashDeposit.address;

        const [owner] = await ethers.getSigners();
        await owner.sendTransaction({
            to: actorAddress,
            value: ethers.utils.parseEther("10.0"), // Sends exactly 1.0 ether
        });

        let WETH = await ethers.getContractAt("IWETH", wethAddress);
        tx = await WETH.connect(actor).approve(flashDepositAddress, BigNumber.from(maxUint256));
        await tx.wait();
        await getWETH(utils.parseUnits("20", 18), actor.address);
        console.log("> user Eth %s", await getERC20Balance(actor.address, wethAddress));

        console.log("> Contract Eth balance %s", await getERC20Balance(flashDepositAddress, wethAddress));
        console.log("> Contract Usdc balance %s", await getERC20Balance(flashDepositAddress, usdcAddress));
        console.log("> Contract Osqth balance %s", await getERC20Balance(flashDepositAddress, osqthAddress));

        const slippage = "990000000000000000";
        const amountETH = "10000000000000000000";

        console.log("> amount wETH to deposit %s", await getERC20Balance(actor.address, wethAddress));

        tx = await FlashDeposit.connect(actor).deposit(amountETH, slippage, actorAddress, "1" , {
            gasLimit: 1500000,
            gasPrice: 8000000000,
        });

        receipt = await tx.wait();
        console.log("> deposit()");
        console.log("> Gas used: %s", receipt.gasUsed);

        console.log("> user Eth %s", await getERC20Balance(actor.address, wethAddress));
        console.log("> user Usdc %s", await getERC20Balance(actor.address, usdcAddress));
        console.log("> user Osqth %s", await getERC20Balance(actor.address, osqthAddress));

        expect(await getERC20Balance(actor.address, usdcAddress)).not.equal("0");
        expect(await getERC20Balance(actor.address, usdcAddress)).not.equal("0");
        expect(await getERC20Balance(actor.address, osqthAddress)).not.equal("0");

        expect(await getERC20Balance(flashDepositAddress, wethAddress)).to.equal("0");
        expect(await getERC20Balance(flashDepositAddress, usdcAddress)).to.equal("0");
        expect(await getERC20Balance(flashDepositAddress, osqthAddress)).to.equal("0");
    });
});
