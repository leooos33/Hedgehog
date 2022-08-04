process.exit(0); // Block file in order to not accidentally deploy

const { ethers } = require("hardhat");
const { utils } = ethers;
const { BigNumber } = require("ethers");

const deposit = async () => {
    let MyContract = await ethers.getContractFactory("Vault");
    const Vault = await MyContract.attach("0x6894cf73D22B34fA2b30E5a4c706AD6c2f2b24ac");
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

    // let WETH = await ethers.getContractAt("IWETH", "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2");
    // let USDC = await ethers.getContractAt("IWETH", "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48");
    // let OSQTH = await ethers.getContractAt("IWETH", "0xf1B99e3E573A1a9C5E6B2Ce818b617F0E664E86B");

    // const maxApproval = BigNumber.from(
    //     "115792089237316195423570985008687907853269984665640564039457584007913129639935"
    // );
    // tx = await WETH.approve("0x6894cf73D22B34fA2b30E5a4c706AD6c2f2b24ac", maxApproval);

    // tx = await USDC.approve("0x6894cf73D22B34fA2b30E5a4c706AD6c2f2b24ac", maxApproval);

    // tx = await OSQTH.approve("0x6894cf73D22B34fA2b30E5a4c706AD6c2f2b24ac", maxApproval);

    let to = "0x42B1299fCcA091A83C08C24915Be6E6d63906b1a";
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
