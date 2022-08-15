const { ethers } = require("hardhat");
const { utils } = ethers;
const { wethAddress, osqthAddress, usdcAddress, _governanceAddress, _vaultStorageAddress } = require("./common");
const { resetFork, getERC20Balance, approveERC20 } = require("./helpers");
const { deployContract } = require("./deploy");

describe.only("Snapshot", function () {
    it("Get snapshot", async function () {
        await resetFork(15345193);

        const VaultStorage = await ethers.getContractAt("VaultStorage", _vaultStorageAddress);

        const orderEthUsdcLower = await VaultStorage.orderEthUsdcLower();
        const orderEthUsdcUpper = await VaultStorage.orderEthUsdcUpper();
        const orderOsqthEthLower = await VaultStorage.orderOsqthEthLower();
        const orderOsqthEthUpper = await VaultStorage.orderOsqthEthUpper();
        const timeAtLastRebalance = await VaultStorage.timeAtLastRebalance();
        const ivAtLastRebalance = await VaultStorage.ivAtLastRebalance();
        const totalValue = await VaultStorage.totalValue();
        const ethPriceAtLastRebalance = await VaultStorage.ethPriceAtLastRebalance();

        console.log("orderEthUsdcLower:", orderEthUsdcLower.toString());
        console.log("orderEthUsdcUpper:", orderEthUsdcUpper.toString());
        console.log("orderOsqthEthLower:", orderOsqthEthLower.toString());
        console.log("orderOsqthEthUpper:", orderOsqthEthUpper.toString());
        console.log("timeAtLastRebalance:", timeAtLastRebalance.toString());
        console.log("ivAtLastRebalance:", ivAtLastRebalance.toString());
        console.log("totalValue:", totalValue.toString());
        console.log("ethPriceAtLastRebalance:", ethPriceAtLastRebalance.toString());
    });
});
