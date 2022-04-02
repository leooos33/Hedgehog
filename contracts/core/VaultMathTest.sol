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

    struct SharesInfo {
        uint256 targetEthShare;
        uint256 targetUsdcShare;
        uint256 targetOsqthShare;
        uint256 totalSupply;
        uint256 _amountEth;
        uint256 _amountUsdc;
        uint256 _amountOsqth;
        uint256 osqthEthPrice;
        uint256 ethUsdcPrice;
        uint256 usdcAmount;
        uint256 ethAmount;
        uint256 osqthAmount;
    }

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

        if (params.totalSupply == 0) {
            return (
                depositorValue,
                depositorValue.mul(targetEthShare).div(params.ethUsdcPrice),
                depositorValue.mul(targetUsdcShare).div(uint256(1e30)),
                depositorValue.mul(targetOsqthShare.mul(1e18)).div(params.osqthEthPrice).div(params.ethUsdcPrice)
            );
        } else {
            uint256 osqthValue = params.osqthAmount.mul(params.ethUsdcPrice).mul(params.osqthEthPrice).div(1e36);
            uint256 ethValue = params.ethAmount.mul(params.ethUsdcPrice).div(uint256(1e18));

            uint256 totalValue = osqthValue.add((params.usdcAmount.mul(uint256(1e12)))).add(ethValue);

            return (
                params.totalSupply.mul(depositorValue).div(totalValue),
                params.ethAmount.mul(depositorValue).div(totalValue),
                params.usdcAmount.mul(depositorValue).div(totalValue),
                params.osqthAmount.mul(depositorValue).div(totalValue)
            );
        }
    }

    struct AuctionInfo {
        uint256 osqthEthPrice;
        uint256 ethUsdcPrice;
        uint256 auctionTime;
        uint256 _auctionTriggerTime;
        bool _isPriceInc;
        uint256 timestamp;
    }

    function _getAuctionPrices(AuctionInfo memory params) public view returns (uint256, uint256) {
        uint256 auctionCompletionRatio = params.timestamp.sub(params._auctionTriggerTime) >= params.auctionTime
            ? 1e18
            : (params.timestamp.sub(params._auctionTriggerTime)).wdiv(params.auctionTime);

        uint256 priceMultiplier;
        if (params._isPriceInc) {
            priceMultiplier = maxPriceMultiplier.sub(
                auctionCompletionRatio.wmul(maxPriceMultiplier.sub(minPriceMultiplier))
            );
        } else {
            priceMultiplier = minPriceMultiplier.add(
                auctionCompletionRatio.wmul(maxPriceMultiplier.sub(minPriceMultiplier))
            );
        }

        return (
            params.osqthEthPrice.wmul(priceMultiplier).wdiv(uint256(1e18)),
            params.ethUsdcPrice.wmul(priceMultiplier).wdiv(uint256(1e18))
        );
    }

    struct DeltasInfo {
        uint256 osqthEthPrice;
        uint256 ethUsdcPrice;
        uint256 usdcAmount;
        uint256 ethAmount;
        uint256 osqthAmount;
    }

    function _getDeltas(DeltasInfo memory params)
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 osqthValue = params.osqthAmount.wmul(params.ethUsdcPrice).wmul(params.osqthEthPrice).wdiv(
            uint256(1e36)
        );
        uint256 ethValue = params.ethAmount.wmul(params.ethUsdcPrice).wdiv(1e18);

        uint256 totalValue = osqthValue.add(params.usdcAmount.mul(uint256(1e12))).add(ethValue);

        return (
            targetEthShare.wmul(totalValue.wdiv(params.ethUsdcPrice)).suba(params.ethAmount),
            ((targetUsdcShare * totalValue) / 1e30).suba(params.usdcAmount),
            targetOsqthShare.wmul(totalValue).wmul(1e18).wdiv(params.osqthEthPrice).wdiv(params.ethUsdcPrice).suba(
                params.osqthAmount
            )
        );
    }
}
