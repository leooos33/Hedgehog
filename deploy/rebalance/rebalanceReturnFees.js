process.exit(0); // Block file in order to not accidentally deploy

const { ethers } = require("hardhat");
const { _bigRebalancerV2 } = require("../../test/common/index");

const deposit = async () => {
    let tx;
    let MyContract = await ethers.getContractFactory("BigRebalancer");
    const Rebalancer = await MyContract.attach(_bigRebalancerV2);

    tx = await Rebalancer.collectProtocol("186708919967578312", 0, 0, "0x12804580C15F4050dda61D44AFC94623198848bC");
    await tx.wait();
};

deposit().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
