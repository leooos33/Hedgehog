// SPDX-License-Identifier: agpl-3.0
pragma solidity =0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

import {IFaucet} from "../libraries/Faucet.sol";

contract UpdateblityGuard is Ownable {
    using SafeMath for uint256;

    address public uniswapMath = 0x61d3312E32F3F6f69aE5629D717F318Bc4656Abd;
    address public vault = 0x6d4CA1177087924edfE0908ef655169EA766FDc3;
    address public auction = 0x2f1D08D53d04559933dBF436a5cD15182a190110;
    address public vaultMath = 0x40B22821f694f1F3b226b57B5852d7832e2B5f3f;
    address public vaultTreasury = 0x12804580C15F4050dda61D44AFC94623198848bC;
    address public vaultStorage = 0xa6D7b99c05038ad2CC39F695CF6D2A06DdAD799a;

    address public newVaultMath;
    uint256 public constant blockToDelay = 1256;
    uint256 public updateOnBlock = type(uint160).max;

    constructor() Ownable() {}

    function setLateUpdate(address _vaultMath) external onlyOwner {
        newVaultMath = _vaultMath;
        updateOnBlock = block.number + blockToDelay;
        //emit event what HH will update in the future
    }

    function lateUpdate() external {
        require(block.number > updateOnBlock, "C1");

        updateFaucet(vault);
        updateFaucet(auction);
        updateFaucet(vaultMath);
        updateFaucet(vaultTreasury);
        updateFaucet(vaultStorage);
        updateOnBlock = type(uint160).max;
        //emit event what HH is updated
    }

    function updateFaucet(address faucet) internal {
        IFaucet(faucet).setComponents(uniswapMath, vault, auction, newVaultMath, vaultTreasury, vaultStorage);
    }
}
