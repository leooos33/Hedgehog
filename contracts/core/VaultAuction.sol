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
        Constants.AuctionParams memory params = IVaultMath(vaultMath)._getAuctionParams(_auctionTriggerTime);

        _executeAuction(keeper, params);

        emit SharedEvents.Rebalance(keeper, params.deltaEth, params.deltaUsdc, params.deltaOsqth);
    }

    /**
     * @notice execute auction based on the parameters calculated
     * @dev withdraw all liquidity from the positions
     * @dev pull in tokens from keeper
     * @dev sell excess tokens to sender
     * @dev place new positions in eth:usdc and osqth:eth pool
     */
    function _executeAuction(address _keeper, Constants.AuctionParams memory params) internal {
        //Get current liquidity in positions
        uint128 liquidityEthUsdc = IVaultTreasury(vaultTreasury).positionLiquidityEthUsdc();
        uint128 liquidityOsqthEth = IVaultTreasury(vaultTreasury).positionLiquidityEthOsqth();

        IVaultMath(vaultMath)._burnAndCollect(
            Constants.poolEthUsdc,
            params.boundaries.ethUsdcLower,
            params.boundaries.ethUsdcUpper,
            liquidityEthUsdc
        );

        IVaultMath(vaultMath)._burnAndCollect(
            Constants.poolEthOsqth,
            params.boundaries.osqthEthLower,
            params.boundaries.osqthEthUpper,
            liquidityOsqthEth
        );

        //Exchange tokens with keeper
        if (params.priceMultiplier < 1e18) {
            Constants.weth.transferFrom(_keeper, address(this), params.deltaEth.add(10));
            Constants.usdc.transferFrom(_keeper, address(this), params.deltaUsdc.add(10));
            IVaultTreasury(vaultTreasury).transfer(Constants.osqth, _keeper, params.deltaOsqth.sub(10));
        } else {
            IVaultTreasury(vaultTreasury).transfer(Constants.weth, _keeper, params.deltaEth.sub(10));
            IVaultTreasury(vaultTreasury).transfer(Constants.usdc, _keeper, params.deltaUsdc.sub(10));
            Constants.osqth.transferFrom(_keeper, address(this), params.deltaOsqth.add(10));
        }

        IVaultTreasury(vaultTreasury).mintLiquidity(
            Constants.poolEthUsdc,
            params.boundaries.ethUsdcLower,
            params.boundaries.ethUsdcUpper,
            params.liquidityEthUsdc
        );

        IVaultTreasury(vaultTreasury).mintLiquidity(
            Constants.poolEthOsqth,
            params.boundaries.osqthEthLower,
            params.boundaries.osqthEthUpper,
            params.liquidityOsqthEth
        );

        IVaultStorage(vaultStotage).setTotalAmountsBoundaries(
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
        (uint256 ethUsdcPrice, uint256 osqthEthPrice) = IVaultMath(vaultMath).getPrices();

        uint256 priceMultiplier = IVaultMath(vaultMath).getPriceMultiplier(_auctionTriggerTime);

        //boundaries for auction prices (current price * multiplier)
        Constants.Boundaries memory boundaries = _getBoundaries(
            ethUsdcPrice.mul(priceMultiplier),
            osqthEthPrice.mul(priceMultiplier)
        );
        //Current strategy holdings
        (uint256 ethBalance, uint256 usdcBalance, uint256 osqthBalance) = IVaultMath(vaultMath).getTotalAmounts();

        //Value for LPing
        uint256 totalValue = IVaultMath(vaultMath)
            .getValue(ethBalance, usdcBalance, osqthBalance, ethUsdcPrice, osqthEthPrice)
            .mul(uint256(2e18) - priceMultiplier);

        //Value multiplier
        uint256 vm = priceMultiplier.mul(uint256(1e18)).div(priceMultiplier.add(uint256(1e18)));

        //Calculate liquidities
        uint128 liquidityEthUsdc = IVaultMath(vaultMath).getLiquidityForValue(
            totalValue.mul(vm),
            ethUsdcPrice,
            uint256(1e30).div(IVaultMath(vaultMath).getPriceFromTick(boundaries.ethUsdcUpper)),
            uint256(1e30).div(IVaultMath(vaultMath).getPriceFromTick(boundaries.ethUsdcLower)),
            1e12
        );

        uint128 liquidityOsqthEth = IVaultMath(vaultMath).getLiquidityForValue(
            totalValue.mul(uint256(1e18) - vm).div(ethUsdcPrice),
            osqthEthPrice,
            uint256(1e18).div(IVaultMath(vaultMath).getPriceFromTick(boundaries.osqthEthUpper)),
            uint256(1e18).div(IVaultMath(vaultMath).getPriceFromTick(boundaries.osqthEthLower)),
            1e18
        );

        //Calculate deltas that need to be exchanged with keeper
        (uint256 deltaEth, uint256 deltaUsdc, uint256 deltaOsqth) = _getDeltas(
            boundaries,
            liquidityEthUsdc,
            liquidityOsqthEth,
            ethBalance,
            usdcBalance,
            osqthBalance
        );

        return
            Constants.AuctionParams(
                priceMultiplier,
                deltaEth,
                deltaUsdc,
                deltaOsqth,
                boundaries,
                liquidityEthUsdc,
                liquidityOsqthEth
            );
    }

    /**
     * @notice calculate deltas that will be exchanged during auction
     * @param boundaries positions boundaries
     * @param liquidityEthUsdc target liquidity for ETH:USDC pool
     * @param liquidityOsqthEth target liquidity for oSQTH:ETH pool
     * @param ethBalance current wETH balance
     * @param usdcBalance current USDC balance
     * @param osqthBalance current oSQTH balance
     * @return deltaEth target wETH amount minus current wETH balance
     * @return deltaUsdc target USDC amount minus current USDC balance
     * @return deltaOsqth target oSQTH amount minus current oSQTH balance
     */
    function _getDeltas(
        Constants.Boundaries memory boundaries,
        uint128 liquidityEthUsdc,
        uint128 liquidityOsqthEth,
        uint256 ethBalance,
        uint256 usdcBalance,
        uint256 osqthBalance
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

        return (ethBalance.suba(ethAmount), usdcBalance.suba(usdcAmount), osqthBalance.suba(osqthAmount));
    }

    /**
     * @notice calculate deltas that will be exchanged during auction
     * @param aEthUsdcPrice auction EthUsdc price
     * @param aOsqthEthPrice auction OsqthEth price
     */
    function _getBoundaries(uint256 aEthUsdcPrice, uint256 aOsqthEthPrice)
        internal
        returns (Constants.Boundaries memory)
    {
        (uint160 _aEthUsdcTick, uint160 _aOsqthEthTick) = _getTicks(aEthUsdcPrice, aOsqthEthPrice);

        int24 aEthUsdcTick = Constants.uniswapMath.getTickAtSqrtRatio(_aEthUsdcTick);
        int24 aOsqthEthTick = Constants.uniswapMath.getTickAtSqrtRatio(_aOsqthEthTick);

        int24 tickSpacingEthUsdc = IVaultStorage(vaultStotage).tickSpacingEthUsdc();
        int24 tickSpacingOsqthEth = IVaultStorage(vaultStotage).tickSpacingOsqthEth();

        int24 tickFloorEthUsdc = _floor(aEthUsdcTick, tickSpacingEthUsdc);
        int24 tickFloorOsqthEth = _floor(aOsqthEthTick, tickSpacingOsqthEth);

        int24 tickCeilEthUsdc = tickFloorEthUsdc + tickSpacingEthUsdc;
        int24 tickCeilOsqthEth = tickFloorOsqthEth + tickSpacingOsqthEth;

        int24 ethUsdcThreshold = IVaultStorage(vaultStotage).ethUsdcThreshold();
        int24 osqthEthThreshold = IVaultStorage(vaultStotage).osqthEthThreshold();
        return
            Constants.Boundaries(
                tickFloorEthUsdc - ethUsdcThreshold,
                tickCeilEthUsdc + ethUsdcThreshold,
                tickFloorOsqthEth - osqthEthThreshold,
                tickCeilOsqthEth + osqthEthThreshold
            );
    }

    /// @dev Rounds tick down towards negative infinity so that it's a multiple
    /// of `tickSpacing`.
    function _floor(int24 tick, int24 tickSpacing) internal pure returns (int24) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        return compressed * tickSpacing;
    }

    /**
     * @notice calculate deltas that will be exchanged during auction
     * @param aEthUsdcPrice auction EthUsdc price
     * @param aOsqthEthPrice auction oSqthEth price
     * @return tick for aEthUsdcPrice
     * @return tick for aOsqthEthPrice
     */
    function _getTicks(uint256 aEthUsdcPrice, uint256 aOsqthEthPrice) internal pure returns (uint160, uint160) {
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
}
