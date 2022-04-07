require("@nomiclabs/hardhat-waffle");

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
      allowUnlimitedContractSize: true,
      chainId: CHAIN_IDS.hardhat,
      forking: getForkingParams()
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.6.6"
      },
      {
        version: "0.6.8"
      },
      {
        version: "0.8.0"
      },
      {
        version: "0.8.4"
      },
      {
        version: "0.5.0"
      },
      {
        version: "0.7.5"
      },
    ]
  }
}

