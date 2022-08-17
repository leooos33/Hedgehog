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

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import "hardhat/console.sol";

contract Rebalancer2 is Ownable {
    using SafeMath for uint256;

    address public addressAuction = 0xA9a68eA2746793F43af0f827EC3DbBb049359067;
    address public addressMath = 0xfbcF638ea33A5F87D1e39509E7deF653958FA9C4;

    // univ3
    ISwapRouter constant swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    IUniswapV3Pool public constant poolEthUsdc = IUniswapV3Pool(0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8);
    IUniswapV3Pool public constant poolEthOsqth = IUniswapV3Pool(0x82c427AdFDf2d245Ec51D8046b41c4ee87F0d29C);

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
        IERC20(usdc).approve(addressAuction, type(uint256).max);
        IERC20(osqth).approve(addressAuction, type(uint256).max);
        IERC20(weth).approve(addressAuction, type(uint256).max);
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

        console.log("auctionTriggerTime %s", auctionTriggerTime);

        require(isTimeRebalance, "Not time");

        (
            uint256 targetEth,
            uint256 targetUsdc,
            uint256 targetOsqth,
            uint256 ethBalance,
            uint256 usdcBalance,
            uint256 osqthBalance
        ) = IAuction(addressAuction).getAuctionParams(auctionTriggerTime);

        console.log("targetEth %s", targetEth);
        console.log("targetUsdc %s", targetUsdc);
        console.log("targetOsqth %s", targetOsqth);
        console.log("ethBalance %s", ethBalance);
        console.log("usdcBalance %s", usdcBalance);
        console.log("osqthBalance %s", osqthBalance);

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

            console.log("branch: 1");
            console.log("borrow weth %s", data.amount1);
            console.log("borrow usdc %s", data.amount2);
            IExec(exec).deferLiquidityCheck(address(this), abi.encode(data));
        } else if (targetEth < ethBalance && targetUsdc < usdcBalance && targetOsqth > osqthBalance) {
            // 1) borrow osqth
            // 2) get usdc & weth
            // 3) sellv3 usdc & weth
            // 4) return osqth

            data.type_of_arbitrage = 2;
            data.amount1 = targetOsqth - osqthBalance + 10;

            console.log("branch: 2");
            console.log("borrow osqth %s", data.amount1);
            IExec(exec).deferLiquidityCheck(address(this), abi.encode(data));
        } else if (targetEth < ethBalance && targetUsdc > usdcBalance && targetOsqth > osqthBalance) {
            // 1) borrow usdc & osqth
            // 2) get weth
            // 3) sellv3 weth
            // 4) return usdc & osqth

            data.type_of_arbitrage = 3;
            data.amount1 = targetUsdc - usdcBalance + 10;
            data.amount2 = targetOsqth - osqthBalance + 10;

            console.log("branch: 3");
            console.log("borrow usdc %s", data.amount1);
            console.log("borrow osqth %s", data.amount2);
            IExec(exec).deferLiquidityCheck(address(this), abi.encode(data));
        } else if (targetEth > ethBalance && targetUsdc < usdcBalance && targetOsqth < osqthBalance) {
            // 1) borrow weth
            // 2) get usdc & osqth
            // 3) sellv3 usdc & osqth
            // 4) return weth

            data.type_of_arbitrage = 4;
            data.amount1 = targetEth - ethBalance + 10;

            console.log("branch: 4");
            console.log("borrow weth %s", data.amount1);
            IExec(exec).deferLiquidityCheck(address(this), abi.encode(data));
        } else if (targetEth > ethBalance && targetUsdc < usdcBalance && targetOsqth > osqthBalance) {
            // 1) borrow weth & osqth
            // 2) get usdc
            // 3) sellv3 usdc
            // 4) return osqth & weth

            data.type_of_arbitrage = 5;
            data.amount1 = targetEth - ethBalance + 10;
            data.amount2 = targetOsqth - osqthBalance + 10;

            console.log("branch: 5");
            console.log("borrow weth %s", data.amount1);
            console.log("borrow osqth %s", data.amount2);
            IExec(exec).deferLiquidityCheck(address(this), abi.encode(data));
        } else if (targetEth < ethBalance && targetUsdc > usdcBalance && targetOsqth < osqthBalance) {
            // 1) borrow usdc
            // 2) get osqth & weth
            // 3) sellv3 osqth & weth
            // 4) return usdc

            data.type_of_arbitrage = 6;
            data.amount1 = targetUsdc - usdcBalance + 10;

            console.log("branch: 6");
            console.log("borrow usdc %s", data.amount1);
            // IExec(exec).deferLiquidityCheck(address(this), abi.encode(data));

            poolEthUsdc.flash(address(this), data.amount1, 0, abi.encode(data));
        } else {
            revert("NO arbitage");
        }
    }

    //TODO: add msg.sender in every subtree;
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external {}
}
