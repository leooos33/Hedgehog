require("@nomiclabs/hardhat-waffle");
require("hardhat-contract-sizer");
require("hardhat-gas-reporter");
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-ethers");

const {
    ETHERSCAN_KEY,
    ROPSTEN_DEPLOYMENT_KEY,
    IFURA_ROPSTEN_URL,
    HEDGEHOG_REBALANCER_V2,
    IFURA_MAINNET_URL,
} = require("./shared/config");
const { getForkingParams } = require("./hardhat.helpers");

task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
    const accounts = await hre.ethers.getSigners();

    for (const account of accounts) {
        console.log(account.address);
    }
});

const CHAIN_IDS = {
    hardhat: 1,
};

const test = {
    allowUnlimitedContractSize: process.env.DEBUG ? true : false,
    chainId: CHAIN_IDS.hardhat,
    forking: getForkingParams(),
    // gasLimit: 3000000,
    // gas: 1800000,
    // gasPrice: 18000000000,
};

const simulate = {
    allowUnlimitedContractSize: true,
    chainId: CHAIN_IDS.hardhat,
    forking: getForkingParams(15534544),
    gasPrice: 18000000000,
    // mining: {
    //     auto: true,
    //     interval: 0,
    // },
};

module.exports = {
    networks: {
        hardhat: process.env.SIMULATION ? simulate : test,
        ropsten: {
            url: IFURA_ROPSTEN_URL,
            accounts: [ROPSTEN_DEPLOYMENT_KEY],
            gasPrice: 5000000000,
        },
        mainnet: {
            url: IFURA_MAINNET_URL,
            accounts: [HEDGEHOG_REBALANCER_V2],
            gasPrice: 3000000000,
        },
    },
    solidity: {
        compilers: [
            {
                version: "0.7.6",
                optimizer: { enabled: true, runs: 10000 },
            },
            {
                version: "0.8.4",
                optimizer: { enabled: true, runs: 10000 },
            },
            {
                version: "0.8.0",
                optimizer: { enabled: true, runs: 10000 },
            },
        ],
    },
    etherscan: {
        apiKey: ETHERSCAN_KEY,
    },
    gasReporter: {
        enabled: process.env.REPORT_GAS ? true : false,
    },
};
