process.exit(0); // Block file in order to not accidentally deploy

const { ethers } = require("hardhat");
const { utils } = ethers;
const { BigNumber } = require("ethers");
const { _rebalancerAddress, _vaultAuctionAddress, _vaultMathAddress } = require("../../test/common/index");

const deposit = async () => {
    let tx;
    let MyContract = await ethers.getContractFactory("VaultAuction");
    const VaultAuction = await MyContract.attach(_vaultAuctionAddress);

    const accounts = await hre.ethers.getSigners();
    const actor = accounts[0];

    console.log(actor.address);
    tx = await VaultAuction.timeRebalance(actor.address, 0, 0, 0, {
        gasLimit: 3100000,
        gasPrice: 8 * 10 ** 9,
        // nonce: 38,
    });
    await tx.wait();
};

deposit().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
