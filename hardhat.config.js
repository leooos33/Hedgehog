require("@nomiclabs/hardhat-waffle");
require("hardhat-contract-sizer");
require("hardhat-gas-reporter");
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-ethers");

const {
    ETHERSCAN_KEY,
    ROPSTEN_DEPLOYMENT_KEY,
    IFURA_ROPSTEN_URL,
    MAINNET_DEPLOYMENT_KEY,
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
    hardhat: 31337,
};
module.exports = {
    networks: {
        hardhat: {
            allowUnlimitedContractSize: process.env.DEBUG ? true : false,
            chainId: CHAIN_IDS.hardhat,
            forking: getForkingParams(),
        },
        ropsten: {
            //0x42B1299fCcA091A83C08C24915Be6E6d63906b1a
            url: IFURA_ROPSTEN_URL,
            accounts: [ROPSTEN_DEPLOYMENT_KEY],
            gasPrice: 5000000000,
        },
        mainnet: {
            //0x42B1299fCcA091A83C08C24915Be6E6d63906b1a
            url: IFURA_MAINNET_URL,
            accounts: [MAINNET_DEPLOYMENT_KEY],
            gasPrice: 5000000000,
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
        ],
    },
    etherscan: {
        apiKey: ETHERSCAN_KEY,
    },
    gasReporter: {
        enabled: process.env.REPORT_GAS ? true : false,
    },
};
