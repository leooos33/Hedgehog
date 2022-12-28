// process.exit(0); // Block file in order to not accidentally deploy

const { util } = require("chai");
const { BigNumber, utils } = require("ethers");
const { ethers } = require("hardhat");
const {
    _cheapRebalancerV2,
    _governanceAddressV2,
    _vaultTreasuryAddressV2,
    _hedgehogRebalancerDeployerV2,
    _vaultAuctionAddressV2,
    wethAddress,
    _rescueAddress,
    _bigRebalancerV2,
    _vaultStorageAddressV2,
} = require("../test/common/index");

let tx, ChepRebalancer, WETH;
const operation = async () => {
    MyContract = await ethers.getContractFactory("CheapRebalancer");
    ChepRebalancer = await MyContract.attach(_cheapRebalancerV2);
    WETH = await ethers.getContractAt("IWETH", wethAddress);
    MyContract = await ethers.getContractFactory("VaultStorage");
    VaultStorage = await MyContract.attach(_vaultStorageAddressV2);

    // await governanceOperations();
    // await rebalanceOperations();
    // await collectToTreasuryOperations();
    await collectToAddress();

    if (tx) console.log(tx);
};

const governanceOperations = async () => {
    const gasPrice = 13 * 10 ** 9;

    // tx = await ChepRebalancer.callStatic.returnGovernance(_hedgehogRebalancerDeployerV2, {
    //     gasLimit: 2000000,
    //     gasPrice,
    // });

    // tx = await VaultStorage.callStatic.setAdjParam("100000000000000000", {
    //     gasLimit: 2000000,
    //     gasPrice,
    // });

    // tx = await VaultStorage.callStatic.setGovernance(_cheapRebalancerV2, {
    //     gasLimit: 2000000,
    //     gasPrice,
    // });
};

const rebalanceOperations = async () => {
    let amount = await WETH.balanceOf(_bigRebalancerV2);
    console.log("Total before", amount.toString());

    // const mul = "999900000000000000";
    // const mul = "999000000000000000";
    // const mul = "998500000000000000";
    // const mul = "998000000000000000";
    // const mul = "997500000000000000";
    // const mul = "997000000000000000";
    // const mul = "995000000000000000";
    // const mul = "990000000000000000";
    // const mul = "950000000000000000";
    tx = await ChepRebalancer.callStatic.rebalance("0", mul, {
        gasLimit: 4000000,
        gasPrice: 12 * 10 ** 9,
    });
};

// Accumulated fee
let fee = utils
    .parseUnits("0.03784263", 18)
    .add(utils.parseUnits("0.033652021", 18))
    .add(utils.parseUnits("0.02958276", 18));

const collectToTreasuryOperations = async () => {
    let amount = await WETH.balanceOf(_bigRebalancerV2);
    console.log("Total", amount.toString());

    let partToSend = utils.parseUnits("0.35", 18);
    console.log("Send ", partToSend.toString());

    tx = await ChepRebalancer.collectProtocol(partToSend, "0", "0", _vaultTreasuryAddressV2, {
        gasLimit: 80000,
        gasPrice: 13 * 10 ** 9,
    });
};

const collectToAddress = async () => {
    let amount = await WETH.balanceOf(_bigRebalancerV2);
    console.log("All", amount.toString());

    tx = await ChepRebalancer.callStatic.collectProtocol(amount, "0", "0", _hedgehogRebalancerDeployerV2, {
        gasLimit: 80000,
        gasPrice: 15 * 10 ** 9,
    });
};

const allOld = async () => {
    // let tx;
    // let MyContract = await ethers.getContractFactory("CheapRebalancer");
    // const ChepRebalancer = await MyContract.attach(_cheapRebalancerV2);
    // console.log(amount.toString());
    // tx = await ChepRebalancer.callStatic.returnGovernance(_governanceAddressV2);
    // const mul = "995000000000000000";
    // const mul = "990000000000000000";
    // const mul = "950000000000000000";
    // tx = await ChepRebalancer.callStatic.rebalance("0", mul, {
    //     gasLimit: 4000000,
    //     gasPrice: 10 * 10 ** 9,
    // });
    // console.log(tx);
    // const WETH = await ethers.getContractAt("IWETH", wethAddress);
    // let amount = await WETH.balanceOf(_bigRebalancerV2);
    // console.log("Total", amount.toString());
    // let was = utils.parseUnits("0", 18);
    // let fee = utils.parseUnits("0.02502623", 18);
    // let partToSend = amount.sub(was).sub(fee);
    // // let partToSend = amount.mul(BigNumber.from(send)).div(BigNumber.from(now));
    // console.log("Send ", partToSend);
    // tx = await ChepRebalancer.collectProtocol(amount, "0", "0", _hedgehogRebalancerDeployerV2, {
    //     gasLimit: 80000,
    //     gasPrice: 10 * 10 ** 9,
    // });
    // tx = await ChepRebalancer.callStatic.collectProtocol(partToSend, "0", "0", _vaultTreasuryAddressV2, {
    //     gasLimit: 80000,
    //     gasPrice: 11 * 10 ** 9,
    // });
    // console.log(tx);
    //? Quick
    // let MyContract = await ethers.getContractFactory("VaultAuction");
    // const VaultAuction = await MyContract.attach(_vaultAuctionAddressV2);
    // tx = await VaultAuction.callStatic.timeRebalance(_hedgehogRebalancerDeployerV2, "0", "0", "0", {
    //     gasLimit: 4000000,
    //     gasPrice: 10 * 10 ** 9,
    // });
    // tx = await WETH.approve(_rescueAddress, 1, {
    //     gasLimit: 30000,
    //     gasPrice: 15 * 10 ** 9,
    //     nonce: 38,
    // });
};

operation().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
//
