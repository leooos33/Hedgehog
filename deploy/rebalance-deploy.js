process.exit(0); // Block file in order to not accidentally deploy

const { ethers } = require("hardhat");
const { utils } = ethers;
const { BigNumber } = require("ethers");

const deploy = async () => {
    const Rebalancer = await deployContract("Rebalancer", [], false);
    console.log(Rebalancer.address);
};

const deployContract = async (name, params, deploy = true) => {
    console.log("Deploying ->", name);
    const Contract = await ethers.getContractFactory(name);
    let contract = await Contract.deploy(...params);
    if (deploy) {
        await contract.deployed();
    }
    return contract;
};

deploy().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
