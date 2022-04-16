// SPDX-License-Identifier: Unlicense

pragma solidity =0.7.6;
pragma abicoder v2;

import "../interfaces/IVault.sol";
import "../libraries/SharedEvents.sol";
import "../libraries/Constants.sol";
import "../libraries/StrategyMath.sol";
import "./VaultMath.sol";

import "hardhat/console.sol";

contract VaultAuction is IAuction, VaultMath {
    using StrategyMath for uint256;

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
        uint256 _targetOsqthShare,
        address iprbCalculusLib
    )
        public
        VaultMath(
            _cap,
            _rebalanceTimeThreshold,
            _rebalancePriceThreshold,
            _auctionTime,
            _minPriceMultiplier,
            _maxPriceMultiplier,
            _targetEthShare,
            _targetUsdcShare,
            _targetOsqthShare,
            iprbCalculusLib
        )
    {}

    /**
     * @notice strategy rebalancing based on time threshold
     * @dev need to attach msg.value if buying oSQTH
     * @param amountEth amount of wETH to buy (strategy sell wETH both in sell and buy auction)
     * @param amountUsdc amount of USDC to buy or sell (depending if price increased or decreased)
     * @param amountOsqth amount of oSQTH to buy or sell (depending if price increased or decreased)
     */
    function timeRebalance(
        uint256 amountEth,
        uint256 amountUsdc,
        uint256 amountOsqth
    ) external override nonReentrant {
        //check if rebalancing based on time threshold is allowed
        (bool isTimeRebalanceAllowed, uint256 auctionTriggerTime) = _isTimeRebalance();

        require(isTimeRebalanceAllowed, "Time rebalance not allowed");

        _rebalance(auctionTriggerTime, amountEth, amountUsdc, amountOsqth);

        emit SharedEvents.TimeRebalance(msg.sender, auctionTriggerTime, amountEth, amountUsdc, amountOsqth);
    }

    /** TODO
     * @notice strategy rebalancing based on price threshold
     * @dev need to attach msg.value if buying oSQTH
     * @param _auctionTriggerTime the time when the price deviation threshold was exceeded and when the auction started
     * @param _isPriceIncreased sell or buy auction, true for sell auction (strategy sell eth and usdc for osqth)
     * @param _amountEth amount of wETH to buy (strategy sell wETH both in sell and buy auction)
     * @param _amountUsdc amount of USDC to buy or sell (depending if price increased or decreased)
     * @param _amountOsqth amount of oSQTH to buy or sell (depending if price increased or decreased)
     */
    function priceRebalance(
        uint256 _auctionTriggerTime,
        bool _isPriceIncreased,
        uint256 _amountEth,
        uint256 _amountUsdc,
        uint256 _amountOsqth
    ) external nonReentrant {
        //check if rebalancing based on price threshold is allowed
        require(_isPriceRebalance(_auctionTriggerTime), "Price rebalance not allowed");

        _rebalance(_auctionTriggerTime, _amountEth, _amountUsdc, _amountOsqth);

        emit SharedEvents.PriceRebalance(msg.sender, _amountEth, _amountUsdc, _amountOsqth);
    }

    /**
     * @notice rebalancing function to adjust proportion of tokens
     * @param _auctionTriggerTime timestamp when auction started
     * @param _amountEth amount of wETH to buy (strategy sell wETH both in sell and buy auction)
     * @param _amountUsdc amount of USDC to buy or sell (depending if price increased or decreased)
     * @param _amountOsqth amount of oSQTH to buy or sell (depending if price increased or decreased)
     */
    function _rebalance(
        uint256 _auctionTriggerTime,
        uint256 _amountEth,
        uint256 _amountUsdc,
        uint256 _amountOsqth
    ) internal {
        Constants.AuctionParams memory params = _getAuctionParams(
            _auctionTriggerTime,
            _amountEth,
            _amountUsdc,
            _amountOsqth
        );

        _executeAuction(params);

        emit SharedEvents.Rebalance(msg.sender, _amountEth, _amountUsdc, _amountOsqth);
    }

    /**
     * @notice execute auction based on the parameters calculated
     * @dev withdraw all liquidity from the positions
     * @dev pull in tokens from keeper
     * @dev sell excess tokens to sender
     * @dev place new positions in eth:usdc and osqth:eth pool
     */
    function _executeAuction(Constants.AuctionParams memory params) internal {
        // (uint128 liquidityEthUsdc, , , , ) = _position(Constants.poolEthUsdc, orderEthUsdcLower, orderEthUsdcUpper);
        // (uint128 liquidityOsqthEth, , , , ) = _position(Constants.poolEthOsqth, orderEthUsdcLower, orderOsqthEthUpper);
        // _burnAndCollect(Constants.poolEthUsdc, orderEthUsdcLower, orderEthUsdcUpper, liquidityEthUsdc);
        // _burnAndCollect(Constants.poolEthOsqth, orderEthUsdcLower, orderOsqthEthUpper, liquidityOsqthEth);
        // if (_isPriceInc) {
        //     //pull in tokens from sender
        //     Constants.usdc.transferFrom(_keeper, address(this), _deltaUsdc);
        //     Constants.weth.transfer(_keeper, _deltaEth);
        //     Constants.osqth.transfer(_keeper, _deltaOsqth);
        // } else {
        //     Constants.weth.transferFrom(_keeper, address(this), _deltaEth);
        //     Constants.osqth.transferFrom(_keeper, address(this), _deltaOsqth);
        //     Constants.usdc.transfer(_keeper, _deltaUsdc);
        // }
        // uint256 balanceEth = uint256(1e18).mul(totalValue.div(2).sub(getBalance(Constants.usdc).mul(1e12))).div(
        //     auctionEthUsdcPrice
        // );
        // console.log("balanceEth %s", balanceEth);
        // _executeEmptyAuction(balanceEth, auctionEthUsdcPrice, auctionOsqthEthPrice);
    }

    function _executeEmptyAuction(
        uint256 balanceEth,
        uint256 auctionEthUsdcPrice,
        uint256 auctionOsqthEthPrice
    ) internal {
        Constants.Boundaries memory boundaries = _getBoundaries(auctionEthUsdcPrice, auctionOsqthEthPrice);

        // console.log("> _executeEmptyAuction => ticks start");
        // console.logInt(boundaries.ethUsdcLower);
        // console.logInt(boundaries.ethUsdcUpper);
        // console.logInt(boundaries.osqthEthLower);
        // console.logInt(boundaries.osqthEthUpper);
        // console.log("> endregion");

        console.log("before first mint");
        console.log("ballance weth %s", getBalance(Constants.weth));
        console.log("ballance usdc %s", getBalance(Constants.usdc));
        console.log("ballance osqth %s", getBalance(Constants.osqth));

        //place orders on Uniswap
        _mintLiquidity(
            Constants.poolEthUsdc,
            boundaries.ethUsdcLower,
            boundaries.ethUsdcUpper,
            getBalance(Constants.usdc),
            balanceEth
        );

        console.log("before second mint");
        console.log("ballance weth %s", getBalance(Constants.weth));
        console.log("ballance usdc %s", getBalance(Constants.usdc));
        console.log("ballance osqth %s", getBalance(Constants.osqth));
        _mintLiquidity(
            Constants.poolEthOsqth,
            boundaries.osqthEthLower,
            boundaries.osqthEthUpper,
            getBalance(Constants.weth),
            getBalance(Constants.osqth)
        );

        (orderEthUsdcLower, orderEthUsdcUpper, orderOsqthEthLower, orderOsqthEthUpper) = (
            boundaries.ethUsdcLower,
            boundaries.ethUsdcUpper,
            boundaries.osqthEthLower,
            boundaries.osqthEthUpper
        );
    }
}
