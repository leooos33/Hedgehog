// SPDX-License-Identifier: agpl-3.0
pragma solidity =0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IAuction} from "../interfaces/IAuction.sol";
import {IVault} from "../interfaces/IVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

import "hardhat/console.sol";

contract FlashDeposit is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    address public addressVault = 0x6894cf73D22B34fA2b30E5a4c706AD6c2f2b24ac;

    ISwapRouter constant swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant osqth = 0xf1B99e3E573A1a9C5E6B2Ce818b617F0E664E86B;

    constructor() Ownable() {
        TransferHelper.safeApprove(weth, address(swapRouter), type(uint256).max);
        TransferHelper.safeApprove(usdc, address(swapRouter), type(uint256).max);
        TransferHelper.safeApprove(osqth, address(swapRouter), type(uint256).max);
        IERC20(usdc).approve(addressVault, type(uint256).max);
        IERC20(osqth).approve(addressVault, type(uint256).max);
        IERC20(weth).approve(addressVault, type(uint256).max);
    }

    function setContracts(address _addressVault) external onlyOwner {
        addressVault = _addressVault;
        IERC20(usdc).approve(addressVault, type(uint256).max);
        IERC20(osqth).approve(addressVault, type(uint256).max);
        IERC20(weth).approve(addressVault, type(uint256).max);
    }

    /**
    @notice deposit tokens in proportion to the vault's holding
    @param amountEth ETH amount to deposit
    @param to receiver address
    @param amountEthMin revert if resulting amount of ETH is smaller than this
    @param amountUsdcMin revert if resulting amount of USDC is smaller than this
    @param amountOsqthMin revert if resulting amount of oSQTH is smaller than this
    @return shares minted shares
    */
    function deposit(
        uint256 amountEth,
        address to,
        uint256 amountEthMin,
        uint256 amountUsdcMin,
        uint256 amountOsqthMin
    ) external nonReentrant returns (uint256) {
        IERC20(weth).transferFrom(msg.sender, address(this), amountEth);

        (uint256 ethToDeposit, uint256 usdcToDeposit, uint256 osqthToDeposit, ) = IVault(addressVault)
            .getAmountsToDeposit(amountEth);
        console.log("ethToDeposit: %s", ethToDeposit);
        console.log("usdcToDeposit: %s", usdcToDeposit);
        console.log("osqthToDeposit: %s", osqthToDeposit);

        ISwapRouter.ExactOutputSingleParams memory params1 = ISwapRouter.ExactOutputSingleParams({
            tokenIn: address(weth),
            tokenOut: address(usdc),
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp,
            amountOut: usdcToDeposit,
            amountInMaximum: amountEth,
            sqrtPriceLimitX96: 0
        });
        swapRouter.exactOutputSingle(params1);

        ISwapRouter.ExactOutputSingleParams memory params2 = ISwapRouter.ExactOutputSingleParams({
            tokenIn: address(weth),
            tokenOut: address(osqth),
            fee: 3000,
            recipient: address(this),
            deadline: block.timestamp,
            amountOut: osqthToDeposit,
            amountInMaximum: amountEth,
            sqrtPriceLimitX96: 0
        });
        swapRouter.exactOutputSingle(params2);

        return
            IVault(addressVault).deposit(
                ethToDeposit,
                usdcToDeposit,
                osqthToDeposit,
                msg.sender,
                amountEthMin,
                amountUsdcMin,
                amountOsqthMin
            );
    }
}
