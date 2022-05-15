// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;

import {Constants} from "../libraries/Constants.sol";

import "hardhat/console.sol";

interface IVaultStorage {
    function orderEthUsdcLower() external view returns (int24);

    function orderEthUsdcUpper() external view returns (int24);

    function orderOsqthEthLower() external view returns (int24);

    function orderOsqthEthUpper() external view returns (int24);

    function accruedFeesEth() external view returns (uint256);

    function accruedFeesUsdc() external view returns (uint256);

    function accruedFeesOsqth() external view returns (uint256);

    function protocolFee() external view returns (uint256);

    function timeAtLastRebalance() external view returns (uint256);

    function rebalanceTimeThreshold() external view returns (uint256);

    function ethPriceAtLastRebalance() external view returns (uint256);

    function rebalancePriceThreshold() external view returns (uint256);

    function maxPriceMultiplier() external view returns (uint256);

    function minPriceMultiplier() external view returns (uint256);

    function auctionTime() external view returns (uint256);

    function twapPeriod() external view returns (uint32);

    function maxTDOsqthEth() external view returns (int24);

    function maxTDEthUsdc() external view returns (int24);

    function ethUsdcThreshold() external view returns (int24);

    function osqthEthThreshold() external view returns (int24);

    function tickSpacingEthUsdc() external view returns (int24);

    function tickSpacingOsqthEth() external view returns (int24);

    function updateAccruedFees(
        uint256,
        uint256,
        uint256
    ) external;

    function setAccruedFeesEth(uint256) external;

    function setAccruedFeesUsdc(uint256) external;

    function setAccruedFeesOsqth(uint256) external;

    function cap() external view returns (uint256);

    function setTotalAmountsBoundaries(
        int24 _orderEthUsdcLower,
        int24 _orderEthUsdcUpper,
        int24 _orderOsqthEthLower,
        int24 _orderOsqthEthUpper
    ) external;
}
