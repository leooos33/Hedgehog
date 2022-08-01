// https://docs.euler.finance/developers/integration-guide
// https://gist.github.com/abhishekvispute/b0101938489a8b8dc292e3070c27156e
// https://soliditydeveloper.com/uniswap3/

// SPDX-License-Identifier: agpl-3.0
pragma solidity =0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

import {IAuction} from "../interfaces/IAuction.sol";
import {IVaultMath} from "../interfaces/IVaultMath.sol";
import {IEulerDToken, IEulerMarkets, IExec} from "./IEuler.sol";

import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

import "hardhat/console.sol";

contract Rebalancer is Ownable {
    using SafeMath for uint256;

    address public addressAuction = 0x9Fcca440F19c62CDF7f973eB6DDF218B15d4C71D;
    address public addressMath = 0x01E21d7B8c39dc4C764c19b308Bd8b14B1ba139E;

    // univ3
    ISwapRouter constant swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    // euler
    address constant exec = 0x59828FdF7ee634AaaD3f58B19fDBa3b03E2D9d80;
    address constant euler = 0x27182842E098f60e3D576794A5bFFb0777E025d3;
    IEulerMarkets constant markets = IEulerMarkets(0x3520d5a913427E6F0D6A83E07ccD4A4da316e4d3);

    // erc20 tokens
    address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant osqth = 0xf1B99e3E573A1a9C5E6B2Ce818b617F0E664E86B;

    struct FlCallbackData {
        uint256 type_of_arbitrage;
        uint256 amount1;
        uint256 amount2;
        uint256 threshold;
    }

    constructor() Ownable() {
        TransferHelper.safeApprove(osqth, address(swapRouter), type(uint256).max);
        TransferHelper.safeApprove(weth, address(swapRouter), type(uint256).max);
        TransferHelper.safeApprove(usdc, address(swapRouter), type(uint256).max);
        IERC20(usdc).approve(addressAuction, type(uint256).max);
        IERC20(osqth).approve(addressAuction, type(uint256).max);
        IERC20(weth).approve(addressAuction, type(uint256).max);
        IERC20(usdc).approve(euler, type(uint256).max);
        IERC20(osqth).approve(euler, type(uint256).max);
        IERC20(weth).approve(euler, type(uint256).max);
    }

    function setContracts(address _addressAuction, address _addressMath) external onlyOwner {
        addressAuction = _addressAuction;
        addressMath = _addressMath;
    }

    function collectProtocol(
        uint256 amountEth,
        uint256 amountUsdc,
        uint256 amountOsqth,
        address to
    ) external onlyOwner {
        if (amountEth > 0) IERC20(weth).transfer(to, amountEth);
        if (amountUsdc > 0) IERC20(usdc).transfer(to, amountUsdc);
        if (amountOsqth > 0) IERC20(osqth).transfer(to, amountOsqth);
    }

    //uint256 threshold
    function rebalance(uint256 threshold) public onlyOwner {
        (bool isTimeRebalance, uint256 auctionTriggerTime) = IVaultMath(addressMath).isTimeRebalance();

        require(isTimeRebalance, "Not time");

        (
            uint256 targetEth,
            uint256 targetUsdc,
            uint256 targetOsqth,
            uint256 ethBalance,
            uint256 usdcBalance,
            uint256 osqthBalance
        ) = IAuction(addressAuction).getAuctionParams(auctionTriggerTime);

        // console.log("targetEth %s", targetEth);
        // console.log("targetUsdc %s", targetUsdc);
        // console.log("targetOsqth %s", targetOsqth);
        // console.log("ethBalance %s", ethBalance);
        // console.log("usdcBalance %s", usdcBalance);
        // console.log("osqthBalance %s", osqthBalance);

        FlCallbackData memory data;
        data.threshold = threshold;

        if (targetEth > ethBalance && targetUsdc > usdcBalance && targetOsqth < osqthBalance) {
            // 1) borrow weth & usdc
            // 2) get osqth
            // 3) sellv3 osqth
            // 4) return eth & usdc

            data.type_of_arbitrage = 1;
            data.amount1 = targetEth - ethBalance + 10;
            data.amount2 = targetUsdc - usdcBalance + 10;

            // console.log("branch: 1");
            // console.log("borrow weth %s", data.amount1);
            // console.log("borrow usdc %s", data.amount2);
            IExec(exec).deferLiquidityCheck(address(this), abi.encode(data));
        } else if (targetEth < ethBalance && targetUsdc < usdcBalance && targetOsqth > osqthBalance) {
            // 1) borrow osqth
            // 2) get usdc & weth
            // 3) sellv3 usdc & weth
            // 4) return osqth

            data.type_of_arbitrage = 2;
            data.amount1 = targetOsqth - osqthBalance + 10;

            // console.log("branch: 2");
            // console.log("borrow osqth %s", data.amount1);
            IExec(exec).deferLiquidityCheck(address(this), abi.encode(data));
        } else if (targetEth < ethBalance && targetUsdc > usdcBalance && targetOsqth > osqthBalance) {
            // 1) borrow usdc & osqth
            // 2) get weth
            // 3) sellv3 weth
            // 4) return usdc & osqth

            data.type_of_arbitrage = 3;
            data.amount1 = targetUsdc - usdcBalance + 10;
            data.amount2 = targetOsqth - osqthBalance + 10;

            // console.log("branch: 3");
            // console.log("borrow usdc %s", data.amount1);
            // console.log("borrow osqth %s", data.amount2);
            IExec(exec).deferLiquidityCheck(address(this), abi.encode(data));
        } else if (targetEth > ethBalance && targetUsdc < usdcBalance && targetOsqth < osqthBalance) {
            // 1) borrow weth
            // 2) get usdc & osqth
            // 3) sellv3 usdc & osqth
            // 4) return weth

            data.type_of_arbitrage = 4;
            data.amount1 = targetEth - ethBalance + 10;

            // console.log("branch: 4");
            // console.log("borrow weth %s", data.amount1);
            IExec(exec).deferLiquidityCheck(address(this), abi.encode(data));
        } else if (targetEth > ethBalance && targetUsdc < usdcBalance && targetOsqth > osqthBalance) {
            // 1) borrow weth & osqth
            // 2) get usdc
            // 3) sellv3 usdc
            // 4) return osqth & weth

            data.type_of_arbitrage = 5;
            data.amount1 = targetEth - ethBalance + 10;
            data.amount2 = targetOsqth - osqthBalance + 10;

            // console.log("branch: 5");
            // console.log("borrow weth %s", data.amount1);
            // console.log("borrow osqth %s", data.amount2);
            IExec(exec).deferLiquidityCheck(address(this), abi.encode(data));
        } else if (targetEth < ethBalance && targetUsdc > usdcBalance && targetOsqth < osqthBalance) {
            // 1) borrow usdc
            // 2) get osqth & weth
            // 3) sellv3 osqth & weth
            // 4) return usdc

            data.type_of_arbitrage = 6;
            data.amount1 = targetUsdc - usdcBalance + 10;

            // console.log("branch: 6");
            // console.log("borrow usdc %s", data.amount1);
            IExec(exec).deferLiquidityCheck(address(this), abi.encode(data));
        } else {
            revert("NO arbitage");
        }
    }

    function onDeferredLiquidityCheck(bytes memory encodedData) external {
        require(msg.sender == euler, "e/flash-loan/on-deferred-caller");
        FlCallbackData memory data = abi.decode(encodedData, (FlCallbackData));

        uint256 ethBefore = IERC20(weth).balanceOf(address(this));

        if (data.type_of_arbitrage == 1) {
            IEulerDToken borrowedDToken1 = IEulerDToken(markets.underlyingToDToken(weth));
            borrowedDToken1.borrow(0, data.amount1);
            IEulerDToken borrowedDToken2 = IEulerDToken(markets.underlyingToDToken(usdc));
            borrowedDToken2.borrow(0, data.amount2);

            IAuction(addressAuction).timeRebalance(address(this), 0, 0, 0);

            // console.log(">> balance weth after timeRebalance: %s", IERC20(weth).balanceOf(address(this)));
            // console.log(">> balance usdc after timeRebalance: %s", IERC20(usdc).balanceOf(address(this)));
            // console.log(">> balance osqth after timeRebalance: %s", IERC20(osqth).balanceOf(address(this)));

            uint256 osqthAfter = IERC20(osqth).balanceOf(address(this));

            // buy weth with osqth
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

            // console.log(">> balance weth afer 1 swap swap: %s", IERC20(weth).balanceOf(address(this)));
            // console.log(">> balance usdc afer 1 swap swap: %s", IERC20(usdc).balanceOf(address(this)));
            // console.log(">> balance osqth afer 1 swap swap: %s", IERC20(osqth).balanceOf(address(this)));

            // buy usdc with weth
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

            // console.log(">> balance weth afer 2 swap swap: %s", IERC20(weth).balanceOf(address(this)));
            // console.log(">> balance usdc afer 2 swap swap: %s", IERC20(usdc).balanceOf(address(this)));
            // console.log(">> balance osqth afer 2 swap swap: %s", IERC20(osqth).balanceOf(address(this)));

            borrowedDToken1.repay(0, data.amount1);
            borrowedDToken2.repay(0, data.amount2);
        } else if (data.type_of_arbitrage == 2) {
            IEulerDToken borrowedDToken1 = IEulerDToken(markets.underlyingToDToken(osqth));
            borrowedDToken1.borrow(0, data.amount1);

            IAuction(addressAuction).timeRebalance(address(this), 0, 0, 0);

            // console.log(">> balance weth after timeRebalance: %s", IERC20(weth).balanceOf(address(this)));
            // console.log(">> balance usdc after timeRebalance: %s", IERC20(usdc).balanceOf(address(this)));
            // console.log(">> balance osqth after timeRebalance: %s", IERC20(osqth).balanceOf(address(this)));

            uint256 usdcAfter = IERC20(usdc).balanceOf(address(this));

            // buy weth with usdc
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

            // console.log(">> balance weth afer 1 swap swap: %s", IERC20(weth).balanceOf(address(this)));
            // console.log(">> balance usdc afer 1 swap swap: %s", IERC20(usdc).balanceOf(address(this)));
            // console.log(">> balance osqth afer 1 swap swap: %s", IERC20(osqth).balanceOf(address(this)));

            uint256 wethAll = IERC20(weth).balanceOf(address(this));

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

            // console.log(">> balance weth afer 2 swap swap: %s", IERC20(weth).balanceOf(address(this)));
            // console.log(">> balance usdc afer 2 swap swap: %s", IERC20(usdc).balanceOf(address(this)));
            // console.log(">> balance osqth afer 2 swap swap: %s", IERC20(osqth).balanceOf(address(this)));

            borrowedDToken1.repay(0, data.amount1);
        } else if (data.type_of_arbitrage == 3) {
            IEulerDToken borrowedDToken1 = IEulerDToken(markets.underlyingToDToken(usdc));
            borrowedDToken1.borrow(0, data.amount1);
            IEulerDToken borrowedDToken2 = IEulerDToken(markets.underlyingToDToken(osqth));
            borrowedDToken2.borrow(0, data.amount2);

            IAuction(addressAuction).timeRebalance(address(this), 0, 0, 0);

            // console.log(">> balance weth after timeRebalance: %s", IERC20(weth).balanceOf(address(this)));
            // console.log(">> balance usdc after timeRebalance: %s", IERC20(usdc).balanceOf(address(this)));
            // console.log(">> balance osqth after timeRebalance: %s", IERC20(osqth).balanceOf(address(this)));

            uint256 wethAfter = IERC20(weth).balanceOf(address(this));

            // buy osqth with weth
            ISwapRouter.ExactOutputSingleParams memory params1 = ISwapRouter.ExactOutputSingleParams({
                tokenIn: address(weth),
                tokenOut: address(osqth),
                fee: 3000,
                recipient: address(this),
                deadline: block.timestamp,
                amountOut: data.amount2,
                amountInMaximum: wethAfter,
                sqrtPriceLimitX96: 0
            });
            swapRouter.exactOutputSingle(params1);

            uint256 wethAfter2 = IERC20(weth).balanceOf(address(this));

            // console.log(">> balance weth afer 1 swap swap: %s", IERC20(weth).balanceOf(address(this)));
            // console.log(">> balance usdc afer 1 swap swap: %s", IERC20(usdc).balanceOf(address(this)));
            // console.log(">> balance osqth afer 1 swap swap: %s", IERC20(osqth).balanceOf(address(this)));

            // buy usdc with weth
            ISwapRouter.ExactOutputSingleParams memory params2 = ISwapRouter.ExactOutputSingleParams({
                tokenIn: address(weth),
                tokenOut: address(usdc),
                fee: 500,
                recipient: address(this),
                deadline: block.timestamp,
                amountOut: data.amount1,
                amountInMaximum: wethAfter2,
                sqrtPriceLimitX96: 0
            });
            swapRouter.exactOutputSingle(params2);

            // console.log(">> balance weth afer 2 swap swap: %s", IERC20(weth).balanceOf(address(this)));
            // console.log(">> balance usdc afer 2 swap swap: %s", IERC20(usdc).balanceOf(address(this)));
            // console.log(">> balance osqth afer 2 swap swap: %s", IERC20(osqth).balanceOf(address(this)));

            borrowedDToken1.repay(0, data.amount1);
            borrowedDToken2.repay(0, data.amount2);
        } else if (data.type_of_arbitrage == 4) {
            IEulerDToken borrowedDToken1 = IEulerDToken(markets.underlyingToDToken(weth));
            borrowedDToken1.borrow(0, data.amount1);

            IAuction(addressAuction).timeRebalance(address(this), 0, 0, 0);

            // console.log(">> balance weth after timeRebalance: %s", IERC20(weth).balanceOf(address(this)));
            // console.log(">> balance usdc after timeRebalance: %s", IERC20(usdc).balanceOf(address(this)));
            // console.log(">> balance osqth after timeRebalance: %s", IERC20(osqth).balanceOf(address(this)));

            uint256 osqthAfter = IERC20(osqth).balanceOf(address(this));
            uint256 usdcAfter = IERC20(usdc).balanceOf(address(this));

            // buy weth with osqth
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

            // console.log(">> balance weth afer 1 swap swap: %s", IERC20(weth).balanceOf(address(this)));
            // console.log(">> balance usdc afer 1 swap swap: %s", IERC20(usdc).balanceOf(address(this)));
            // console.log(">> balance osqth afer 1 swap swap: %s", IERC20(osqth).balanceOf(address(this)));

            // buy weth with usdc
            ISwapRouter.ExactInputSingleParams memory params2 = ISwapRouter.ExactInputSingleParams({
                tokenIn: address(usdc),
                tokenOut: address(weth),
                fee: 500,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: usdcAfter,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
            swapRouter.exactInputSingle(params2);

            // console.log(">> balance weth afer 2 swap swap: %s", IERC20(weth).balanceOf(address(this)));
            // console.log(">> balance usdc afer 2 swap swap: %s", IERC20(usdc).balanceOf(address(this)));
            // console.log(">> balance osqth afer 2 swap swap: %s", IERC20(osqth).balanceOf(address(this)));

            borrowedDToken1.repay(0, data.amount1);
        } else if (data.type_of_arbitrage == 5) {
            IEulerDToken borrowedDToken1 = IEulerDToken(markets.underlyingToDToken(weth));
            borrowedDToken1.borrow(0, data.amount1);
            IEulerDToken borrowedDToken2 = IEulerDToken(markets.underlyingToDToken(osqth));
            borrowedDToken2.borrow(0, data.amount2);

            IAuction(addressAuction).timeRebalance(address(this), 0, 0, 0);

            // console.log(">> balance weth after timeRebalance: %s", IERC20(weth).balanceOf(address(this)));
            // console.log(">> balance usdc after timeRebalance: %s", IERC20(usdc).balanceOf(address(this)));
            // console.log(">> balance osqth after timeRebalance: %s", IERC20(osqth).balanceOf(address(this)));

            uint256 usdcAfter = IERC20(usdc).balanceOf(address(this));

            // buy weth with usdc
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

            // console.log(">> balance weth afer 1 swap swap: %s", IERC20(weth).balanceOf(address(this)));
            // console.log(">> balance usdc afer 1 swap swap: %s", IERC20(usdc).balanceOf(address(this)));
            // console.log(">> balance osqth afer 1 swap swap: %s", IERC20(osqth).balanceOf(address(this)));

            // buy weth with osqth
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

            // console.log(">> balance weth afer 2 swap swap: %s", IERC20(weth).balanceOf(address(this)));
            // console.log(">> balance usdc afer 2 swap swap: %s", IERC20(usdc).balanceOf(address(this)));
            // console.log(">> balance osqth afer 2 swap swap: %s", IERC20(osqth).balanceOf(address(this)));

            borrowedDToken1.repay(0, data.amount1);
            borrowedDToken2.repay(0, data.amount2);
        } else if (data.type_of_arbitrage == 6) {
            IEulerDToken borrowedDToken1 = IEulerDToken(markets.underlyingToDToken(usdc));
            borrowedDToken1.borrow(0, data.amount1);

            IAuction(addressAuction).timeRebalance(address(this), 0, 0, 0);

            // console.log(">> balance weth after timeRebalance: %s", IERC20(weth).balanceOf(address(this)));
            // console.log(">> balance usdc after timeRebalance: %s", IERC20(usdc).balanceOf(address(this)));
            // console.log(">> balance osqth after timeRebalance: %s", IERC20(osqth).balanceOf(address(this)));

            uint256 osqthAfter = IERC20(osqth).balanceOf(address(this));

            // buy weth with osqth
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

            // console.log(">> balance weth afer 1 swap swap: %s", IERC20(weth).balanceOf(address(this)));
            // console.log(">> balance usdc afer 1 swap swap: %s", IERC20(usdc).balanceOf(address(this)));
            // console.log(">> balance osqth afer 1 swap swap: %s", IERC20(osqth).balanceOf(address(this)));

            uint256 wethAll = IERC20(weth).balanceOf(address(this));

            // buy usdc with weth
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

            // console.log(">> balance weth afer 2 swap swap: %s", IERC20(weth).balanceOf(address(this)));
            // console.log(">> balance usdc afer 2 swap swap: %s", IERC20(usdc).balanceOf(address(this)));
            // console.log(">> balance osqth afer 2 swap swap: %s", IERC20(osqth).balanceOf(address(this)));

            borrowedDToken1.repay(0, data.amount1);
        }

        // console.log(">> profit ETH %s", IERC20(weth).balanceOf(address(this)));
        // console.log(">> profit USDC %s", IERC20(usdc).balanceOf(address(this)));
        // console.log(">> profit oSQTH %s", IERC20(osqth).balanceOf(address(this)));
        require(IERC20(weth).balanceOf(address(this)).sub(ethBefore) > data.threshold, "NEP");
        revert("Success");
    }
}
