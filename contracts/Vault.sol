// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import "@uniswap/v3-periphery/contracts/libraries/PositionKey.sol";

import "./interfaces/IVault.sol";
import "./interfaces/IOracle.sol";


contract Vault is 
    IVault,
    IUniswapV3MintCallback,
    ERC20,
    ReentrancyGuard
    {
        using SafeERC20 for IERC20;
        using SafeMath for uint256;

    event Deposit (
       address indexed sender,
       uint256 shares
    );

    IUniswapV3Pool public immutable poolETHUSDC;
    IUniswapV3Pool public immutable poolOSQTHETH;

    IERC20 public immutable tokenETHUSDC0;
    IERC20 public immutable tokenETHUSDC1;
    IERC20 public immutable tokenOSQTHETH0;
    IERC20 public immutable tokenOSQTHETH1;
    IERC20 public immutable tokenToDeposit;

    address public immutable oracleETHUSDC;
    address public immutable oracleOSQTHETH;

    event TimeRebalance (
        address indexed hedger,
        bool auctionType,
        uint256 hedgerPrice,
        uint256 auctionTriggerTimestamp
    );

    event PriceRebalance (
        address indexed hedger,
        bool auctionType,
        uint256 hedgerPrice,
        uint256 auctionTriggerTimestamp
    );

    struct Account {
        uint256 shares;
        uint256 ethBalance;
        uint256 usdcBalance;
        uint256 osqthBalance;
    }

    IUniswapV3Pool public immutable poolEU; //ETH-USDC
    IUniswapV3Pool public immutable poolES; //ETH-oSQTH
    IERC20 public immutable tokenEU0; 
    IERC20 public immutable tokenEU1;
    IERC20 public immutable tokenES0;
    IERC20 public immutable tokenES1;
    IERC20 public immutable tokenToDeposit; // weth?
    
    address public immutable oracleEU;
    address public immutable oracleES;

    int24 public immutable tickSpacing;
    uint32 public twapPeriod = 420 seconds;

    uint256 public protocolFee;
    uint256 public totalETHDeposited;
    uint256 public cap;
    address public governance;

    int24 public orderETHUSDCLower;
    int24 public orderETHUSDCUpper;
    int24 public orderOSQTHETHLower;
    int24 public orderOSQTHETHUpper;

    uint256 public timeAtLastRebalance;
    uint256 public ethPriceAtLastRebalance;
    uint256 public rebalanceTimeThreshold;
    
    uint256 public auctionTime;
    uint256 public minPriceMultiplier;
    uint256 public maxPriceMultiplier;
    uint256 public targetEthShare;
    uint256 public targetUsdcShare;
    uint256 public targetOsqthShare;

    constructor (
        address _tokenToDeposit,
        uint256 _cap,
        address _poolETHUSDC,
        address _poolOSQTHETH,
        uint256 _protocolFee,
        address _oracleETHUSDC,
        address _oracleOSQTHETH,
        uint256 _rebalanceTimeThreshold,
        uint256 _rebalancePriceThreshold,
        uint256 _auctionTime,
        uint256 _minPriceMultiplier,
        uint256 _maxPriceMultiplier,
        uint256 _targetEthShare,
        uint256 _targetUsdcShare,
        uint256 _targetOsqthShare
    ) ERC20 ("Hedging DL", "HDL") {
        
        tokenToDeposit = _tokenToDeposit;
        cap = _cap;

        poolETHUSDC = IUniswapV3Pool(_poolETHUSDC);
        poolOSQTHETH = IUniswapV3Pool(_poolOSQTHETH);

        tokenETHUSDC0 = IERC20(IUniswapV3Pool(_poolETHUSDC).token0);
        tokenETHUSDC1 = IERC20(IUniswapV3Pool(_poolETHUSDC).token1);
        tokenOSQTHETH0 = IERC20(IUniswapV3Pool(_poolOSQTHETH).token0);
        tokenOSQTHETH1 = IERC20(IUniswapV3Pool(_poolOSQTHETH).token1);

        protocolFee = _protocolFee;

        oracleETHUSDC = _oracleETHUSDC;
        oracleOSQTHETH = _oracleOSQTHETH;

        tickSpacingEthUsdc = IUniswapV3Pool(_poolETHUSDC).tickSpacing();
        tickSpacingOsqthEth = IUniswapV3Pool(_poolOSQTHETH).tickSpacing();
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

    function deposit(uint256 _amountToDeposit) external override nonReentrant returns (uint256 shares)
    {
        require(_amountToDeposit > 0, "Zero amount");
        require(totalETHDeposited.add(_amountToDeposit) <= cap, "Cap is reached");

        tokenToDeposit.safeTrasferFrom(msg.sender, address(this), _amountToDeposit);

        // Poke positions so vault's current holdings are up to date
        _poke(poolETHUSDC, orderETHUSDCLower, orderETHUSDCUpper);
        _poke(poolOSQTHETH, orderETHUSDCLower, orderETHUSDCUpper);

        //Calculate shares to mint
        shares = _calcShares(_amountToDeposit);

        _mint(msg.sender, shares);
        
        if (accounts[msg.sender] == address(0)){
            accounts[msg.sender] = new Account(shares, 0, 0, 0);
        } else {
            accounts[msg.sender].shares = shares;
        }

        emit Deposit(msg.sender, shares);     
        
    }

    function withdraw(uint256 shares, uint256 amountEthMin, uint256 amountUsdcMin, amountOsqthMin) external override nonReentrant 
    returns (
        uint256 amountEth,
        uint256 amountUsdc,
        uint256 amountOsqth
    ) {
        require(shares > 0, "Zero shares");

        uint256 totalSupply = totalSupply();

        _burn(msg.sender, shares);

        (uint256 amountETHUSDC0, uint256 amountETHUSDC1) = _burnLiquidityShare(poolETHUSDC, orderETHUSDCLower, orderETHUSDCUpper, shares, totalSupply);
        (uint256 amountOSQTHETH0, uint256 amountOSQTHETH1) = _burnLiquidityShare(poolOSQTHETH, orderOSQTHETHLower, orderOSQTHETHUpper, shares, totalSupply);

        amountEth = amountETHUSDC0.add(amountOSQTHETH1);
        amountUsdc = amountETHUSDC1;
        amountOsqth = amountOSQTETH0;

        require(amountEth >= amountEthMin, "amountEthMin");
        require(amountUsdc >= amountUsdcMin, "amountUsdcMin");
        require(amountOsqth >= amountOsqthMin, "amountOsqthMin");

        if (amountEth > 0) weth.safeTrasferFrom(msg.sender, amountEth);
        if (amountUsdc > 0) usdc.safeTrasferFrom(msg.sender, amountUsdc);
        if (amountOsqth > 0) osqth.safeTrasferFrom(msg.sender, amountOsqth);

        emit Withdraw(msg.sender, shares, amountEth, amountUsdc, amountOsqth);

    }

    function timeRebalance(bool _isPriceIncreased, uint256 _amountEth, uint256 _amountUsdc, uint256 _amountOsqth) external nonReentrant {
        (bool isTimeRebalanceAllowed, uint256 auctionTriggerTime) = _isTimeRebalance();

        require (isTimeRebalanceAllowed, "Time rebalancing is not allowed");

        _rebalance(auctionTriggerTime, _isPriceIncreased, _amountEth, _amountUsdc, _amountUsdc);

        emit TimeRebalance(msg.sender, _isPriceIncreased, auctionTriggerTime, _amountEth, _amountUsdc, _amountOsqth);
    }

    function priceRebalance(uint256 _auctionTriggerTime, bool _isPriceIncreased, uint256 _amountEth, uint256 _amountUsdc, uint256 _amountOsqth) external nonReentrant {

        require(_isPriceRebalance(_auctionTriggerTime), "Price rebalance not allowed");

        _rebalance(auctionTriggerTime, _isPriceIncreased, _amountEth, _amountUsdc, _amountOsqth);

        emit PriceRebalance(msg.sender, _isPriceIncreased, _amountEth, _amountUsdc, _amountOsqth);
    }

    function _poke(address pool, int24 tickLower, int24 tickUpper) internal {
        
        (uint128 liquidity, , , ,) = _position(pool, tickLower,  tickUpper);
        
        if (liquidity > 0) {
            pool.burn(tickLower, tickUpper);
        }
    }

    function _position(address pool, int24 tickLower, int24 tickUpper) internal view 
    returns (
            uint128,
            uint256,
            uint256,
            uint128,
            uint128
        ) {
        bytes32 positionKey = PositionKey.compute(address(this), tickLower, tickUpper);
        return pool.positions(positionKey);
    }

    function _calcShares(uint256 _amountToDeposit) internal view returns (uint256 shares) {
        uint256 totalSupply =  totalSupply();

        (uint256 ethAmount, uint256 usdcAmount, uint256 osqthAmount) = _getTotalAmounts();

        uint256 osqthEthPrice = IOracle(oracleOSQTHETH).getTwap(
            poolOSQTHETH, 
            tokenOSQTHETH0, 
            tokenOSQTHETH1, 
            twapPeriod, 
            true);

        uint256 usdcEthPrice = IOracle(oracleETHUSDC).getTwap(
            poolETHUSDC, 
            tokenETHUSDC1, 
            tokenETHUSDC0, 
            twapPeriod, 
            true);

        if (totalSupply == 0) {
            shares = _amountToDeposit;
        } else {
            uint256 totalEth = ethAmount.add(usdcAmount.mul(usdcEthPrice)).add(osqthAmount.mul(osqthEthPrice));
            uint256 depositorShare = _amountToDeposit.div(totalEth.add(_amountToDeposit));
            shares = totalSupply.mul(depositorShare).div(uint256(1e18).sub(depositorShare));
        }
    }

    function _getTotalAmounts() internal view override returns (uint256 ethAmount, uint256 usdcAmount, uint256 osqthAmount){
        (uint256 amountETHUSDC0, uint256 amountETHUSDC1) = getPositionAmount(
            poolETHUSDC, 
            orderETHUSDCLower, 
            orderETHUSDCUpper);

        (uint256 amountOSQTHETH0, uint256 amountOSQTHETH1) = getPositionAmount(
            poolOSQTHETH, 
            orderOSQTHETHLower, 
            orderOSQTHETHUpper);

        ethAmount = amountETHUSDC0.add(amountOSQTHETH1); //check
        usdcAmount = amountETHUSDC1; //check
        osqthAmount = amountOSQTHETH0; //check
    }

    function getPositionAmount(address pool ,int24 tickLower, int24 tickUpper) public view returns (uint256 total0, uint256 total1) {
        (uint128 liquidity, , , uint128 tokensOwed0, uint128 tokensOwed1) = _position(pool, tickLower, tickUpper);
        (total0, total1) = _amountsForLiquidity(pool, tickLower, tickUpper, liquidity);
    }

    function _amountForLiquidity(
            address pool, 
            int24 tickLower, 
            int24 tickUpper, 
            uint128 liquidity
        ) 
        internal view returns (uint256, uint256) 
        {
        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
        return LiquidityAmounts.getAmountsForLiquidity(
            sqrtRatioX96, 
            TickMath.getSqrtRatioAtTick(tickLower), 
            TickMath.getSqrtRatioAtTick(tickUpper), 
            liquidity);
    }

    function _burnLiquidityShare(
            address pool, 
            int24 tickLower, 
            int24 tickUpper, 
            uint256 shares, 
            uint256 totalSupply
            ) 
        internal returns (
            uint256 amount0, 
            uint256 amount1
            ) 
        {
        (uint128 totalLiquidity, , , , ) = _position(pool, tickLower, tickUpper);
        uint256 liquidity = uint256(totalLiquidity).mul(shares).div(totalSupply);

        if (liquidity > 0) {
            (uint256 burned0, uint256 burned1, uint256 fees0, uint256 fees1) = _burnAndCollect(pool, tickLower, tickUpper, _toUint128(liquidity));

            //add share of fees
            amount0 = burned0.add(fees0.mul(shares).div(totalSupply));
            amount1 = burned1.add(fees0.mul(shares).div(totalSupply));
        }
        
    }

    function _burnAndCollect(address pool, int24 tickLower, int24 tickUpper, uint128 liquidity) internal returns (
            uint256 burned0, 
            uint256 burned1, 
            uint256 feesToVault0, 
            uint256 feesToVault1
        ) {
            if (liquidity > 0) {
                pool.burn(tickLower, tickUpper, liquidity);
            }

            (uint256 collect0, uint256 collect1) = pool.collect(address(this), tickLower, tickUpper, type(uint128).max, type(uint128).max);

            feesToVault0 = collect0.sub(burned0);
            feesToVault1 = collect1.sub(burned1);

            emit CollectFees(feesToVault0, feesToVault1);
    }

    function _isTimeRebalance() internal view returns (bool, uint256) {
        uint256 auctionTriggerTime = timeAtLastRebalance.add(rebalanceTimeThreshold);

        return (block.timestamp >= auctionTriggerTime, auctionTriggerTime);
    }

    function _isPriceRebalance() {
        
    }

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

        }  else {

            require(_amountEth >= deltaEth, "Wrong amount");
            require(_amountUsdc >= deltaUsdc, "Wrong amount");

            _executeAuction(msg.sender, deltaEth, deltaUsdc, deltaOsqth, isPriceInc);
        }

        emit Rebalance(msg.sender, _isPriceIncreased, _amountEth, _amountUsdc, _amountOsqth);
    }

    function _startAuction(uint256 _auctionTriggerTime) internal returns (bool, uint256, uint256, uint256) {

        uint256 currentEthToUsdcPrice = IOracle(oracleETHUSDC).getTwap(
            poolETHUSDC,
            weth, 
            usdc, 
            twapPeriod, 
            true
        );

        uint256 currentOsqthToEthPrice = IOracle(oracleOSQTHETH).getTwap(
            poolOSQTHETH, 
            osqth, 
            weth, 
            twapPeriod, 
            true
        );

        bool isPriceInc = _checkAuctionType(currentEthToUsdcPrice, currentOsqthToEthPrice);
        (uint256 deltaEth, uint256 deltaUsdc, uint256 deltaOsqth) = _getDeltas(
            currentEthToUsdcPrice, 
            currentOsqthToEthPrice, 
            _auctionTriggerTime, 
            isPriceInc);

        timeAtLastRebalance = block.timestamp;
        ethPriceAtLastRebalance = currentEthToUsdcPrice;

        return(isPriceInc, deltaEth, deltaUsdc, deltaOsqth);
    }
    
    function _getDeltas(
        uint256 _currentEthToUsdcPrice, 
        uint256 _currentOsqthToEthPrice, 
        uint256 _auctionTriggerTime, 
        bool _isPriceInc
        ) internal view returns(
            uint256 deltaEth, 
            uint256 deltaUsdc, 
            uint256 deltaOsqth
        ) {

        (uint256 ethAmount, uint256 usdcAmount, uint256 osqthAmount) = _getTotalAmounts();

        //add unused deposited tokens
        ethAmount = ethAmount.add(weth.balanceOf(address(this)));
        usdcAmount = usdcAmount.add(usdc.balanceOf(address(this)));
        osqthAmount = osqthAmount.add(osqth.balanceOf(address(this)));

        (uint256 auctionEthToUsdcPrice, uint256 auctionOsqthToEthPrice) = _getPriceMultiplier(_auctionTriggerTime, _currentEthToUsdcPrice, _currentOsqthToEthPrice, _isPriceInc);

        totalValue = ethAmount.mul(auctionEthToUsdcPrice).add(osqthAmount.mul(auctionOsqthToEthPrice)).add(usdcAmount);

        deltaEth = targetEthShare.div(1e18).mul(totalValue.div(auctionEthToUsdcPrice)).sub(ethAmount);
        deltaUsdc = targetUsdcShare.div(1e18).mul(totalValue).sub(usdcAmount);
        deltaOsqth = targetOsqthShare.div(1e18).mul(totalValue.div(auctionOsqthToEthPrice.mul(auctionEthToUsdcPrice))).sub(osqthAmount);
    }

    function _getPriceMultiplier(
        uint256 _auctionTriggerTime, 
        uint256 _currentEthToUsdcPrice, 
        uint256 _currentOsqthToEthPrice, 
        bool _isPriceInc
        ) internal returns (
            uint256 auctionEthToUsdcPrice, 
            uint256 auctionOsqthToEthPrice
        ) {
            uint256 auctionCompletionRatio = block.timestamp.sub(_auctionTriggerTime) >= auctionTime
            ? 1e18
            : (block.timestamp.sub(_auctionTriggerTime)).div(auctionTime);

            uint256 priceMultiplier;

            if (_isPriceInc) {
                priceMultiplier = maxPriceMultiplier.sub(auctionCompletionRatio.wmul(maxPriceMultiplier.sub(minPriceMultiplier)));
            } else {
                priceMultiplier = minPriceMultiplier.add(auctionCompletionRatio.wmul(maxPriceMultiplier.sub(minPriceMultiplier)));
            }
            auctionEthToUsdcPrice = priceMultiplier.mul(_currentEthToUsdcPrice);
            auctionOsqthToEthPrice = priceMultiplier.mul(_currentOsqthToEthPrice);
        }

    function _executeAuction(
        address keeper, 
        uint256 _deltaEth, 
        uint256 _deltaUsdc, 
        uint256 _deltaOsqth, 
        bool _isPriceInc
        ) internal {
            
        (uint128 liquidityEthUsdc, , , , ) = _position(poolETHUSDC, orderETHUSDCLower, orderETHUSDCUpper);
        (uint128 liquidityOsqthEth, , , , ) = _position(poolOSQTHETH, orderOSQTHETHLower, orderOSQTHETHUpper);
        
        _burnAndCollect(poolETHUSDC, orderETHUSDCLower, orderETHUSDCUpper, liquidityEthUsdc);
        _burnAndCollect(poolOSQTHETH, orderOSQTHETHLower, orderOSQTHETHUpper, liquidityOsqthEth);

        if (_isPriceInc) {
        //pull in tokens from sender
        osqth.safeTrasferFrom(keeper, address(this), _deltaOsqth);

        //send excess tokens to sender
        eth.safeTrasfer(keeper, _deltaEth);
        usdc.safeTrasfer(keeper, _deltaUsdc);

        } else {
            usdc.safeTrasferFrom(keeper, address(this), _deltaUsdc);

            eth.safeTrasfer(keeper, _deltaEth);
            osqth.safeTrasfer(keeper, deltaOsqth);
        }

        (int24 _ethUsdcLower, int24 _ethUsdcUpper, int24 _osqthEthLower, int24 _osqthEthUpper) = _getBoundaries();

        uint128 liquidityEthUsdc = _liquidityForAmounts(
            poolETHUSDC,
            _ethUsdcLower, 
            _ethUsdcUpper, 
            balanceOf(weth).mul(targetUsdcShare.div(2)), 
            balanceOf(usdc));

        uint128 liquidityOsqthEth = _liquidityForAmounts(
            poolOSQTHETH,
            _osqthEthLower,
            _osqthEthUpper,
            balanceOf(weth),
            balanceOf(osqth)
        );

        _mintLiquidity(poolETHUSDC, ethUsdcLower, ethUsdcUpper, liquidityEthUsdc);
        _mintLiquidity(poolOSQTHETH, osqthEthLower, osqthEthUpper, liquidityOsqthEth);

        (orderETHUSDCLower, orderETHUSDCUpper, orderOSQTHETHLower, orderOSQTHETHUpper) = (ethUsdcLower, ethUsdcUpper, osqthEthLower, osqthEthUpper);
    }

    function _getBoundaries() internal view returns (int24 ethUsdcLower, int24 ethUsdcUpper, int24 osqthEthLower, int24 osqthEthUpper) {

        int24 tickEthUsdc = getTick(poolETHUSDC);
        int24 tickOsqthEth = getTick(poolOSQTHETH);

        int24 tickFloorEthUsdc = _floor(poolETHUSDC ,tickEthUsdc, tickSpacingEthUsdc);
        int24 tickFloorOsqthEth = _floor(poolOSQTHETH, tickOsqthEth, tickSpacingOsqthEth);

        int24 tickCeilEthUsdc = tickFloorEthUsdc + tickSpacingEthUsdc;
        int24 tickFloorOsqthEth = tickFloorOsqthEth + tickSpacingOsqthEth;

        ethUsdcLower = tickFloorEthUsdc.sub(ethUsdcThreshold);
        ethUsdcUpper = tickCeilEthUsdc.add(ethUsdcThreshold);
        osqthEthLower = tickFloorOsqthEth.sub(osqthEthThreshold);
        osqthEthUpper = tickCeilOsqthEth.add(osqthEthThreshold);

    }

    function getTick(address pool) public view returns (int24 tick) {
        (, tick, , , , , ) = pool.slot0();
    }

    function _floor(address pool, int24 tick, int24 tickSpacing) internal view returns (int24) {

        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        return compressed * tickSpacing;
    } 

    function _liquidityForAmounts(
        address pool, 
        int24 tickLower, 
        int24 tickUpper, 
        uint256 amount0, 
        uint256 amount1) 
        internal view returns (uint128) 
        {
        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
        return
            LiquidityAmounts.getLiquidityForAmounts(
                sqrtRatioX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                amount0,
                amount1
            );
    }

    function _mintLiquidity(address pool, int24 tickLower, int24 tickUpper, uint128 liquidity) internal {
        if (liquidity > 0) { 
            pool.mint(address(this), tickLower, tickUpper, liquidity, "");
        }
    }

    }