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
    const UniswapMath = await deployContract("UniswapMath", []);
    const Vault = await deployContract("Vault", [...params, governance.address]);
    const VaultMath = await deployContract("VaultMath", params);
    const VaultTreasury = await deployContract("VaultTreasury", []);
    console.log(UniswapMath.address);
    console.log(Vault.address);
    console.log(VaultMath.address);
    console.log(VaultTreasury.address);

    {
        let tx;
        tx = await Vault
            .setComponents(UniswapMath.address, Vault.address, VaultMath.address, VaultTreasury.address);
        await tx.wait();

        tx = await VaultMath
            .setComponents(UniswapMath.address, Vault.address, VaultMath.address, VaultTreasury.address);
        await tx.wait();

        tx = await VaultTreasury
            .setComponents(UniswapMath.address, Vault.address, VaultMath.address, VaultTreasury.address);
        await tx.wait();
    }

    return [
        Vault,
        VaultMath,
        VaultTreasury
    ];
}

const deployContract = async (name, params) => {
    const Contract = await ethers.getContractFactory(name);
    let contract = await Contract.deploy(...params);
    await contract.deployed();
    return contract;
}

module.exports = {
    deploymentParams, hardhatDeploy, deployContract
};