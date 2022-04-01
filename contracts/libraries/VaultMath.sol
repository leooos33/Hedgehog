// SPDX-License-Identifier: Unlicense

pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import "@uniswap/v3-periphery/contracts/libraries/PositionKey.sol";

import "../libraries/SharedEvents.sol";
import "./Constants.sol";
import "./VaultParams.sol";

import "hardhat/console.sol";

// remove  due to not implementing this function
abstract contract VaultMath is IERC20, ERC20, ReentrancyGuard, VaultParams {
    using SafeMath for uint256;

    /**
     * @notice strategy constructor
       @param _cap max amount of wETH that strategy accepts for deposits
       @param _rebalanceTimeThreshold rebalance time threshold (seconds)
       @param _rebalancePriceThreshold rebalance price threshold (0.05*1e18 = 5%)
       @param _auctionTime auction duration (seconds)
       @param _minPriceMultiplier minimum auction price multiplier (0.95*1e18 = min auction price is 95% of twap)
       @param _maxPriceMultiplier maximum auction price multiplier (1.05*1e18 = max auction price is 105% of twap)
       @param _targetEthShare targeted share of value in wETH (0.5*1e18 = 50% of total value(in usd) in wETH)
       @param _targetUsdcShare targeted share of value in USDC (~0.2622*1e18 = 26.22% of total value(in usd) in USDC)
       @param _targetOsqthShare targeted share of value in oSQTH (~0.2378*1e18 = 23.78% of total value(in usd) in oSQTH)
     */
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
        ERC20("Hedging DL", "HDL")
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

    /**
     * @dev Do zero-burns to poke a position on Uniswap so earned fees are
     * updated. Should be called if total amounts needs to include up-to-date
     * fees.
     * @param pool address of pool to poke
     * @param tickLower lower tick of the position
     * @param tickUpper upper tick of the position
     */
    function _poke(
        address pool,
        int24 tickLower,
        int24 tickUpper
    ) internal {
        (uint128 liquidity, , , , ) = _position(pool, tickLower, tickUpper);

        if (liquidity > 0) {
            IUniswapV3Pool(pool).burn(tickLower, tickUpper, 0);
        }
    }

    /// @dev Wrapper around `IUniswapV3Pool.positions()`.
    function _position(
        address pool,
        int24 tickLower,
        int24 tickUpper
    )
        internal
        view
        returns (
            uint128,
            uint256,
            uint256,
            uint128,
            uint128
        )
    {
        bytes32 positionKey = PositionKey.compute(address(this), tickLower, tickUpper);
        return IUniswapV3Pool(pool).positions(positionKey);
    }

    /**
     * @notice calculate strategy shares to ming
     * @param _amountToDeposit amount of wETH to deposit
     * @return shares strategy shares to mint
     */
    function _calcShares(uint256 _amountToDeposit) internal view returns (uint256 shares) {
        uint256 totalSupply = totalSupply();

        (uint256 ethAmount, uint256 usdcAmount, uint256 osqthAmount) = _getTotalAmounts();

        uint256 osqthEthPrice = Constants.oracle.getTwap(
            Constants.poolEthOsqth,
            address(Constants.weth),
            address(Constants.osqth),
            twapPeriod,
            true
        );

        uint256 usdcEthPrice = Constants.oracle.getTwap(
            Constants.poolEthUsdc,
            address(Constants.usdc),
            address(Constants.weth),
            twapPeriod,
            true
        );

        if (totalSupply == 0) {
            shares = _amountToDeposit;
        } else {
            uint256 totalEth = ethAmount.add(usdcAmount.mul(usdcEthPrice)).add(osqthAmount.mul(osqthEthPrice));
            uint256 depositorShare = _amountToDeposit.div(totalEth.add(_amountToDeposit));
            shares = totalSupply.mul(depositorShare).div(uint256(1e18).sub(depositorShare));
        }
    }

    function calcSharesAndAmounts(
        uint256 _amountEth,
        uint256 _amountUsdc,
        uint256 _amountOsqth
    )
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        (uint256 ethAmount, uint256 usdcAmount, uint256 osqthAmount) = _getTotalAmounts();

        uint256 osqthEthPrice = Constants.oracle.getTwap(
            Constants.poolEthOsqth,
            address(Constants.osqth),
            address(Constants.weth),
            twapPeriod,
            true
        );

        uint256 ethUsdcPrice = Constants.oracle.getTwap(
            Constants.poolEthUsdc,
            address(Constants.weth),
            address(Constants.usdc),
            twapPeriod,
            true
        );

        SharesInfo memory params = SharesInfo(
            totalSupply(),
            _amountEth,
            _amountUsdc,
            _amountOsqth,
            osqthEthPrice,
            ethUsdcPrice,
            usdcAmount,
            ethAmount,
            osqthAmount
        );

        return _calcSharesAndAmounts(params);
    }

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
        // console.log("!!!");
        // console.log(params.totalSupply);
        uint256 depositorValue = params
            ._amountEth
            .add(params._amountOsqth.mul(params.osqthEthPrice.div(uint256(1e18))))
            .mul(params.ethUsdcPrice.div(uint256(1e18)))
            .add(params._amountUsdc.mul(uint256(1e12)));

        if (params.totalSupply == 0) {
            return (
                depositorValue,
                // depositorValue.mul(targetEthShare).div(ethUsdcPrice),
                // depositorValue.mul(targetUsdcShare),
                // depositorValue.mul(targetOsqthShare).div(osqthEthPrice.mul(ethUsdcPrice))
                depositorValue.mul(targetEthShare.div(uint256(1e18))).div(params.ethUsdcPrice),
                depositorValue.mul(targetUsdcShare.div(uint256(1e18))),
                depositorValue.mul(targetOsqthShare.div(uint256(1e18))).div(
                    params.osqthEthPrice.mul(params.ethUsdcPrice)
                )
            );
        } else {
            uint256 totalValue = params
                .ethAmount
                .add(params.osqthAmount.mul(params.osqthEthPrice.div(uint256(1e18))))
                .mul(params.ethUsdcPrice.div(uint256(1e18)))
                .add(params.usdcAmount.mul(uint256(1e12)));
            uint256 depositorShare = depositorValue.div(totalValue.add(depositorValue));

            return (
                params.totalSupply.mul(depositorShare).div(uint256(1e18).sub(depositorShare)),
                depositorShare.mul(params.ethAmount).div(uint256(1e18).sub(depositorShare)),
                depositorShare.mul(params.usdcAmount).div(uint256(1e18).sub(depositorShare)),
                depositorShare.mul(params.osqthAmount).div(uint256(1e18).sub(depositorShare))
            );
        }
    }

    /**
     * @notice Calculates the vault's total holdings of token0 and token1 - in
     * other words, how much of each token the vault would hold if it withdrew
     * all its liquidity from Uniswap.
     */
    function _getTotalAmounts()
        internal
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        (uint256 amountWeth0, uint256 usdcAmount) = getPositionAmount(
            Constants.poolEthUsdc,
            orderEthUsdcLower,
            orderEthUsdcUpper
        );

        (uint256 osqthAmount, uint256 amountWeth1) = getPositionAmount(
            Constants.poolEthOsqth,
            orderEthUsdcLower,
            orderEthUsdcUpper
        );

        return (amountWeth0.add(amountWeth1), usdcAmount, osqthAmount);
    }

    /**
     * @notice Amounts of token0 and token1 held in vault's position. Includes owed fees.
     * @dev Doesn't include fees accrued since last poke.
     */
    function getPositionAmount(
        address pool,
        int24 tickLower,
        int24 tickUpper
    ) public view returns (uint256 total0, uint256 total1) {
        (uint128 liquidity, , , uint128 tokensOwed0, uint128 tokensOwed1) = _position(pool, tickLower, tickUpper);
        (total0, total1) = _amountsForLiquidity(pool, tickLower, tickUpper, liquidity);
    }

    /// @dev Wrapper around `LiquidityAmounts.getAmountsForLiquidity()`.
    function _amountsForLiquidity(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) internal view returns (uint256, uint256) {
        (uint160 sqrtRatioX96, , , , , , ) = IUniswapV3Pool(pool).slot0();
        return
            LiquidityAmounts.getAmountsForLiquidity(
                sqrtRatioX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidity
            );
    }

    /// @dev Withdraws share of liquidity in a range from Uniswap pool.
    function _burnLiquidityShare(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint256 shares,
        uint256 totalSupply
    ) internal returns (uint256 amount0, uint256 amount1) {
        (uint128 totalLiquidity, , , , ) = _position(pool, tickLower, tickUpper);
        uint256 liquidity = uint256(totalLiquidity).mul(shares).div(totalSupply);

        if (liquidity > 0) {
            (uint256 burned0, uint256 burned1, uint256 fees0, uint256 fees1) = _burnAndCollect(
                pool,
                tickLower,
                tickUpper,
                _toUint128(liquidity)
            );

            //add share of fees
            amount0 = burned0.add(fees0.mul(shares).div(totalSupply));
            amount1 = burned1.add(fees1.mul(shares).div(totalSupply));
        }
    }

    /// @dev Withdraws liquidity from a range and collects all fees in the process.
    function _burnAndCollect(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    )
        internal
        returns (
            uint256 burned0,
            uint256 burned1,
            uint256 feesToVault0,
            uint256 feesToVault1
        )
    {
        if (liquidity > 0) {
            IUniswapV3Pool(pool).burn(tickLower, tickUpper, liquidity);
        }

        (uint256 collect0, uint256 collect1) = IUniswapV3Pool(pool).collect(
            address(this),
            tickLower,
            tickUpper,
            type(uint128).max,
            type(uint128).max
        );

        feesToVault0 = collect0.sub(burned0);
        feesToVault1 = collect1.sub(burned1);
    }

    /**
     * @notice check if hedging based on time threshold is allowed
     * @return true if time hedging is allowed
     * @return auction trigger timestamp
     */
    function _isTimeRebalance() internal view returns (bool, uint256) {
        uint256 auctionTriggerTime = timeAtLastRebalance.add(rebalanceTimeThreshold);

        return (block.timestamp >= auctionTriggerTime, auctionTriggerTime);
    }

    /** //TODO
     * @notice check if hedging based on price threshold is allowed
     * @param _auctionTriggerTime timestamp where auction started
     * @return true if hedging is allowed
     */
    function _isPriceRebalance(uint256 _auctionTriggerTime) internal returns (bool) {
        return true;
    }

    /**
     * @notice check the direction of auction
     * @param _ethUsdcPrice current wETH/USDC price
     * @return isPriceInc true if price increased
     */
    function _checkAuctionType(uint256 _ethUsdcPrice) internal view returns (bool isPriceInc) {
        isPriceInc = _ethUsdcPrice >= ethPriceAtLastRebalance ? true : false;
    }

    /**
     * @notice calculate how much of each token the strategy need to sell to achieve target proportion
     * @param _currentEthUsdcPrice current wETH/USDC price
     * @param _currentOsqthEthPrice current oSQTH/ETH price
     * @param _auctionTriggerTime time when auction has started
     * @param _isPriceInc true if price increased
     * @return deltaEth amount of wETH to sell or buy
     * @return deltaUsdc amount of USDC to sell or buy
     * @return deltaOsqth amount of oSQTH to sell or buy
     */
    function _getDeltas(
        uint256 _currentEthUsdcPrice,
        uint256 _currentOsqthEthPrice,
        uint256 _auctionTriggerTime,
        bool _isPriceInc
    )
        internal
        view
        returns (
            uint256 deltaEth,
            uint256 deltaUsdc,
            uint256 deltaOsqth
        )
    {
        (uint256 ethAmount, uint256 usdcAmount, uint256 osqthAmount) = _getTotalAmounts();

        //add unused deposited tokens
        ethAmount = ethAmount.add(Constants.weth.balanceOf(address(this)));
        //@dev some usdc and osqth may left after the prev rebalance
        usdcAmount = usdcAmount.add(Constants.usdc.balanceOf(address(this)));
        osqthAmount = osqthAmount.add(Constants.osqth.balanceOf(address(this)));

        (uint256 _auctionEthUsdcPrice, uint256 _auctionOsqthEthPrice) = _getPriceMultiplier(
            _auctionTriggerTime,
            _currentEthUsdcPrice,
            _currentOsqthEthPrice,
            _isPriceInc
        );

        //calculate current total value based on auction prices
        uint256 totalValue = ethAmount.mul(_auctionEthUsdcPrice).add(osqthAmount.mul(_auctionOsqthEthPrice)).add(
            usdcAmount
        );

        deltaEth = targetEthShare.div(1e18).mul(totalValue.div(_auctionEthUsdcPrice)).sub(ethAmount);
        deltaUsdc = targetUsdcShare.div(1e18).mul(totalValue).sub(usdcAmount);
        deltaOsqth = targetOsqthShare
            .div(1e18)
            .mul(totalValue.div(_auctionOsqthEthPrice.mul(_auctionEthUsdcPrice)))
            .sub(osqthAmount);
    }

    /**
     * @notice calculate auction price based on auction direction, start time and ETH/USDC price
     * @param _auctionTriggerTime time when auction has started
     * @param _currentEthUsdcPrice current ETH/USDC price
     * @param _currentOsqthEthPrice current oSQTH/ETH price
     * @param _isPriceInc true if price increased (determine auction direction)
     */
    function _getPriceMultiplier(
        uint256 _auctionTriggerTime,
        uint256 _currentEthUsdcPrice,
        uint256 _currentOsqthEthPrice,
        bool _isPriceInc
    ) internal view returns (uint256 auctionEthUsdcPrice, uint256 auctionOsqthEthPrice) {
        uint256 auctionCompletionRatio = block.timestamp.sub(_auctionTriggerTime) >= auctionTime
            ? 1e18
            : (block.timestamp.sub(_auctionTriggerTime)).div(auctionTime);

        uint256 priceMultiplier;

        if (_isPriceInc) {
            priceMultiplier = maxPriceMultiplier.sub(
                auctionCompletionRatio.mul(maxPriceMultiplier.sub(minPriceMultiplier))
            );
        } else {
            priceMultiplier = minPriceMultiplier.add(
                auctionCompletionRatio.mul(maxPriceMultiplier.sub(minPriceMultiplier))
            );
        }
        auctionEthUsdcPrice = priceMultiplier.mul(_currentEthUsdcPrice);
        auctionOsqthEthPrice = priceMultiplier.mul(_currentOsqthEthPrice);
    }

    /**
     * @notice calculate lower and upper tick for liquidity provision on Uniswap
     * @return ethUsdcLower tick lower for eth:usdc pool
     * @return ethUsdcUpper tick upper for eth:usdc pool
     * @return osqthEthLower tick lower for osqth:eth pool
     * @return osqthEthUpper tick upper for osqth:eth pool
     */
    function _getBoundaries()
        internal
        view
        returns (
            int24 ethUsdcLower,
            int24 ethUsdcUpper,
            int24 osqthEthLower,
            int24 osqthEthUpper
        )
    {
        int24 tickEthUsdc = getTick(Constants.poolEthUsdc);
        int24 tickOsqthEth = getTick(Constants.poolEthOsqth);

        int24 tickFloorEthUsdc = _floor(tickEthUsdc, tickSpacingEthUsdc);
        int24 tickFloorOsqthEth = _floor(tickOsqthEth, tickSpacingOsqthEth);

        int24 tickCeilEthUsdc = tickFloorEthUsdc + tickSpacingEthUsdc;
        int24 tickCeilOsqthEth = tickFloorOsqthEth + tickSpacingOsqthEth;

        int24 ethUsdcThreshold = 1;
        int24 osqthEthThreshold = 1;

        ethUsdcLower = tickFloorEthUsdc - ethUsdcThreshold;
        ethUsdcUpper = tickCeilEthUsdc + ethUsdcThreshold;
        osqthEthLower = tickFloorOsqthEth - osqthEthThreshold;
        osqthEthUpper = tickCeilOsqthEth + osqthEthThreshold;
    }

    /// @dev Fetches current price in ticks from Uniswap pool.
    function getTick(address pool) public view returns (int24 tick) {
        (, tick, , , , , ) = IUniswapV3Pool(pool).slot0();
    }

    /// @dev Wrapper around `LiquidityAmounts.getLiquidityForAmounts()`.
    function _liquidityForAmounts(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1
    ) internal view returns (uint128) {
        (uint160 sqrtRatioX96, , , , , , ) = IUniswapV3Pool(pool).slot0();
        return
            LiquidityAmounts.getLiquidityForAmounts(
                sqrtRatioX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                amount0,
                amount1
            );
    }

    /// @dev Deposits liquidity in a range on the Uniswap pool.
    function _mintLiquidity(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) internal {
        if (liquidity > 0) {
            IUniswapV3Pool(pool).mint(address(this), tickLower, tickUpper, liquidity, "");
        }
    }
}
