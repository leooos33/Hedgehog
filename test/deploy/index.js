const { ethers } = require("hardhat");
const { utils } = ethers;

const deploymentParams = [
    utils.parseUnits("4000000000000", 18),
    10,
    utils.parseUnits("0.05", 18),
    "10",
    "900000000000000000",
    "1100000000000000000",
    "0",
    "1000",
    "1000"
];

const hardhatDeploy = async (governance, params) => {
    await network.provider.send("evm_setAutomine", [false]);

    const UniswapMath = await deployContract("UniswapMath", [], false);
    const Vault = await deployContract("Vault", params, false);
    const VaultMath = await deployContract("VaultMath", params, false);
    const VaultTreasury = await deployContract("VaultTreasury", [], false);

    console.log(UniswapMath.address);
    console.log(Vault.address);
    console.log(VaultMath.address);
    console.log(VaultTreasury.address);

    await network.provider.request({
        method: "evm_mine",
    });
    {
        let tx;
        tx = await Vault
            .setComponents(UniswapMath.address, Vault.address, VaultMath.address, VaultTreasury.address, governance.address);
        // await tx.wait();

        tx = await VaultMath
            .setComponents(UniswapMath.address, Vault.address, VaultMath.address, VaultTreasury.address, governance.address);
        // await tx.wait();

        tx = await VaultTreasury
            .setComponents(UniswapMath.address, Vault.address, VaultMath.address, VaultTreasury.address, governance.address);
        // await tx.wait();
    }
    await network.provider.request({
        method: "evm_mine",
    });
    await network.provider.send("evm_setAutomine", [true]);

    return [
        Vault,
        VaultMath,
        VaultTreasury
    ];
}

const deployContract = async (name, params, deploy = true) => {
    const Contract = await ethers.getContractFactory(name);
    let contract = await Contract.deploy(...params);
    if (deploy) {
        await contract.deployed();
    }
    return contract;
}

module.exports = {
    deploymentParams, hardhatDeploy, deployContract
};