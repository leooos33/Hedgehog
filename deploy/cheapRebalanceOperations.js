process.exit(0); // Block file in order to not accidentally deploy

const { ethers } = require("hardhat");
const {
    _cheapRebalancerV2,
    _governanceAddressV2,
    _vaultTreasuryAddressV2,
    _hedgehogRebalancerDeployerV2,
} = require("../test/common/index");

const deposit = async () => {
    let MyContract = await ethers.getContractFactory("CheapRebalancer");
    const ChepRebalancer = await MyContract.attach(_cheapRebalancerV2);

    // tx = await ChepRebalancer.returnGovernance(_governanceAddressV2);

    // tx = await ChepRebalancer.rebalance("0", "998000000000000000", {
    //     gasLimit: 4000000,
    //     gasPrice: 6000000000,
    // });
    // console.log(tx);

    // tx = await ChepRebalancer.collectProtocol("62419207589797136", "0", "0", _vaultTreasuryAddressV2, {
    //     gasLimit: 60000,
    //     gasPrice: 12000000000,
    // });
    // console.log(tx);
};

deposit().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
