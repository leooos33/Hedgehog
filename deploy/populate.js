process.exit(0); // Block file in order to not accidentally deploy

const { ethers } = require("hardhat");

const populate = async () => {
    const Rebalancer = await ethers.getContractAt("IRebalancer", "0xD3ed5915AAA27dB7a3646bf926dB6C98243d5c40");
    let tx;
    tx = await Rebalancer.setContracts(
        "0xA9a68eA2746793F43af0f827EC3DbBb049359067",
        "0xfbcF638ea33A5F87D1e39509E7deF653958FA9C4",
        {
            gasLimit: 30000,
            gasPrice: 7000000000,
            nonce: 13,
        }
    );
    await tx.wait();
};

populate().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
