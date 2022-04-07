// SPDX-License-Identifier: Unlicense

pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IUniswapV3MintCallback} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import "@uniswap/v3-periphery/contracts/libraries/PositionKey.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "../../libraries/SharedEvents.sol";
import "../../libraries/Constants.sol";
import "../../libraries/StrategyMath.sol";

import "./VaultMathTest.sol";
import "./VaultMathOracle.sol";

import "hardhat/console.sol";

// remove  due to not implementing this function
contract VaultMath is IERC20, ERC20, VaultParams, ReentrancyGuard, IUniswapV3MintCallback, IUniswapV3SwapCallback {
    // using SafeMath for uint256;
    // using StrategyMath for uint256;
    using SafeERC20 for IERC20;

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
    {
        vaultMathOracle = new VaultMathOracle();
        vaultMathTest = new VaultMathTest(
            _minPriceMultiplier,
            _maxPriceMultiplier,
            _targetEthShare,
            _targetUsdcShare,
            _targetOsqthShare
        );
    }

    VaultMathOracle vaultMathOracle;
    VaultMathTest vaultMathTest;

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
            targetEthShare,
            targetUsdcShare,
            targetOsqthShare,
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

        return vaultMathTest._calcSharesAndAmounts(params);
    }

    function _getWithdrawAmounts(uint256 shares, uint256 totalSupply)
        public
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        console.log("totalSupply %s", totalSupply);

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
        console.log("_isTimeRebalance => timeAtLastRebalance: %s", timeAtLastRebalance);
        uint256 auctionTriggerTime = timeAtLastRebalance.add(rebalanceTimeThreshold);

        console.log("_isTimeRebalance => block.timestamp: %s", block.timestamp);
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
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        (uint256 ethAmount, uint256 usdcAmount, uint256 osqthAmount) = _getTotalAmounts();
        (uint256 _auctionEthUsdcPrice, uint256 _auctionOsqthEthPrice) = getAuctionPrices(
            _auctionTriggerTime,
            _currentEthUsdcPrice,
            _currentOsqthEthPrice,
            _isPriceInc
        );

        Constants.DeltasInfo memory params = Constants.DeltasInfo(
            _auctionOsqthEthPrice,
            _auctionEthUsdcPrice,
            usdcAmount,
            ethAmount,
            osqthAmount
        );

        return vaultMathTest._getDeltas(params);
    }

    //@dev <tested>
    /**
     * @notice calculate auction price based on auction direction, start time and ETH/USDC price
     * @param _auctionTriggerTime time when auction has started
     * @param _currentEthUsdcPrice current ETH/USDC price
     * @param _currentOsqthEthPrice current oSQTH/ETH price
     * @param _isPriceInc true if price increased (determine auction direction)
     */
    function getAuctionPrices(
        uint256 _auctionTriggerTime,
        uint256 _currentEthUsdcPrice,
        uint256 _currentOsqthEthPrice,
        bool _isPriceInc
    ) public view returns (uint256, uint256) {
        Constants.AuctionInfo memory params = Constants.AuctionInfo(
            _currentOsqthEthPrice,
            _currentEthUsdcPrice,
            auctionTime,
            _auctionTriggerTime,
            _isPriceInc,
            block.timestamp
        );

        return vaultMathTest._getAuctionPrices(params);
    }

    //@dev <tested>
    /**
     * @notice calculate lower and upper tick for liquidity provision on Uniswap
     * @return ethUsdcLower tick lower for eth:usdc pool
     * @return ethUsdcUpper tick upper for eth:usdc pool
     * @return osqthEthLower tick lower for osqth:eth pool
     * @return osqthEthUpper tick upper for osqth:eth pool
     */
    function _getBoundaries()
        public
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

        int24 ethUsdcThreshold = 1020;
        int24 osqthEthThreshold = 1020;

        ethUsdcLower = tickFloorEthUsdc - ethUsdcThreshold;
        ethUsdcUpper = tickCeilEthUsdc + ethUsdcThreshold;
        osqthEthLower = tickFloorOsqthEth - osqthEthThreshold;
        osqthEthUpper = tickCeilOsqthEth + osqthEthThreshold;
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
        return
            LiquidityAmounts.getLiquidityForAmounts(
                sqrtRatioX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                amount0,
                amount1
            );
    }

    //@dev <tested>
    /// @dev Deposits liquidity in a range on the Uniswap pool.
    function _mintLiquidity(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) public {
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

    /// @dev Callback for Uniswap V3 pool.
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external override {
        // TODO: fix
        // require(msg.sender == address(pool));
        // if (amount0Delta > 0) Constants.weth.safeTransfer(msg.sender, uint256(amount0Delta));
        // if (amount1Delta > 0) Constants.osqth.safeTransfer(msg.sender, uint256(amount1Delta));
    }

    //@dev <tested>
    /// @dev Rounds tick down towards negative infinity so that it's a multiple
    /// of `tickSpacing`.
    function _floor(int24 tick, int24 tickSpacing) public pure returns (int24) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        return compressed * tickSpacing;
    }
}
