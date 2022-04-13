// SPDX-License-Identifier: Unlicense

pragma solidity =0.7.6;

interface IVault {
    function deposit(
        uint256,
        uint256,
        uint256,
        address,
        uint256,
        uint256,
        uint256
    ) external returns (uint256);

    function withdraw(
        uint256,
        uint256,
        uint256,
        uint256
    ) external;
}

interface IAuction {
    function timeRebalance(
        uint256,
        uint256,
        uint256
    ) external;

    // function getTotalAmounts() external view returns (uint256, uint256);
}
