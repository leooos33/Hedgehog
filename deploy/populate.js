// process.exit(0); // Block file in order to not accidentally deploy

const { ethers } = require("hardhat");
const { _rebalancerAddress, _vaultAuctionAddress, _vaultMathAddress } = require("../test/common/index");

const populate = async () => {
    const MyContract = await ethers.getContractFactory("Rebalancer");
    const Rebalancer = await MyContract.attach(_rebalancerAddress);

    // let tx;
    // tx = await Rebalancer.setContracts(_vaultAuctionAddress, _vaultMathAddress, {
    //     gasLimit: 35000,
    //     // gasPrice: 6000000000,
    //     // nonce: 13,
    // });
    // await tx.wait();

    console.log(await Rebalancer.addressAuction());
};

populate().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
