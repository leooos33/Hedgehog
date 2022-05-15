// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;
pragma abicoder v2;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFaucet {
    function setComponents(
        address,
        address,
        address,
        address,
        address,
        address,
        address
    ) external;
}

contract Faucet is IFaucet, Ownable {
    address public uniswapMath;
    address public vault;
    address public auction;
    address public vaultMath;
    address public vaultTreasury;
    address public vaultStotage;

    constructor() Ownable() {}

    function setComponents(
        address _uniswapMath,
        address _vault,
        address _auction,
        address _vaultMath,
        address _vaultTreasury,
        address _vaultStotage,
        address _governance
    ) public override onlyOwner {
        (uniswapMath, vault, auction, vaultMath, vaultTreasury, vaultStotage, governance) = (
            _uniswapMath,
            _vault,
            _auction,
            _vaultMath,
            _vaultTreasury,
            _vaultStotage,
            _governance
        );
    }

    modifier onlyVault() {
        require(msg.sender == vault || msg.sender == auction, "vault");
        _;
    }

    modifier onlyMath() {
        require(msg.sender == vaultMath, "math");
        _;
    }

    modifier onlyKeepers() {
        require(msg.sender == vault || msg.sender == vaultMath || msg.sender == auction, "keeper");
        _;
    }

    address public governance;

    modifier onlyGovernance() {
        require(msg.sender == governance, "governance");
        _;
    }

    /**
     * @notice owner can transfer his admin power to another address
     * @param _governance new governance address
     */
    function setGovernance(address _governance) external onlyGovernance {
        governance = _governance;
    }

    /**
     * @notice current balance of a certain token
     */
    function _getBalance(IERC20 token) internal view returns (uint256) {
        return token.balanceOf(vaultTreasury);
    }
}
