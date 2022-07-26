// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;
pragma abicoder v2;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
    ) external override nonReentrant notPaused {
        //check if rebalancing based on time threshold is allowed
        (bool isTimeRebalanceAllowed, uint256 auctionTriggerTime) = IVaultMath(vaultMath).isTimeRebalance();

        require(isTimeRebalanceAllowed, "C10");

        _executeAuction(keeper, auctionTriggerTime);

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
    ) external override nonReentrant notPaused {
        //check if rebalancing based on price threshold is allowed
        require(IVaultMath(vaultMath).isPriceRebalance(auctionTriggerTime), "C11");

        _executeAuction(keeper, auctionTriggerTime);

        emit SharedEvents.PriceRebalance(keeper, amountEth, amountUsdc, amountOsqth);
    }

    /**
     * @notice execute auction based on the parameters calculated
     * @dev withdraw all liquidity from the positions
     * @dev pull in tokens from keeper
     * @dev sell excess tokens to sender
     * @dev place new positions in eth:usdc and osqth:eth pool
     */
    function _executeAuction(address _keeper, uint256 _auctionTriggerTime) internal {
        Constants.AuctionParams memory params = _getAuctionParams(_auctionTriggerTime);

        //Withdraw all the liqudity from the positions
        IVaultMath(vaultMath).burnAndCollect(
            Constants.poolEthUsdc,
            IVaultStorage(vaultStorage).orderEthUsdcLower(),
            IVaultStorage(vaultStorage).orderEthUsdcUpper(),
            IVaultTreasury(vaultTreasury).positionLiquidityEthUsdc()
        );

        IVaultMath(vaultMath).burnAndCollect(
            Constants.poolEthOsqth,
            IVaultStorage(vaultStorage).orderOsqthEthLower(),
            IVaultStorage(vaultStorage).orderOsqthEthUpper(),
            IVaultTreasury(vaultTreasury).positionLiquidityEthOsqth()
        );

        //Calculate amounts that need to be exchanged with keeper
        (uint256 ethBalance, uint256 usdcBalance, uint256 osqthBalance) = IVaultMath(vaultMath).getTotalAmounts();
        console.log("ethBalance %s, usdcBalance %s, osqthBalance %s", ethBalance, usdcBalance, osqthBalance);

        (uint256 targetEth, uint256 targetUsdc, uint256 targetOsqth) = _getTargets(
            params.boundaries,
            params.liquidityEthUsdc,
            params.liquidityOsqthEth
        );
        console.log("targetEth %s, targetUsdc %s, targetOsqth %s", targetEth, targetUsdc, targetOsqth);

        //Exchange tokens with keeper
        _swapWithKeeper(ethBalance, targetEth, address(Constants.weth), _keeper);
        _swapWithKeeper(usdcBalance, targetUsdc, address(Constants.usdc), _keeper);
        _swapWithKeeper(osqthBalance, targetOsqth, address(Constants.osqth), _keeper);

        //Place new positions
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

        IVaultStorage(vaultStorage).setSnapshot(
            params.boundaries.ethUsdcLower,
            params.boundaries.ethUsdcUpper,
            params.boundaries.osqthEthLower,
            params.boundaries.osqthEthUpper,
            block.timestamp,
            IVaultMath(vaultMath).getIV(),
            params.totalValue,
            params.ethUsdcPrice
        );
        console.log(
            "orderEthUsdcLower %s, orderEthUsdcUpper %s",
            uint256(int256(IVaultStorage(vaultStorage).orderEthUsdcLower())),
            uint256(int256(IVaultStorage(vaultStorage).orderEthUsdcUpper()))
        );
        console.log(
            "orderOsqthEthLower %s, orderOsqthEthUpper %s",
            uint256(int256(IVaultStorage(vaultStorage).orderOsqthEthLower())),
            uint256(int256(IVaultStorage(vaultStorage).orderOsqthEthUpper()))
        );
    }

    /**
     * @notice calculate all auction parameters
     * @param _auctionTriggerTime timestamp when auction started
     */
    function _getAuctionParams(uint256 _auctionTriggerTime) internal view returns (Constants.AuctionParams memory) {
        //current ETH/USDC and oSQTH/ETH price
        (uint256 ethUsdcPrice, uint256 osqthEthPrice) = IVaultMath(vaultMath).getPrices();
        console.log("ethUsdcPrice %s, osqthEthPrice %s", ethUsdcPrice, osqthEthPrice);



        uint256 expIVbump;
        uint256 vm;
        bool isPosIVbump;
        uint256 priceMultiplier;
        {
            //current implied volatility
            uint256 cIV = IVaultMath(vaultMath).getIV();
            console.log("current IV %s", cIV);

            //previous implied volatility
            uint256 pIV = IVaultStorage(vaultStorage).ivAtLastRebalance();
            console.log("previous IV %s", pIV);

            isPosIVbump = cIV < pIV;
            console.log("isPosIVbump %s", isPosIVbump);

            priceMultiplier = IVaultMath(vaultMath).getPriceMultiplier(_auctionTriggerTime, isPosIVbump);
            console.log("priceMultiplier %s", priceMultiplier);

            if (isPosIVbump) {
                expIVbump = pIV.div(cIV);
                vm = priceMultiplier.div(priceMultiplier + uint256(1e18)) + uint256(1e16).div(cIV);
            } else {
                expIVbump = cIV.div(pIV);
                vm = priceMultiplier.div(priceMultiplier + uint256(1e18)) - uint256(1e16).div(cIV);
            }
            //IV bump > 3 leads to a negative values of one of the lower or upper boundary
            expIVbump = expIVbump > uint256(3e18) ? uint256(3e18) : expIVbump;
        }
        console.log("expIVbump %s", expIVbump);
        console.log("vm %s", vm);
        console.log("isPosIVbump %s", isPosIVbump);

        //boundaries for auction prices (current price * multiplier)
        Constants.Boundaries memory boundaries = _getBoundaries(
            ethUsdcPrice.mul(priceMultiplier),
            osqthEthPrice.mul(priceMultiplier),
            isPosIVbump,
            expIVbump
        );

        uint256 totalValue;
        {
            (uint256 ethBalance, uint256 usdcBalance, uint256 osqthBalance) = IVaultMath(vaultMath).getTotalAmounts();
            console.log("ethBalance %s, usdcBalance %s, osqthBalance %s", ethBalance, usdcBalance, osqthBalance);

            //Value for LPing
            totalValue = IVaultMath(vaultMath).getValue(
                ethBalance,
                usdcBalance,
                osqthBalance,
                ethUsdcPrice,
                osqthEthPrice
            );
        }

        //totalValue = totalValue.mul(992881623277851000);

        console.log("totalValue %s", totalValue);

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

        return Constants.AuctionParams(boundaries, liquidityEthUsdc, liquidityOsqthEth, totalValue, ethUsdcPrice);
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

        int24 tickFloorEthUsdc = _floor(
            IUniswapMath(uniswapMath).getTickAtSqrtRatio(
                _toUint160(((uint256(1e30).div(aEthUsdcPrice)).sqrt()).mul(79228162514264337593543950336))
            ),
            tickSpacing
        );

        int24 tickFloorOsqthEth = _floor(
            IUniswapMath(uniswapMath).getTickAtSqrtRatio(
                _toUint160(((uint256(1e18).div(aOsqthEthPrice)).sqrt()).mul(79228162514264337593543950336))
            ),
            tickSpacing
        );
        console.log("tickFloorOsqthEth %s", uint256(int256(tickFloorOsqthEth)));

        //base thresholds
        int24 baseThreshold = IVaultStorage(vaultStorage).baseThreshold();
        console.log("baseThreshold %s", uint256(int256(baseThreshold)));

        //iv adj parameter
        int24 baseAdj = toInt24(
            int256(
                (((expIVbump - uint256(1e18)).div(IVaultStorage(vaultStorage).adjParam())).floor() *
                    uint256(int256(tickSpacing))).div(1e36)
            )
        );
        console.log("baseAdj %s", uint256(int256(baseAdj)));
        int24 tickAdj;
        if (isPosIVbump) {
            tickAdj = baseAdj < int24(120) ? int24(60) : baseAdj;

            return
                Constants.Boundaries(
                    tickFloorEthUsdc - baseThreshold - tickAdj,
                    tickFloorEthUsdc + tickSpacing + baseThreshold - tickAdj,
                    tickFloorOsqthEth - baseThreshold - tickAdj,
                    tickFloorOsqthEth + tickSpacing + baseThreshold - tickAdj
                );
        } else {
            tickAdj = baseAdj > tickSpacing ? int24(120) : baseAdj;

            return
                Constants.Boundaries(
                    tickFloorEthUsdc - baseThreshold + tickAdj,
                    tickFloorEthUsdc + tickSpacing + baseThreshold + tickAdj,
                    tickFloorOsqthEth - baseThreshold + tickAdj,
                    tickFloorOsqthEth + tickSpacing + baseThreshold + tickAdj
                );
        }
    }

    function _swapWithKeeper(
        uint256 balance,
        uint256 target,
        address coin,
        address keeper
    ) internal {
        if (target >= balance) {
            IERC20(coin).transferFrom(keeper, vaultTreasury, target.sub(balance).add(10));
        } else {
            IVaultTreasury(vaultTreasury).transfer(IERC20(coin), keeper, balance.sub(target).sub(10));
        }
    }

    /// @dev Rounds tick down towards negative infinity so that it's a multiple
    /// of `tickSpacing`.
    function _floor(int24 tick, int24 tickSpacing) internal pure returns (int24) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        return compressed * tickSpacing;
    }

    /// @dev Casts uint256 to uint160 with overflow check.
    function _toUint160(uint256 x) internal pure returns (uint160) {
        assert(x <= type(uint160).max);
        return uint160(x);
    }

    /// @dev Casts int256 to int24 with overflow check.
    function toInt24(int256 value) internal pure returns (int24) {
        require(value >= type(int24).min && value <= type(int24).max, "C18");
        return int24(value);
    }

    function getAuctionParams(uint256 _auctionTriggerTime)
        external
        view
        override
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        Constants.AuctionParams memory auctionDetails = _getAuctionParams(_auctionTriggerTime);

        (uint256 targetEth, uint256 targetUsdc, uint256 targetOsqth) = _getTargets(
            auctionDetails.boundaries,
            auctionDetails.liquidityEthUsdc,
            auctionDetails.liquidityOsqthEth
        );

        (uint256 ethBalance, uint256 usdcBalance, uint256 osqthBalance) = IVaultMath(vaultMath).getTotalAmounts();

        return (targetEth, targetUsdc, targetOsqth, ethBalance, usdcBalance, osqthBalance);
    }
}
