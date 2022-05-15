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
    "1000",
];

const hardhatDeploy = async (governance, params) => {
    await network.provider.send("evm_setAutomine", [false]);

    const UniswapMath = await deployContract("UniswapMath", [], false);

    const Vault = await deployContract("Vault", [], false);
    const VaultAuction = await deployContract("VaultAuction", [], false);
    const VaultMath = await deployContract("VaultMath", [], false);
    const VaultTreasury = await deployContract("VaultTreasury", [], false);
    const VaultStorage = await deployContract("VaultStorage", params, false);

    const arguments = [
        UniswapMath.address,
        Vault.address,
        VaultAuction.address,
        VaultMath.address,
        VaultTreasury.address,
        VaultStorage.address,
        governance.address,
    ];
    console.log(arguments);

    await network.provider.request({
        method: "evm_mine",
    });
    {
        let tx;

        tx = await Vault.setComponents(...arguments);

        tx = await VaultAuction.setComponents(...arguments);

        tx = await VaultMath.setComponents(...arguments);

        tx = await VaultTreasury.setComponents(...arguments);

        tx = await VaultStorage.setComponents(...arguments);
    }
    await network.provider.request({
        method: "evm_mine",
    });
    await network.provider.send("evm_setAutomine", [true]);

    return [Vault, VaultAuction, VaultMath, VaultTreasury, VaultStorage];
};

const deployContract = async (name, params, deploy = true) => {
    const Contract = await ethers.getContractFactory(name);
    let contract = await Contract.deploy(...params);
    if (deploy) {
        await contract.deployed();
    }
    return contract;
};

module.exports = {
    deploymentParams,
    hardhatDeploy,
    deployContract,
};
