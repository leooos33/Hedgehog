// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;

import {IFaucet} from "../libraries/Faucet.sol";

interface IVault is IFaucet {
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

    function collectProtocol(
        uint256 amountUsdc,
        uint256 amountEth,
        uint256 amountOsqth,
        address to
    ) external;
}
