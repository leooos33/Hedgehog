// SPDX-License-Identifier: Unlicense

pragma solidity =0.7.6;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../libraries/Constants.sol";

import "hardhat/console.sol";

abstract contract VaultParams is IERC20, ERC20 {
    //@dev Uniswap pools tick spacing
    int24 public immutable tickSpacingEthUsdc;
    int24 public immutable tickSpacingOsqthEth;

    //@dev twap period to use for rebalance calculations
    uint32 public twapPeriod = 420 seconds;

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
    ) ERC20("Hedging DL", "HDL") {
        cap = _cap;

        tickSpacingEthUsdc = IUniswapV3Pool(Constants.poolEthUsdc).tickSpacing();
        tickSpacingOsqthEth = IUniswapV3Pool(Constants.poolEthOsqth).tickSpacing();
        rebalanceTimeThreshold = _rebalanceTimeThreshold;
        rebalancePriceThreshold = _rebalancePriceThreshold;

        auctionTime = _auctionTime;
        minPriceMultiplier = _minPriceMultiplier;
        maxPriceMultiplier = _maxPriceMultiplier;

        governance = msg.sender;

        timeAtLastRebalance = 0;
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

    // TODO: remove on main
    /**
     * Used to for unit testing
     */
    function setTimeAtLastRebalance(uint256 _timeAtLastRebalance) public {
        timeAtLastRebalance = _timeAtLastRebalance;
    }

    // TODO: remove on main
    /**
     * Used to for unit testing
     */
    function setEthPriceAtLastRebalance(uint256 _ethPriceAtLastRebalance) public {
        ethPriceAtLastRebalance = _ethPriceAtLastRebalance;
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
