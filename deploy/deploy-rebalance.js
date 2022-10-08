// process.exit(0); // Block file in order to not accidentally deploy

const { ethers } = require("hardhat");
const { deployContract } = require("./common");
const { wethAddress, _rescueAddress } = require("../test/common/index");

const deploy = async () => {
    const Rebalancer = await deployContract("CheapRebalancer", [], false);
    console.log(Rebalancer.address);

    // let WETH = await ethers.getContractAt("IWETH", wethAddress);
    // tx = await WETH.approve(_rescueAddress, 1, { nonce: 12 });
};

deploy().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
