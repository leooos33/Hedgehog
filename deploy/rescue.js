// process.exit(0); // Block file in order to not accidentally deploy

const { assert } = require("chai");
const {
    _rebalancerAddress,
    _rescueAddress,
    _governanceAddress,
    _vaultTreasuryAddress,
    _vaultStorageAddress,
    wethAddress,
    usdcAddress,
    osqthAddress,
    _rebalancerBigAddress,
} = require("../test/common/index");

const { getERC20Balance } = require("../test/helpers/tokenHelpers");

const main = async () => {
    let MyContract = await ethers.getContractFactory("BigRebalancer");
    const Rebalancer = await MyContract.attach(_rebalancerBigAddress);

    MyContract = await ethers.getContractFactory("RescueTeam");
    const Rescue = await MyContract.attach(_rescueAddress);

    MyContract = await ethers.getContractFactory("VaultStorage");
    const VaultStorage = await MyContract.attach(_vaultStorageAddress);

    const accounts = await hre.ethers.getSigners();
    const gov = accounts[0];

    if (gov.address != _governanceAddress) process.exit(1);

    // tx = await Rebalancer.transferOwnership(_rescueAddress, {
    //     gasLimit: 300000,
    //     gasPrice: 8 * 10 ** 9,
    // });
    // await tx.wait();

    // tx = await Rescue.rebalance({
    //     gasLimit: 3000000,
    //     gasPrice: 5 * 10 ** 9,
    // });
    // await tx.wait();

    // tx = await Rescue.stepTwo({
    //     gasLimit: 3000000,
    //     gasPrice: 5 * 10 ** 9,
    // });
    // await tx.wait();

    // tx = await Rescue.timeRebalance({
    //     gasLimit: 3000000,
    //     gasPrice: 6 * 10 ** 9,
    // });
    // await tx.wait();

    // tx = await Rescue.collectProtocol("107381526272399979", 0, 0, gov.address, {
    //     gasLimit: 3000000,
    //     gasPrice: 4 * 10 ** 9,
    // });
    // await tx.wait();

    // console.log((await Rescue.owner()) == gov.address);
    // console.log((await Rebalancer.owner()) == _rescueAddress);
    // console.log((await VaultStorage.governance()) == _rescueAddress);

    console.log("> Treasury WETH %s", await getERC20Balance(_vaultTreasuryAddress, wethAddress));
    console.log("> Treasury USDC %s", await getERC20Balance(_vaultTreasuryAddress, usdcAddress));
    console.log("> Treasury oSQTH %s", await getERC20Balance(_vaultTreasuryAddress, osqthAddress));

    console.log("> Governance WETH %s", await getERC20Balance(_governanceAddress, wethAddress));
    console.log("> Governance USDC %s", await getERC20Balance(_governanceAddress, usdcAddress));
    console.log("> Governance oSQTH %s", await getERC20Balance(_governanceAddress, osqthAddress));

    console.log("> Rebalancer WETH %s", await getERC20Balance(Rebalancer.address, wethAddress));
    console.log("> Rebalancer USDC %s", await getERC20Balance(Rebalancer.address, usdcAddress));
    console.log("> Rebalancer oSQTH %s", await getERC20Balance(Rebalancer.address, osqthAddress));

    console.log("> Rescue WETH %s", await getERC20Balance(Rescue.address, wethAddress));
    console.log("> Rescue USDC %s", await getERC20Balance(Rescue.address, usdcAddress));
    console.log("> Rescue oSQTH %s", await getERC20Balance(Rescue.address, osqthAddress));
};
main();
