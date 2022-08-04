const { ethers } = require("hardhat");
const { utils, BigNumber } = ethers;

const mainnetDeploymentParams = [
    utils.parseUnits("100", 18),
    BigNumber.from(43200),
    utils.parseUnits("0.1", 18),
    BigNumber.from("1200"),
    BigNumber.from("950000000000000000"),
    BigNumber.from("1050000000000000000"),
    BigNumber.from("0"),
];

const deploymentParams = mainnetDeploymentParams;

const hardhatDeploy = async (governance, params) => {
    await network.provider.send("evm_setAutomine", [false]);

    const UniswapMath = await deployContract("UniswapMath", [], false);

    const Vault = await deployContract("Vault", [], false);
    const VaultAuction = await deployContract("VaultAuction", [], false);
    const VaultMath = await deployContract("VaultMath", [], false);
    const VaultTreasury = await deployContract("VaultTreasury", [], false);

    params.push(governance.address);
    const VaultStorage = await deployContract("VaultStorage", params, false);

    const arguments = [
        UniswapMath.address,
        Vault.address,
        VaultAuction.address,
        VaultMath.address,
        VaultTreasury.address,
        VaultStorage.address,
    ];

    console.log("> UniswapMath:", arguments[0]);
    console.log("> Vault:", arguments[1]);
    console.log("> VaultAuction:", arguments[2]);
    console.log("> VaultMath:", arguments[3]);
    console.log("> VaultTreasury:", arguments[4]);
    console.log("> VaultStorage:", arguments[5]);

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

const hardhatInitializeDeploed = async () => {
    return [
        await ethers.getContractAt("IVault", "0x6894cf73D22B34fA2b30E5a4c706AD6c2f2b24ac"),
        await ethers.getContractAt("IAuction", "0xA9a68eA2746793F43af0f827EC3DbBb049359067"),
        await ethers.getContractAt("IVaultMath", "0xfbcf638ea33a5f87d1e39509e7def653958fa9c4"),
        await ethers.getContractAt("IVaultTreasury", "0xf403970040e27613a45699c3a32d6be3751f0184"),
        await ethers.getContractAt(
            "contracts/interfaces/IVaultStorage.sol:IVaultStorage",
            "0x60554f5064c4bb6cba563ad4066b22ab6a43c806"
        ),
    ];
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
    hardhatInitializeDeploed,
    deploymentParams,
    hardhatDeploy,
    deployContract,
};
