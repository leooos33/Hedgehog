const { IFURA_KEY } = require("../shared/config");
const { providers } = require("ethers");
const { resetFork, logBlock } = require("../test/helpers");

const mainnetProvider = new providers.InfuraProvider(1, IFURA_KEY);

const getLastBlock = async () => (await mainnetProvider.getBlock("latest")).number - 100;

const run = async () => {
    let lastAvaliableBlock = await getLastBlock();
    // let lastAvaliableBlock = 15553753;
    await resetFork(lastAvaliableBlock);
    console.log("initialized:", lastAvaliableBlock);

    let prevBlock = lastAvaliableBlock;
    while (true) {
        prevBlock = await main(prevBlock);
        // console.log("!");
    }
};

run();

const main = async (prevBlock) => {
    let lastAvaliableBlock = await getLastBlock();
    // let lastAvaliableBlock = 15553754;
    if (lastAvaliableBlock == prevBlock) {
        return prevBlock;
    }

    console.log("updated:", lastAvaliableBlock);
    const block = await mainnetProvider.getBlockWithTransactions(lastAvaliableBlock);

    console.log(block.transactions.length);
    for (const tx of block.transactions) {
        console.log(tx.hash);
        await sendTxImpersonated(tx);
    }

    console.log("done");
    await network.provider.send("evm_mine");
    // await hre.network.provider.request({
    //     method: "evm_mine",
    // });
    console.log("done");
    await logBlock();

    return lastAvaliableBlock;
};

const sendTxImpersonated = async (tx) => {
    try {
        // console.log(tx);
        const { from, gasPrice, gasLimit, to, value, nonce, data } = tx;
        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [from],
        });
        const fromActor = await ethers.getSigner(from);

        // console.log("impersonated!");

        await fromActor.sendTransaction({
            // gasPrice,
            // gasLimit,
            to,
            value,
            nonce,
            data,
        });
        // console.log(tx);
    } catch (err) {
        console.log(err);
        console.log(tx);
    }
};
