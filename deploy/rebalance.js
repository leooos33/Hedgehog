process.exit(0); // Block file in order to not accidentally deploy

const { ethers } = require("hardhat");
const { utils } = ethers;
const { BigNumber } = require("ethers");

const deposit = async () => {
    let MyContract = await ethers.getContractFactory("Rebalancer");
    const Rebalancer = await MyContract.attach("0x09b1937D89646b7745377f0fcc8604c179c06aF5");
    console.log(await Rebalancer.addressAuction());

    let tx;
    tx = await Rebalancer.rebalance(0, {
        gasLimit: 3100000,
        gasPrice: 15 * 10 ** 9,
        nonce: 28,
    });
    await tx.wait();
};

deposit().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
