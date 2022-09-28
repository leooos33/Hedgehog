process.exit(0); // Block file in order to not accidentally deploy

const { ethers } = require("hardhat");
const { utils } = ethers;
const { BigNumber } = require("ethers");
const { _rebalancerAddress, _vaultAuctionAddress, _vaultMathAddress } = require("../test/common/index");

const deposit = async () => {
    let tx;
    let MyContract = await ethers.getContractFactory("Rebalancer");
    const Rebalancer = await MyContract.attach(_rebalancerAddress);

    console.log("addressAuction:", await Rebalancer.addressAuction());
    console.log("addressMath:", await Rebalancer.addressMath());

    //? if you need to change contracts
    // tx = await Rebalancer.setContracts(_vaultAuctionAddress, _vaultMathAddress, {
    //     gasLimit: 3100000,
    //     gasPrice: 6 * 10 ** 9,
    // });
    // await tx.wait();

    tx = await Rebalancer.rebalance(0, {
        gasLimit: 3100000,
        gasPrice: 5 * 10 ** 9,
        nonce: 38,
    });
    await tx.wait();
};

deposit().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
