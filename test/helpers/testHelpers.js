const { ethers } = require("hardhat");
const { utils } = ethers;
const csv = require("csvtojson");
const path = require("path");
const { getResetParams } = require("../../hardhat.helpers");
const { wethAddress, osqthAddress, usdcAddress } = require("../common");
const { getERC20Balance } = require('./tokenHelpers');

const loadTestDataset = async (name) => {
    const csvFilePath = path.join(__dirname, "../ds/", `${name}.csv`);
    const array = await csv().fromFile(csvFilePath);
    return array;
};

const toWEIS = (value, num = 18) => {
    return utils.parseUnits(Number(value).toFixed(num), num).toString();
};

const toWEI = (value, num = 18) => {
    return utils.parseUnits(Number(value).toFixed(num), num);
};

const assertWP = (a, b, pres = 4, num = 18) => {
    const getTail = (value, pres, num) => {
        const decimals = value.slice(-num);

        const _pres = Math.max(0, decimals.length - pres);
        const tail = Math.round(Number(decimals) / 10 ** _pres);

        // console.debug("debug:", decimals);
        // console.debug("debug:", tail);

        return tail;
    };

    if (getTail(a, pres, num) == getTail(b, pres, num)) return true;

    console.log("current  >>>", utils.formatUnits(a, num));
    console.log("current  >>>", a);
    console.log("expected >>>", utils.formatUnits(b, num));
    console.log("expected >>>", b);

    return false;
};

const resetFork = async () => {
    await network.provider.request({
        method: "hardhat_reset",
        params: [
            {
                forking: getResetParams(),
            },
        ],
    });
};

const logBlock = async () => {
    const blockNumBefore = await ethers.provider.getBlockNumber();
    const blockBefore = await ethers.provider.getBlock(blockNumBefore);
    const timestampBefore = blockBefore.timestamp;
    console.log(blockNumBefore, timestampBefore);
};

const logBalance = async (address) => {
    console.log(await getERC20Balance(address, wethAddress));
    console.log(await getERC20Balance(address, usdcAddress));
    console.log(await getERC20Balance(address, osqthAddress));
}

module.exports = {
    logBalance,
    logBlock,
    resetFork,
    assertWP,
    toWEIS,
    toWEI,
    loadTestDataset,
};
