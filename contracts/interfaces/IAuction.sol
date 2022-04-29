// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;

interface IAuction {
    function timeRebalance(
        address,
        uint256,
        uint256,
        uint256
    ) external;

    function priceRebalance(
        address keeper,
        uint256 _auctionTriggerTime,
        uint256 _amountEth,
        uint256 _amountUsdc,
        uint256 _amountOsqth
    ) external;
}
