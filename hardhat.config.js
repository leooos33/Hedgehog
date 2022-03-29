require("@nomiclabs/hardhat-waffle");
const fs = require('fs');
const path = require('path');
const dotenv = require('dotenv');

const envDir = path.join(__dirname, '.env');
const { ALCHEMY_KEY } = dotenv.parse(fs.readFileSync(envDir));

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
      chainId: CHAIN_IDS.hardhat,
      forking: {
        url: `https://eth-mainnet.alchemyapi.io/v2/${ALCHEMY_KEY}`,
        blockNumber: 12821000,
      },
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
    ]
  }
}

