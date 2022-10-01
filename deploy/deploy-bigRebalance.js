process.exit(0); // Block file in order to not accidentally deploy

const { ethers } = require("hardhat");
const { utils } = ethers;
const { BigNumber } = require("ethers");
const { deployContract } = require("./common");
const { wethAddress, maxApproval } = require("../test/common");

const deploy = async () => {
    const Rebalancer = await deployContract("BigRebalancer", [], false);
    console.log(Rebalancer.address);

    // let WETH = await ethers.getContractAt("IWETH", wethAddress);
    // tx = await WETH.approve("0x2f0b98eF1093B41897a99b76956Fb69025F1682b", "2", {
    //     nonce: 1,
    // });
};

deploy().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
