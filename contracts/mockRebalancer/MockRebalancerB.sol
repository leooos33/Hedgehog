// https://docs.euler.finance/developers/integration-guide
// https://gist.github.com/abhishekvispute/b0101938489a8b8dc292e3070c27156e
// https://soliditydeveloper.com/uniswap3/

// SPDX-License-Identifier: agpl-3.0
pragma solidity =0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

import {IAuction} from "../interfaces/IAuction.sol";
import {IVaultMath} from "../interfaces/IVaultMath.sol";
import {IEulerDToken, IEulerMarkets, IExec} from "./FLStuff.sol";

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

import "hardhat/console.sol";

interface IUniswapRouter is ISwapRouter {
    function refundETH() external payable;
}

contract MockRebalancerB is Ownable {
    using SafeERC20 for ERC20;
    using SafeMath for uint256;

    address public constant _addressAuction = 0x9Fcca440F19c62CDF7f973eB6DDF218B15d4C71D;
    IAuction public constant vaultAuction = IAuction(_addressAuction);
    IVaultMath public constant vaultMath = IVaultMath(0x01E21d7B8c39dc4C764c19b308Bd8b14B1ba139E);

    ISwapRouter immutable swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    address exec = 0x59828FdF7ee634AaaD3f58B19fDBa3b03E2D9d80;
    address euler = 0x27182842E098f60e3D576794A5bFFb0777E025d3;
    address eulerMarket = 0x3520d5a913427E6F0D6A83E07ccD4A4da316e4d3;
    IEulerMarkets markets = IEulerMarkets(eulerMarket);

    address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address osqth = 0xf1B99e3E573A1a9C5E6B2Ce818b617F0E664E86B;

    struct MyCallbackData {
        uint256 type_of_arbitrage;
        uint256 amount1;
        uint256 amount2;
    }

    constructor() Ownable() {}

    function rebalance() public onlyOwner {
        (bool isTimeRebalance, uint256 auctionTriggerTime) = vaultMath.isTimeRebalance();
        console.log(">> isTimeRebalance: %s", isTimeRebalance);
        console.log(">> auctionTriggerTime: %s", auctionTriggerTime);

        console.log(">> balance eth start:", IERC20(weth).balanceOf(address(this)));
        console.log(">> balance usdc start:", IERC20(usdc).balanceOf(address(this)));
        console.log(">> balance osqth start:", IERC20(osqth).balanceOf(address(this)));

        (
            uint256 targetEth,
            uint256 targetUsdc,
            uint256 targetOsqth,
            uint256 ethBalance,
            uint256 usdcBalance,
            uint256 osqthBalance
        ) = vaultAuction.getAuctionParams(auctionTriggerTime);

        console.log(">> targetEth: %s", targetEth);
        console.log(">> targetUsdc: %s", targetUsdc);
        console.log(">> targetOsqth: %s", targetOsqth);
        console.log(">> ethBalance: %s", ethBalance);
        console.log(">> usdcBalance: %s", usdcBalance);
        console.log(">> osqthBalance: %s", osqthBalance);

        if (targetEth > ethBalance && targetUsdc > usdcBalance && targetOsqth < osqthBalance) {
            // 1) borrow eth & usdc
            // 2) get osq
            // 3) sellv3  osq to eth & usdc
            // 4) returnn eth & usdc
            console.log("type_of_arbitrage 1");

            MyCallbackData memory data;
            data.type_of_arbitrage = 1;
            data.amount1 = targetEth - ethBalance + 10;
            data.amount2 = targetUsdc - usdcBalance + 10;

            IExec(exec).deferLiquidityCheck(address(this), abi.encode(data));
        } else if (targetEth < ethBalance && targetUsdc < usdcBalance && targetOsqth > osqthBalance) {
            console.log("type_of_arbitrage 2");
        } else if (targetEth < ethBalance && targetUsdc > usdcBalance && targetOsqth > osqthBalance) {
            console.log("type_of_arbitrage 3");
        } else if (targetEth > ethBalance && targetUsdc < usdcBalance && targetOsqth < osqthBalance) {
            console.log("type_of_arbitrage 4");
        } else if (targetEth > ethBalance && targetUsdc < usdcBalance && targetOsqth > osqthBalance) {
            console.log("type_of_arbitrage 5");
        } else if (targetEth < ethBalance && targetUsdc > usdcBalance && targetOsqth < osqthBalance) {
            console.log("type_of_arbitrage 6");
        }
    }

    function onDeferredLiquidityCheck(bytes memory encodedData) external {
        require(msg.sender == euler, "e/flash-loan/on-deferred-caller");

        MyCallbackData memory data = abi.decode(encodedData, (MyCallbackData));
        console.log(">> data.type_of_arbitrage: %s", data.type_of_arbitrage);

        if (data.type_of_arbitrage == 1) {
            IEulerDToken borrowedDToken1 = IEulerDToken(markets.underlyingToDToken(weth));
            borrowedDToken1.borrow(0, data.amount1);
            IEulerDToken borrowedDToken2 = IEulerDToken(markets.underlyingToDToken(usdc));
            borrowedDToken2.borrow(0, data.amount2);

            IERC20(weth).approve(_addressAuction, type(uint256).max);
            IERC20(usdc).approve(_addressAuction, type(uint256).max);

            // console.log(">> balance eth before:", IERC20(weth).balanceOf(address(this)));
            // console.log(">> balance usdc before:", IERC20(usdc).balanceOf(address(this)));
            // console.log(">> balance osqth before:", IERC20(osqth).balanceOf(address(this)));

            vaultAuction.timeRebalance(address(this), 0, 0, 0);
            uint256 osqthAfter = IERC20(osqth).balanceOf(address(this));

            console.log(">> balance eth after:", IERC20(weth).balanceOf(address(this)));
            console.log(">> balance usdc after:", IERC20(usdc).balanceOf(address(this)));
            console.log(">> balance osqth after:", IERC20(osqth).balanceOf(address(this)));

            TransferHelper.safeApprove(address(osqth), address(swapRouter), type(uint256).max);

            // buy weth for osqth
            ISwapRouter.ExactOutputSingleParams memory paramsOsqthWeth = ISwapRouter.ExactOutputSingleParams({
                tokenIn: address(osqth),
                tokenOut: address(weth),
                fee: 3000,
                recipient: address(this),
                deadline: block.timestamp,
                amountOut: data.amount1,
                amountInMaximum: osqthAfter,
                sqrtPriceLimitX96: 0
            });
            uint256 outOsqthWeth = swapRouter.exactOutputSingle(paramsOsqthWeth);
            // swapRouter.refundETH();

            // console.log(">> outOsqthWeth: %s", outOsqthWeth);
            // console.log(">> data.amount1: %s", data.amount1);
            console.log(">> !");
            console.log(">> balance eth:", IERC20(weth).balanceOf(address(this)));
            console.log(">> balance usdc:", IERC20(usdc).balanceOf(address(this)));
            console.log(">> balance osqth:", IERC20(osqth).balanceOf(address(this)));

            uint256 osqthAfter2 = IERC20(osqth).balanceOf(address(this));

            uint24 poolFee = 3000;
            // buy usdc for osqth
            ISwapRouter.ExactInputParams memory paramsOsqthUsdc = ISwapRouter.ExactInputParams({
                path: abi.encodePacked(osqth, poolFee, weth, poolFee, usdc),
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: osqthAfter2,
                amountOutMinimum: 1644710
            });
            uint256 outOsqthUsdc = swapRouter.exactInput(paramsOsqthUsdc);

            // console.log(">> outOsqthUsdc: %s", outOsqthUsdc);
            // console.log(">> data.amount2: %s", data.amount2);
            console.log(">> !");
            console.log(">> balance eth:", IERC20(weth).balanceOf(address(this)));
            console.log(">> balance usdc:", IERC20(usdc).balanceOf(address(this)));
            console.log(">> balance osqth:", IERC20(osqth).balanceOf(address(this)));

            console.log(">> data.amount1: %s", data.amount1);
            console.log(">> data.amount2: %s", data.amount2);
            IERC20(weth).approve(euler, type(uint256).max);
            borrowedDToken1.repay(0, data.amount1);
            IERC20(usdc).approve(euler, type(uint256).max);
            borrowedDToken2.repay(0, data.amount2);
        } else {}
    }

    function safeTransferWithApprove(uint256 amountIn, address routerAddress) internal {
        // TransferHelper.safeTransferFrom(
        //     osqth,
        //     msg.sender,
        //     address(this),
        //     amountIn
        // );

        TransferHelper.safeApprove(osqth, routerAddress, amountIn);
    }
}
