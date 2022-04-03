// SPDX-License-Identifier: Unlicense

pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";

import "../../libraries/StrategyMath.sol";
import "../../libraries/Constants.sol";

import "hardhat/console.sol";

contract VaultMathOracle {
    // using SafeMath for uint256;
    using StrategyMath for uint256;

    //@dev <tested>
    function _getTwap(
        address poolEthOsqth,
        address token1,
        address token2,
        uint32 period
    ) public view returns (uint256) {
        return Constants.oracle.getTwap(poolEthOsqth, token1, token2, period, true);
    }
}
