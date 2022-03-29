// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

interface IVault {
    function deposit(uint256, address) external returns (uint256);

    function withdraw(
        uint256,
        uint256,
        uint256,
        address
    ) external returns (uint256, uint256);

    function timeRebalance(
        bool,
        uint256,
        uint256,
        uint256
    ) external;

    function getTotalAmounts() external view returns (uint256, uint256);
}
