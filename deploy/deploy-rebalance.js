process.exit(0); // Block file in order to not accidentally deploy

const { ethers } = require("hardhat");
const { deployContract } = require("./common");

const deploy = async () => {
    const Rebalancer = await deployContract("CheapRebalancer", [], false);
    console.log(Rebalancer.address);
};

deploy().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
