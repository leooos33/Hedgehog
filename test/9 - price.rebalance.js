const { ethers } = require("hardhat");
const { utils } = ethers;
const { resetFork } = require("./helpers");

describe("VaultMath", function () {
    let contract, library, tx;
    it("Should deploy contract", async function () {
        await resetFork();

        const Library = await ethers.getContractFactory("UniswapAdaptor");
        library = await Library.deploy();
        await library.deployed();

        const Contract = await ethers.getContractFactory("Vault");
        contract = await Contract.deploy(
            utils.parseUnits("4000000000000", 18),
            10,
            utils.parseUnits("0.05", 18),
            "10",
            "900000000000000000",
            "1100000000000000000",
            "0",
            "1000",
            "1000"
        );
        await contract.deployed();
    });

    it("_isPriceRebalance", async function () {
        tx = await contract.setTimeAtLastRebalance("1648646626");
        await tx.wait();

        tx = await contract.setEthPriceAtLastRebalance("3391393578000000000000");
        await tx.wait();

        const resp = await contract._isPriceRebalance("1648646636");
        console.log(resp);
    });
});
