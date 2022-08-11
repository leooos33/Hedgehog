// process.exit(0); // Block file in order to not accidentally deploy

const { ethers } = require("hardhat");
const { utils } = ethers;
const { BigNumber } = require("ethers");
const { _governanceAddress, _vaultAddress } = require("../test/common/index");

const withdraw = async () => {
    const user = _governanceAddress;
    let MyContract = await ethers.getContractFactory("Vault");
    const Vault = await MyContract.attach(_vaultAddress);
    let tx;

    console.log((await Vault.totalSupply()).toString());
    console.log((await Vault.balanceOf(user)).toString());

    // tx = await Vault.withdraw(eth, usdc, sqth, to, 0, 0, 0, {
    //     gasPrice: 8000000000,
    //     gasLimit: 900000,
    //     // nonce: 24,
    // });
    // await tx.wait();
};

withdraw().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
