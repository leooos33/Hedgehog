process.exit(0); // Block file in order to not accidentally deploy

const { ethers } = require("hardhat");
const { utils } = ethers;
const { BigNumber } = require("ethers");
const { _bigRebalancerV2 } = require("../../test/common/index");

const deposit = async () => {
    let tx;
    let MyContract = await ethers.getContractFactory("BigRebalancer");
    const Rebalancer = await MyContract.attach(_bigRebalancerV2);

    console.log("addressAuction:", await Rebalancer.addressAuction());
    console.log("addressMath:", await Rebalancer.addressMath());

    tx = await Rebalancer.rebalance(0, 0, {
        gasLimit: 4000000,
    });
    await tx.wait();
};

deposit().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
