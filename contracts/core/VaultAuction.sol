// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;
pragma abicoder v2;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {IVaultTreasury} from "../interfaces/IVaultTreasury.sol";
import {IVaultMath} from "../interfaces/IVaultMath.sol";
import {IAuction} from "../interfaces/IAuction.sol";
import {IVaultStorage} from "../interfaces/IVaultStorage.sol";

import {SharedEvents} from "../libraries/SharedEvents.sol";
import {PRBMathUD60x18} from "../libraries/math/PRBMathUD60x18.sol";
import {Constants} from "../libraries/Constants.sol";
import {Faucet} from "../libraries/Faucet.sol";
import {IUniswapMath} from "../libraries/uniswap/IUniswapMath.sol";

import "hardhat/console.sol";

contract VaultAuction is IAuction, Faucet, ReentrancyGuard {
    using PRBMathUD60x18 for uint256;

    /**
     * @notice strategy constructor
     */
    constructor() Faucet() {}

    /**
     * @notice strategy rebalancing based on time threshold
     * @param keeper keeper address
     * @param amountEth amount of wETH to buy (strategy sell wETH both in sell and buy auction)
     * @param amountUsdc amount of USDC to buy or sell (depending if price increased or decreased)
     * @param amountOsqth amount of oSQTH to buy or sell (depending if price increased or decreased)
     */
    function timeRebalance(
        address keeper,
        uint256 amountEth,
        uint256 amountUsdc,
        uint256 amountOsqth
    ) external override nonReentrant {
        //check if rebalancing based on time threshold is allowed
        (bool isTimeRebalanceAllowed, uint256 auctionTriggerTime) = IVaultMath(vaultMath).isTimeRebalance();

        require(isTimeRebalanceAllowed, "Time rebalance not allowed");

        _rebalance(keeper, auctionTriggerTime);

        emit SharedEvents.TimeRebalance(keeper, auctionTriggerTime, amountEth, amountUsdc, amountOsqth);
    }

    /**
     * @notice strategy rebalancing based on price threshold
     * @param keeper keeper address
     * @param auctionTriggerTime the time when the price deviation threshold was exceeded and when the auction started
     * @param amountEth amount of wETH to buy (strategy sell wETH both in sell and buy auction)
     * @param amountUsdc amount of USDC to buy or sell (depending if price increased or decreased)
     * @param amountOsqth amount of oSQTH to buy or sell (depending if price increased or decreased)
     */
    function priceRebalance(
        address keeper,
        uint256 auctionTriggerTime,
        uint256 amountEth,
        uint256 amountUsdc,
        uint256 amountOsqth
    ) external override nonReentrant {
        //check if rebalancing based on price threshold is allowed
        require(IVaultMath(vaultMath)._isPriceRebalance(auctionTriggerTime), "Price rebalance not allowed");

        _rebalance(keeper, auctionTriggerTime);

        emit SharedEvents.PriceRebalance(keeper, amountEth, amountUsdc, amountOsqth);
    }

    /**
     * @notice rebalancing function to adjust proportion of tokens
     * @param keeper keeper address
     * @param _auctionTriggerTime timestamp when auction started
     */
    function _rebalance(address keeper, uint256 _auctionTriggerTime) internal {
        Constants.AuctionParams memory params = _getAuctionParams(_auctionTriggerTime);

        //Calculate amounts that need to be exchanged with keeper
        (uint256 targetEth, uint256 targetUsdc, uint256 targetOsqth) = _getTargets(
            params.boundaries,
            params.liquidityEthUsdc,
            params.liquidityOsqthEth
        );

        console.log("Targets - %s ETH, %s USDC, %s oSQTH", targetEth, targetUsdc, targetOsqth);

        _executeAuction(keeper, params, targetEth, targetUsdc, targetOsqth);

        emit SharedEvents.Rebalance(keeper, targetEth, targetUsdc, targetOsqth);
    }

    /**
     * @notice execute auction based on the parameters calculated
     * @dev withdraw all liquidity from the positions
     * @dev pull in tokens from keeper
     * @dev sell excess tokens to sender
     * @dev place new positions in eth:usdc and osqth:eth pool
     */
    function _executeAuction(
        address _keeper,
        Constants.AuctionParams memory params,
        uint256 targetEth,
        uint256 targetUsdc,
        uint256 targetOsqth
    ) internal {
        //Get current liquidity in positions
        uint128 liquidityEthUsdc = IVaultTreasury(vaultTreasury).positionLiquidityEthUsdc();
        uint128 liquidityOsqthEth = IVaultTreasury(vaultTreasury).positionLiquidityEthOsqth();

        IVaultMath(vaultMath).burnAndCollect(
            Constants.poolEthUsdc,
            params.boundaries.ethUsdcLower,
            params.boundaries.ethUsdcUpper,
            liquidityEthUsdc
        );

        IVaultMath(vaultMath).burnAndCollect(
            Constants.poolEthOsqth,
            params.boundaries.osqthEthLower,
            params.boundaries.osqthEthUpper,
            liquidityOsqthEth
        );

        //Exchange tokens with keeper
        (uint256 ethBalance, uint256 usdcBalance, uint256 osqthBalance) = IVaultMath(vaultMath).getTotalAmounts();

        console.log("Balances - %s ETH,  %s USDC, %s oSQTH", ethBalance, usdcBalance, osqthBalance);

        console.log("!");
        if (targetEth > ethBalance) {
            console.log("Eth to exchange %s", targetEth.sub(ethBalance).add(10));
            Constants.weth.transferFrom(_keeper, vaultTreasury, targetEth.sub(ethBalance).add(10));
        } else {
            console.log("Eth to exchange %s", ethBalance.sub(targetEth).sub(10));
            IVaultTreasury(vaultTreasury).transfer(Constants.weth, _keeper, ethBalance.sub(targetEth).sub(10));
        }

        if (targetUsdc > usdcBalance) {
            console.log("USDC to exchange %s", targetUsdc.sub(usdcBalance).add(10));
            Constants.usdc.transferFrom(_keeper, vaultTreasury, targetUsdc.sub(usdcBalance).add(10));
        } else {
            console.log("USDC to exchange %s", usdcBalance.sub(targetUsdc).sub(10));
            IVaultTreasury(vaultTreasury).transfer(Constants.usdc, _keeper, usdcBalance.sub(targetUsdc).sub(10));
        }

        if (targetOsqth > osqthBalance) {
            console.log("oSQTH to exchange %s", targetOsqth.sub(osqthBalance).add(10));
            Constants.osqth.transferFrom(_keeper, vaultTreasury, targetOsqth.sub(osqthBalance).add(10));
        } else {
            console.log("oSQTH to exchange %s", targetOsqth.sub(osqthBalance).sub(10));
            IVaultTreasury(vaultTreasury).transfer(Constants.osqth, _keeper, osqthBalance.sub(targetOsqth).sub(10));
        }
        console.log("!");

        IVaultTreasury(vaultTreasury).mintLiquidity(
            Constants.poolEthUsdc,
            params.boundaries.ethUsdcUpper,
            params.boundaries.ethUsdcLower,
            params.liquidityEthUsdc
        );

        IVaultTreasury(vaultTreasury).mintLiquidity(
            Constants.poolEthOsqth,
            params.boundaries.osqthEthUpper,
            params.boundaries.osqthEthLower,
            params.liquidityOsqthEth
        );

         IVaultStorage(vaultStorage).setTotalAmountsBoundaries(
             params.boundaries.ethUsdcLower,
             params.boundaries.ethUsdcUpper,
             params.boundaries.osqthEthLower,
             params.boundaries.osqthEthUpper
         );
    }

    /**
     * @notice calculate all auction parameters
     * @param _auctionTriggerTime timestamp when auction started
     */
    function _getAuctionParams(uint256 _auctionTriggerTime) internal returns (Constants.AuctionParams memory) {
        //current ETH/USDC and oSQTH/ETH price
        (uint256 ethUsdcPrice, uint256 osqthEthPrice) = IVaultMath(vaultMath).getPrices();

        console.log("Current EthUsdcPrice %s, Current OsqthEthPrice %s", ethUsdcPrice, osqthEthPrice);

        //current implied volatility
        uint256 cIV = IVaultMath(vaultMath).getIV();
        console.log("current IV %s", cIV);
        //previous implied volatility
        uint256 pIV = IVaultStorage(vaultStorage).ivAtLastRebalance();
        console.log("previous IV %s", pIV);

        uint256 expIVbump;
        if (cIV < pIV) {
            expIVbump = pIV.div(cIV);
        } else {
            expIVbump = cIV.div(pIV);
        }

        //IV bump > 3 leads to a negative values of one of the lower or upper boundary
        expIVbump = expIVbump > uint256(3e18) ? uint256(3e18) : expIVbump;
        console.log("Expected IV bump %s", expIVbump);

        uint256 priceMultiplier = IVaultMath(vaultMath).getPriceMultiplier(_auctionTriggerTime);
        console.log("Price Multiplier %s", priceMultiplier);

        console.log("Auction EthUsdc Price %s", ethUsdcPrice.mul(priceMultiplier));
        console.log("Auction OsqthEth Price %s", osqthEthPrice.mul(priceMultiplier));
        console.log("isPosIVbump", cIV < pIV);

        //boundaries for auction prices (current price * multiplier)
        Constants.Boundaries memory boundaries = _getBoundaries(
            ethUsdcPrice.mul(priceMultiplier),
            osqthEthPrice.mul(priceMultiplier),
            cIV < pIV,
            expIVbump
        );

        console.log("ethUsdcLower %s", uint256(int256(boundaries.ethUsdcLower)));
        console.log("ethUsdcUpper %s", uint256(int256(boundaries.ethUsdcUpper)));
        
        console.log("osqthEthLower %s", uint256(int256(boundaries.osqthEthLower)));
        console.log("osqthEthUpper %s", uint256(int256(boundaries.osqthEthUpper)));


        //Value for LPing
        uint256 totalValue = _getTotalValue(ethUsdcPrice, osqthEthPrice);

        console.log("Total Value to Rebalance %s", totalValue);

        //Value multiplier
        uint256 vm;
        if (cIV < pIV) {
            vm = priceMultiplier.div(priceMultiplier + uint256(1e18)) + uint256(1e16).div(cIV);
        } else {
            vm = priceMultiplier.div(priceMultiplier + uint256(1e18)) - uint256(1e16).div(cIV);
        }

        console.log("Value Multiplier %s", vm);

        //Calculate liquidities
        uint128 liquidityEthUsdc = IVaultMath(vaultMath).getLiquidityForValue(
            totalValue.mul(ethUsdcPrice).mul(vm),
            ethUsdcPrice,
            uint256(1e30).div(IVaultMath(vaultMath).getPriceFromTick(boundaries.ethUsdcLower)),
            uint256(1e30).div(IVaultMath(vaultMath).getPriceFromTick(boundaries.ethUsdcUpper)),
            1e12
        );

        console.log("liquidityEthUsdc %s", liquidityEthUsdc);

        uint128 liquidityOsqthEth = IVaultMath(vaultMath).getLiquidityForValue(
            totalValue.mul(uint256(1e18) - vm),
            osqthEthPrice,
            uint256(1e18).div(IVaultMath(vaultMath).getPriceFromTick(boundaries.osqthEthLower)),
            uint256(1e18).div(IVaultMath(vaultMath).getPriceFromTick(boundaries.osqthEthUpper)),
            1e18
        );

        console.log("liquidityOsqthEth %s", liquidityOsqthEth);

        return Constants.AuctionParams(priceMultiplier, boundaries, liquidityEthUsdc, liquidityOsqthEth);
    }

    function _getTotalValue(uint256 ethUsdcPrice, uint256 osqthEthPrice) internal view returns (uint256 totalValue) {
        //Current strategy holdings
        (uint256 ethBalance, uint256 usdcBalance, uint256 osqthBalance) = IVaultMath(vaultMath).getTotalAmounts();

        //Value for LPing
        totalValue = IVaultMath(vaultMath).getValue(ethBalance, usdcBalance, osqthBalance, ethUsdcPrice, osqthEthPrice);
    }

    /**
     * @notice calculate amounts that will be exchanged during auction
     * @param boundaries positions boundaries
     * @param liquidityEthUsdc target liquidity for ETH:USDC pool
     * @param liquidityOsqthEth target liquidity for oSQTH:ETH pool
     */
    function _getTargets(
        Constants.Boundaries memory boundaries,
        uint128 liquidityEthUsdc,
        uint128 liquidityOsqthEth
    )
        internal
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        (uint256 ethAmount, uint256 usdcAmount, uint256 osqthAmount) = IVaultTreasury(vaultTreasury)
            .allAmountsForLiquidity(boundaries, liquidityEthUsdc, liquidityOsqthEth);

        return (ethAmount, usdcAmount, osqthAmount);
    }

    function _getTickFloors(
        uint256 aEthUsdcPrice,
        uint256 aOsqthEthPrice,
        int24 tickSpacing
    ) internal view returns (int24, int24) {
        (uint160 _aEthUsdcSqrtX96, uint160 _aOsqthEthSqrtX96) = _getSqrtX96(aEthUsdcPrice, aOsqthEthPrice);

        return (
            _floor(IUniswapMath(uniswapMath).getTickAtSqrtRatio(_aEthUsdcSqrtX96), tickSpacing),
            _floor(IUniswapMath(uniswapMath).getTickAtSqrtRatio(_aOsqthEthSqrtX96), tickSpacing)
        );
    }

    /**
     * @notice calculate lp-positions boundaries
     * @param aEthUsdcPrice auction EthUsdc price
     * @param aOsqthEthPrice auction OsqthEth price
     */
    function _getBoundaries(
        uint256 aEthUsdcPrice,
        uint256 aOsqthEthPrice,
        bool isPosIVbump,
        uint256 expIVbump
    ) internal view returns (Constants.Boundaries memory) {
        int24 tickSpacing = IVaultStorage(vaultStorage).tickSpacing();

        (int24 tickFloorEthUsdc, int24 tickFloorOsqthEth) = _getTickFloors(
            aEthUsdcPrice,
            aOsqthEthPrice,
            tickSpacing
        );

        console.log("tickFloorEthUsdc %s", uint256(int256(tickFloorEthUsdc)));
        console.log("tickFloorOsqthEth %s", uint256(int256(tickFloorOsqthEth)));

        //base thresholds
        int24 baseThreshold = IVaultStorage(vaultStorage).baseThreshold();
        
        console.log("baseThreshold %s", uint256(int256(baseThreshold)));

        //iv adj parameter

        //60 - tickSpacing
        int24 baseAdj = toInt24(
            int256(
                (((expIVbump - uint256(1e18)).div(IVaultStorage(vaultStorage).adjParam())).floor() *
                    uint256(60)).div(1e36)
            )
        );

        console.log("Base adj %s", uint256(int256(baseAdj)));

        int24 tickAdj;
        if (isPosIVbump) {
            tickAdj = baseAdj < int24(120) ? int24(60) : baseAdj;
                    console.log("Tick adj %s", uint256(int256(tickAdj)));

            return
                Constants.Boundaries(
                    tickFloorEthUsdc + tickSpacing + baseThreshold - tickAdj,
                    tickFloorEthUsdc - baseThreshold  - tickAdj,
                    tickFloorOsqthEth + tickSpacing + baseThreshold - tickAdj,
                    tickFloorOsqthEth - baseThreshold - tickAdj
                );
                
        } else {
            tickAdj = baseAdj > tickSpacing ? int24(120) : baseAdj;
                    console.log("Tick adj %s", uint256(int256(tickAdj)));

            return
                Constants.Boundaries(
                    tickFloorEthUsdc + tickSpacing + baseThreshold + tickAdj,
                    tickFloorEthUsdc  - baseThreshold + tickAdj,
                    tickFloorOsqthEth + tickSpacing + baseThreshold + tickAdj,
                    tickFloorOsqthEth - baseThreshold + tickAdj
                );
        }
    }

    /// @dev Rounds tick down towards negative infinity so that it's a multiple
    /// of `tickSpacing`.
    function _floor(int24 tick, int24 tickSpacing) internal pure returns (int24) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        return compressed * tickSpacing;
    }

    /**
     * @notice get current prices in sqrtPriceX96
     * @param aEthUsdcPrice auction EthUsdc price
     * @param aOsqthEthPrice auction oSqthEth price
     * @return ratio for aEthUsdcPrice
     * @return ratio for aOsqthEthPrice
     */
    function _getSqrtX96(uint256 aEthUsdcPrice, uint256 aOsqthEthPrice) internal pure returns (uint160, uint160) {
        return (
            _toUint160(
                //sqrt(price)*2**96
                ((uint256(1e30).div(aEthUsdcPrice)).sqrt()).mul(79228162514264337593543950336)
            ),
            _toUint160(((uint256(1e18).div(aOsqthEthPrice)).sqrt()).mul(79228162514264337593543950336))
        );
    }

    /// @dev Casts uint256 to uint160 with overflow check.
    function _toUint160(uint256 x) internal pure returns (uint160) {
        assert(x <= type(uint160).max);
        return uint160(x);
    }

    /// @dev Casts int256 to int24 with overflow check.
    function toInt24(int256 value) internal pure returns (int24) {
        require(value >= type(int24).min && value <= type(int24).max);
        return int24(value);
    }
}
