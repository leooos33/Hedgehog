const { ethers } = require("hardhat");
const { utils } = ethers;

const governance = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";

const deploymentParams = [
    utils.parseUnits("4000000000000", 18),
    10,
    utils.parseUnits("0.05", 18),
    "10",
    "950000000000000000",
    "1050000000000000000",
    "0",
    "1000",
    "1000",
];

const hardhatDeploy = async (governance, params) => {
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
        governance,
    ];
    console.log("UniswapMath:", arguments[0]);
    console.log("Vault:", arguments[1]);
    console.log("VaultAuction:", arguments[2]);
    console.log("VaultMath:", arguments[3]);
    console.log("VaultTreasury:", arguments[4]);
    console.log("VaultStorage:", arguments[5]);

    let tx;

    tx = await Vault.setComponents(...arguments);
    await tx.wait();

    tx = await VaultAuction.setComponents(...arguments);
    await tx.wait();

    tx = await VaultMath.setComponents(...arguments);
    await tx.wait();

    tx = await VaultTreasury.setComponents(...arguments);
    await tx.wait();

    tx = await VaultStorage.setComponents(...arguments);
    await tx.wait();
};

const deployContract = async (name, params, deploy = true) => {
    const Contract = await ethers.getContractFactory(name);
    let contract = await Contract.deploy(...params);
    if (deploy) {
        await contract.deployed();
    }
    return contract;
};

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
hardhatDeploy(governance, deploymentParams).catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

//Link https://www.google.com/search?q=deploy+harhat+on+mainnet&oq=deploy+harhat+on+mainnet&aqs=chrome..69i57j33i10i160.4040j0j7&sourceid=chrome&ie=UTF-8#kpvalbx=_pfvXYtSVEqiF9u8Pj-ax0Ag14
