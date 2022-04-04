// SPDX-License-Identifier: Unlicense

pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";

import "./VaultParams.sol";
import "../libraries/StrategyMath.sol";

import "hardhat/console.sol";

contract VaultMathTest is VaultParams {
    // using SafeMath for uint256;
    using StrategyMath for uint256;

    struct SharesInfo {
        uint256 totalSupply;
        uint256 _amountEth;
        uint256 _amountUsdc;
        uint256 _amountOsqth;
        uint256 osqthEthPrice;
        uint256 ethUsdcPrice;
        uint256 usdcAmount;
        uint256 ethAmount;
        uint256 osqthAmount;
        uint256 _auctionTime;
        uint256 _auctionTriggerTime;
        uint256 _isPriceInc;
    }

    constructor(
        uint256 _cap,
        uint256 _rebalanceTimeThreshold,
        uint256 _rebalancePriceThreshold,
        uint256 _auctionTime,
        uint256 _minPriceMultiplier,
        uint256 _maxPriceMultiplier,
        uint256 _targetEthShare,
        uint256 _targetUsdcShare,
        uint256 _targetOsqthShare
    )
        public
        VaultParams(
            _cap,
            _rebalanceTimeThreshold,
            _rebalancePriceThreshold,
            _auctionTime,
            _minPriceMultiplier,
            _maxPriceMultiplier,
            _targetEthShare,
            _targetUsdcShare,
            _targetOsqthShare
        )
    {}

    function _calcSharesAndAmounts(SharesInfo memory params)
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 depositorValue = (
            params._amountOsqth.mul(params.ethUsdcPrice).mul(params.osqthEthPrice).div(uint256(1e36))
        ).add((params._amountUsdc.mul(uint256(1e12)))).add((params._amountEth.mul(params.ethUsdcPrice).div(1e18)));

        console.log("depositorValue: %s", depositorValue);

        if (params.totalSupply == 0) {
            return (
                depositorValue,
                depositorValue.mul(targetEthShare.div(uint256(1e18))).div(params.ethUsdcPrice),
                depositorValue.mul(targetUsdcShare.div(uint256(1e18))),
                depositorValue.mul(targetOsqthShare.div(uint256(1e18))).div(
                    params.osqthEthPrice.mul(params.ethUsdcPrice)
                )
            );
        } else {
            uint256 osqthValue = params.osqthAmount.mul(params.ethUsdcPrice).mul(params.osqthEthPrice).div(1e36);
            uint256 ethValue = params.ethAmount.mul(params.ethUsdcPrice).div(uint256(1e18));

            uint256 totalValue = osqthValue.add((params.usdcAmount.mul(uint256(1e12)))).add(ethValue);
            // console.log("totalValue: %s", totalValue);

            return (
                params.totalSupply.mul(depositorValue).div(totalValue),
                params.ethAmount.mul(depositorValue).div(totalValue),
                params.usdcAmount.mul(depositorValue).div(totalValue),
                params.osqthAmount.mul(depositorValue).div(totalValue)
            );
        }
    }

    function _getAuctionPrices(SharesInfo memory params)
    public view 
    returns (
        uint256,
        uint256
    )
    {
        uint256 auctionCompletionRatio = block.timestamp.sub(params._auctionTriggerTime) >= auctionTime ? 1e18 
        : (block.timestamp.sub(params._auctionTriggerTime)).wdiv(params._auctionTime);

        uint256 priceMultiplier;
        if(params._isPriceInc) {
            priceMultiplier = params._maxPriceMultiplier.sub(auctionCompletionRatio.wmul(params._maxPriceMultiplier.sub(params._minPriceMultiplier))
            );
        } else {
            priceMultiplier = params._minPriceMultiplier.add(
                auctionCompletionRatio.wmul(params._maxPriceMultiplier.sub(params._minPriceMultiplier))
            );
        }

        return (
            params.osqthEthPrice.wmul(priceMultiplier).wdiv(uint256(1e18));
            params.ethUsdcPrice.wmul(priceMultiplier).wdiv(uint256(1e18));
        );
    }

    function _getDeltas(SharesInfo memory params)
    public view
    returns(
        uint256,
        uint256,
        uint256
    ) 
    {
        uint256 osqthValue = params.osqthAmount.wmul(params.ethUsdcPrice).wmul(params.osqthEthPrice).wdiv(uint256(1e36));
        uint256 usdcValue = params.usdcAmount.wmul(uint256(1e12));
        uint256 ethValue = params.ethAmount.wmul(params.ethUsdcPrice).wdiv(1e18);

        uint256 totalValue = osqthValue.add(usdcValue).add(ethValue);

        if (params._isPriceInc) {
            return (
            params._amountEth.sub(params.targetEthShare.wmul(totalValue.wdiv(params.ethUsdcPrice)));
            params.targetUsdcShare.wmul(totalValue.wdiv(uint256(1e18))).sub(params._amountUsdc);
            params.targetOsqthShare.wmul(totalValue).wmul(1e18).wdiv(paramsOsqthEthPrice).wdiv(paramsEthUsdcPrice).sub(params._amountOsqth);
            )
        } else {
            return (
                params.targetEthShare.wmul(totalValue.wdiv(params.ethUsdcPrice)).suba(params.ethAmount);
                params.targerUsdcShare.wmul(totalValue.wdiv(uint256(1e18))).suba(params.usdcAmount);
                params.targetOsqthShare.wmul(totalValue).wmul(1e18).wdiv(params.osqthEthPrice).wdiv(params.ethUsdcPrice).suba(params.osqthAmount);
            )
        }

        return(

        )
    }
}
