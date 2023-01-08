process.exit(0); // Block file in order to not accidentally deploy

const { ethers } = require("hardhat");
const { utils } = ethers;
const { BigNumber } = require("ethers");
const { _governanceAddress, _harhatAccount1, _harhatAccount7 } = require("../test/common/index");
const { deployContract } = require("./common");

const governance = _governanceAddress;
// const governance = _harhatAccount1;
// const governance = _harhatAccount7;

const mainnetDeploymentParams = [
    utils.parseUnits("100", 18),
    BigNumber.from(43200),
    utils.parseUnits("0.1", 18),
    BigNumber.from("600"),
    BigNumber.from("950000000000000000"),
    BigNumber.from("1050000000000000000"),
    BigNumber.from("0"),
];

mainnetDeploymentParams.map((i) => console.log(i.toString()));

const hardhatDeploy = async (governance, keeper, params) => {
    const UniswapMath = await deployContract("UniswapMath", []);
    const Vault = await deployContract("Vault", []);
    const VaultAuction = await deployContract("VaultAuction", []);
    const VaultMath = await deployContract("VaultMath", []);
    const VaultTreasury = await deployContract("VaultTreasury", []);

    params.push(governance);
    params.push(keeper);
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

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
hardhatDeploy(governance, governance, mainnetDeploymentParams).catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

// Link https://www.google.com/search?q=deploy+harhat+on+mainnet&oq=deploy+harhat+on+mainnet&aqs=chrome..69i57j33i10i160.4040j0j7&sourceid=chrome&ie=UTF-8#kpvalbx=_pfvXYtSVEqiF9u8Pj-ax0Ag14
