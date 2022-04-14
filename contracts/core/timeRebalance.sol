function timeRebalance(
        uint256 amountEth,
        uint256 amountUsdc,
        uint256 amountOsqth
    ) external override nonReentrant {
        //check if rebalancing based on time threshold is allowed
        (bool isTimeRebalanceAllowed, uint256 auctionTriggerTime) = _isTimeRebalance(); //no changes

        require(isTimeRebalanceAllowed, "Time rebalance not allowed");

        _rebalance(auctionTriggerTime, amountEth, amountUsdc, amountOsqth);

        emit SharedEvents.TimeRebalance(msg.sender, auctionTriggerTime, amountEth, amountUsdc, amountOsqth);
    }

    function _rebalance(
        uint256 _auctionTriggerTime,
        uint256 _amountEth,
        uint256 _amountUsdc,
        uint256 _amountOsqth
    ) internal {

        _getAuctionParams(_auctionTriggerTime);

        _executeAuction(_amountEth, _amountUsdc, _amountOsqth);
        
        emit SharedEvents.Rebalance(msg.sender, _amountEth, _amountUsdc, _amountOsqth);
    }

    struct AuctionParams {
        bool isPriceInc;
        uint256 deltaEth;
        uint256 deltaUsdc;
        uint256 deltaOsqth;
        int24 ethUsdcLower;
        int24 ethUsdcUpper;
        int24 osqthEthLower;
        int24 osqthEthUpper;
        uint128 liquidityEthUsdc;
        uint128 liquidityOsqthEth;
    }

    function _getAuctionParams (uint256 _auctionTriggerTime, uint256 _amountEth, uint256 _amountUsdc, uint256 _amountOsqth) internal view 
    {
        uint128 liquidityEthUsdc;
        uint128 liquidityOsqthEth;
        int24 ethUsdcLower;
        int24 ethUsdcUpper;
        int24 osqthEthLower;
        int24 osqthEthUpper;
        bool _isPriceInc;
        
        {//scope

        (, uint160 ethUsdcTick, , , , , ) = poolEthUsdc.slot0();
        (, uint160 osqthEthTick , , , , , ) = poolEthOsqth.slot0();

        uint256 ethUsdcPrice = uint256(1e30).div(_getPriceTick(ethUsdcTick));
        uint256 osqthEthPrice = uint256(1e18).div(_getPriceFromTick(osqthEthTick));

        _isPriceInc = _checkAuctionType(ethUsdcPrice);
        uint256 priceMultiplier = _getPriceMultiplier(_auctionTriggerTime, _isPriceInc);

        //auction prices price*multiplier
        uint256 aEthUsdcPrice = ethUsdcPrice.mul(priceMultiplier);
        uint256 aOqsthEthPrice = osqthEthPrice.mul(priceMultiplier);

        (ethUsdcLower, ethUsdcUpper, osqthEthLower, osqthEthUpper) = _getBoundaries(aEthUsdcPrice, aOqsthEthPrice);

        uint256 totalValue = _getValue(
            getBalance(weth),
            getBalance(usdc),
            getBalance(osqth),
            ethUsdcPrice,
            osqthEthPrice            
        );

        uint256 vm = priceMultiplier.mul(uint256(1e18)).div(priceMultiplier.add(uint256(1e18))); //Value multiplier
      
        liquidityEthUsdc = _getLiquidityForValue(
            totalValue.mul(vm).div(1e18),
            ethUsdcPrice,
            uint256(1e30).div(_getPriceTick(ethUsdcUpper)), //проверить порядок 
            uint256(1e30).div(_getPriceTick(ethUsdcLower))
        );

        liquidityOsqthEth = _getLiquidityForValue(
            totalValue.mul(uint256(1e18).sub(vm)),
            osqthEthPrice,
            uint256(1e18).div(_getPriceFromTick(osqthEthLower)),
            uint256(1e18).div(_getPriceFromTick(osqthEthUpper))
        );
        }
        //запись в стракт 

        //???вынести в отдельную функцию _getDeltas (если стак ту дип)
        uint256 deltaEth;
        uint256 deltaUsdc;
        uint256 deltaOsqth;
        {//scope
            (uint256 ethAmount0, uint256 usdcAmount) = _amountsForLiquidity(poolEthUsdc, ethUsdcLower, ethUsdcUpper, liquidityEthUsdc);
            (uint256 ethAmount1, uint256 osqthAmount) = _amountsForLiquidity(poolEthOsqth, osqthEthLower, osqthEthUpper, liquidityOsqthEth);

            deltaEth = abs(getBalance(weth).sub(ethAmount0).sub(ethAmount1));
            deltaUsdc = abs(getBalance(usdc).sub(usdcAmount));
            deltaOsqth = abs(getBalance(osqth).sub(osqthAmount));
        }
    }

function _getValue(
    uint256 amountEth,
    uint256 amountUsdc,
    uint256 amountOsqth,
    uint256 ethUsdcPrice,
    uint256 osqthEthPrice
) internal view returns (uint256) {
    return (amountOsqth.mul(osqthEthPrice) + amountEth).mul(ethUsdcPrice) + amountUsdc.mul(1e30);
}


function _getLiquidityForValue (
    uint256 v,
    uint256 p,
    uint256 pL,
    uint256 pH
) internal view returns (uint128) {
    return _toUint128(v.div((p.sqrt()).mul(2e18) - pL.sqrt() - p.div(pH.sqrt())).mul(1e9));
    }

function _getBoundaries(uint256 aEthUsdcPrice, uint256 aOsqthEthPrice) internal view returns (int24, int24, int24, int24) {
    int24 ethUsdcLower;
    int24 ethUsdcUpper;
    int24 osqthEthLower;
    int24 osqthEthUpper;
    { //scope
        int24 aEthUsdcTick = TickMath.getTickAtSqrtRatio(
            _toUint160(
                //sqrt(price)*2**96
                ((aEthUsdcPrice.div(1e18)).sqrt()).mul(79228162514264337593543950336)
                )
        );

        int24 aOsqthEthTick = TickMath.getTickAtSqrtRatio(
            _toUint160(
                ((uint256(1e18).div(aOsqthEthPrice)).sqrt()).mul(79228162514264337593543950336)
                )
        );

        int24 tickFloorEthUsdc = _floor(aEthUsdcTick, tickSpacingEthUsdc);
        int24 tickFloorOsqthEth = _floor(aEthUsdcTick, tickSpacingOsqthEth);

        int24 tickCeilEthUsdc = tickFloorEthUsdc + tickSpacingEthUsdc;
        int24 tickCeilOsqthEth = tickFloorOsqthEth + tickSpacingOsqthEth;

        int24 ethUsdcThreshold = 960;
        int24 osqthEthThreshold = 960;

        ethUsdcLower = tickFloorEthUsdc - ethUsdcThreshold;
        ethUsdcUpper = tickCeilEthUsdc + ethUsdcThreshold;
        osqthEthLower = tickFloorOsqthEth - osqthEthThreshold;
        osqthEthUpper = tickCeilOsqthEth + osqthEthThreshold;
    }
}

function _getPriceMultiplier(uint256 _auctionTriggerTime, bool _isPriceInc) internal view returns (uint256) {

    uint256 auctionCompletionRatio = block.timestamp.sub(_auctionTriggerTime) >= auctionTime
            ? 1e18
            : (block.timestamp.sub(_auctionTriggerTime)).div(params.auctionTime);

    uint256 priceMultiplier;
        if (_isPriceInc) {
            priceMultiplier = maxPriceMultiplier.sub(
                auctionCompletionRatio.mul(maxPriceMultiplier.sub(minPriceMultiplier))
            );
        } else {
            priceMultiplier = minPriceMultiplier.add(
                auctionCompletionRatio.mul(maxPriceMultiplier.sub(minPriceMultiplier))
            );
        }

        return priceMultiplier;
}

function _getPriceFromTick(int24 tick) internal view returns (uint256) {
    return (
        //const = 2^192
        uint256 const = 6277101735386680763835789423207666416102355444464034512896;
        //uint x = 162714639867323407420353073371;
    return ((TickMath.getSqrtRatioAtTick(tick)).pow(uint256(2e18)).mul(1e36).div(const));
    )
}

function _checkAuctionType(uint256 _ethUsdcPrice) public view returns (bool isPriceInc) {
        isPriceInc = _ethUsdcPrice >= ethPriceAtLastRebalance ? true : false;
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
    