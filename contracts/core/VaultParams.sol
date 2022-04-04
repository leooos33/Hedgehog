// SPDX-License-Identifier: Unlicense

pragma solidity ^0.6.6;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import "../libraries/Constants.sol";

import "hardhat/console.sol";

abstract contract VaultParams {
    // using SafeMath for uint256;

    //@dev Uniswap pools tick spacing
    int24 public immutable tickSpacingEthUsdc;
    int24 public immutable tickSpacingOsqthEth;

    //@dev twap period to use for rebalance calculations
    uint32 public twapPeriod = 420;

    //@dev total amount of deposited wETH
    uint256 public totalEthDeposited;

    //@dev max amount of wETH that strategy accept for deposit
    uint256 public cap;

    //@dev governance
    address public governance;

    //@dev lower and upper ticks in Uniswap pools
    // Removed
    int24 public orderEthUsdcLower;
    int24 public orderEthUsdcUpper;
    int24 public orderOsqthEthLower;
    int24 public orderOsqthEthUpper;

    //@dev timestamp when last rebalance executed
    uint256 public timeAtLastRebalance;

    //@dev ETH/USDC price when last rebalance executed
    uint256 public ethPriceAtLastRebalance;

    //@dev time difference to trigger a hedge (seconds)
    uint256 public rebalanceTimeThreshold;
    uint256 public rebalancePriceThreshold;

    //@dev rebalance auction duration (seconds)
    uint256 public auctionTime;

    //@dev start auction price multiplier for rebalance buy auction and reserve price for rebalance sell auction (scaled 1e18)
    uint256 public minPriceMultiplier;
    uint256 public maxPriceMultiplier;

    //@dev targeted share of value in a certain token (0.5*100 = 50%)
    uint256 public targetEthShare;
    uint256 public targetUsdcShare;
    uint256 public targetOsqthShare;

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
    ) public {
        cap = _cap;

        tickSpacingEthUsdc = IUniswapV3Pool(Constants.poolEthUsdc).tickSpacing();
        tickSpacingOsqthEth = IUniswapV3Pool(Constants.poolEthOsqth).tickSpacing();
        rebalanceTimeThreshold = _rebalanceTimeThreshold;
        rebalancePriceThreshold = _rebalancePriceThreshold;

        auctionTime = _auctionTime;
        minPriceMultiplier = _minPriceMultiplier;
        maxPriceMultiplier = _maxPriceMultiplier;
        targetEthShare = _targetEthShare;
        targetUsdcShare = _targetUsdcShare;
        targetOsqthShare = _targetOsqthShare;

        governance = msg.sender;
    }

    /**
        All strategy getters and setters will be here
     */

    // TODO: remove on main
    /**
     * Used to for _getTotalAmounts unit testing
     */
    function setTotalAmountsBoundaries(
        int24 _orderEthUsdcLower,
        int24 _orderEthUsdcUpper,
        int24 _orderOsqthEthLower,
        int24 _orderOsqthEthUpper
    ) public {
        orderEthUsdcLower = _orderEthUsdcLower;
        orderEthUsdcUpper = _orderEthUsdcUpper;
        orderOsqthEthLower = _orderOsqthEthLower;
        orderOsqthEthUpper = _orderOsqthEthUpper;
    }

    /// @dev Casts uint256 to uint128 with overflow check.
    function _toUint128(uint256 x) internal pure returns (uint128) {
        assert(x <= type(uint128).max);
        return uint128(x);
    }
}
