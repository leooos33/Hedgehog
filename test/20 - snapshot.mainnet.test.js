const { ethers } = require("hardhat");
const { utils } = ethers;
const {
    wethAddress,
    osqthAddress,
    usdcAddress,
    _governanceAddressV2,
    _vaultStorageAddressV2,
    _vaultMathAddressV2,
    _vaultAddressV2,
    _vaultTreasuryAddressV2,
} = require("./common");
const { resetFork, getERC20Balance, approveERC20 } = require("./helpers");

describe.skip("Snapshot Mainnet", function () {
    it("Get snapshot", async function () {
        await resetFork(15747520);

        const VaultStorage = await ethers.getContractAt("VaultStorage", _vaultStorageAddressV2);
        const Vault = await ethers.getContractAt("Vault", _vaultAddressV2);
        const VaultMath = await ethers.getContractAt("VaultMath", _vaultMathAddressV2);
        const VaultTreasury = await ethers.getContractAt("VaultTreasury", _vaultTreasuryAddressV2);

        const totalSupply = await Vault.totalSupply();
        console.log("totalSupply %s", totalSupply);

        console.log("orderEthUsdcLower:", (await VaultStorage.orderEthUsdcLower()).toString());
        console.log("orderEthUsdcUpper:", (await VaultStorage.orderEthUsdcUpper()).toString());
        console.log("orderOsqthEthLower:", (await VaultStorage.orderOsqthEthLower()).toString());
        console.log("orderOsqthEthUpper:", (await VaultStorage.orderOsqthEthUpper()).toString());
        console.log("timeAtLastRebalance:", (await VaultStorage.timeAtLastRebalance()).toString());
        console.log("ivAtLastRebalance:", (await VaultStorage.ivAtLastRebalance()).toString());

        console.log("ethPriceAtLastRebalance:", (await VaultStorage.ethPriceAtLastRebalance()).toString());

        const prices = await VaultMath.getPrices();
        console.log("ETH/USDC price %s", prices[0]);
        console.log("oSQTH/ETH price %s", prices[1]);
        const amounts = await VaultMath.getTotalAmounts();
        console.log("wETH amount %s", amounts[0]);
        console.log("USDC amount %s", amounts[1]);
        console.log("oSQTH amount %s", amounts[2]);

        const value = await VaultMath.getValue(amounts[0], amounts[1], amounts[2], prices[0], prices[1]);
        console.log("Total ETH value %s", value);
        console.log("sharePrice %s", value / totalSupply);
    });
});
