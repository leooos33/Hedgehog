// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;
pragma abicoder v2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface IFaucet {
    function setComponents(
        address,
        address,
        address,
        address
    ) external;
}

contract Faucet is IFaucet, Ownable {
    address public uniswapMath;
    address public vault;
    address public vaultMath;
    address public vaultTreasury;

    constructor() Ownable() {}

    function setComponents(
        address _uniswapMath,
        address _vault,
        address _vaultMath,
        address _vaultTreasury
    ) public override onlyOwner {
        (uniswapMath, vault, vaultMath, vaultTreasury) = (_uniswapMath, _vault, _vaultMath, _vaultTreasury);
    }
}
