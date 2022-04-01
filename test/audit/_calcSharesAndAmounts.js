const { ethers } = require("hardhat");
const { BigNumber } = ethers;

const e12 = BigNumber.from(10).pow(12);
const e18 = BigNumber.from(10).pow(18);
const e36 = BigNumber.from(10).pow(36);

const _calcSharesAndAmounts = (params) => {
    let depositorValue = (
        params._amountOsqth.mul(params.ethUsdcPrice).mul(params.osqthEthPrice).div(e36)
    ).add((params._amountUsdc.mul(e12))).add((params._amountEth.mul(params.ethUsdcPrice).div(e18)));

    console.log("depositorValue: %s", depositorValue);

    if (params.totalSupply == 0) {
        return [
            depositorValue,
            depositorValue.mul(targetEthShare.div(e18)).div(params.ethUsdcPrice),
            depositorValue.mul(targetUsdcShare.div(e18)),
            depositorValue.mul(targetOsqthShare.div(e18)).div(
                params.osqthEthPrice.mul(params.ethUsdcPrice)
            )
        ];
    } else {
        let osqthValue = params.osqthAmount.mul(params.ethUsdcPrice).mul(params.osqthEthPrice).div(e36);
        let ethValue = params.ethAmount.mul(params.ethUsdcPrice).div(e18);

        let totalValue = osqthValue.add((params.usdcAmount.mul(e12))).add(ethValue);

        return [
            params.totalSupply.mul(depositorValue).div(totalValue),
            params.ethAmount.mul(depositorValue).div(totalValue),
            params.usdcAmount.mul(depositorValue).div(totalValue),
            params.osqthAmount.mul(depositorValue).div(totalValue)
        ];
    }
}

module.exports = { _calcSharesAndAmounts };