// https://consensys.github.io/smart-contract-best-practices/development-recommendations/general/external-calls/
// https://ethereum-contract-security-techniques-and-tips.readthedocs.io/en/latest/recommendations/

// SPDX-License-Identifier: agpl-3.0
pragma solidity =0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVaultStorage} from "../interfaces/IVaultStorage.sol";

interface IModule {
    function transferOwnership(address newOwner) external;

    function returnGovernance(address to) external;

    function setKeeper(address to) external;
}

event ModuleUpdated(uint256 id, address moduleAddress);

event ComponentUpdated(uint256 id, address componentAddress);


//TODO: errors to codes

//TODO: Put reentrancy gards everythere
contract HedgehogGovernance is Ownable {
    address[] public modules;

    address[] public components; // TODO: optimize array uint value evrythere

    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant OSQTH = 0xf1B99e3E573A1a9C5E6B2Ce818b617F0E664E86B;

    constructor() Ownable() {
        components.push(0x6d4CA1177087924edfE0908ef655169EA766FDc3); // vault    0
        components.push(0x2f1D08D53d04559933dBF436a5cD15182a190110); // auction  1
        components.push(0x40B22821f694f1F3b226b57B5852d7832e2B5f3f); // math     2
        components.push(0x12804580C15F4050dda61D44AFC94623198848bC); // treasury 3
        components.push(0xa6D7b99c05038ad2CC39F695CF6D2A06DdAD799a); // storage  4
    }

    function updateComponent(uint256 componentId, address componentAddress) external onlyOwner {
        components[componentId] = componentAddress;

        emit ComponentUpdated(componentId, componentAddress);
    }

    function addComponent(address componentAddress) external onlyOwner {
        components.push(componentAddress);

        emit ComponentUpdated(components.length -1, componentAddress);
    }

    function updateModule(uint256 moduleId, address moduleAddress) external onlyOwner {
        modules[moduleId] = moduleAddress;

        emit ModuleUpdated(moduleId, moduleAddress);
    }

    function addModule(address moduleAddress) external onlyOwner {
        modules.push(moduleAddress);

        emit ModuleUpdated(modules.length -1, moduleAddress);
    }

    function setGovernance(address to) external onlyOwner {
        IVaultStorage(components[4]).setGovernance(to);

        //TODO: events here?
    }

    function setKeeper(address to) external onlyOwner {
        IVaultStorage(components[4]).setKeeper(to);

        //TODO: events here?
    }

    function transferModuleOwnership(uint256 moduleId, address to) external onlyOwner {
        IModule(modules[moduleId]).transferOwnership(to);
    }

    function call(
        uint256 moduleId,
        address _governance,
        address _keeper,
        bytes calldata _data,
    ) public onlyOwner {
        address moduleAddress = modules[moduleId];
        if(_governance != address(0)) setGovernance(_governance);
        if(_keeper != address(0)) setKeeper(_keeper);

        (bool success, ) = moduleAddress.call(_data);
        require(success, 'call failed');

        // this should return error if it's not transfered, for example for BigRebalancerEuler
        //TODO: check it
        if(_governance != address(0)) IModule(_governance).setGovernance(address(this));
        if(_keeper != address(0)) IModule(_keeper).setKeeper(address(this));
    }
}
