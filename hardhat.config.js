require("@nomiclabs/hardhat-waffle");
require("hardhat-contract-sizer");
require("hardhat-gas-reporter");
require("@nomiclabs/hardhat-etherscan");

const { ETHERSCAN_KEY, ROPSTEN_DEPLOYMENT_KEY, IFURA_ROPSTEN_URL } = require("./shared/config");
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
            allowUnlimitedContractSize: true, //TODO: process.env.DEBUG ? true : false,
            chainId: CHAIN_IDS.hardhat,
            forking: getForkingParams(),
        },
        ropsten: {
            //0x42B1299fCcA091A83C08C24915Be6E6d63906b1a
            url: IFURA_ROPSTEN_URL,
            accounts: [ROPSTEN_DEPLOYMENT_KEY],
        },
    },
    solidity: {
        compilers: [
            {
                version: "0.7.6",
                optimizer: { enabled: process.env.DEBUG ? false : true },
            },
            {
                version: "0.8.4",
                optimizer: { enabled: process.env.DEBUG ? false : true },
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
