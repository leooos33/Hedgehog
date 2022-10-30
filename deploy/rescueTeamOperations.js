process.exit(0); // Block file in order to not accidentally deploy
const {
    _rescueAddress,
    wethAddress,
    _vaultTreasuryAddressV2,
    _hedgehogRebalancerDeployerV2,
} = require("../test/common/index");

const deploy = async () => {
    MyContract = await ethers.getContractFactory("RescueTeam");
    const RescueTeam = await MyContract.attach(_rescueAddress);

    // tx = await RescueTeam.timeRebalance({
    //     gasLimit: 3000000,
    //     gasPrice: 7 * 10 ** 9,
    // });
    // console.log(tx);

    // tx = await RescueTeam.collectProtocol("148600372900059973", "136000000", "0", _hedgehogRebalancerDeployerV2, {
    //     gasLimit: 90000,
    //     gasPrice: 8 * 10 ** 9,
    // });
    // console.log(tx);
};

deploy().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
