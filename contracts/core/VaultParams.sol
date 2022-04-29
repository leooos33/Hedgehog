// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Constants} from "../libraries/Constants.sol";

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

    int24 public ethUsdcThreshold = 960;
    int24 public osqthEthThreshold = 960;

    uint256 public protocolFee = 0;

    uint256 public accruedFeesEth = 0;
    uint256 public accruedFeesUsdc = 0;
    uint256 public accruedFeesOsqth = 0;

    //@dev rebalance auction duration (seconds)
    uint256 public auctionTime;

    //@dev start auction price multiplier for rebalance buy auction and reserve price for rebalance sell auction (scaled 1e18)
    uint256 public minPriceMultiplier;
    uint256 public maxPriceMultiplier;

    int24 public maxTDEthUsdc;
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
    ) ERC20("Hedging DL", "HDL") {
        cap = _cap;

        protocolFee = _protocolFee;

        tickSpacingEthUsdc = IUniswapV3Pool(Constants.poolEthUsdc).tickSpacing();
        tickSpacingOsqthEth = IUniswapV3Pool(Constants.poolEthOsqth).tickSpacing();
        rebalanceTimeThreshold = _rebalanceTimeThreshold;
        rebalancePriceThreshold = _rebalancePriceThreshold;

        auctionTime = _auctionTime;
        minPriceMultiplier = _minPriceMultiplier;
        maxPriceMultiplier = _maxPriceMultiplier;

        governance = msg.sender;

        timeAtLastRebalance = 0;
        maxTDEthUsdc = _maxTDEthUsdc;
        maxTDOsqthEth = _maxTDOsqthEth;
    }

    function setTwapPeriod(uint32 _twapPeriod) external onlyGovernance {
        twapPeriod = _twapPeriod;
    }

    function setCap(uint256 _cap) external onlyGovernance {
        cap = _cap;
    }

    function setRebalanceTimeThreshold(uint256 _rebalanceTimeThreshold) external onlyGovernance {
        rebalanceTimeThreshold = _rebalanceTimeThreshold;
    }

    function setRebalancePriceThreshold(uint256 _rebalancePriceThreshold) external onlyGovernance {
        rebalancePriceThreshold = _rebalancePriceThreshold;
    }

    function setEthUsdcThreshold(int24 _ethUsdcThreshold) external onlyGovernance {
        ethUsdcThreshold = _ethUsdcThreshold;
    }

    function setOsqthEthThreshold(int24 _osqthEthThreshold) external onlyGovernance {
        osqthEthThreshold = _osqthEthThreshold;
    }

    function setAuctionTime(uint256 _auctionTime) external onlyGovernance {
        auctionTime = _auctionTime;
    }

    function setMinPriceMultiplier(uint256 _minPriceMultiplier) external onlyGovernance {
        minPriceMultiplier = _minPriceMultiplier;
    }

    function setMaxPriceMultiplier(uint256 _maxPriceMultiplier) external onlyGovernance {
        maxPriceMultiplier = _maxPriceMultiplier;
    }

    function setProtocolFee(uint256 _protocolFee) external onlyGovernance {
        protocolFee = _protocolFee;
    }

    function setGovernance(address _governance) external onlyGovernance {
        governance = _governance;
    }

    modifier onlyGovernance() {
        require(msg.sender == governance, "governance");
        _;
    }

    /**
     * Used to for unit testing
     */
    // TODO: remove on main
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
