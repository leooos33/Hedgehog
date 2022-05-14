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
        uint128 liquidityEthUsdc = IVaultMath(vaultMath)._positionLiquidityEthUsdc();
        uint128 liquidityOsqthEth = IVaultMath(vaultMath)._positionLiquidityEthOsqth();

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
}
