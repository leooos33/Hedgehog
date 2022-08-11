process.exit(0); // Block file in order to not accidentally deploy

const { ethers } = require("hardhat");
const { utils } = ethers;
const { BigNumber } = require("ethers");
const { _rebalancerAddress } = require("../test/common/index");

const deposit = async () => {
    let MyContract = await ethers.getContractFactory("Rebalancer");
    const Rebalancer = await MyContract.attach(_rebalancerAddress);
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
