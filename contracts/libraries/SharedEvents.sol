// SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.6;

library SharedEvents {
    event Deposit(address indexed sender, uint256 shares);

    event TimeRebalance(
        address indexed hedger,
        bool auctionType,
        uint256 auctionTriggerTime,
        uint256 amountEth,
        uint256 amountUsdc,
        uint256 amountOsqth
    );

    event PriceRebalance(
        address indexed hedger,
        bool auctionType,
        uint256 amountEth,
        uint256 amountUsdc,
        uint256 amountOsqth
    );

    event Withdraw(address indexed hedger, uint256 shares, uint256 amountEth, uint256 amountUsdc, uint256 amountOsqth);

    event Rebalance(
        address indexed hedger,
        bool isPriceIncreased,
        uint256 amountEth,
        uint256 amountUsdc,
        uint256 amountOsqth
    );
}
