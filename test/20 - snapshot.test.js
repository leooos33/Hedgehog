const { ethers } = require("hardhat");
const { utils } = ethers;
const { wethAddress, osqthAddress, usdcAddress, _governanceAddress, _vaultStorageAddress, _vaultMathAddress } = require("./common");
const { resetFork, getERC20Balance, approveERC20 } = require("./helpers");
const { deployContract } = require("./deploy");

describe.only("Snapshot", function () {
    it("Get snapshot", async function () {
        await resetFork(15560400);

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

        const VaultMath = await ethers.getContractAt("VaultMath", _vaultMathAddress);

        const prices = await VaultMath.getPrices();
        console.log("ETH/USDC price %s", prices[0]);
        console.log("oSQTH/ETH price %s", prices[1]);
        const amounts = await VaultMath.getTotalAmounts();
        console.log("wETH amount %s", amounts[0]);
        console.log("USDC amount %s", amounts[1]);
        console.log("oSQTH amount %s", amounts[2]);

        const value = await VaultMath.getValue(amounts[0], amounts[1], amounts[2], prices[0], prices[1]);
        console.log("Total ETH value %s", value);
    });
});
