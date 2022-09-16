const { IFURA_KEY } = require("../shared/config");
const { providers } = require("ethers");
const { resetFork, logBlock } = require("../test/helpers");

const mainnetProvider = new providers.InfuraProvider(1, IFURA_KEY);

let initialized;

// mainnetProvider.on("block", async (blockNumber) => {
//     blockNumber -= 5;

// });

const main = async () => {
    blockNumber = 15534588;
    await resetFork(blockNumber);
    console.log("initialized:", blockNumber);

    blockNumber = 15534589;
    console.log("updated:", blockNumber);
    const block = await mainnetProvider.getBlock(blockNumber);

    for (const txhash of block.transactions) {
        console.log(txhash);
        const tx = await mainnetProvider.getTransaction(txhash);
        await sendTxImpersonated(tx);
    }

    await hre.network.provider.request({
        method: "evm_mine",
    });
    await logBlock();
    // console.log(tx);
};

main();

const sendTxImpersonated = async (tx) => {
    const { from, gasPrice, gasLimit, to, value, nonce, data } = tx;
    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [from],
    });
    const fromActor = await ethers.getSigner(from);

    await fromActor.sendTransaction({
        gasPrice,
        gasLimit,
        to,
        value,
        nonce,
        data,
    });
};
