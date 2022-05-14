// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;

import {Constants} from "../libraries/Constants.sol";

import "hardhat/console.sol";

interface IVaultStorage {
    function orderEthUsdcLower() external returns (int24);

    function orderEthUsdcUpper() external returns (int24);

    function orderOsqthEthLower() external returns (int24);

    function orderOsqthEthUpper() external returns (int24);

    function accruedFeesEth() external returns (uint256);

    function accruedFeesUsdc() external returns (uint256);

    function accruedFeesOsqth() external returns (uint256);

    function protocolFee() external returns (uint256);

    function timeAtLastRebalance() external returns (uint256);

    function rebalanceTimeThreshold() external returns (uint256);

    function ethPriceAtLastRebalance() external returns (uint256);

    function rebalancePriceThreshold() external returns (uint256);

    function maxPriceMultiplier() external returns (uint256);

    function minPriceMultiplier() external returns (uint256);

    function auctionTime() external returns (uint256);

    function twapPeriod() external returns (uint32);

    function maxTDOsqthEth() external returns (int24);

    function maxTDEthUsdc() external returns (int24);

    function ethUsdcThreshold() external returns (int24);

    function osqthEthThreshold() external returns (int24);

    function tickSpacingEthUsdc() external returns (int24);

    function tickSpacingOsqthEth() external returns (int24);

    function updateAccruedFees(
        uint256,
        uint256,
        uint256
    ) external;

    function setAccruedFeesEth(uint256) external;

    function setAccruedFeesUsdc(uint256) external;

    function setAccruedFeesOsqth(uint256) external;

    function cap() external returns (uint256);

    function setTotalAmountsBoundaries(
        int24 _orderEthUsdcLower,
        int24 _orderEthUsdcUpper,
        int24 _orderOsqthEthLower,
        int24 _orderOsqthEthUpper
    ) external;
}
