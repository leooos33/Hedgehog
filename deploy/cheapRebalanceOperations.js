process.exit(0); // Block file in order to not accidentally deploy

const { ethers } = require("hardhat");
const {
    _cheapRebalancerV2,
    _governanceAddressV2,
    _vaultTreasuryAddressV2,
    _hedgehogRebalancerDeployerV2,
    _vaultAuctionAddressV2,
    wethAddress,
    _rescueAddress,
} = require("../test/common/index");

const deposit = async () => {
    let MyContract = await ethers.getContractFactory("CheapRebalancer");
    const ChepRebalancer = await MyContract.attach(_cheapRebalancerV2);
    // tx = await ChepRebalancer.callStatic.returnGovernance(_governanceAddressV2);

    // tx = await ChepRebalancer.rebalance("0", "995000000000000000", {
    //     gasLimit: 4000000,
    //     gasPrice: 12 * 10 ** 9,
    // });

    // console.log(tx);
    // tx = await ChepRebalancer.collectProtocol("41519691772219230", "0", "0", _vaultTreasuryAddressV2, {
    //     gasLimit: 60000,
    //     gasPrice: 20 * 10 ** 9,
    // });
    // console.log(tx);
    //? Quick
    // let MyContract = await ethers.getContractFactory("VaultAuction");
    // const VaultAuction = await MyContract.attach(_vaultAuctionAddressV2);
    // tx = await VaultAuction.callStatic.timeRebalance(_hedgehogRebalancerDeployerV2, "0", "0", "0", {
    //     gasLimit: 4000000,
    //     gasPrice: 10 * 10 ** 9,
    // });
    // let WETH = await ethers.getContractAt("IWETH", wethAddress);
    // tx = await WETH.approve(_rescueAddress, 1, {
    //     gasLimit: 30000,
    //     gasPrice: 15 * 10 ** 9,
    //     nonce: 38,
    // });

    console.log(tx);
};

deposit().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
