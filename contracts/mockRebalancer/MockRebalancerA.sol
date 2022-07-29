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

contract MockRebalancerA is Ownable {
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

        (
            uint256 targetEth,
            uint256 targetUsdc,
            uint256 targetOsqth,
            uint256 ethBalance,
            uint256 usdcBalance,
            uint256 osqthBalance
        ) = vaultAuction.getAuctionParams(auctionTriggerTime);

        if (targetEth > ethBalance && targetUsdc > usdcBalance && targetOsqth < osqthBalance) {
            // 1) borrow eth & usdc
            // 2) get osqth
            // 3) sellv3 osqth to eth & usdc
            // 4) returnn eth & usdc

            MyCallbackData memory data;
            data.type_of_arbitrage = 1;
            data.amount1 = targetEth - ethBalance + 10;
            data.amount2 = targetUsdc - usdcBalance + 10;

            IExec(exec).deferLiquidityCheck(address(this), abi.encode(data));
        } else if (targetEth < ethBalance && targetUsdc < usdcBalance && targetOsqth > osqthBalance) {
            // 1) borrow osqth
            // 2) get usdc eth
            // 3) sellv3 usdc and eth to osqth
            // 4) returnn osqth
            MyCallbackData memory data;
            data.type_of_arbitrage = 2;
            data.amount1 = targetOsqth - osqthBalance + 10;

            IExec(exec).deferLiquidityCheck(address(this), abi.encode(data));
        } else if (targetEth < ethBalance && targetUsdc > usdcBalance && targetOsqth > osqthBalance) {
            console.log("type_of_arbitrage 3");
        } else if (targetEth > ethBalance && targetUsdc < usdcBalance && targetOsqth < osqthBalance) {
            console.log("type_of_arbitrage 4");
        } else if (targetEth > ethBalance && targetUsdc < usdcBalance && targetOsqth > osqthBalance) {
            // 1) borrow eth & osqth
            // 2) get usdc
            // 3) sellv3 usdc to eth and osqth
            // 4) returnn osqth & eth

            MyCallbackData memory data;
            data.type_of_arbitrage = 5;
            data.amount1 = targetEth - ethBalance + 10;
            data.amount2 = targetOsqth - osqthBalance + 10;

            IExec(exec).deferLiquidityCheck(address(this), abi.encode(data));
        } else if (targetEth < ethBalance && targetUsdc > usdcBalance && targetOsqth < osqthBalance) {
            // 1) borrow usdc
            // 2) get osqth eth
            // 3) sellv3 osqth and eth to usdc
            // 4) returnn usdc
            MyCallbackData memory data;
            data.type_of_arbitrage = 6;
            data.amount1 = targetUsdc - usdcBalance + 10;

            IExec(exec).deferLiquidityCheck(address(this), abi.encode(data));
        } else {
            revert("NOT arbitage");
        }
    }

    function onDeferredLiquidityCheck(bytes memory encodedData) external {
        require(msg.sender == euler, "e/flash-loan/on-deferred-caller");
        MyCallbackData memory data = abi.decode(encodedData, (MyCallbackData));

        if (data.type_of_arbitrage == 1) {
            IEulerDToken borrowedDToken1 = IEulerDToken(markets.underlyingToDToken(weth));
            borrowedDToken1.borrow(0, data.amount1);
            IEulerDToken borrowedDToken2 = IEulerDToken(markets.underlyingToDToken(usdc));
            borrowedDToken2.borrow(0, data.amount2);

            IERC20(weth).approve(_addressAuction, type(uint256).max);
            IERC20(usdc).approve(_addressAuction, type(uint256).max);

            vaultAuction.timeRebalance(address(this), 0, 0, 0);
            uint256 osqthAfter = IERC20(osqth).balanceOf(address(this));

            console.log(">> balance eth after call1:", IERC20(weth).balanceOf(address(this)));
            console.log(">> balance usdc after call1:", IERC20(usdc).balanceOf(address(this)));
            console.log(">> balance osqth after call1:", osqthAfter);

            TransferHelper.safeApprove(osqth, address(swapRouter), type(uint256).max);

            // buy weth for osqth
            ISwapRouter.ExactInputSingleParams memory params1 = ISwapRouter.ExactInputSingleParams({
                tokenIn: address(osqth),
                tokenOut: address(weth),
                fee: 3000,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: osqthAfter,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
            swapRouter.exactInputSingle(params1);

            console.log(">> !");
            console.log(">> balance eth after sqth->weth swap: %s", IERC20(weth).balanceOf(address(this)));
            console.log(">> balance usdc after sqth->weth swap: %s", IERC20(usdc).balanceOf(address(this)));
            console.log(">> balance osqth after sqth->weth swap %s:", IERC20(osqth).balanceOf(address(this)));

            TransferHelper.safeApprove(weth, address(swapRouter), type(uint256).max);
            // buy usdc for weth
            uint256 ethAfter2 = IERC20(weth).balanceOf(address(this));
            ISwapRouter.ExactOutputSingleParams memory params2 = ISwapRouter.ExactOutputSingleParams({
                tokenIn: address(weth),
                tokenOut: address(usdc),
                fee: 500,
                recipient: address(this),
                deadline: block.timestamp,
                amountOut: data.amount2,
                amountInMaximum: ethAfter2 - data.amount1,
                sqrtPriceLimitX96: 0
            });

            swapRouter.exactOutputSingle(params2);

            console.log(">> !");
            console.log(">> final balance eth after usdc->weth swap %s", IERC20(weth).balanceOf(address(this)));
            console.log(">> final balance usdc after usdc->weth swap %s", IERC20(usdc).balanceOf(address(this)));
            console.log(">> final balance osqth after usdc->weth swap %s", IERC20(osqth).balanceOf(address(this)));

            console.log(">> data.amount1: %s", data.amount1);
            console.log(">> data.amount2: %s", data.amount2);
            IERC20(weth).approve(euler, type(uint256).max);
            borrowedDToken1.repay(0, data.amount1);
            IERC20(usdc).approve(euler, type(uint256).max);
            borrowedDToken2.repay(0, data.amount2);

            console.log(">> profit ETH %s", IERC20(weth).balanceOf(address(this)));
            console.log(">> profit USDC %s", IERC20(usdc).balanceOf(address(this)));
            console.log(">> profit oSQTH %s", IERC20(osqth).balanceOf(address(this)));
            //revert("Success");
        } else if (data.type_of_arbitrage == 2) {
            IEulerDToken borrowedDToken1 = IEulerDToken(markets.underlyingToDToken(osqth));
            borrowedDToken1.borrow(0, data.amount1);

            IERC20(osqth).approve(_addressAuction, type(uint256).max);

            vaultAuction.timeRebalance(address(this), 0, 0, 0);

            console.log(">> !");
            console.log(">> balance eth after call2: %s", IERC20(weth).balanceOf(address(this)));
            console.log(">> balance usdc after call2: %s", IERC20(usdc).balanceOf(address(this)));
            console.log(">> balance osqth after call2: %s", IERC20(osqth).balanceOf(address(this)));

            uint256 usdcAfter = IERC20(usdc).balanceOf(address(this));

            TransferHelper.safeApprove(usdc, address(swapRouter), type(uint256).max);

            // buy weth for usdc
            ISwapRouter.ExactInputSingleParams memory params1 = ISwapRouter.ExactInputSingleParams({
                tokenIn: address(usdc),
                tokenOut: address(weth),
                fee: 500,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: usdcAfter,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
            swapRouter.exactInputSingle(params1);

            console.log(">> !");
            console.log(">> balance eth after usdc->weth swap: %s", IERC20(weth).balanceOf(address(this)));
            console.log(">> balance usdc after usdc->weth swap: %s", IERC20(usdc).balanceOf(address(this)));
            console.log(">> balance osqth after usdc->weth swap: %s", IERC20(osqth).balanceOf(address(this)));

            uint256 wethAll = IERC20(weth).balanceOf(address(this));
            TransferHelper.safeApprove(weth, address(swapRouter), type(uint256).max);

            // weth->osqth
            ISwapRouter.ExactOutputSingleParams memory params2 = ISwapRouter.ExactOutputSingleParams({
                tokenIn: address(weth),
                tokenOut: address(osqth),
                fee: 3000,
                recipient: address(this),
                deadline: block.timestamp,
                amountOut: data.amount1,
                amountInMaximum: wethAll,
                sqrtPriceLimitX96: 0
            });
            swapRouter.exactOutputSingle(params2);

            console.log(">> !");
            console.log(">> balance eth after weth->usdc swap: %s", IERC20(weth).balanceOf(address(this)));
            console.log(">> balance usdc after weth->usdc swap: %s", IERC20(usdc).balanceOf(address(this)));
            console.log(">> balance osqth after weth->usdc swap: %s", IERC20(osqth).balanceOf(address(this)));

            console.log(">> amount to repay %s", data.amount1);
            IERC20(osqth).approve(euler, type(uint256).max);
            borrowedDToken1.repay(0, data.amount1);

            console.log(">> profit ETH %s", IERC20(weth).balanceOf(address(this)));
            console.log(">> profit USDC %s", IERC20(usdc).balanceOf(address(this)));
            console.log(">> profit oSQTH %s", IERC20(osqth).balanceOf(address(this)));
            //revert("Success");
        } else if (data.type_of_arbitrage == 5) {
            IEulerDToken borrowedDToken1 = IEulerDToken(markets.underlyingToDToken(weth));
            borrowedDToken1.borrow(0, data.amount1);
            IEulerDToken borrowedDToken2 = IEulerDToken(markets.underlyingToDToken(osqth));
            borrowedDToken2.borrow(0, data.amount2);

            IERC20(weth).approve(_addressAuction, type(uint256).max);
            IERC20(osqth).approve(_addressAuction, type(uint256).max);

            vaultAuction.timeRebalance(address(this), 0, 0, 0);
            uint256 usdcAfter = IERC20(usdc).balanceOf(address(this));

            console.log(">> balance eth after call5: %s", IERC20(weth).balanceOf(address(this)));
            console.log(">> balance usdc after call5: %s", IERC20(usdc).balanceOf(address(this)));
            console.log(">> balance osqth after call5: %s", IERC20(osqth).balanceOf(address(this)));

            TransferHelper.safeApprove(usdc, address(swapRouter), type(uint256).max);

            // buy weth for usdc
            ISwapRouter.ExactInputSingleParams memory params1 = ISwapRouter.ExactInputSingleParams({
                tokenIn: address(usdc),
                tokenOut: address(weth),
                fee: 500,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: usdcAfter,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

            swapRouter.exactInputSingle(params1);
            uint256 wethAfter2 = IERC20(weth).balanceOf(address(this));

            console.log(">> !");
            console.log(">> balance eth after usdc->weth swap: %s", wethAfter2);
            console.log(">> balance usdc after usdc->weth swap: %s", IERC20(usdc).balanceOf(address(this)));
            console.log(">> balance osqth after usdc->weth swap: %s", IERC20(osqth).balanceOf(address(this)));

            // buy weth for osqth
            console.log("required sqth %s", data.amount2);
            TransferHelper.safeApprove(weth, address(swapRouter), type(uint256).max);

            ISwapRouter.ExactOutputSingleParams memory params2 = ISwapRouter.ExactOutputSingleParams({
                tokenIn: address(weth),
                tokenOut: address(osqth),
                fee: 3000,
                recipient: address(this),
                deadline: block.timestamp,
                amountOut: data.amount2,
                amountInMaximum: wethAfter2,
                sqrtPriceLimitX96: 0
            });
            swapRouter.exactOutputSingle(params2);

            console.log(">> !");
            console.log(">> balance eth after osqth->eth swap: %s", IERC20(weth).balanceOf(address(this)));
            console.log(">> balance usdc after osqth->eth swap: %s", IERC20(usdc).balanceOf(address(this)));
            console.log(">> balance osqth after osqth->eth swap: %s", IERC20(osqth).balanceOf(address(this)));

            console.log(">> data.amount1: %s", data.amount1);
            console.log(">> data.amount2: %s", data.amount2);
            IERC20(weth).approve(euler, type(uint256).max);
            borrowedDToken1.repay(0, data.amount1);
            IERC20(osqth).approve(euler, type(uint256).max);
            borrowedDToken2.repay(0, data.amount2);

            console.log(">> profit ETH %s", IERC20(weth).balanceOf(address(this)));
            console.log(">> profit USDC %s", IERC20(usdc).balanceOf(address(this)));
            console.log(">> profit oSQTH %s", IERC20(osqth).balanceOf(address(this)));
            //revert("Success");
        } else if (data.type_of_arbitrage == 6) {
            IEulerDToken borrowedDToken1 = IEulerDToken(markets.underlyingToDToken(usdc));
            borrowedDToken1.borrow(0, data.amount1);

            IERC20(usdc).approve(_addressAuction, type(uint256).max);

            vaultAuction.timeRebalance(address(this), 0, 0, 0);

            console.log(">> !");
            console.log(">> balance eth after call6: %s", IERC20(weth).balanceOf(address(this)));
            console.log(">> balance usdc after call6: %s", IERC20(usdc).balanceOf(address(this)));
            console.log(">> balance osqth after call6: %s", IERC20(osqth).balanceOf(address(this)));

            uint256 osqthAfter = IERC20(osqth).balanceOf(address(this));

            TransferHelper.safeApprove(osqth, address(swapRouter), type(uint256).max);

            // buy weth for osqthAfter
            ISwapRouter.ExactInputSingleParams memory params1 = ISwapRouter.ExactInputSingleParams({
                tokenIn: address(osqth),
                tokenOut: address(weth),
                fee: 3000,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: osqthAfter,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
            swapRouter.exactInputSingle(params1);

            console.log(">> !");
            console.log(">> balance eth afer weth->sqth swap: %s", IERC20(weth).balanceOf(address(this)));
            console.log(">> balance usdc afer weth->sqth swap: %s", IERC20(usdc).balanceOf(address(this)));
            console.log(">> balance osqth afer weth->sqth swap: %s", IERC20(osqth).balanceOf(address(this)));

            uint256 wethAll = IERC20(weth).balanceOf(address(this));
            TransferHelper.safeApprove(weth, address(swapRouter), type(uint256).max);
            // buy usdc for weth
            ISwapRouter.ExactOutputSingleParams memory params2 = ISwapRouter.ExactOutputSingleParams({
                tokenIn: address(weth),
                tokenOut: address(usdc),
                fee: 500,
                recipient: address(this),
                deadline: block.timestamp,
                amountOut: data.amount1,
                amountInMaximum: wethAll,
                sqrtPriceLimitX96: 0
            });
            swapRouter.exactOutputSingle(params2);

            console.log(">> !");
            console.log(">> balance eth afer usdc->weth swap: %s", IERC20(weth).balanceOf(address(this)));
            console.log(">> balance usdc afer usdc->weth swap: %s", IERC20(usdc).balanceOf(address(this)));
            console.log(">> balance osqth afer usdc->weth swap: %s", IERC20(osqth).balanceOf(address(this)));

            console.log(">> data.amount1: %s", data.amount1);
            IERC20(usdc).approve(euler, type(uint256).max);
            borrowedDToken1.repay(0, data.amount1);

            console.log(">> profit ETH %s", IERC20(weth).balanceOf(address(this)));
            console.log(">> profit USDC %s", IERC20(usdc).balanceOf(address(this)));
            console.log(">> profit oSQTH %s", IERC20(osqth).balanceOf(address(this)));
            //revert("Success");
        } else {}
    }
}
