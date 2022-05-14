// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;
pragma abicoder v2;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface IFaucet {
    function setComponents(
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
    address public vaultMath;
    address public vaultTreasury;
    address public vaultStotage;

    constructor() Ownable() {}

    function setComponents(
        address _uniswapMath,
        address _vault,
        address _vaultMath,
        address _vaultTreasury,
        address _vaultStotage,
        address _governance
    ) public override onlyOwner {
        (uniswapMath, vault, vaultMath, vaultTreasury, vaultStotage, governance) = (
            _uniswapMath,
            _vault,
            _vaultMath,
            _vaultTreasury,
            _vaultStotage,
            _governance
        );
    }

    modifier onlyVault() {
        require(msg.sender == vault, "vault");
        _;
    }

    modifier onlyMath() {
        require(msg.sender == vaultMath, "math");
        _;
    }

    modifier onlyKeepers() {
        require(msg.sender == vault || msg.sender == vaultMath, "keeper");
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
}
