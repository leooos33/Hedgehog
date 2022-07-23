const { ethers } = require("hardhat");
const { utils } = ethers;
const { wethAddress, usdcAddress } = require("./common");
const { resetFork, logBlock, getUSDC, getERC20Balance, mineSomeBlocks } = require("./helpers");
const { hardhatDeploy, deploymentParams } = require("./deploy");

describe.only("VaultMath", function () {
    let swaper, depositor, keeper, governance;
    it("Should set actors", async function () {
        const signers = await ethers.getSigners();
        governance = signers[0];
        depositor = signers[7];
        keeper = signers[8];
        swaper = signers[9];
    });

    let Vault, VaultAuction, VaultMath, VaultTreasury, VaultStorage, tx;
    it("Should deploy contract", async function () {
        await resetFork(15173789);

        const params = [...deploymentParams];
        params[6] = "10000";
        [Vault, VaultAuction, VaultMath, VaultTreasury, VaultStorage] = await hardhatDeploy(governance, params);
        // await logBlock();

        const ContractHelper = await ethers.getContractFactory("V3Helper");
        contractHelper = await ContractHelper.deploy();
        await contractHelper.deployed();
    });

    it("preset", async function () {
        tx = await VaultStorage.connect(governance).setTimeAtLastRebalance(1648646662);
        await tx.wait();

        tx = await VaultStorage.connect(governance).setEthPriceAtLastRebalance("1791393578000000000000");
        await tx.wait();

        tx = await VaultStorage.connect(governance).setIvAtLastRebalance("1214682673158336601");
        await tx.wait();
    });

    it("swap", async function () {
        swapAmount = utils.parseUnits("100000000", 6).toString();
        await getUSDC(swapAmount, contractHelper.address, "0xcffad3200574698b78f32232aa9d63eabd290703");
        console.log("> WETH before swap:", await getERC20Balance(contractHelper.address, wethAddress));
        console.log("> USDC before swap:", await getERC20Balance(contractHelper.address, usdcAddress));

        // await logBlock();
        tx = await contractHelper.connect(swaper).swapUSDC_WETH(swapAmount);
        await tx.wait();
        await logBlock();

        console.log("> WETH after swap:", await getERC20Balance(contractHelper.address, wethAddress));
        console.log("> USDC after swap:", await getERC20Balance(contractHelper.address, usdcAddress));
        await mineSomeBlocks(105);
    });

    it("isPriceRebalance", async function () {
        let resp = await VaultMath.isPriceRebalance("15173902");
        console.log("Not valid block:", resp);

        resp = await VaultMath.isPriceRebalance("1658243810");
        console.log("Valid block:", resp);
    });
});
