require("@nomiclabs/hardhat-waffle");
require('hardhat-contract-sizer');

const { getForkingParams } = require('./hardhat.helpers');

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
      forking: getForkingParams()
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.7.6",
        optimizer: {enabled: process.env.DEBUG ? false : true},
      },
      {
        version: "0.8.4",
        optimizer: {enabled: process.env.DEBUG ? false : true},
      },
    ]
  }
}

