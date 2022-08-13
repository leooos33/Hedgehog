const { ethers } = require("hardhat");
const { utils } = ethers;
const { wethAddress, osqthAddress, usdcAddress, _governanceAddress } = require("./common");
const { resetFork, getERC20Balance, approveERC20 } = require("./helpers");
const { deployContract } = require("./deploy");

describe.only("Flash deposit", function () {
    let tx, receipt, FlashDeposit;
    let actor;
    let actorAddress = _governanceAddress;

    it("Should set actors", async function () {
        await resetFork(15334815);

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [actorAddress],
        });

        actor = await ethers.getSigner(actorAddress);
        console.log("actor:", actor.address);

        FlashDeposit = await deployContract("FlashDeposit", [], false);
        // tx = await FlashDeposit.setContracts(Vault.address);
        // await tx.wait();
    });

    it("flash deposit", async function () {
        console.log("> user Eth %s", await getERC20Balance(actor.address, wethAddress));
        console.log("> user Usdc %s", await getERC20Balance(actor.address, usdcAddress));
        console.log("> user Osqth %s", await getERC20Balance(actor.address, osqthAddress));

        let amountEth = "5105085075218935";
        await approveERC20(actor, FlashDeposit.address, amountEth, wethAddress);

        tx = await FlashDeposit.connect(actor).deposit(
            amountEth,
            utils.parseUnits("99", 16),
            actor.address,
            "0",
            "0",
            "0"
        );
        await tx.wait();
        console.log("> deposit()");

        console.log("> user Eth %s", await getERC20Balance(actor.address, wethAddress));
        console.log("> user Usdc %s", await getERC20Balance(actor.address, usdcAddress));
        console.log("> user Osqth %s", await getERC20Balance(actor.address, osqthAddress));

        console.log("> FlashDeposit Eth %s", await getERC20Balance(FlashDeposit.address, wethAddress));
        console.log("> FlashDeposit Usdc %s", await getERC20Balance(FlashDeposit.address, usdcAddress));
        console.log("> FlashDeposit Osqth %s", await getERC20Balance(FlashDeposit.address, osqthAddress));

        const signers = await ethers.getSigners();
        let governance = signers[0];
        tx = await FlashDeposit.connect(governance).collectRemains(
            "49151068761009",
            "5001895",
            "8974852826343",
            actor.address
        );
        await tx.wait();
        console.log("> collectProtocol()");

        console.log("> user Eth %s", await getERC20Balance(actor.address, wethAddress));
        console.log("> user Usdc %s", await getERC20Balance(actor.address, usdcAddress));
        console.log("> user Osqth %s", await getERC20Balance(actor.address, osqthAddress));

        console.log("> FlashDeposit Eth %s", await getERC20Balance(FlashDeposit.address, wethAddress));
        console.log("> FlashDeposit Usdc %s", await getERC20Balance(FlashDeposit.address, usdcAddress));
        console.log("> FlashDeposit Osqth %s", await getERC20Balance(FlashDeposit.address, osqthAddress));
    });
});
