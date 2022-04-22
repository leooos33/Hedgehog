// SPDX-License-Identifier: Unlicense
pragma solidity =0.8.4;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IOracle} from "../interfaces/IOracle.sol";
import {IUniswapAdaptor} from "../interfaces/IUniswapAdaptor.sol";

library Constants {
    //@dev ETH-USDC Uniswap pool
    address public constant poolEthUsdc = 0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8;

    //@dev oSQTH-ETH Uniswap pool
    address public constant poolEthOsqth = 0x82c427AdFDf2d245Ec51D8046b41c4ee87F0d29C;

    //@dev wETH, USDC and oSQTH tokens
    IERC20 public constant weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 public constant usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 public constant osqth = IERC20(0xf1B99e3E573A1a9C5E6B2Ce818b617F0E664E86B);

    //@dev strategy Uniswap oracle
    IOracle public constant oracle = IOracle(0x65D66c76447ccB45dAf1e8044e918fA786A483A1);

    //TODO: change this before maiinet deploy
    IUniswapAdaptor public constant uniswapAdaptor = IUniswapAdaptor(0x870526b7973b56163a6997bB7C886F5E4EA53638);

    struct SharesInfo {
        uint256 totalSupply;
        uint256 _amountEth;
        uint256 _amountUsdc;
        uint256 _amountOsqth;
        uint256 osqthEthPrice;
        uint256 ethUsdcPrice;
        uint256 usdcAmount;
        uint256 ethAmount;
        uint256 osqthAmount;
    }

    struct Boundaries {
        int24 ethUsdcLower;
        int24 ethUsdcUpper;
        int24 osqthEthLower;
        int24 osqthEthUpper;
    }

    struct AuctionParams {
        bool isPriceInc;
        uint256 deltaEth;
        uint256 deltaUsdc;
        uint256 deltaOsqth;
        Boundaries boundaries;
        uint128 liquidityEthUsdc;
        uint128 liquidityOsqthEth;
    }
}
