// process.exit(0); // Block file in order to not accidentally deploy

const { ethers } = require("hardhat");
const { utils } = ethers;
const { BigNumber } = require("ethers");

const withdraw = async () => {
    const user = "0x42B1299fCcA091A83C08C24915Be6E6d63906b1a";
    let MyContract = await ethers.getContractFactory("Vault");
    const Vault = await MyContract.attach("0x6894cf73D22B34fA2b30E5a4c706AD6c2f2b24ac");
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
