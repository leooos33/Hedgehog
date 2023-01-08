// process.exit(0); // Block file in order to not accidentally deploy

const { utils } = require("ethers");
const { ethers } = require("hardhat");
const {
    _cheapRebalancerV2,
    _vaultTreasuryAddressV2,
    _hedgehogRebalancerDeployerV2,
    wethAddress,
    _bigRebalancerEuler,
    _rebalanceModuleV2,
    _vaultStorageAddressV2,
} = require("../test/common/index");

let tx, ChepRebalancer, WETH;
const operation = async () => {
    MyContract = await ethers.getContractFactory("CheapRebalancer");
    ChepRebalancer = await MyContract.attach(_cheapRebalancerV2);
    WETH = await ethers.getContractAt("IWETH", wethAddress);
    MyContract = await ethers.getContractFactory("VaultStorage");
    VaultStorage = await MyContract.attach(_vaultStorageAddressV2);
    MyContract = await ethers.getContractFactory("BigRebalancerEuler");
    BigRebalancerEuler = await MyContract.attach(_bigRebalancerEuler);
    MyContract = await ethers.getContractFactory("BigRebalancer");
    BigRebalancer = await MyContract.attach(_rebalanceModuleV2);

    // await governanceOperations();
    await rebalanceOperations();
    // await collectToTreasuryOperations();
    // await collectToAddress();
    // await rebalanceManipulations();

    if (tx) console.log(tx);
};

const rebalanceManipulations = async () => {
    const gasPrice = 13 * 10 ** 9;

    // tx = await BigRebalancerEuler.addressStorage();
    // console.log(tx);

    // tx = await ChepRebalancer.callStatic.returnOwner(_hedgehogRebalancerDeployerV2, {
    //     gasLimit: 2000000,
    //     gasPrice,
    // });

    // tx = await BigRebalancerEuler.callStatic.transferOwnership(ChepRebalancer.address, {
    //     gasLimit: 2000000,
    //     gasPrice,
    // });

    // tx = await BigRebalancer.callStatic.setKeeper(BigRebalancerEuler.address, {
    //     gasLimit: 2000000,
    //     gasPrice,
    // });

    // tx = await ChepRebalancer.callStatic.setContracts(BigRebalancerEuler.address, {
    //     gasLimit: 2000000,
    //     gasPrice,
    // });
};
const governanceOperations = async () => {
    const gasPrice = 20 * 10 ** 9;

    // tx = await ChepRebalancer.callStatic.returnGovernance(_hedgehogRebalancerDeployerV2, {
    //     gasLimit: 2000000,
    //     gasPrice,
    // });

    // tx = await VaultStorage.callStatic.setAdjParam("100000000000000000", {
    //     gasLimit: 2000000,
    //     gasPrice,
    // });

    // tx = await VaultStorage.callStatic.setCap("228000000000000000000", {
    //     gasLimit: 2000000,
    //     gasPrice,
    // });

    // tx = await VaultStorage.callStatic.setGovernance(_cheapRebalancerV2, {
    //     gasLimit: 2000000,
    //     gasPrice,
    // });
};

const rebalanceOperations = async () => {
    let amount = await WETH.balanceOf(_rebalanceModuleV2);
    console.log("Total before", amount.toString());

    // const mul = "1100000000000000000";
    // const mul = "1000000000000000000";
    // const mul = "999900000000000000";
    // const mul = "999600000000000000";
    const mul = "999000000000000000";
    // const mul = "998500000000000000";
    // const mul = "998000000000000000";
    // const mul = "997500000000000000";
    // const mul = "997000000000000000";
    // const mul = "995000000000000000";
    // const mul = "990000000000000000";
    // const mul = "950000000000000000";
    tx = await ChepRebalancer.callStatic.rebalance("0", mul, {
        gasLimit: 4000000,
        gasPrice: 15 * 10 ** 9,
    });
};

// Accumulated fee
let fee = utils.parseUnits("0", 18);

const collectToTreasuryOperations = async () => {
    let amount = await WETH.balanceOf(_rebalanceModuleV2);
    console.log("Total", amount.toString());

    let partToSend = utils.parseUnits("0.35", 18);
    console.log("Send ", partToSend.toString());

    tx = await ChepRebalancer.collectProtocol(partToSend, "0", "0", _vaultTreasuryAddressV2, {
        gasLimit: 80000,
        gasPrice: 13 * 10 ** 9,
    });
};

const collectToAddress = async () => {
    let amount = await WETH.balanceOf(_rebalanceModuleV2);
    console.log("All", amount.toString());

    tx = await ChepRebalancer.collectProtocol(amount, "0", "0", _hedgehogRebalancerDeployerV2, {
        gasLimit: 80000,
        gasPrice: 18 * 10 ** 9,
    });
};

operation().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
