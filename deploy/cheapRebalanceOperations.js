process.exit(0); // Block file in order to not accidentally deploy

const { ethers } = require("hardhat");
const { _cheapRebalancerV2, _governanceAddressV2, _vaultTreasuryAddressV2 } = require("../test/common/index");

const deposit = async () => {
    let MyContract = await ethers.getContractFactory("CheapRebalancer");
    const ChepRebalancer = await MyContract.attach(_cheapRebalancerV2);

    // tx = await ChepRebalancer.returnGovernance(_governanceAddressV2);

    // tx = await ChepRebalancer.rebalance("0", "950000000000000000", {
    //     nonce: 18,
    //     gasLimit: 4000000,
    // });

    // tx = await ChepRebalancer.collectProtocol("1483167730391756966", "0", "0", _vaultTreasuryAddressV2);
    // console.log(tx);
};

deposit().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
