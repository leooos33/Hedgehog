// SPDX-License-Identifier: Unlicense

pragma solidity =0.7.6;
pragma abicoder v2;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IUniswapV3MintCallback} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";
import {IUniswapV3SwapCallback} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import {PositionKey} from "@uniswap/v3-periphery/contracts/libraries/PositionKey.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

import "../libraries/SharedEvents.sol";
import "../libraries/Constants.sol";
import "../libraries/StrategyMath.sol";
import {IPrbMathCalculus} from "../interfaces/IPrbMathCalculus.sol";
import "./VaultParams.sol";

import "hardhat/console.sol";

contract VaultMath is VaultParams, ReentrancyGuard, IUniswapV3MintCallback, IUniswapV3SwapCallback {
    using StrategyMath for uint256;
    using SafeERC20 for IERC20;

    /**
     * @notice strategy constructor
       @param _cap max amount of wETH that strategy accepts for deposits
       @param _rebalanceTimeThreshold rebalance time threshold (seconds)
       @param _rebalancePriceThreshold rebalance price threshold (0.05*1e18 = 5%)
       @param _auctionTime auction duration (seconds)
       @param _minPriceMultiplier minimum auction price multiplier (0.95*1e18 = min auction price is 95% of twap)
       @param _maxPriceMultiplier maximum auction price multiplier (1.05*1e18 = max auction price is 105% of twap)
     */
    constructor(
        uint256 _cap,
        uint256 _rebalanceTimeThreshold,
        uint256 _rebalancePriceThreshold,
        uint256 _auctionTime,
        uint256 _minPriceMultiplier,
        uint256 _maxPriceMultiplier
        address iprbCalculusLib //TODO: move to constants
    )
        public
        VaultParams(
            _cap,
            _rebalanceTimeThreshold,
            _rebalancePriceThreshold,
            _auctionTime,
            _minPriceMultiplier,
            _maxPriceMultiplier
        )
    {
        prbMathCalculus = IPrbMathCalculus(iprbCalculusLib);
    }

    IPrbMathCalculus prbMathCalculus;

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
    ) public {
        (uint128 liquidity, , , , ) = _position(pool, tickLower, tickUpper);

        if (liquidity > 0) {
            IUniswapV3Pool(pool).burn(tickLower, tickUpper, 0);
        }
    }

    //@dev <tested>
    /// @dev Wrapper around `IUniswapV3Pool.positions()`.
    function _position(
        address pool,
        int24 tickLower,
        int24 tickUpper
    )
        public
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

        Constants.SharesInfo memory params = Constants.SharesInfo(
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

        return __calcSharesAndAmounts(params);
    }

    function _getWithdrawAmounts(uint256 shares, uint256 totalSupply)
        public
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        // console.log("totalSupply %s", totalSupply);

        uint256 unusedAmountEth = getBalance(Constants.weth).mul(shares).div(totalSupply);
        uint256 unusedAmountUsdc = getBalance(Constants.usdc).mul(shares).div(totalSupply);
        uint256 unusedAmountOsqth = getBalance(Constants.osqth).mul(shares).div(totalSupply);

        //withdraw user share of tokens from the lp positions in current proportion
        (uint256 amountEth0, uint256 amountUsdc) = _burnLiquidityShare(
            Constants.poolEthUsdc,
            orderEthUsdcLower,
            orderEthUsdcUpper,
            shares,
            totalSupply
        );
        (uint256 amountOsqth, uint256 amountEth1) = _burnLiquidityShare(
            Constants.poolEthOsqth,
            orderOsqthEthLower,
            orderOsqthEthUpper,
            shares,
            totalSupply
        );

        // Sum up total amounts owed to recipient
        return (
            unusedAmountEth.add(amountEth0).add(amountEth1),
            unusedAmountUsdc.add(amountUsdc),
            unusedAmountOsqth.add(amountOsqth)
        );
    }

    uint256 public test1;
    uint256 public test2;
    uint256 public test3;

    //@dev <tested>
    /**
     * @notice Calculates the vault's total holdings of token0 and token1 - in
     * other words, how much of each token the vault would hold if it withdrew
     * all its liquidity from Uniswap.
     */
    function _getTotalAmounts()
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        (uint256 usdcAmount, uint256 amountWeth0) = getPositionAmounts(
            Constants.poolEthUsdc,
            orderEthUsdcLower,
            orderEthUsdcUpper
        );

        (uint256 amountWeth1, uint256 osqthAmount) = getPositionAmounts(
            Constants.poolEthOsqth,
            orderOsqthEthLower,
            orderOsqthEthUpper
        );

        return (
            getBalance(Constants.weth).add(amountWeth0).add(amountWeth1),
            getBalance(Constants.usdc).add(usdcAmount),
            getBalance(Constants.osqth).add(osqthAmount)
        );
    }

    //@dev <tested but without swap>
    /**
     * @notice Amounts of token0 and token1 held in vault's position. Includes owed fees.
     * @dev Doesn't include fees accrued since last poke.
     */
    function getPositionAmounts(
        address pool,
        int24 tickLower,
        int24 tickUpper
    ) public view returns (uint256 total0, uint256 total1) {
        (uint128 liquidity, , , uint128 tokensOwed0, uint128 tokensOwed1) = _position(pool, tickLower, tickUpper);
        (uint256 amount0, uint256 amount1) = _amountsForLiquidity(pool, tickLower, tickUpper, liquidity);

        total0 = amount0.add(tokensOwed0);
        total1 = amount1.add(tokensOwed1);
    }

    function getBalance(IERC20 token) public view returns (uint256) {
        return token.balanceOf(address(this)); //? accrued protocol fees
    }

    //@dev <tested>
    /// @dev Wrapper around `LiquidityAmounts.getAmountsForLiquidity()`.
    function _amountsForLiquidity(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) public view returns (uint256, uint256) {
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
    ) public returns (uint256 amount0, uint256 amount1) {
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
        public
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
    function _isTimeRebalance() public view returns (bool, uint256) {
        // console.log("_isTimeRebalance => timeAtLastRebalance: %s", timeAtLastRebalance);
        uint256 auctionTriggerTime = timeAtLastRebalance.add(rebalanceTimeThreshold);

        // console.log("_isTimeRebalance => block.timestamp: %s", block.timestamp);
        return (block.timestamp >= auctionTriggerTime, auctionTriggerTime);
    }

    /**
     * @notice check if hedging based on price threshold is allowed
     * @param _auctionTriggerTime timestamp where auction started
     * @return true if hedging is allowed
     */
    function _isPriceRebalance(uint256 _auctionTriggerTime) public returns (bool) {
        //if (_auctionTriggerTime < timeAtLastRebalance) return false;
        //uint32 secondsToTrigger = uint32(block.timestamp.sub(_auctionTriggerTime));
        //uint256 ethUsdcPriceAtTrigger = IOracle(oracle).getHistoricalTwap(
        //    Constants.poolEthUsdc,
        //    address(Constants.weth),
        //    address(Constants.usdc),
        //    secondsToTrigger + twapPeriod,
        //    secondsToTrigger
        //);

        //uint256 cachedRatio = ethUsdcPriceAtTrigger.wdiv(ethPriceAtLastRebalance);
        //uint256 priceTreshold = cachedRatio > 1e18 : (cachedRatio).sub(1e18) : uint256(1e18).sub(cachedRatio);
        //return priceTreshold >= rebalancePriceThreshold

        return true;
    }

    /**
     * @notice check the direction of auction
     * @param _ethUsdcPrice current wETH/USDC price
     * @return isPriceInc true if price increased
     */
    function _checkAuctionType(uint256 _ethUsdcPrice) public view returns (bool isPriceInc) {
        // console.log("_checkAuctionType");
        // console.log(_ethUsdcPrice);
        // console.log(ethPriceAtLastRebalance);
        isPriceInc = _ethUsdcPrice >= ethPriceAtLastRebalance ? true : false;
    }

    function _getPriceFromTick(int24 tick) internal view returns (uint256) {
        //uint x = 162714639867323407420353073371;

        console.log(uint256(TickMath.getSqrtRatioAtTick(tick)));
        return prbMathCalculus.getPriceFromTick(TickMath.getSqrtRatioAtTick(tick));
    }

    function _getPriceMultiplier(uint256 _auctionTriggerTime, bool _isPriceInc) internal view returns (uint256) {
        uint256 auctionCompletionRatio = block.timestamp.sub(_auctionTriggerTime) >= auctionTime
            ? 1e18
            : (block.timestamp.sub(_auctionTriggerTime)).div(auctionTime);

        uint256 priceMultiplier;
        if (_isPriceInc) {
                priceMultiplier = minPriceMultiplier.add(
                auctionCompletionRatio.mul(maxPriceMultiplier.sub(minPriceMultiplier))
            );

        } else {
            priceMultiplier = maxPriceMultiplier.sub(
                auctionCompletionRatio.mul(maxPriceMultiplier.sub(minPriceMultiplier))
            );
        }

        return priceMultiplier;
    }

    function _getValue(
        uint256 amountEth,
        uint256 amountUsdc,
        uint256 amountOsqth,
        uint256 ethUsdcPrice,
        uint256 osqthEthPrice
    ) internal view returns (uint256) {
        return (amountOsqth.mul(osqthEthPrice) + amountEth).mul(ethUsdcPrice) + amountUsdc.mul(1e30);
    }

    function _getAuctionParams(
        uint256 _auctionTriggerTime
    ) 
    internal view returns (Constants.AuctionParams memory) {
        (uint256 ethUsdcPrice, uint256 osqthEthPrice) = _getPrices();

        bool _isPriceInc = _checkAuctionType(ethUsdcPrice);
        uint256 priceMultiplier = _getPriceMultiplier(_auctionTriggerTime, _isPriceInc);

        //boundaries for auction prices (current price * multiplier)
        Constants.Boundaries memory boundaries = _getBoundaries(
            ethUsdcPrice.mul(priceMultiplier), 
            osqthEthPrice.mul(priceMultiplier)
        );

        (uint256 ethBalance, uint256 usdcBalance, uint256 osqthBalance) = _getTotalAmounts();

        //Value for LPing
        uint256 totalValue=_getValue(
            ethBalance,
            usdcBalance,
            osqthBalance,
            ethUsdcPrice,
            osqthEthPrice
        ).mul(uint256(2e18) - priceMultiplier);

        uint256 vm = priceMultiplier.mul(uint256(1e18)).div(priceMultiplier.add(uint256(1e18))); //Value multiplier

        uint128 liquidityEthUsdc = prbMathCalculus.getLiquidityForValue(
            totalValue.mul(vm),
            ethUsdcPrice,
            uint256(1e30).div(_getPriceFromTick(boundaries.ethUsdcUpper)), //проверить порядок
            uint256(1e30).div(_getPriceFromTick(boundaries.ethUsdcLower))
        );

        uint128 liquidityOsqthEth = prbMathCalculus.getLiquidityForValue(
            totalValue.mul(uint256(1e18) - vm).div(ethUsdcPrice),
            osqthEthPrice,
            uint256(1e18).div(_getPriceFromTick(boundaries.osqthEthLower)),
            uint256(1e18).div(_getPriceFromTick(boundaries.osqthEthUpper))
        );

        (uint256 deltaEth, uint256 deltaUsdc, uint256 deltaOsqth) = __getDeltas(
            boundaries,
            liquidityEthUsdc,
            liquidityOsqthEth,
            ethBalance,
            usdcBalance,
            osqthBalance
        );

        return
            Constants.AuctionParams(
                _isPriceInc,
                deltaEth,
                deltaUsdc,
                deltaOsqth,
                boundaries,
                liquidityEthUsdc,
                liquidityOsqthEth
            );
    }

    function _getPrices() internal view returns (uint256 ethUsdcPrice, uint256 osqthEthPrice) {
        int24 ethUsdcTick = getTick(Constants.poolEthUsdc);
        int24 osqthEthTick = getTick(Constants.poolEthOsqth);

        ethUsdcPrice = uint256(1e30).div(_getPriceFromTick(ethUsdcTick));
        osqthEthPrice = uint256(1e18).div(_getPriceFromTick(osqthEthTick));
    }

    //@dev <tested>
    /// @dev Fetches current price in ticks from Uniswap pool.
    function getTick(address pool) public view returns (int24 tick) {
        (, tick, , , , , ) = IUniswapV3Pool(pool).slot0();
    }

    //@dev <tested>
    /// @dev Wrapper around `LiquidityAmounts.getLiquidityForAmounts()`.
    function _liquidityForAmounts(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1
    ) public view returns (uint128) {
        (uint160 sqrtRatioX96, , , , , , ) = IUniswapV3Pool(pool).slot0();
        // console.log("_liquidityForAmounts");
        // console.log(sqrtRatioX96);
        // console.log(TickMath.getSqrtRatioAtTick(tickLower));
        // console.log(TickMath.getSqrtRatioAtTick(tickUpper));
        // console.log(amount0);
        // console.log(amount1);
        return
            LiquidityAmounts.getLiquidityForAmounts(
                sqrtRatioX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                amount0,
                amount1
            );
    }
    //TODO
    //@dev <tested>
    /// @dev Deposits liquidity in a range on the Uniswap pool.
    function _mintLiquidity(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) public {
        console.log("pool %s", pool);
        console.log("tickLower %s", uint256(tickLower));
        console.log("tickUpper %s", uint256(tickUpper));
        console.log("liquidity %s", uint256(liquidity));

        if (liquidity > 0) {
            address token0 = pool == Constants.poolEthUsdc ? address(Constants.usdc) : address(Constants.weth);
            address token1 = pool == Constants.poolEthUsdc ? address(Constants.weth) : address(Constants.osqth);
            bytes memory params = abi.encode(pool, token0, token1);

            IUniswapV3Pool(pool).mint(address(this), tickLower, tickUpper, liquidity, params);
        }
    }

    //@dev <tested>
    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external override {
        (address pool, address token0, address token1) = abi.decode(data, (address, address, address));
        console.log("callback on  %s: %s", token0, amount0Owed);
        console.log("callback on  %s: %s", token1, amount1Owed);

        require(msg.sender == pool);
        if (amount0Owed > 0) IERC20(token0).safeTransfer(msg.sender, amount0Owed);
        if (amount1Owed > 0) IERC20(token1).safeTransfer(msg.sender, amount1Owed);
    }

    // @dev Callback for Uniswap V3 pool.
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external override {
        (address pool, address token0, address token1) = abi.decode(data, (address, address, address));
        console.log("!callback on %s: %s", token0, uint256(amount0Delta));
        console.log("!callback on %s: %s", token1, uint256(amount1Delta));

        require(msg.sender == pool);
        if (amount0Delta > 0) IERC20(token0).safeTransfer(msg.sender, uint256(amount0Delta));
        if (amount1Delta > 0) IERC20(token1).safeTransfer(msg.sender, uint256(amount1Delta));
    }

    // TODO: add to new function
    //@dev <tested>
    function __calcSharesAndAmounts(Constants.SharesInfo memory params)
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 depositorValue = _getValue(
            _amountEth,
            _amountUsdc,
            _amountOsqth,
            params.ethUsdcPrice,
            params.osqthEthPrice
        );

        if (params.totalSupply == 0) {
            //deposit in a 50.79% eth, 24.35% usdc, 24.86% osqth proportion
            return (
                depositorValue,
                depositorValue.mul(507924136843192000).div(params.ethUsdcPrice),
                depositorValue.mul(243509747368953000).div(uint256(1e30)),
                depositorValue.mul(248566115787854000).div(params.osqthEthPrice).div(params.ethUsdcPrice)
                );
        } else {
            uint256 totalValue = getValue(
                params.osqthAmount,
                params.ethUsdcPrice,
                params.ethAmount,
                params.osqthEthPrice,
                params.usdcAmount
            );

            return (
                params.totalSupply.mul(depositorValue).div(totalValue),
                params.ethAmount.mul(depositorValue).div(totalValue),
                params.usdcAmount.mul(depositorValue).div(totalValue),
                params.osqthAmount.mul(depositorValue).div(totalValue)
            );
        }
    }

    //@dev <tested>
    function __getDeltas(
        Constants.Boundaries memory boundaries,
        uint128 liquidityEthUsdc,
        uint128 liquidityOsqthEth,
        uint256 ethBalance,
        uint256 usdcBalance,
        uint256 osqthBalance
    )
        public
        view
        returns (
            uint256, //deltaEth
            uint256, //deltaUsdc
            uint256 //deltaOsqth
        )
    {
        //scope
        (uint256 ethAmount0, uint256 usdcAmount) = _amountsForLiquidity(
            Constants.poolEthUsdc,
            boundaries.ethUsdcLower,
            boundaries.ethUsdcUpper,
            liquidityEthUsdc
        );
        (uint256 ethAmount1, uint256 osqthAmount) = _amountsForLiquidity(
            Constants.poolEthOsqth,
            boundaries.osqthEthLower,
            boundaries.osqthEthUpper,
            liquidityOsqthEth
        );
        return (
            ethBalance.suba(ethAmount0).suba(ethAmount1),
            usdcBalance.suba(usdcAmount),
            osqthBalance.suba(osqthAmount)
        );
    }

    //@dev <tested>
    /// @dev Rounds tick down towards negative infinity so that it's a multiple
    /// of `tickSpacing`.
    function _floor(int24 tick, int24 tickSpacing) public pure returns (int24) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        return compressed * tickSpacing;
    }

    function _getBoundaries(uint256 aEthUsdcPrice, uint256 aOsqthEthPrice)
        public
        view
        returns (Constants.Boundaries memory)
    {
        (uint160 _aEthUsdcTick, uint160 _aOsqthEthTick) = prbMathCalculus.getTicks(aEthUsdcPrice, aOsqthEthPrice);

        int24 aEthUsdcTick = TickMath.getTickAtSqrtRatio(_aEthUsdcTick);

        int24 aOsqthEthTick = TickMath.getTickAtSqrtRatio(_aOsqthEthTick);

        int24 tickFloorEthUsdc = _floor(aEthUsdcTick, tickSpacingEthUsdc);
        int24 tickFloorOsqthEth = _floor(aEthUsdcTick, tickSpacingOsqthEth);

        int24 tickCeilEthUsdc = tickFloorEthUsdc + tickSpacingEthUsdc;
        int24 tickCeilOsqthEth = tickFloorOsqthEth + tickSpacingOsqthEth;

        int24 ethUsdcThreshold = 960;
        int24 osqthEthThreshold = 960;

        return
            Constants.Boundaries(
                tickFloorEthUsdc - ethUsdcThreshold,
                tickCeilEthUsdc + ethUsdcThreshold,
                tickFloorOsqthEth - osqthEthThreshold,
                tickCeilOsqthEth + osqthEthThreshold
            );
    }
}
