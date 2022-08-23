const {
    getOSQTH,
    approveERC20,
    getUSDC,
    getWETH,
    toHexdigital,
    getERC20Allowance,
    getERC20Balance,
    getAndApprove,
    getAndApprove2,
    getSnapshot,
} = require("./tokenHelpers");

const { toWEIS, toWEI, loadTestDataset, assertWP, resetFork, logBlock, logBalance } = require("./testHelpers");

const mineSomeBlocks = async (blocksToMine) => {
    await logBlock();
    await hre.network.provider.send("hardhat_mine", [`0x${blocksToMine.toString(16)}`]);
    console.log(`${blocksToMine} blocks was mine`);
    await logBlock();
};

module.exports = {
    getSnapshot,
    mineSomeBlocks,
    logBalance,
    logBlock,
    getAndApprove,
    getAndApprove2,
    resetFork,
    assertWP,
    toWEIS,
    toWEI,
    getOSQTH,
    approveERC20,
    getUSDC,
    getWETH,
    toHexdigital,
    getERC20Allowance,
    loadTestDataset,
    getERC20Balance,
};
