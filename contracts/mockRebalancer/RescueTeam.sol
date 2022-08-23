// SPDX-License-Identifier: agpl-3.0
pragma solidity =0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

import {IAuction} from "../interfaces/IAuction.sol";

interface IVaultStorage {
    function setPause(bool _pause) external;

    function setGovernance(address _governance) external;

    function setRebalanceTimeThreshold(uint256 _rebalanceTimeThreshold) external;

    function setAuctionTime(uint256 _auctionTime) external;
}

interface IBig {
    function rebalance(uint256 threshold) external;

    function transferOwnership(address newOwner) external;
}

contract RescueTeam is Ownable {
    using SafeMath for uint256;

    address public addressAuction = 0x399dD7Fd6EF179Af39b67cE38821107d36678b5D;
    address public addressStorage = 0x0973b2d95236964E59a9cE95aCE22b07FA87c26A;
    address public addressBig = 0x412AfCc7A3Ee9589bdC883cB8F2dEe7E41CF0b14;

    address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant osqth = 0xf1B99e3E573A1a9C5E6B2Ce818b617F0E664E86B;

    constructor() Ownable() {
        IERC20(usdc).approve(addressAuction, type(uint256).max);
        IERC20(osqth).approve(addressAuction, type(uint256).max);
        IERC20(weth).approve(addressAuction, type(uint256).max);
        IERC20(usdc).approve(addressBig, type(uint256).max);
        IERC20(osqth).approve(addressBig, type(uint256).max);
        IERC20(weth).approve(addressBig, type(uint256).max);
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

    function rebalance() external onlyOwner {
        IVaultStorage(addressStorage).setPause(false);
        IBig(addressBig).rebalance(0);
        IVaultStorage(addressStorage).setPause(true);
    }

    function timeRebalance() external onlyOwner {
        IVaultStorage(addressStorage).setPause(false);
        IAuction(addressAuction).timeRebalance(address(this), 0, 0, 0);
        IVaultStorage(addressStorage).setPause(true);
    }

    function returnGovernance() external onlyOwner {
        IVaultStorage(addressStorage).setGovernance(msg.sender);
        IBig(addressBig).transferOwnership(msg.sender);
    }

    function stepTwo() external onlyOwner {
        IVaultStorage(addressStorage).setAuctionTime(1);
        IVaultStorage(addressStorage).setRebalanceTimeThreshold(1);
    }
}
