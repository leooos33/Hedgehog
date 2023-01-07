// SPDX-License-Identifier: agpl-3.0
pragma solidity =0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PRBMathUD60x18} from "../libraries/math/PRBMathUD60x18.sol";
import {IVaultStorage} from "../interfaces/IVaultStorage.sol";

interface IRebalanceModule {
    function collectProtocol(
        uint256 amountEth,
        uint256 amountUsdc,
        uint256 amountOsqth,
        address to
    ) external;

    function transferOwnership(address newOwner) external;

    function rebalance(uint256 threshold) external;

    function rebalance(uint256 threshold, uint256 triggerTime) external;
}

//TODO: check all addresses
contract CheapRebalancerUpdatable is Ownable {
    using PRBMathUD60x18 for uint256;

    address[] public rebalanceModules;

    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant OSQTH = 0xf1B99e3E573A1a9C5E6B2Ce818b617F0E664E86B;

    constructor() Ownable() {
        rebalanceModules.push(0xa6D7b99c05038ad2CC39F695CF6D2A06DdAD799a); //Storage
    }

    function updateModule(uint256 moduleId, address moduleAddress) external onlyOwner {
        rebalanceModules[moduleId] = moduleAddress;
    }

    function addModule(address moduleAddress) external onlyOwner {
        rebalanceModules.push(moduleAddress);
    }

    function transferOwnerOfModule(uint256 moduleId, address to) external onlyOwner {
        IRebalanceModule(rebalanceModules[moduleId]).transferOwnership(to);
    }

    function collectProtocol(
        uint256 moduleId,
        uint256 amountEth,
        uint256 amountUsdc,
        uint256 amountOsqth,
        address to
    ) external onlyOwner {
        IRebalanceModule(rebalanceModules[moduleId]).collectProtocol(amountEth, amountUsdc, amountOsqth, to);
    }

    function transferGovernance(address to) external onlyOwner {
        IVaultStorage(rebalanceModules[0]).setGovernance(to);
    }

    function transferKeeper(address to) external onlyOwner {
        IVaultStorage(rebalanceModules[0]).setKeeper(to);
    }

    function rebalanceInstant(
        uint256 moduleId,
        uint256 threshold,
        uint256 newPM,
        uint256 thresholdAfter
    ) public onlyOwner {
        IVaultStorage VaultStorage = IVaultStorage(rebalanceModules[0]);
        VaultStorage.setKeeper(rebalanceModules[moduleId]);

        uint256 maxPM = VaultStorage.maxPriceMultiplier();
        uint256 minPM = VaultStorage.minPriceMultiplier();

        VaultStorage.setRebalanceTimeThreshold(
            block.timestamp.sub(VaultStorage.timeAtLastRebalance()).sub(
                (VaultStorage.auctionTime()).mul(maxPM.sub(newPM).div(maxPM.sub(minPM)))
            )
        );

        IRebalanceModule(rebalanceModules[moduleId]).rebalance(threshold, 0);

        VaultStorage.setRebalanceTimeThreshold(thresholdAfter);

        IRebalanceModule() VaultStorage.setKeeper(address(this));
    }

    function rebalance(uint256 moduleId, uint256 threshold) public onlyOwner {
        IVaultStorage VaultStorage = IVaultStorage(rebalanceModules[0]);
        VaultStorage.setKeeper(rebalanceModules[moduleId]);

        IRebalanceModule(rebalanceModules[moduleId]).rebalance(threshold);

        VaultStorage.setKeeper(address(this));
    }

    //TODO: add more setters
}
