// SPDX-License-Identifier: Unlicense

pragma solidity ^0.6.6;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import "@uniswap/v3-periphery/contracts/libraries/PositionKey.sol";

import "./interfaces/IVault.sol";
import "./libraries/SharedEvents.sol";
import "./libraries/Constants.sol";
import "./libraries/VaultParams.sol";

import "hardhat/console.sol";

// remove  due to not implementing this function
contract Vault is IVault, ERC20, ReentrancyGuard, VaultParams {
    using SafeMath for uint256;

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
    )
        public
        ERC20("Hedging DL", "HDL")
        VaultParams(
            _cap,
            _rebalanceTimeThreshold,
            _rebalancePriceThreshold,
            _auctionTime,
            _minPriceMultiplier,
            _maxPriceMultiplier,
            _targetEthShare,
            _targetUsdcShare,
            _targetOsqthShare
        )
    {}

    function getProportion(uint256 _wethAmountToDeposit)
        public
        pure
        returns (uint256 usdcAmountToDeposit, uint256 osqthAmountToDeposit)
    {
        usdcAmountToDeposit = _wethAmountToDeposit.mul(2);
        osqthAmountToDeposit = _wethAmountToDeposit.mul(2);
    }

    /**
     * @notice deposit wETH into strategy
     * @dev provide wETH, return strategy token (shares)
     * @dev deposited wETH sit in the vault and are not used for liquidity on
     * Uniswap until the next rebalance.
     * @param _wethAmountToDeposit amount of wETH to deposit
     * @return shares number of strategy tokens (shares) minted
     */
    function deposit(uint256 _wethAmountToDeposit) external override returns (uint256 shares) {
        require(_wethAmountToDeposit > 0, "Zero amount");
        require(totalEthDeposited.add(_wethAmountToDeposit) <= cap, "Cap is reached");

        (uint256 _usdcAmountToDeposit, uint256 _osqthAmountToDeposit) = getProportion(_wethAmountToDeposit);
        //Pull in wETH from sender
        Constants.weth.transferFrom(msg.sender, address(this), _wethAmountToDeposit);
        Constants.usdc.transferFrom(msg.sender, address(this), _usdcAmountToDeposit);
        Constants.osqth.transferFrom(msg.sender, address(this), _osqthAmountToDeposit);

        //Poke positions so vault's current holdings are up to date
        _poke(Constants.poolEthUsdc, orderEthUsdcLower, orderEthUsdcUpper);
        _poke(Constants.poolEthOsqth, orderOsqthEthLower, orderOsqthEthUpper);

        //Calculate shares to mint
        shares = _calcShares(_wethAmountToDeposit);

        //Mint shares to user
        _mint(msg.sender, shares);

        //Track deposited wETH amount
        totalEthDeposited += _wethAmountToDeposit;

        emit SharedEvents.Deposit(msg.sender, shares);
    }

    /**
      @notice withdraws tokens in proportion to the vault's holdings.
      @dev provide strategy tokens, returns set of wETH, USDC, and oSQTH
      @param shares shares burned by sender
      @param amountEthMin revert if resulting amount of wETH is smaller than this
      @param amountUsdcMin revert if resulting amount of USDC is smaller than this
      @param amountOsqthMin revert if resulting amount of oSQTH is smaller than this
     */
    function withdraw(
        uint256 shares,
        uint256 amountEthMin,
        uint256 amountUsdcMin,
        uint256 amountOsqthMin
    )
        external
        override
        nonReentrant
        returns (
            uint256 amountEth,
            uint256 amountUsdc,
            uint256 amountOsqth
        )
    {
        require(shares > 0, "Zero shares");

        uint256 totalSupply = totalSupply();

        _burn(msg.sender, shares);

        //withdraw user share of tokens from the lp positions in current proportion
        (uint256 amountEth0, uint256 amountUsdc) = _burnLiquidityShare(
            Constants.poolEthUsdc,
            orderEthUsdcLower,
            orderEthUsdcUpper,
            shares,
            totalSupply
        );
        (uint256 amountOsqth, uint256 amountEth1) = _burnLiquidityShare(
            Constants.poolEthOsqth,
            orderOsqthEthLower,
            orderOsqthEthUpper,
            shares,
            totalSupply
        );

        //sum up received eth from eth:usdc pool and from osqth:eth pool
        amountEth = amountEth0.add(amountEth1);

        console.log(amountEth);
        console.log(amountUsdc);
        console.log(amountOsqth);
        require(amountEth >= amountEthMin, "amountEthMin");
        require(amountUsdc >= amountUsdcMin, "amountUsdcMin");
        require(amountOsqth >= amountOsqthMin, "amountOsqthMin");

        //send tokens to user
        if (amountEth > 0) Constants.weth.transfer(msg.sender, amountEth);
        if (amountUsdc > 0) Constants.usdc.transfer(msg.sender, amountUsdc);
        if (amountOsqth > 0) Constants.osqth.transfer(msg.sender, amountOsqth);

        //track deposited wETH amount
        //TODO

        emit SharedEvents.Withdraw(msg.sender, shares, amountEth, amountUsdc, amountOsqth);
    }

    /**
     * @notice strategy rebalancing based on time threshold
     * @dev need to attach msg.value if buying oSQTH
     * @param _isPriceIncreased sell or buy auction, true for sell auction (strategy sell eth and usdc for osqth)
     * @param _amountEth amount of wETH to buy (strategy sell wETH both in sell and buy auction)
     * @param _amountUsdc amount of USDC to buy or sell (depending if price increased or decreased)
     * @param _amountOsqth amount of oSQTH to buy or sell (depending if price increased or decreased)
     */
    function timeRebalance(
        bool _isPriceIncreased,
        uint256 _amountEth,
        uint256 _amountUsdc,
        uint256 _amountOsqth
    ) external override nonReentrant {
        //check if rebalancing based on time threshold is allowed
        (bool isTimeRebalanceAllowed, uint256 auctionTriggerTime) = _isTimeRebalance();

        require(isTimeRebalanceAllowed, "Time rebalance not allowed");

        _rebalance(auctionTriggerTime, _isPriceIncreased, _amountEth, _amountUsdc, _amountOsqth);

        emit SharedEvents.TimeRebalance(
            msg.sender,
            _isPriceIncreased,
            auctionTriggerTime,
            _amountEth,
            _amountUsdc,
            _amountOsqth
        );
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

        _rebalance(_auctionTriggerTime, _isPriceIncreased, _amountEth, _amountUsdc, _amountOsqth);

        emit SharedEvents.PriceRebalance(msg.sender, _isPriceIncreased, _amountEth, _amountUsdc, _amountOsqth);
    }

    /**
     * @dev Do zero-burns to poke a position on Uniswap so earned fees are
     * updated. Should be called if total amounts needs to include up-to-date
     * fees.
     * @param pool address of pool to poke
     * @param tickLower lower tick of the position
     * @param tickUpper upper tick of the position
     */
    function _poke(
        address pool,
        int24 tickLower,
        int24 tickUpper
    ) internal {
        (uint128 liquidity, , , , ) = _position(pool, tickLower, tickUpper);

        if (liquidity > 0) {
            IUniswapV3Pool(pool).burn(tickLower, tickUpper, 0);
        }
    }

    /// @dev Wrapper around `IUniswapV3Pool.positions()`.
    function _position(
        address pool,
        int24 tickLower,
        int24 tickUpper
    )
        internal
        view
        returns (
            uint128,
            uint256,
            uint256,
            uint128,
            uint128
        )
    {
        bytes32 positionKey = PositionKey.compute(address(this), tickLower, tickUpper);
        return IUniswapV3Pool(pool).positions(positionKey);
    }

    /**
     * @notice calculate strategy shares to ming
     * @param _amountToDeposit amount of wETH to deposit
     * @return shares strategy shares to mint
     */
    function _calcShares(uint256 _amountToDeposit) internal view returns (uint256 shares) {
        uint256 totalSupply = totalSupply();

        (uint256 ethAmount, uint256 usdcAmount, uint256 osqthAmount) = _getTotalAmounts();

        uint256 osqthEthPrice = Constants.oracle.getTwap(
            Constants.poolEthOsqth,
            address(Constants.weth),
            address(Constants.osqth),
            twapPeriod,
            true
        );

        uint256 usdcEthPrice = Constants.oracle.getTwap(
            Constants.poolEthUsdc,
            address(Constants.usdc),
            address(Constants.weth),
            twapPeriod,
            true
        );

        if (totalSupply == 0) {
            shares = _amountToDeposit;
        } else {
            uint256 totalEth = ethAmount.add(usdcAmount.mul(usdcEthPrice)).add(osqthAmount.mul(osqthEthPrice));
            uint256 depositorShare = _amountToDeposit.div(totalEth.add(_amountToDeposit));
            shares = totalSupply.mul(depositorShare).div(uint256(1e18).sub(depositorShare));
        }
    }

    /**
     * @notice Calculates the vault's total holdings of token0 and token1 - in
     * other words, how much of each token the vault would hold if it withdrew
     * all its liquidity from Uniswap.
     */
    function _getTotalAmounts()
        internal
        view
        returns (
            uint256 ethAmount,
            uint256 usdcAmount,
            uint256 osqthAmount
        )
    {
        (uint256 amountWeth0, uint256 usdcAmount) = getPositionAmount(
            Constants.poolEthUsdc,
            orderEthUsdcLower,
            orderEthUsdcUpper
        );

        (uint256 osqthAmount, uint256 amountWeth1) = getPositionAmount(
            Constants.poolEthOsqth,
            orderEthUsdcLower,
            orderEthUsdcUpper
        );

        ethAmount = amountWeth0.add(amountWeth1);
    }

    /**
     * @notice Amounts of token0 and token1 held in vault's position. Includes owed fees.
     * @dev Doesn't include fees accrued since last poke.
     */
    function getPositionAmount(
        address pool,
        int24 tickLower,
        int24 tickUpper
    ) public view returns (uint256 total0, uint256 total1) {
        (uint128 liquidity, , , uint128 tokensOwed0, uint128 tokensOwed1) = _position(pool, tickLower, tickUpper);
        (total0, total1) = _amountsForLiquidity(pool, tickLower, tickUpper, liquidity);
    }

    /// @dev Wrapper around `LiquidityAmounts.getAmountsForLiquidity()`.
    function _amountsForLiquidity(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) internal view returns (uint256, uint256) {
        (uint160 sqrtRatioX96, , , , , , ) = IUniswapV3Pool(pool).slot0();
        return
            LiquidityAmounts.getAmountsForLiquidity(
                sqrtRatioX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidity
            );
    }

    /// @dev Withdraws share of liquidity in a range from Uniswap pool.
    function _burnLiquidityShare(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint256 shares,
        uint256 totalSupply
    ) internal returns (uint256 amount0, uint256 amount1) {
        (uint128 totalLiquidity, , , , ) = _position(pool, tickLower, tickUpper);
        uint256 liquidity = uint256(totalLiquidity).mul(shares).div(totalSupply);

        if (liquidity > 0) {
            (uint256 burned0, uint256 burned1, uint256 fees0, uint256 fees1) = _burnAndCollect(
                pool,
                tickLower,
                tickUpper,
                _toUint128(liquidity)
            );

            //add share of fees
            amount0 = burned0.add(fees0.mul(shares).div(totalSupply));
            amount1 = burned1.add(fees1.mul(shares).div(totalSupply));
        }
    }

    /// @dev Withdraws liquidity from a range and collects all fees in the process.
    function _burnAndCollect(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    )
        internal
        returns (
            uint256 burned0,
            uint256 burned1,
            uint256 feesToVault0,
            uint256 feesToVault1
        )
    {
        if (liquidity > 0) {
            IUniswapV3Pool(pool).burn(tickLower, tickUpper, liquidity);
        }

        (uint256 collect0, uint256 collect1) = IUniswapV3Pool(pool).collect(
            address(this),
            tickLower,
            tickUpper,
            type(uint128).max,
            type(uint128).max
        );

        feesToVault0 = collect0.sub(burned0);
        feesToVault1 = collect1.sub(burned1);
    }

    /**
     * @notice check if hedging based on time threshold is allowed
     * @return true if time hedging is allowed
     * @return auction trigger timestamp
     */
    function _isTimeRebalance() internal view returns (bool, uint256) {
        uint256 auctionTriggerTime = timeAtLastRebalance.add(rebalanceTimeThreshold);

        return (block.timestamp >= auctionTriggerTime, auctionTriggerTime);
    }

    /** //TODO
     * @notice check if hedging based on price threshold is allowed
     * @param _auctionTriggerTime timestamp where auction started
     * @return true if hedging is allowed
     */
    function _isPriceRebalance(uint256 _auctionTriggerTime) internal returns (bool) {
        return true;
    }

    /**
     * @notice rebalancing function to adjust proportion of tokens
     * @param _auctionTriggerTime timestamp when auction started
     * @param _isPriceIncreased auction type, true for sell auction
     * @param _amountEth amount of wETH to buy (strategy sell wETH both in sell and buy auction)
     * @param _amountUsdc amount of USDC to buy or sell (depending if price increased or decreased)
     * @param _amountOsqth amount of oSQTH to buy or sell (depending if price increased or decreased)
     */
    function _rebalance(
        uint256 _auctionTriggerTime,
        bool _isPriceIncreased,
        uint256 _amountEth,
        uint256 _amountUsdc,
        uint256 _amountOsqth
    ) internal {
        (bool isPriceInc, uint256 deltaEth, uint256 deltaUsdc, uint256 deltaOsqth) = _startAuction(_auctionTriggerTime);

        require(isPriceInc == _isPriceIncreased, "Wrong auction type");

        if (isPriceInc) {
            require(_amountOsqth >= deltaOsqth, "Wrong amount");

            _executeAuction(msg.sender, deltaEth, deltaUsdc, deltaOsqth, isPriceInc);
        } else {
            require(_amountEth >= deltaEth, "Wrong amount");
            require(_amountUsdc >= deltaUsdc, "Wrong amount");

            _executeAuction(msg.sender, deltaEth, deltaUsdc, deltaOsqth, isPriceInc);
        }

        emit SharedEvents.Rebalance(msg.sender, _isPriceIncreased, _amountEth, _amountUsdc, _amountOsqth);
    }

    /**
     * @notice determine auction direction, price, and ensure auction hasn't switched directions
     * @param _auctionTriggerTime auction starting time
     * @return auction type
     * @return wETH to sell/buy
     * @return USDC to sell/buy
     * @return oSQTH amount to sell or buy
     */
    function _startAuction(uint256 _auctionTriggerTime)
        internal
        returns (
            bool,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 currentEthUsdcPrice = Constants.oracle.getTwap(
            Constants.poolEthUsdc,
            address(Constants.weth),
            address(Constants.usdc),
            twapPeriod,
            true
        );

        uint256 currentOsqthEthPrice = Constants.oracle.getTwap(
            Constants.poolEthOsqth,
            address(Constants.weth),
            address(Constants.osqth),
            twapPeriod,
            true
        );

        bool _isPriceInc = _checkAuctionType(currentEthUsdcPrice);
        (uint256 deltaEth, uint256 deltaUsdc, uint256 deltaOsqth) = _getDeltas(
            currentEthUsdcPrice,
            currentOsqthEthPrice,
            _auctionTriggerTime,
            _isPriceInc
        );

        timeAtLastRebalance = block.timestamp;
        ethPriceAtLastRebalance = currentEthUsdcPrice;

        return (_isPriceInc, deltaEth, deltaUsdc, deltaOsqth);
    }

    /**
     * @notice check the direction of auction
     * @param _ethUsdcPrice current wETH/USDC price
     * @return isPriceInc true if price increased
     */
    function _checkAuctionType(uint256 _ethUsdcPrice) internal view returns (bool isPriceInc) {
        isPriceInc = _ethUsdcPrice >= ethPriceAtLastRebalance ? true : false;
    }

    /**
     * @notice calculate how much of each token the strategy need to sell to achieve target proportion
     * @param _currentEthUsdcPrice current wETH/USDC price
     * @param _currentOsqthEthPrice current oSQTH/ETH price
     * @param _auctionTriggerTime time when auction has started
     * @param _isPriceInc true if price increased
     * @return deltaEth amount of wETH to sell or buy
     * @return deltaUsdc amount of USDC to sell or buy
     * @return deltaOsqth amount of oSQTH to sell or buy
     */
    function _getDeltas(
        uint256 _currentEthUsdcPrice,
        uint256 _currentOsqthEthPrice,
        uint256 _auctionTriggerTime,
        bool _isPriceInc
    )
        internal
        view
        returns (
            uint256 deltaEth,
            uint256 deltaUsdc,
            uint256 deltaOsqth
        )
    {
        (uint256 ethAmount, uint256 usdcAmount, uint256 osqthAmount) = _getTotalAmounts();

        //add unused deposited tokens
        ethAmount = ethAmount.add(Constants.weth.balanceOf(address(this)));
        //@dev some usdc and osqth may left after the prev rebalance
        usdcAmount = usdcAmount.add(Constants.usdc.balanceOf(address(this)));
        osqthAmount = osqthAmount.add(Constants.osqth.balanceOf(address(this)));

        (uint256 _auctionEthUsdcPrice, uint256 _auctionOsqthEthPrice) = _getPriceMultiplier(
            _auctionTriggerTime,
            _currentEthUsdcPrice,
            _currentOsqthEthPrice,
            _isPriceInc
        );

        //calculate current total value based on auction prices
        uint256 totalValue = ethAmount.mul(_auctionEthUsdcPrice).add(osqthAmount.mul(_auctionOsqthEthPrice)).add(
            usdcAmount
        );

        deltaEth = targetEthShare.div(1e18).mul(totalValue.div(_auctionEthUsdcPrice)).sub(ethAmount);
        deltaUsdc = targetUsdcShare.div(1e18).mul(totalValue).sub(usdcAmount);
        deltaOsqth = targetOsqthShare
            .div(1e18)
            .mul(totalValue.div(_auctionOsqthEthPrice.mul(_auctionEthUsdcPrice)))
            .sub(osqthAmount);
    }

    /**
     * @notice calculate auction price based on auction direction, start time and ETH/USDC price
     * @param _auctionTriggerTime time when auction has started
     * @param _currentEthUsdcPrice current ETH/USDC price
     * @param _currentOsqthEthPrice current oSQTH/ETH price
     * @param _isPriceInc true if price increased (determine auction direction)
     */
    function _getPriceMultiplier(
        uint256 _auctionTriggerTime,
        uint256 _currentEthUsdcPrice,
        uint256 _currentOsqthEthPrice,
        bool _isPriceInc
    ) internal view returns (uint256 auctionEthUsdcPrice, uint256 auctionOsqthEthPrice) {
        uint256 auctionCompletionRatio = block.timestamp.sub(_auctionTriggerTime) >= auctionTime
            ? 1e18
            : (block.timestamp.sub(_auctionTriggerTime)).div(auctionTime);

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
        auctionEthUsdcPrice = priceMultiplier.mul(_currentEthUsdcPrice);
        auctionOsqthEthPrice = priceMultiplier.mul(_currentOsqthEthPrice);
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
        uint256 _deltaEth,
        uint256 _deltaUsdc,
        uint256 _deltaOsqth,
        bool _isPriceInc
    ) internal {
        (uint128 liquidityEthUsdc, , , , ) = _position(Constants.poolEthUsdc, orderEthUsdcLower, orderEthUsdcUpper);

        (uint128 liquidityOsqthEth, , , , ) = _position(Constants.poolEthOsqth, orderEthUsdcLower, orderOsqthEthUpper);

        _burnAndCollect(Constants.poolEthUsdc, orderEthUsdcLower, orderEthUsdcUpper, liquidityEthUsdc);
        _burnAndCollect(Constants.poolEthOsqth, orderEthUsdcLower, orderOsqthEthUpper, liquidityOsqthEth);

        if (_isPriceInc) {
            //pull in tokens from sender
            Constants.osqth.transferFrom(_keeper, address(this), _deltaOsqth);

            //send excess tokens to sender
            Constants.weth.transfer(_keeper, _deltaEth);
            Constants.usdc.transfer(_keeper, _deltaUsdc);
        } else {
            Constants.usdc.transferFrom(_keeper, address(this), _deltaUsdc);

            Constants.weth.transfer(_keeper, _deltaEth);
            Constants.osqth.transfer(_keeper, _deltaOsqth);
        }

        (int24 _ethUsdcLower, int24 _ethUsdcUpper, int24 _osqthEthLower, int24 _osqthEthUpper) = _getBoundaries();

        uint128 liquidityEthUsdcForAmounts = _liquidityForAmounts(
            Constants.poolEthUsdc,
            _ethUsdcLower,
            _ethUsdcUpper,
            balanceOf(address(Constants.weth)).mul(targetUsdcShare.div(2)),
            balanceOf(address(Constants.usdc))
        );

        uint128 liquidityOsqthEthForAmounts = _liquidityForAmounts(
            Constants.poolEthOsqth,
            _osqthEthLower,
            _osqthEthUpper,
            balanceOf(address(Constants.weth)),
            balanceOf(address(Constants.osqth))
        );

        //place orders on Uniswap
        _mintLiquidity(Constants.poolEthUsdc, _ethUsdcLower, _ethUsdcUpper, liquidityEthUsdcForAmounts);
        _mintLiquidity(Constants.poolEthOsqth, _osqthEthLower, _osqthEthUpper, liquidityOsqthEthForAmounts);

        (orderEthUsdcLower, orderEthUsdcUpper, orderOsqthEthLower, orderOsqthEthUpper) = (
            _ethUsdcLower,
            _ethUsdcUpper,
            _osqthEthLower,
            _osqthEthUpper
        );
    }

    /**
     * @notice calculate lower and upper tick for liquidity provision on Uniswap
     * @return ethUsdcLower tick lower for eth:usdc pool
     * @return ethUsdcUpper tick upper for eth:usdc pool
     * @return osqthEthLower tick lower for osqth:eth pool
     * @return osqthEthUpper tick upper for osqth:eth pool
     */
    function _getBoundaries()
        internal
        view
        returns (
            int24 ethUsdcLower,
            int24 ethUsdcUpper,
            int24 osqthEthLower,
            int24 osqthEthUpper
        )
    {
        int24 tickEthUsdc = getTick(Constants.poolEthUsdc);
        int24 tickOsqthEth = getTick(Constants.poolEthOsqth);

        int24 tickFloorEthUsdc = _floor(tickEthUsdc, tickSpacingEthUsdc);
        int24 tickFloorOsqthEth = _floor(tickOsqthEth, tickSpacingOsqthEth);

        int24 tickCeilEthUsdc = tickFloorEthUsdc + tickSpacingEthUsdc;
        int24 tickCeilOsqthEth = tickFloorOsqthEth + tickSpacingOsqthEth;

        int24 ethUsdcThreshold = 1;
        int24 osqthEthThreshold = 1;

        ethUsdcLower = tickFloorEthUsdc - ethUsdcThreshold;
        ethUsdcUpper = tickCeilEthUsdc + ethUsdcThreshold;
        osqthEthLower = tickFloorOsqthEth - osqthEthThreshold;
        osqthEthUpper = tickCeilOsqthEth + osqthEthThreshold;
    }

    /// @dev Fetches current price in ticks from Uniswap pool.
    function getTick(address pool) public view returns (int24 tick) {
        (, tick, , , , , ) = IUniswapV3Pool(pool).slot0();
    }

    /// @dev Wrapper around `LiquidityAmounts.getLiquidityForAmounts()`.
    function _liquidityForAmounts(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1
    ) internal view returns (uint128) {
        (uint160 sqrtRatioX96, , , , , , ) = IUniswapV3Pool(pool).slot0();
        return
            LiquidityAmounts.getLiquidityForAmounts(
                sqrtRatioX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                amount0,
                amount1
            );
    }

    /// @dev Deposits liquidity in a range on the Uniswap pool.
    function _mintLiquidity(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) internal {
        if (liquidity > 0) {
            IUniswapV3Pool(pool).mint(address(this), tickLower, tickUpper, liquidity, "");
        }
    }
}
