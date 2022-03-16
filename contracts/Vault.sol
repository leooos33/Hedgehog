// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import "@uniswap/v3-periphery/contracts/libraries/PositionKey.sol";

import "./interfaces/IVault.sol";
import "./interfaces/IOracle.sol";

contract Vault is 
    IVault,
    IUniswapV3MintCallback,
    IUniswapV3SwapCallback,
    ERC20,
    ReentrancyGuard
 {
     using SafeERC20 for IERC20;
     using SafeMath for uint256;

     event Deposit (
        address indexed sender,
        uint256 shares
     );

     event Withdraw (
         
     );

     event CollectFees (

     );

     event Snapshot (

     );

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
    

    uint256 public strategyFee;
    uint256 public cap;
    address public strategy;
    address public governance;

    int24 public orderEULower;
    int24 public orderEUUpper;
    int24 public orderESLower;
    int24 public orderESUpper;

    uint256 public accruedProtocolFees0;
    uint256 public accruedProtocolFees1;

    /**
     * @dev After deploying, strategy needs to be set via `setStrategy()`
     * @param _poolEU Underlying Uniswap V3 ETH-USDC pool
     * @param _poolES Underlying Uniswap V3 ETH-oSQTH pool
     * @param _protocolFee Protocol fee expressed as multiple of 1e-6
     * @param _cap Cap on total supply
     */
    constructor (
        address _poolEU,
        address _poolES,
        address _tokenToDeposit,
        uint256 _protocolFee,
        uint256 _cap,
        address _oracleEU,
        address _oracleES        
    ) ERC20 ("Hedging DL", "HDL") {
        poolEU = IUniswapV3Pool(_poolEU);
        poolES = IUniswapV3Pool(_poolES);

        tokenEU0 = IERC20(IUniswapV3Pool(_poolEU).token0());
        tokenEU1 = IERC20(IUniswapV3Pool(_poolEU).token1());
        tokenES0 = IERC20(IUniswapV3Pool(_poolES).token0());
        tokenES1 = IERC20(IUniswapV3Pool(_poolES).token1());

        tickSpacing = IUniswapV3Pool(_pool).tickSpacing();

        tokenToDeposit = _tokenToDeposit;
        protocolFee = _protocolFee;
        cap = _cap;
        tokenToDeposit = _tokenToDeposit;
        
        oracleEU = _oracleEU;
        oracleES = _oracleES;

        governance = msg.sender;
    }

    /**
     * @notice Deposits wETH and receive pool shares
     * @dev Deposited tokens sit in the vault are not used for liquidity until the next rebalance.
     * @param amountToDeposit amount of USDC to deposit
     * @return shares Number of shares minted
     */
    function deposit (uint256 amountToDeposit) external override nonReentrant returns (shares)
    {
        require(amountToDeposit > 0, "Amount to deposit should be > 0");
        
        // Poke positions so vault's current holdings are up to date
        _poke(orderEULower, orderEUUpper);
        _poke(orderESLower, orderESUpper);

        // Pull in tokens from sender
        tokenToDeposit.safeTrasferFrom(msg.sender, address(this), amountToDeposit);

        // Mint shares to recipient
        shares = _calcShares(_amountToDeposit);
        _mint(msg.sender, shares);

        require(totalSupply() <= cap, "Cap is reached");

        emit Deposit(msg.sender, shares);

    }

    /// @dev Do zero-burns to poke a position on Uniswap so earned fees are
    /// updated. Should be called if total amounts needs to include up-to-date
    /// fees.
    function _poke(int24 tickLower, int24 tickUpper) internal {
        (uint128 liquidity, , , ,) = _position(tickLower,  tickUpper);
        if (liquidity > 0) {
            pool.burn(tickLower, tickUpper);
        }
    }

    function _calcShares(uint256 _amountToDeposit) internal view returns (uint256 shares) {
        uint256 totalSupply = totalSupply();

        (uint256 totalETH, uint256 totalUSDC, uint256 totalOSQTH) = getTotalAmounts();

        // If total supply > 0, the vault can't be empty
        // assert(totalSupply == 0 || totalETH > 0 || totalUSDC > 0 || totalOSQTH > 0);

        uint256 wSqueethEthPrice = IOracle(oracleES).getTwap(
            poolES,
            wPowerPerp,
            weth,
            twapPeriod,
            true
        );

        uint256 wUsdcEthPrice = IOracle(oracleEU).getTwap(
            poolEU,
            usdc,
            weth,
            twapPeriod,
            true
        );
        
        if (totalSupply == 0){
            //Shares to mint
            shares = _amountToDeposit;
        } else {
            
            // Value of USDC token holdings in ETH
            uint256 valueUsdcEth = totalUSDC.mul(wUsdcEthPrice);
            // Value of oSQTH token holdings in ETH
            uint256 valueWSqueethEth = totalOSQTH.mul(wSqueethEthPrice);
            // Total value in ETH
            uint256 totalValue = totalETH.add(valueUsdcEth).add(valueWSqueethEth);
            // Calculate depositor share
            uint256 depositorShare = _amountToDeposit.div(totalValue.add(_amountToDeposit));
            // Shares to mint
            shares = totalSupply.mul(depositorShare).div(uint256(1e18).sub(depositorShare));
        }
    }

    function getTotalAmounts() public view override returns (uint256 totalETH, uint256 totalUSDC, uint256 totalOSQTH) {
        (uint256 amountEU0, uint256 amountEU1) = getPositionAmount(orderEULower, orderEUUpper);
        (uint256 amountES0, uint256 amountES1) = getPositionAmount(orderESLower, orderESUpper);

        totalETH = getBalanceETH().add(amountEU0).add(amountES0); //check TODO
        totalUSDC = amountEU1;
        totalOSQTH = amountES1;  
    }

    function getPositionAmount(int24 tickLower, int24 tickUpper) public view returns (uint256 total0, uint256 total1) {
        (uint128 liquidity, , , uint128 tokensOwed0, uint128 tokensOwed1) = _position(tickLower, tickUpper);
        (amount0, amount1) = _amountsForLiquidity(tickLower, tickUpper, liquidity);

        // Subtract protocol fees
        uint256 oneMinusFee = uint256(1e6).sub(protocolFee);
        amount0 = amount0.add(uint256(tokensOwed0).mul(oneMinusFee).div(1e6));
        amount1 = amount1.add(uint256(tokensOwed1).mul(oneMinusFee).div(1e6));
    }
    
    /// @dev Wrapper around `IUniswapV3Pool.positions()`.
    function _position(int24 tickLower, int24 tickUpper)
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
        return pool.positions(positionKey);
    }
    
 }

