// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;
pragma abicoder v2;

import "../libraries/Constants.sol";

interface IVaultMath {
    function _calcSharesAndAmounts(
        uint256 _amountEth,
        uint256 _amountUsdc,
        uint256 _amountOsqth,
        uint256 _totalSupply
    )
        external
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        );

    function _getWithdrawAmounts(uint256 shares, uint256 totalSupply)
        external
        returns (
            uint256,
            uint256,
            uint256
        );

    function isTimeRebalance() external returns (bool, uint256);

    function _isPriceRebalance(uint256 _auctionTriggerTime) external returns (bool);

    function _getAuctionParams(uint256 _auctionTriggerTime) external returns (Constants.AuctionParams memory);

    function _burnAndCollect(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    )
        external
        returns (
            uint256 burned0,
            uint256 burned1,
            uint256 feesToVault0,
            uint256 feesToVault1
        );

    function burnLiquidityShare(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint256 shares,
        uint256 totalSupply
    ) external returns (uint256 amount0, uint256 amount1);

    function getTotalAmounts()
        external
        returns (
            uint256,
            uint256,
            uint256
        );

    function getPrices() external returns (uint256 ethUsdcPrice, uint256 osqthEthPrice);

    function getValue(
        uint256 amountEth,
        uint256 amountUsdc,
        uint256 amountOsqth,
        uint256 ethUsdcPrice,
        uint256 osqthEthPrice
    ) external returns (uint256);
}
