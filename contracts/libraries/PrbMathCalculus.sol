// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;
pragma abicoder v2;

import {PRBMathUD60x18} from "@prb/math/contracts/PRBMathUD60x18.sol";

import "hardhat/console.sol";

contract PrbMathCalculus {
    using PRBMathUD60x18 for uint256;

    function getTicks(uint256 aEthUsdcPrice, uint256 aOsqthEthPrice) public view returns (uint160, uint160) {
        console.log("getTicks %s", aOsqthEthPrice);
        return (
            _toUint160(
                //sqrt(price)*2**96
                ((aEthUsdcPrice.div(1e18)).sqrt()).mul(79228162514264337593543950336)
            ),
            _toUint160(((uint256(1e18).div(aOsqthEthPrice)).sqrt()).mul(79228162514264337593543950336))
        );
    }

    function getLiquidityForValue(
        uint256 v,
        uint256 p,
        uint256 pL,
        uint256 pH
    ) public pure returns (uint128) {
        return _toUint128(v.div((p.sqrt()).mul(2e18) - pL.sqrt() - p.div(pH.sqrt())).mul(1e9));
    }

    function getPriceFromTick(uint160 sqrtRatioAtTick) public pure returns (uint256) {
        //const = 2^192
        uint256 const = 6277101735386680763835789423207666416102355444464034512896;

        return (uint256(sqrtRatioAtTick)).pow(uint256(2e18)).mul(1e36).div(const);
    }

    //@dev <tested>
    /// @dev Rounds tick down towards negative infinity so that it's a multiple
    /// of `tickSpacing`.
    function _floor(int24 tick, int24 tickSpacing) public pure returns (int24) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        return compressed * tickSpacing;
    }

    /// @dev Casts uint256 to uint160 with overflow check.
    function _toUint160(uint256 x) internal pure returns (uint160) {
        assert(x <= type(uint160).max);
        return uint160(x);
    }

    /// @dev Casts uint256 to uint128 with overflow check.
    function _toUint128(uint256 x) internal pure returns (uint128) {
        assert(x <= type(uint128).max);
        return uint128(x);
    }
}
