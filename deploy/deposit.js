// process.exit(0); // Block file in order to not accidentally deploy

const { ethers } = require("hardhat");
const { utils } = ethers;
const { BigNumber } = require("ethers");
const {
    _governanceAddress,
    _vaultAddress,
    wethAddress,
    usdcAddress,
    osqthAddress,
    maxUint256,
} = require("../test/common/index");
const { getERC20Allowance } = require("../test/helpers");

const deposit = async () => {
    let MyContract = await ethers.getContractFactory("Vault");
    const Vault = await MyContract.attach(_vaultAddress);
    let tx;

    let tS = (await Vault.totalSupply()).toString();

    let eth = utils.parseUnits("0.005", 18);
    let usdc = utils.parseUnits("4.6", 6);
    let sqth = utils.parseUnits("0.026", 18);

    let data = await Vault.calcSharesAndAmounts(eth, usdc, sqth, tS, false);
    console.log(data);

    console.log(eth.toString());
    console.log(data[1].toString());
    console.log(usdc.toString());
    console.log(data[2].toString());
    console.log(sqth.toString());
    console.log(data[3].toString());

    let actor = (await hre.ethers.getSigners())[1];
    let to = actor.address;

    console.log("> userWEth allowance %s", await getERC20Allowance(to, _vaultAddress, wethAddress));
    console.log("> userUsdc allowance %s", await getERC20Allowance(to, _vaultAddress, usdcAddress));
    console.log("> userOsqth allowance %s", await getERC20Allowance(to, _vaultAddress, osqthAddress));

    // let WETH = await ethers.getContractAt("IWETH", wethAddress);
    // let USDC = await ethers.getContractAt("IWETH", usdcAddress);
    // let OSQTH = await ethers.getContractAt("IWETH", osqthAddress);

    // const maxApproval = BigNumber.from(maxUint256);
    // tx = await WETH.connect(actor).approve(_vaultAddress, maxApproval);
    // tx = await USDC.connect(actor).approve(_vaultAddress, maxApproval);
    // tx = await OSQTH.connect(actor).approve(_vaultAddress, maxApproval);

    // tx = await Vault.connect(actor).deposit(eth, usdc, sqth, to, 0, 0, 0, {
    //     gasPrice: 5000000000,
    //     gasLimit: 900000,
    //     // nonce: 24,
    // });
    // await tx.wait();
};

deposit().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
