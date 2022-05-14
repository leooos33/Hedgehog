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

    function _pokeEthUsdc() external;

    function _pokeEthOsqth() external;

    function isTimeRebalance() external returns (bool, uint256);

    function _isPriceRebalance(uint256 _auctionTriggerTime) external returns (bool);

    function _getAuctionParams(uint256 _auctionTriggerTime) external returns (Constants.AuctionParams memory);

    function _positionLiquidityEthUsdc() external returns (uint128);

    function _positionLiquidityEthOsqth() external returns (uint128);

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
}
