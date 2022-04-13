// SPDX-License-Identifier: Unlicense

pragma solidity =0.7.6;
pragma abicoder v2;

import "../../libraries/Constants.sol";

import "hardhat/console.sol";

contract VaultMathOracle {
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
