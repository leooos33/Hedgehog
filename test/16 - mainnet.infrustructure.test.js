const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { utils } = ethers;
const { wethAddress, osqthAddress, usdcAddress } = require("./common");
const {
    mineSomeBlocks,
    resetFork,
    logBlock,
    getAndApprove2,
    getERC20Balance,
    getWETH,
    getOSQTH,
    getUSDC,
} = require("./helpers");
const { hardhatInitializeDeploed } = require("./deploy");
const { BigNumber } = require("ethers");

const ownable = require("./helpers/abi/ownable");

describe("Mainnet Infrustructure Test", function () {
    let governance;
    let governanceAddress = "0x42B1299fCcA091A83C08C24915Be6E6d63906b1a";
    it("Should set actors", async function () {
        await resetFork(15275315);
        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [governanceAddress],
        });

        governance = await ethers.getSigner(governanceAddress);
        console.log("governance:", governance.address);
    });

    it("1 test", async function () {
        let MyContract = await ethers.getContractFactory("Vault");
        const vaultAddress = "0x6894cf73D22B34fA2b30E5a4c706AD6c2f2b24ac";
        const Vault = await MyContract.attach(vaultAddress);
        let tx;

        let tS = (await Vault.totalSupply()).toString();

        let eth = utils.parseUnits("0.015", 18); //50
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

        let WETH = await ethers.getContractAt("IWETH", "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2");
        let USDC = await ethers.getContractAt("IWETH", "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48");
        let OSQTH = await ethers.getContractAt("IWETH", "0xf1B99e3E573A1a9C5E6B2Ce818b617F0E664E86B");
        const maxApproval = BigNumber.from(
            "115792089237316195423570985008687907853269984665640564039457584007913129639935"
        );

        console.log("> userEth %s", await getERC20Balance(governance.address, wethAddress));
        console.log("> userUsdc %s", await getERC20Balance(governance.address, usdcAddress));
        console.log("> userOsqth %s", await getERC20Balance(governance.address, osqthAddress));

        tx = await WETH.connect(governance).approve(vaultAddress, maxApproval);
        await tx.wait();
        tx = await USDC.connect(governance).approve(vaultAddress, maxApproval);
        await tx.wait();
        tx = await OSQTH.connect(governance).approve(vaultAddress, maxApproval);
        await tx.wait();

        let to = governanceAddress;

        tx = await Vault.connect(governance).deposit(eth, usdc, sqth, to, 0, 0, 0);
        receipt = await tx.wait();
        console.log("> Gas used:", receipt.gasUsed.toString());

        console.log("> userEth %s", await getERC20Balance(governance.address, wethAddress));
        console.log("> userUsdc %s", await getERC20Balance(governance.address, usdcAddress));
        console.log("> userOsqth %s", await getERC20Balance(governance.address, osqthAddress));
    });
});
