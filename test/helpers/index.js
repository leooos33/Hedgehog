const { ethers, network } = require("hardhat");
const { utils, BigNumber } = ethers;
const csv = require('csvtojson');
const path = require('path');
const { wethAddress, usdcAddress, osqthAddress } = require('../common');

const gasToSend = 100812679875357878208;

async function getWETH(amount, account) {
    const wethAccountHolder = "0x2f0b23f53734252bda2277357e97e1517d6b042a";
    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [wethAccountHolder],
    });

    const signer = await ethers.getSigner(wethAccountHolder);

    const WETH = await ethers.getContractAt('IWETH', wethAddress);

    await network.provider.send("hardhat_setBalance", [
        signer.address,
        toHexdigital(gasToSend)
    ]);

    await WETH.connect(signer).transfer(account, amount);

    await network.provider.request({
        method: "hardhat_stopImpersonatingAccount",
        params: [wethAccountHolder],
    });
}

async function getUSDC(amount, account) {
    const wethAccountHolder = "0x2e6907a0ce523ccb5532ffea2e411df1eee26607";
    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [wethAccountHolder],
    });

    const signer = await ethers.getSigner(wethAccountHolder);

    const WETH = await ethers.getContractAt('IWETH', usdcAddress);

    await network.provider.send("hardhat_setBalance", [
        signer.address,
        toHexdigital(gasToSend)
    ]);

    await WETH.connect(signer).transfer(account, amount);

    await network.provider.request({
        method: "hardhat_stopImpersonatingAccount",
        params: [wethAccountHolder],
    });
}

async function getOSQTH(amount, account) {
    const wethAccountHolder = "0x94b86a218264c7c424c1476160d675a05ecb0b3d";
    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [wethAccountHolder],
    });

    const signer = await ethers.getSigner(wethAccountHolder);

    const WETH = await ethers.getContractAt('IWETH', osqthAddress);

    await network.provider.send("hardhat_setBalance", [
        signer.address,
        toHexdigital(gasToSend)
    ]);

    await WETH.connect(signer).transfer(account, amount);

    await network.provider.request({
        method: "hardhat_stopImpersonatingAccount",
        params: [wethAccountHolder],
    });
}

const toHexdigital = (amount) => {
    return "0x" + (amount).toString(16);
}

const getERC20Balance = async (account, tokenAddress) => {
    const WETH = await ethers.getContractAt('IWETH', tokenAddress);
    return (await WETH.balanceOf(account)).toString();
}

const approveERC20 = async (owner, account, amount, tokenAddress) => {
    const WETH = await ethers.getContractAt('IWETH', tokenAddress);
    await WETH.connect(owner).approve(account, amount);
}

const getERC20Allowance = async (owner, spender, tokenAddress) => {
    const WETH = await ethers.getContractAt('IWETH', tokenAddress);
    return (await WETH.allowance(owner, spender)).toString();
}

const loadTestDataset = async (name) => {
    const csvFilePath = path.join(__dirname, '../ds/', `${name}.csv`);
    const array = await csv().fromFile(csvFilePath);
    return array;
}

const toWEIS = (value, num = 18) => {
    // let [a, b] = value.split('.');
    // value = a + Math(b
    return utils.parseUnits(Number(value).toFixed(num), num).toString();
}

module.exports = {
    toWEIS,
    getOSQTH,
    approveERC20,
    getUSDC,
    getWETH,
    toHexdigital,
    getERC20Allowance,
    loadTestDataset,
    getERC20Balance,
}