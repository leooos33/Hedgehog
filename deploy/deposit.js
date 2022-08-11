process.exit(0); // Block file in order to not accidentally deploy

const { ethers } = require("hardhat");
const { utils } = ethers;
const { BigNumber } = require("ethers");
const { _governanceAddress, _vaultAddress, wethAddress, usdcAddress, osqthAddress } = require("../test/common/index");

const deposit = async () => {
    let MyContract = await ethers.getContractFactory("Vault");
    const Vault = await MyContract.attach(_vaultAddress);
    let tx;

    let tS = (await Vault.totalSupply()).toString();

    let eth = utils.parseUnits("0.015", 18); //25
    let usdc = utils.parseUnits("12", 6);
    let sqth = utils.parseUnits("0.08", 18);

    let data = await Vault.calcSharesAndAmounts(eth, usdc, sqth, tS);
    console.log(data);

    console.log(eth.toString());
    console.log(data[1].toString());
    console.log(usdc.toString());
    console.log(data[2].toString());
    console.log(sqth.toString());
    console.log(data[3].toString());

    // let WETH = await ethers.getContractAt("IWETH", wethAddress);
    // let USDC = await ethers.getContractAt("IWETH", usdcAddress);
    // let OSQTH = await ethers.getContractAt("IWETH", osqthAddress);

    // const maxApproval = BigNumber.from(
    //     "115792089237316195423570985008687907853269984665640564039457584007913129639935"
    // );
    // tx = await WETH.approve(_vaultAddress, maxApproval);

    // tx = await USDC.approve(_vaultAddress, maxApproval);

    // tx = await OSQTH.approve(_vaultAddress, maxApproval);

    let to = _governanceAddress;
    tx = await Vault.deposit(eth, usdc, sqth, to, 0, 0, 0, {
        gasPrice: 8000000000,
        gasLimit: 900000,
        // nonce: 24,
    });
    await tx.wait();
};

deposit().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
