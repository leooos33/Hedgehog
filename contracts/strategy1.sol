// SPDX-License-Identifier: Unlicense

pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import "./interfaces/IVault.sol";
import "./libraries/StrategyMath.sol";

import "./core/VaultAuction.sol";

import "hardhat/console.sol";

contract Vault is 
    IVault, 
    ReentrancyGuard, 
    IUniswapV3MintCallback, 
    ERC20 
{
    using SafeMath for uint256;

    IUniswapV3Pool public immutable poolEthUsdc;
    IUniswapV3Pool public immutable poolEthOsqth;

    address public immutable weth;
    address public immutable usdc;
    address public immutable osqth;

    address public immutable oracle;

    int24 public constant TICK_SPACING = 60;

    uint32 public constant TWAP_PERIOD = 420 seconds;

    uint256 public cap;

    int24 public orderEthUsdcLower;
    int24 public orderEthUsdcUpper;
    int24 public orderEthOsqthLower;
    int24 public orderEthOsqthUpper;

    uint256 public timeAtLastRebalance;
    // eth/usdc price at last rebalance
    uint256 public priceAtLastRebalance;

    uint256 public rebalanceTimeTreshold;
    uint256 public rebalancePriceThreshold;
    uint256 public auctionTime;
    uint256 public minPriceMultiplier;
    uint256 public maxPriceMultiplier;

    uint256 public targetEthShare;
    uint256 public targetUsdcShare;
    uint256 public targetOsqthShare;

    constructor (
        address _poolEthUsdc,
        address _poolEthOsqth,
        address _oracle,
        uint256 _cap,
        uint256 _rebalanceTimeTreshold,
        uint256 _rebalancePriceThreshold,
        uint256 _auctionTime,
        uint256 _minPriceMultiplier,
        uint256 _maxPriceMultiplier,
        uint256 _targetEthShare,
        uint256 _targetUsdcShare,
        uint256 _targetOsqthShare

    ) ERC20 ("Hedging DL", "HDL") 
    {
        poolEthUsdc = IUniswapV3Pool(_poolEthUsdc);
        poolEthOsqth = IUniswapV3Pool(_poolEthOsqth);

        weth = IERC20(IUniswapV3Pool(_poolEthOsqth).token0);
        
        osqth = IERC20(IUniswapV3Pool(_poolEthOsqth).token1);
    } 
}