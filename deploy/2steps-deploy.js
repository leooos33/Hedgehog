//Link https://www.google.com/search?q=deploy+harhat+on+mainnet&oq=deploy+harhat+on+mainnet&aqs=chrome..69i57j33i10i160.4040j0j7&sourceid=chrome&ie=UTF-8#kpvalbx=_pfvXYtSVEqiF9u8Pj-ax0Ag14

process.exit(0); // Block file in order to not accidentally deploy

const { ethers } = require("hardhat");
const { utils } = ethers;
const { BigNumber } = require("ethers");
const {
    _governanceAddress,
    _vaultAddress,
    _vaultAuctionAddress,
    _vaultMathAddress,
    _vaultTreasuryAddress,
    _vaultStorageAddress,
    _uniMathAddress,
} = require("../test/common/index");

const governance = _governanceAddress;

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
    // const UniswapMath = await deployContract("UniswapMath", [], false); //? Omited due to its existing
    const Vault = await deployContract("Vault", [], false);
    const VaultAuction = await deployContract("VaultAuction", [], false);
    const VaultMath = await deployContract("VaultMath", [], false);
    const VaultTreasury = await deployContract("VaultTreasury", [], false);

    params.push(governance);
    const VaultStorage = await deployContract("VaultStorage", params, false);

    const arguments = [
        _uniMathAddress,
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
    const Vault = await ethers.getContractAt("IFaucetHelper", _vaultAddress);
    const VaultAuction = await ethers.getContractAt("IFaucetHelper", _vaultAuctionAddress);
    const VaultMath = await ethers.getContractAt("IFaucetHelper", _vaultMathAddress);
    const VaultTreasury = await ethers.getContractAt("IFaucetHelper", _vaultTreasuryAddress);
    const VaultStorage = await ethers.getContractAt("IFaucetHelper", _vaultStorageAddress);

    const arguments = [
        _uniMathAddress, // UniswapMath Address
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
hardhatInitializeContracts(governance, mainnetDeploymentParams).catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
