const { ethers } = require("hardhat");
const { resetFork, logBlock } = require("./helpers");
const { hardhatDeploy, deploymentParams } = require("./deploy");

describe("VaultMath", function () {
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
        await resetFork();

        const params = [...deploymentParams];
        [Vault, VaultAuction, VaultMath, VaultTreasury, VaultStorage] = await hardhatDeploy(governance, params);
        await logBlock();
        //14487789 1648646654

        const ContractHelper = await ethers.getContractFactory("V3Helper");
        contractHelper = await ContractHelper.deploy();
        await contractHelper.deployed();
    });

    it("_isPriceRebalance", async function () {
        tx = await VaultStorage.setTimeAtLastRebalance("1648646626");
        await tx.wait();

        tx = await VaultStorage.setEthPriceAtLastRebalance("3391393578000000000000");
        await tx.wait();

        const resp = await VaultMath._isPriceRebalance("1648646636");
        console.log(resp);
    });
});
