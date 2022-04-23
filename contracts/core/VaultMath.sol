// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;
pragma abicoder v2;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IUniswapV3MintCallback} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";
import {IUniswapV3SwapCallback} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {PositionKey} from "@uniswap/v3-periphery/contracts/libraries/PositionKey.sol";

import "../libraries/SharedEvents.sol";
import "../libraries/Constants.sol";
import {PRBMathUD60x18} from "../libraries/math/PRBMathUD60x18.sol";

import "./VaultParams.sol";

import "hardhat/console.sol";

contract VaultMath is VaultParams, ReentrancyGuard, IUniswapV3MintCallback, IUniswapV3SwapCallback {
    using PRBMathUD60x18 for uint256;
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
        uint256 _maxPriceMultiplier,
        uint256 protocolFee
    )
        VaultParams(
            _cap,
            _rebalanceTimeThreshold,
            _rebalancePriceThreshold,
            _auctionTime,
            _minPriceMultiplier,
            _maxPriceMultiplier,
            protocolFee
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

        (uint256 ethUsdcPrice, uint256 osqthEthPrice) = _getPrices();

        console.log("calcSharesAndAmounts");
        console.log("osqthEthPrice %s", osqthEthPrice);
        console.log("ethUsdcPrice %s", ethUsdcPrice);
        // console.log("ethAmount %s", ethAmount);
        // console.log("usdcAmount %s", usdcAmount);
        // console.log("osqthAmount %s", osqthAmount);

        uint256 depositorValue = getValue(_amountEth, _amountUsdc, _amountOsqth, ethUsdcPrice, osqthEthPrice);

        // console.log("depositorValue %s", depositorValue);

        if (totalSupply() == 0) {
            //deposit in a 50.79% eth, 24.35% usdc, 24.86% osqth proportion
            return (
                depositorValue,
                depositorValue.mul(507924136843192000).div(ethUsdcPrice),
                depositorValue.mul(243509747368953000).div(uint256(1e30)),
                depositorValue.mul(248566115787854000).div(osqthEthPrice).div(ethUsdcPrice)
            );
        } else {
            uint256 totalValue = getValue(osqthAmount, ethUsdcPrice, ethAmount, osqthEthPrice, usdcAmount);

            return (
                totalSupply().mul(depositorValue).div(totalValue),
                ethAmount.mul(depositorValue).div(totalValue),
                usdcAmount.mul(depositorValue).div(totalValue),
                osqthAmount.mul(depositorValue).div(totalValue)
            );
        }
    }

    function _getWithdrawAmounts(uint256 shares, uint256 totalSupply)
        public
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        console.log("_getWithdrawAmounts");
        console.log("totalSupply %s", totalSupply);
        console.log("shares %s", shares);

        uint256 unusedAmountEth = (getBalance(Constants.weth).sub(accruedFeesEth)).mul(shares).div(totalSupply);
        uint256 unusedAmountUsdc = (getBalance(Constants.usdc).sub(accruedFeesUsdc)).mul(shares).div(totalSupply);
        uint256 unusedAmountOsqth = (getBalance(Constants.osqth).sub(accruedFeesOsqth)).mul(shares).div(totalSupply);

        console.log("unusedAmountEth %s", unusedAmountEth);
        console.log("unusedAmountUsdc %s", unusedAmountUsdc);
        console.log("unusedAmountOsqth %s", unusedAmountOsqth);

        //withdraw user share of tokens from the lp positions in current proportion
        (uint256 amountUsdc, uint256 amountEth0) = _burnLiquidityShare(
            Constants.poolEthUsdc,
            orderEthUsdcLower,
            orderEthUsdcUpper,
            shares,
            totalSupply
        );
        (uint256 amountEth1, uint256 amountOsqth) = _burnLiquidityShare(
            Constants.poolEthOsqth,
            orderOsqthEthLower,
            orderOsqthEthUpper,
            shares,
            totalSupply
        );

        // console.log("amountEth0 %s", )

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

        console.log("_getTotalAmounts");
        console.log("usdcAmount %s", usdcAmount);
        console.log("amountWeth0 %s", amountWeth0);
        console.log("amountWeth1 %s", amountWeth1);
        console.log("osqthAmount %s", osqthAmount);

        return (
            getBalance(Constants.weth).add(amountWeth0).add(amountWeth1).sub(accruedFeesEth),
            getBalance(Constants.usdc).add(usdcAmount).sub(accruedFeesUsdc),
            getBalance(Constants.osqth).add(osqthAmount).sub(accruedFeesOsqth)
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
    ) public view returns (uint256, uint256) {
        (uint128 liquidity, , , uint128 tokensOwed0, uint128 tokensOwed1) = _position(pool, tickLower, tickUpper);
        (uint256 amount0, uint256 amount1) = _amountsForLiquidity(pool, tickLower, tickUpper, liquidity);

        uint256 oneMinusFee = uint256(1e6).sub(protocolFee);
        console.log("getPositionAmounts");
        console.log("oneMinusFee %s", oneMinusFee);
        console.log("amount0 %s", amount0);
        console.log("tokensOwed0 %s", tokensOwed0);
        console.log("amount1 %s", amount1);
        console.log("tokensOwed1 %s", tokensOwed1);

        uint256 total0;
        if (pool == Constants.poolEthUsdc) {
            total0 = (amount0.add(tokensOwed0)).mul(oneMinusFee.mul(1e30));
        } else {
            total0 = (amount0.add(tokensOwed0)).mul(oneMinusFee).div(1e6);
        }

        // console.log("total0 %s", total0);
        return (total0, (amount1.add(tokensOwed1)).mul(oneMinusFee).div(1e6));
        // return (amount0.add(tokensOwed0), amount1.add(tokensOwed1));
    }

    function getBalance(IERC20 token) public view returns (uint256) {
        return token.balanceOf(address(this)); //? accrued protocol fees
    }

    //@dev <tested>
    function _amountsForLiquidity(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) public view returns (uint256, uint256) {
        (uint160 sqrtRatioX96, , , , , , ) = IUniswapV3Pool(pool).slot0();
        return
            Constants.uniswapAdaptor.getAmountsForLiquidity(
                sqrtRatioX96,
                Constants.uniswapAdaptor.getSqrtRatioAtTick(tickLower),
                Constants.uniswapAdaptor.getSqrtRatioAtTick(tickUpper),
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
        console.log("_burnAndCollect");
        console.logInt(tickLower);
        console.logInt(tickUpper);
        console.log(liquidity);

        if (liquidity > 0) {
            (burned0, burned1) = IUniswapV3Pool(pool).burn(tickLower, tickUpper, liquidity);
        }

        console.log("burned0 %s ", burned0);
        console.log("burned1 %s ", burned1);

        (uint256 collect0, uint256 collect1) = IUniswapV3Pool(pool).collect(
            address(this),
            tickLower,
            tickUpper,
            type(uint128).max,
            type(uint128).max
        );

        feesToVault0 = collect0.sub(burned0);
        feesToVault1 = collect1.sub(burned1);

        if (protocolFee > 0) {
            uint256 feesToProtocol0 = feesToVault0.mul(protocolFee).div(1e6);
            uint256 feesToProtocol1 = feesToVault1.mul(protocolFee).div(1e6);

            console.log("feesToProtocol0 %s", feesToProtocol0);
            console.log("feesToProtocol1 %s", feesToProtocol1);

            feesToVault0 = feesToVault0.sub(feesToProtocol0);
            feesToVault1 = feesToVault1.sub(feesToProtocol1);
            if (pool == Constants.poolEthUsdc) {
                accruedFeesUsdc = accruedFeesUsdc.add(feesToProtocol0);
                accruedFeesEth = accruedFeesEth.add(feesToProtocol1);
            } else if (pool == Constants.poolEthOsqth) {
                accruedFeesEth = accruedFeesEth.add(feesToProtocol0);
                accruedFeesOsqth = accruedFeesOsqth.add(feesToProtocol1);
            }

            console.log("accruedFeesUsdc %s", accruedFeesUsdc);
            console.log("accruedFeesEth %s", accruedFeesEth);
            console.log("accruedFeesOsqth %s", accruedFeesOsqth);
        }
        //emit CollectFees(feesToVault0, feesToVault1, feesToProtocol0, feesToProtocol1);
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
        //const = 2^192
        uint256 const = 6277101735386680763835789423207666416102355444464034512896;

        uint160 sqrtRatioAtTick = Constants.uniswapAdaptor.getSqrtRatioAtTick(tick);
        return (uint256(sqrtRatioAtTick)).pow(uint256(2e18)).mul(1e36).div(const);
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

    function _getAuctionParams(uint256 _auctionTriggerTime) internal view returns (Constants.AuctionParams memory) {
        console.log("_getAuctionParams");
        console.log("block.timestamp", block.timestamp);

        (uint256 ethUsdcPrice, uint256 osqthEthPrice) = _getPrices();

        console.log("ethUsdcPrice %s", ethUsdcPrice);
        console.log("osqthEthPrice %s", osqthEthPrice);

        bool _isPriceInc = _checkAuctionType(ethUsdcPrice);
        uint256 priceMultiplier = _getPriceMultiplier(_auctionTriggerTime, _isPriceInc);

        console.log("priceMultiplier %s", priceMultiplier);

        //boundaries for auction prices (current price * multiplier)
        Constants.Boundaries memory boundaries = _getBoundaries(
            ethUsdcPrice.mul(priceMultiplier),
            osqthEthPrice.mul(priceMultiplier)
        );

        console.log(">boundaries");
        console.log("boundaries.ethUsdcUpper");
        console.logInt(boundaries.ethUsdcUpper);
        console.log("boundaries.ethUsdcLower");
        console.logInt(boundaries.ethUsdcLower);
        console.log("boundaries.osqthEthLower");
        console.logInt(boundaries.osqthEthLower);
        console.log("boundaries.osqthEthUpper");
        console.logInt(boundaries.osqthEthUpper);

        (uint256 ethBalance, uint256 usdcBalance, uint256 osqthBalance) = _getTotalAmounts();

        console.log("ethBalance %s", ethBalance);
        console.log("usdcBalance %s", usdcBalance);
        console.log("osqthBalance %s", osqthBalance);

        //Value for LPing
        uint256 totalValue = getValue(ethBalance, usdcBalance, osqthBalance, ethUsdcPrice, osqthEthPrice).mul(
            uint256(2e18) - priceMultiplier
        );

        uint256 vm = priceMultiplier.mul(uint256(1e18)).div(priceMultiplier.add(uint256(1e18))); //Value multiplier

        // console.log("boundaries.ethUsdcUpper");
        // console.log(int256(boundaries.ethUsdcUpper));
        // console.log("boundaries.ethUsdcLower");
        // console.log(int256(boundaries.ethUsdcLower));

        console.log("_getPriceFromTick(boundaries.ethUsdcUpper)");
        console.log(_getPriceFromTick(boundaries.ethUsdcUpper));
        console.log("_getPriceFromTick(boundaries.ethUsdcLower)");
        console.log(_getPriceFromTick(boundaries.ethUsdcLower));

        uint128 liquidityEthUsdc = getLiquidityForValue(
            totalValue.mul(vm),
            ethUsdcPrice,
            uint256(1e30).div(_getPriceFromTick(boundaries.ethUsdcUpper)),
            uint256(1e30).div(_getPriceFromTick(boundaries.ethUsdcLower)),
            1e12
        );

        uint128 liquidityOsqthEth = getLiquidityForValue(
            totalValue.mul(uint256(1e18) - vm).div(ethUsdcPrice),
            osqthEthPrice,
            uint256(1e18).div(_getPriceFromTick(boundaries.osqthEthUpper)),
            uint256(1e18).div(_getPriceFromTick(boundaries.osqthEthLower)),
            1e18
        );

        console.log("liquidityEthUsdc %s", liquidityEthUsdc);
        console.log("liquidityOsqthEth %s", liquidityOsqthEth);

        (uint256 deltaEth, uint256 deltaUsdc, uint256 deltaOsqth) = _getDeltas(
            boundaries,
            liquidityEthUsdc,
            liquidityOsqthEth,
            ethBalance,
            usdcBalance,
            osqthBalance
        );

        console.log("deltaEth %s", deltaEth);
        console.log("deltaUsdc %s", deltaUsdc);
        console.log("deltaOsqth %s", deltaOsqth);

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

        (int24 twapEthUsdc, int24 twapOsqthEth) = _getTwap();

        int24 deviation0 = ethUsdcTick > twapEthUsdc ? ethUsdcTick - twapEthUsdc : twapEthUsdc - ethUsdcTick;
        int24 deviation1 = osqthEthTick > twapOsqthEth ? osqthEthTick - twapOsqthEth : twapOsqthEth - osqthEthTick;

        require(deviation0 <= maxTDEthUsdc || deviation1 <= maxTDOsqthEth, "Max TWAP Deviation");

        ethUsdcPrice = uint256(1e30).div(_getPriceFromTick(ethUsdcTick));
        osqthEthPrice = uint256(1e18).div(_getPriceFromTick(osqthEthTick));
    }

    //@dev <tested>
    /// @dev Fetches current price in ticks from Uniswap pool.
    function getTick(address pool) public view returns (int24 tick) {
        (, tick, , , , , ) = IUniswapV3Pool(pool).slot0();
    }

    function _getTwap() public view returns (int24, int24) {
        uint32 _twapPeriod = twapPeriod;
        uint32[] memory secondsAgo = new uint32[](2);
        secondsAgo[0] = _twapPeriod;
        secondsAgo[1] = 0;

        (int56[] memory tickCumulativesEthUsdc, ) = Constants.poolEthUsdc.observe(secondsAgo);
        (int56[] memory tickCumulativesEthOsqth, ) = Constants.poolEthOsqth.observe(secondsAgo);
        return (
            int24((tickCumulativesEthUsdc[1] - tickCumulativesEthUsdc[0]) / _twapPeriod),
            int24((tickCumulativesEthOsqth[1] - tickCumulativesEthOsqth[0]) / _twapPeriod)
                );
    }

    //@dev <tested>
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
        // console.log(Constants.uniswapAdaptor.getSqrtRatioAtTick(tickLower));
        // console.log(Constants.uniswapAdaptor.getSqrtRatioAtTick(tickUpper));
        // console.log(amount0);
        // console.log(amount1);
        return
            Constants.uniswapAdaptor.getLiquidityForAmounts(
                sqrtRatioX96,
                Constants.uniswapAdaptor.getSqrtRatioAtTick(tickLower),
                Constants.uniswapAdaptor.getSqrtRatioAtTick(tickUpper),
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
        // console.log("tickLower %s", uint256(tickLower));
        // console.log("tickUpper %s", uint256(tickUpper));
        // console.log("liquidity %s", uint256(liquidity));

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

    //@dev <tested>
    function _getDeltas(
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
        (uint256 usdcAmount, uint256 ethAmount0) = _amountsForLiquidity(
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

        console.log("_getDeltas");
        console.log("usdcAmount %s", usdcAmount);
        console.log("ethAmount0 %s", ethAmount0);
        console.log("ethAmount1 %s", ethAmount1);
        console.log("osqthAmount %s", osqthAmount);

        return (
            ethBalance.suba(ethAmount0).suba(ethAmount1),
            usdcBalance.suba(usdcAmount),
            osqthBalance.suba(osqthAmount)
        );
    }

    function _getBoundaries(uint256 aEthUsdcPrice, uint256 aOsqthEthPrice)
        public
        view
        returns (Constants.Boundaries memory)
    {
        console.log("_getBoundaries");
        (uint160 _aEthUsdcTick, uint160 _aOsqthEthTick) = getTicks(aEthUsdcPrice, aOsqthEthPrice);

        console.log("aEthUsdcPrice %s", aEthUsdcPrice);
        console.log("aOsqthEthPrice %s", aOsqthEthPrice);
        console.log("_aEthUsdcTick %s", _aEthUsdcTick);
        console.log("_aOsqthEthTick %s", _aOsqthEthTick);

        int24 aEthUsdcTick = Constants.uniswapAdaptor.getTickAtSqrtRatio(_aEthUsdcTick);
        int24 aOsqthEthTick = Constants.uniswapAdaptor.getTickAtSqrtRatio(_aOsqthEthTick);

        int24 tickFloorEthUsdc = _floor(aEthUsdcTick, tickSpacingEthUsdc);
        int24 tickFloorOsqthEth = _floor(aOsqthEthTick, tickSpacingOsqthEth);

        int24 tickCeilEthUsdc = tickFloorEthUsdc + tickSpacingEthUsdc;
        int24 tickCeilOsqthEth = tickFloorOsqthEth + tickSpacingOsqthEth;

        console.log("aEthUsdcTick");
        console.logInt(aEthUsdcTick);
        console.log("aOsqthEthTick");
        console.logInt(aOsqthEthTick);

        console.log("tickFloorEthUsdc");
        console.logInt(tickFloorEthUsdc);
        console.log("tickFloorOsqthEth");
        console.logInt(tickFloorOsqthEth);

        return
            Constants.Boundaries(
                tickFloorEthUsdc - ethUsdcThreshold,
                tickCeilEthUsdc + ethUsdcThreshold,
                tickFloorOsqthEth - osqthEthThreshold,
                tickCeilOsqthEth + osqthEthThreshold
            );
    }

    function getTicks(uint256 aEthUsdcPrice, uint256 aOsqthEthPrice) public pure returns (uint160, uint160) {
        return (
            _toUint160(
                //sqrt(price)*2**96
                ((uint256(1e30).div(aEthUsdcPrice)).sqrt()).mul(79228162514264337593543950336)
            ),
            _toUint160(((uint256(1e18).div(aOsqthEthPrice)).sqrt()).mul(79228162514264337593543950336))
        );
    }

    /// @dev Fetches time-weighted average price in ticks from Uniswap pool.
    function _getTwap() public view returns (int24, int24) {
        uint32 _twapPeriod = twapPeriod;
        uint32[] memory secondsAgo = new uint32[](2);
        secondsAgo[0] = _twapPeriod;
        secondsAgo[1] = 0;

        (int56[] memory tickCumulativesEthUsdc, ) = IUniswapV3Pool(Constants.poolEthUsdc).observe(secondsAgo);
        (int56[] memory tickCumulativesEthOsqth, ) = IUniswapV3Pool(Constants.poolEthOsqth).observe(secondsAgo);
        return (
            int24((tickCumulativesEthUsdc[1] - tickCumulativesEthUsdc[0]) / _twapPeriod),
            int24((tickCumulativesEthOsqth[1] - tickCumulativesEthOsqth[0]) / _twapPeriod)
        );
    }

    function getLiquidityForValue(
        uint256 v,
        uint256 p,
        uint256 pL,
        uint256 pH,
        uint256 digits
    ) public view returns (uint128) {
        console.log("getLiquidityForValue");
        console.log(v);
        console.log(p);
        console.log(pL);
        console.log(pH);

        return _toUint128(v.div((p.sqrt()).mul(2e18) - pL.sqrt() - p.div(pH.sqrt())).mul(digits));
    }

    function getValue(
        uint256 amountEth,
        uint256 amountUsdc,
        uint256 amountOsqth,
        uint256 ethUsdcPrice,
        uint256 osqthEthPrice
    ) public pure returns (uint256) {
        // console.log("_getValue");
        // console.log("amountEth %s", amountEth);
        // console.log("amountUsdc %s", amountUsdc);
        // console.log("amountOsqth %s", amountOsqth);
        // console.log("ethUsdcPrice %s", ethUsdcPrice);
        // console.log("osqthEthPrice %s", osqthEthPrice);

        return (amountOsqth.mul(osqthEthPrice) + amountEth).mul(ethUsdcPrice) + amountUsdc.mul(1e30);
    }

    //@dev <tested>
    /// @dev Rounds tick down towards negative infinity so that it's a multiple
    /// of `tickSpacing`.
    function _floor(int24 tick, int24 tickSpacing) internal pure returns (int24) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        return compressed * tickSpacing;
    }

    /// @dev Casts uint256 to uint128 with overflow check.
    function _toUint128(uint256 x) internal pure returns (uint128) {
        assert(x <= type(uint128).max);
        return uint128(x);
    }

    /// @dev Casts uint256 to uint160 with overflow check.
    function _toUint160(uint256 x) internal pure returns (uint160) {
        assert(x <= type(uint160).max);
        return uint160(x);
    }
}
