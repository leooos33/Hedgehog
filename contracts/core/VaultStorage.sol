// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {Constants} from "../libraries/Constants.sol";
import {Faucet} from "../libraries/Faucet.sol";

import "hardhat/console.sol";

contract VaultStorage is Faucet {
    //@dev Uniswap pools tick spacing
    int24 public immutable tickSpacingEthUsdc;
    int24 public immutable tickSpacingOsqthEth;

    //@dev twap period to use for rebalance calculations
    uint32 public twapPeriod = 420 seconds;

    //@dev max amount of wETH that strategy accept for deposit
    uint256 public cap;

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

    //@dev ticks thresholds for boundaries calculation
    //values for tests
    int24 public ethUsdcThreshold = 960;
    int24 public osqthEthThreshold = 960;

    //@dev protocol fee expressed as multiple of 1e-6
    uint256 public protocolFee = 0;

    //@dev accrued fees
    uint256 public accruedFeesEth = 0;
    uint256 public accruedFeesUsdc = 0;
    uint256 public accruedFeesOsqth = 0;

    //@dev rebalance auction duration (seconds)
    uint256 public auctionTime;

    //@dev start auction price multiplier for rebalance buy auction and reserve price for rebalance sell auction (scaled 1e18)
    uint256 public minPriceMultiplier;
    uint256 public maxPriceMultiplier;
    //@dev max TWAP deviation for EthUsdc price in ticks
    int24 public maxTDEthUsdc;
    //@dev max TWAP deviation for oSqthEth price in ticks
    int24 public maxTDOsqthEth;

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
        uint256 _protocolFee,
        int24 _maxTDEthUsdc,
        int24 _maxTDOsqthEth
    ) Faucet() {
        cap = _cap;

        protocolFee = _protocolFee;

        tickSpacingEthUsdc = IUniswapV3Pool(Constants.poolEthUsdc).tickSpacing();
        tickSpacingOsqthEth = IUniswapV3Pool(Constants.poolEthOsqth).tickSpacing();
        rebalanceTimeThreshold = _rebalanceTimeThreshold;
        rebalancePriceThreshold = _rebalancePriceThreshold;

        auctionTime = _auctionTime;
        minPriceMultiplier = _minPriceMultiplier;
        maxPriceMultiplier = _maxPriceMultiplier;

        timeAtLastRebalance = 0;
        maxTDEthUsdc = _maxTDEthUsdc;
        maxTDOsqthEth = _maxTDOsqthEth;
    }

    function setTwapPeriod(uint32 _twapPeriod) external onlyGovernance {
        twapPeriod = _twapPeriod;
    }

    /**
     * @notice owner can set the strategy cap in USD terms
     * @dev deposits are rejected if it would put the strategy above the cap amount
     * @param _cap the maximum strategy collateral in USD, checked on deposits
     */
    function setCap(uint256 _cap) external onlyGovernance {
        cap = _cap;
    }

    /**
     * @notice owner can set the hedge time threshold in seconds that determines how often the strategy can be hedged
     * @param _rebalanceTimeThreshold the rebalance time threshold, in seconds
     */
    function setRebalanceTimeThreshold(uint256 _rebalanceTimeThreshold) external onlyGovernance {
        rebalanceTimeThreshold = _rebalanceTimeThreshold;
    }

    /**
     * @notice owner can set the hedge time threshold in percent, scaled by 1e18 that determines the deviation in EthUsdc price that can trigger a rebalance
     * @param _rebalancePriceThreshold the hedge price threshold, in percent, scaled by 1e18
     */
    function setRebalancePriceThreshold(uint256 _rebalancePriceThreshold) external onlyGovernance {
        rebalancePriceThreshold = _rebalancePriceThreshold;
    }

    /**
     * @notice owner can set the threshold for ETH:USDC liquidity positions
     * @param _ethUsdcThreshold the rebalance time threshold, in ticks
     */
    function setEthUsdcThreshold(int24 _ethUsdcThreshold) external onlyGovernance {
        ethUsdcThreshold = _ethUsdcThreshold;
    }

    /**
     * @notice owner can set the threshold for oSQTH:ETH liquidity positions
     * @param _osqthEthThreshold the rebalance time threshold, in ticks
     */
    function setOsqthEthThreshold(int24 _osqthEthThreshold) external onlyGovernance {
        osqthEthThreshold = _osqthEthThreshold;
    }

    /**
     * @notice owner can set the auction time, in seconds, that a hedge auction runs for
     * @param _auctionTime the length of the hedge auction in seconds
     */
    function setAuctionTime(uint256 _auctionTime) external onlyGovernance {
        auctionTime = _auctionTime;
    }

    /**
     * @notice owner can set the min price multiplier in a percentage scaled by 1e18 (95e16 is 95%)
     * @param _minPriceMultiplier the min price multiplier, a percentage, scaled by 1e18
     */
    function setMinPriceMultiplier(uint256 _minPriceMultiplier) external onlyGovernance {
        minPriceMultiplier = _minPriceMultiplier;
    }

    /**
     * @notice owner can set the max price multiplier in a percentage scaled by 1e18 (105e15 is 105%)
     * @param _maxPriceMultiplier the max price multiplier, a percentage, scaled by 1e18
     */
    function setMaxPriceMultiplier(uint256 _maxPriceMultiplier) external onlyGovernance {
        maxPriceMultiplier = _maxPriceMultiplier;
    }

    /**
     * @notice owner can set the protocol fee expressed as multiple of 1e-6
     * @param _protocolFee the protocol fee, scaled by 1e18
     */
    function setProtocolFee(uint256 _protocolFee) external onlyGovernance {
        protocolFee = _protocolFee;
    }

    function setTotalAmountsBoundaries(
        int24 _orderEthUsdcLower,
        int24 _orderEthUsdcUpper,
        int24 _orderOsqthEthLower,
        int24 _orderOsqthEthUpper
    ) public onlyVault {
        orderEthUsdcLower = _orderEthUsdcLower;
        orderEthUsdcUpper = _orderEthUsdcUpper;
        orderOsqthEthLower = _orderOsqthEthLower;
        orderOsqthEthUpper = _orderOsqthEthUpper;
    }

    function setAccruedFeesEth(uint256 _accruedFeesEth) external onlyMath {
        accruedFeesEth = _accruedFeesEth;
    }

    function setAccruedFeesUsdc(uint256 _accruedFeesUsdc) external onlyMath {
        accruedFeesUsdc = _accruedFeesUsdc;
    }

    function setAccruedFeesOsqth(uint256 _accruedFeesOsqth) external onlyMath {
        accruedFeesOsqth = _accruedFeesOsqth;
    }

    function updateAccruedFees(
        uint256 amountEth,
        uint256 amountUsdc,
        uint256 amountOsqth
    ) external onlyVault {
        accruedFeesUsdc = accruedFeesUsdc - amountUsdc;
        accruedFeesEth = accruedFeesEth - amountEth;
        accruedFeesOsqth = accruedFeesOsqth - amountOsqth;
    }

    /**
     * Used to for unit testing
     */
    // TODO: remove on main
    function setTimeAtLastRebalance(uint256 _timeAtLastRebalance) public {
        timeAtLastRebalance = _timeAtLastRebalance;
    }

    /**
     * Used to for unit testing
     */
    function setEthPriceAtLastRebalance(uint256 _ethPriceAtLastRebalance) public {
        ethPriceAtLastRebalance = _ethPriceAtLastRebalance;
    }
}
