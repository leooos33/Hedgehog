// SPDX-License-Identifier: agpl-3.0
pragma solidity =0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PRBMathUD60x18} from "../../libraries/math/PRBMathUD60x18.sol";

import {IAuction} from "../../interfaces/IAuction.sol";
import {IVaultMath} from "../../interfaces/IVaultMath.sol";
import {IVaultStorage} from "../../interfaces/IVaultStorage.sol";
import {IVaultTreasury} from "../../interfaces/IVaultTreasury.sol";
import {IEulerDToken, IEulerMarkets, IExec} from "./IEuler.sol";

import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

interface IRegistry {
    address[] public components;
}

event ProtocolFeeUpdated(uint256 _protocolFee);

//TODO: we could not need it but call directly from hh governance
//TODO: add events evrythere
contract ParamsModule is Ownable {
    constructor() Ownable() {}

    function setGovernance(address to) external onlyOwner {
        IVaultStorage(IRegistry(msg.sender).components(4)).setGovernance(to);
    }

    function setProtocolFee(uint256 _protocolFee) external onlyOwner {
        IVaultStorage(IRegistry(msg.sender).components(4)).setProtocolFee(_protocolFee);
        emit ProtocolFeeUpdated(_protocolFee);
    }

    function setDepositCount(uint256 _depositCount) external onlyOwner {
        IVaultStorage(IRegistry(msg.sender).components(4)).setDepositCount(_depositCount);
    }

    //TODO: add more setters
}
