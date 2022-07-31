//Link https://www.google.com/search?q=deploy+harhat+on+mainnet&oq=deploy+harhat+on+mainnet&aqs=chrome..69i57j33i10i160.4040j0j7&sourceid=chrome&ie=UTF-8#kpvalbx=_pfvXYtSVEqiF9u8Pj-ax0Ag14

const { ethers } = require("hardhat");
const { utils } = ethers;
const { BigNumber } = require("ethers");

const governance = "0x42B1299fCcA091A83C08C24915Be6E6d63906b1a";

const mainnetDeploymentParams = [
    utils.parseUnits("100", 18),
    BigNumber.from(43200),
    utils.parseUnits("0.1", 18),
    BigNumber.from("600"),
    BigNumber.from("950000000000000000"),
    BigNumber.from("1050000000000000000"),
    BigNumber.from("0"),
];

const hardhatDeployContractsInParallel = async (governance, params) => {
    const UniswapMath = await deployContract("UniswapMath", [], false);
    const Vault = await deployContract("Vault", [], true);
    const VaultAuction = await deployContract("VaultAuction", [], true);
    const VaultMath = await deployContract("VaultMath", [], false);
    const VaultTreasury = await deployContract("VaultTreasury", [], false);

    params.push(governance);
    const VaultStorage = await deployContract("VaultStorage", params);

    const arguments = [
        UniswapMath.address,
        Vault.address,
        VaultAuction.address,
        VaultMath.address,
        VaultTreasury.address,
        VaultStorage.address,
    ];
    console.log("UniswapMath:", arguments[0]);
    console.log("Vault:", arguments[1]);
    console.log("VaultAuction:", arguments[2]);
    console.log("VaultMath:", arguments[3]);
    console.log("VaultTreasury:", arguments[4]);
    console.log("VaultStorage:", arguments[5]);
};

const hardhatInitializeContracts = async () => {
    const Vault = await ethers.getContractAt("IFaucetHelper", "0x6894cf73D22B34fA2b30E5a4c706AD6c2f2b24ac");
    const VaultAuction = await ethers.getContractAt("IFaucetHelper", "0xA9a68eA2746793F43af0f827EC3DbBb049359067");
    const VaultMath = await ethers.getContractAt("IFaucetHelper", "0xfbcf638ea33a5f87d1e39509e7def653958fa9c4");
    const VaultTreasury = await ethers.getContractAt("IFaucetHelper", "0xf403970040e27613a45699c3a32d6be3751f0184");
    const VaultStorage = await ethers.getContractAt("IFaucetHelper", "0x60554f5064c4bb6cba563ad4066b22ab6a43c806");

    const arguments = [
        "0x61d3312e32f3f6f69ae5629d717f318bc4656abd", // UniswapMath Address
        Vault.address,
        VaultAuction.address,
        VaultMath.address,
        VaultTreasury.address,
        VaultStorage.address,
    ];
    console.log("UniswapMath:", arguments[0]);
    console.log("Vault:", arguments[1]);
    console.log("VaultAuction:", arguments[2]);
    console.log("VaultMath:", arguments[3]);
    console.log("VaultTreasury:", arguments[4]);
    console.log("VaultStorage:", arguments[5]);

    let tx;
    tx = await Vault.setComponents(...arguments);
    // await tx.wait();
    tx = await VaultAuction.setComponents(...arguments);
    // await tx.wait();
    tx = await VaultMath.setComponents(...arguments);
    // await tx.wait();
    tx = await VaultTreasury.setComponents(...arguments);
    // await tx.wait();
    tx = await VaultStorage.setComponents(...arguments);
    // await tx.wait();
};

const deployContract = async (name, params, deploy = true) => {
    console.log("Deploying ->", name);
    const Contract = await ethers.getContractFactory(name);
    let contract = await Contract.deploy(...params);
    if (deploy) {
        await contract.deployed();
    }
    return contract;
};

// hardhatInitializeContracts(governance, mainnetDeploymentParams).catch((error) => {
hardhatDeployContractsInParallel(governance, mainnetDeploymentParams).catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
