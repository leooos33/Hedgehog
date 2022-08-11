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
const { hardhatInitializeDeploed, deploymentParams, hardhatDeploy } = require("./deploy");
const { BigNumber } = require("ethers");
const abi = ethers.utils.defaultAbiCoder;

const ownable = require("./helpers/abi/ownable");

describe.skip("Mainnet Infrustructure Test", function () {
    it("1 test", async function () {
        this.skip();
        await resetFork(15278550);

        let MyContract = await ethers.getContractFactory("Rebalancer");
        const rebalancer = await MyContract.attach("0x09b1937D89646b7745377f0fcc8604c179c06aF5");

        console.log("> userEth %s", await getERC20Balance(rebalancer.address, wethAddress));
        console.log("> userUsdc %s", await getERC20Balance(rebalancer.address, usdcAddress));
        console.log("> userOsqth %s", await getERC20Balance(rebalancer.address, osqthAddress));

        await resetFork(15278554);

        console.log("> userEth %s", await getERC20Balance(rebalancer.address, wethAddress));
        console.log("> userUsdc %s", await getERC20Balance(rebalancer.address, usdcAddress));
        console.log("> userOsqth %s", await getERC20Balance(rebalancer.address, osqthAddress));

        console.log(0.000023504084671461 * 1600);
    });

    it("unuthorized test", async function () {
        this.skip();
        await resetFork(15278541);

        [Vault, VaultAuction, VaultMath, VaultTreasury, VaultStorage] = await hardhatInitializeDeploed();
        const signers = await ethers.getSigners();
        unuthorized = signers[12];

        const arr = abi.encode(
            ["address", "address", "address"],
            [
                unuthorized.address,
                "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
                "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
            ]
        );
        tx = await VaultTreasury.connect(unuthorized).uniswapV3MintCallback(1, 1, arr);
        await tx.wait();

        console.log("> unuthorized ETH %s", await getERC20Balance(unuthorized.address, wethAddress));
        console.log("> unuthorized USDC %s", await getERC20Balance(unuthorized.address, usdcAddress));
        console.log("> unuthorized oSQTH %s", await getERC20Balance(unuthorized.address, osqthAddress));
    });

    let unuthorized, governance;
    it("Should deploy contract", async function () {
        // this.skip();
        const signers = await ethers.getSigners();
        governance = signers[0];
        unuthorized = signers[12];
        await resetFork(15173789);

        const params = [...deploymentParams];
        deploymentParams[6] = "10000";
        [Vault, VaultAuction, VaultMath, VaultTreasury, VaultStorage] = await hardhatDeploy(governance, params);
    });

    it("Should deploy contract", async function () {
        // this.skip();
        console.log(unuthorized.address);
        const arr = abi.encode(
            ["address", "address"],
            ["0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"]
        );
        tx = await VaultTreasury.connect(unuthorized).uniswapV3MintCallback(1, 1, arr);
        await tx.wait();
    });
});
