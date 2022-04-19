// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

pragma abicoder v2;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

import "hardhat/console.sol";

interface IOracle {
    function getTwap(
        address _pool,
        address _base,
        address _quote,
        uint32 _period,
        bool _checkPeriod
    ) external view returns (uint256);

    function getMaxPeriod(address _pool) external view returns (uint32);

    function getTimeWeightedAverageTickSafe(address _pool, uint32 _period)
        external
        view
        returns (int24 timeWeightedAverageTick);
}

contract V3Helper {
    IERC20 public constant weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 public constant usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    address public constant poolEthUsdc = 0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8;
    IOracle public constant oracle = IOracle(0x65D66c76447ccB45dAf1e8044e918fA786A483A1);

    using SafeERC20 for ERC20;
    using SafeMath for uint256;

    uint32 twapPeriod = 420 seconds;

    ISwapRouter immutable swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    function swap(uint256 amount) public {
        // sell weth for usdc
        TransferHelper.safeApprove(address(weth), address(swapRouter), amount);
        ISwapRouter.ExactInputSingleParams memory paramsWethUSDC = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(weth),
            tokenOut: address(usdc),
            fee: 3000,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amount,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        uint256 usdcFromSwap = swapRouter.exactInputSingle(paramsWethUSDC);
        // console.log("usdcFromSwap:", usdcFromSwap);
    }

    function swapR(uint256 amount) public {
        // sell weth for usdc
        TransferHelper.safeApprove(address(usdc), address(swapRouter), amount);
        ISwapRouter.ExactInputSingleParams memory paramsWethUSDC = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(usdc),
            tokenOut: address(weth),
            fee: 3000,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amount,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        uint256 usdcFromSwap = swapRouter.exactInputSingle(paramsWethUSDC);
        // console.log("usdcFromSwap:", usdcFromSwap);
    }

    /// @dev Fetches current price in ticks from Uniswap pool.
    function getTick(address pool) public view returns (int24 tick) {
        (, tick, , , , , ) = IUniswapV3Pool(pool).slot0();
    }

    function getTwap() public view returns (uint256, int24) {
        // How much usdc I get for 1 WETH
        console.log("block.timestamp", block.timestamp);
        return (oracle.getTwap(poolEthUsdc, address(weth), address(usdc), twapPeriod, false), getTick(poolEthUsdc));
    }

    function getTwapR() public view returns (uint256, int24) {
        // How much usdc I get for 1 WETH
        console.log("block.timestamp", block.timestamp);
        return (oracle.getTwap(poolEthUsdc, address(usdc), address(weth), twapPeriod, false), getTick(poolEthUsdc));
    }
}
