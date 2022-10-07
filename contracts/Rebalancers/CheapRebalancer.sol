// SPDX-License-Identifier: agpl-3.0
pragma solidity =0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PRBMathUD60x18} from "../libraries/math/PRBMathUD60x18.sol";
import "hardhat/console.sol";

interface IVaultStorage {
    function timeAtLastRebalance() external view returns (uint256);

    function auctionTime() external view returns (uint256);

    function maxPriceMultiplier() external view returns (uint256);

    function minPriceMultiplier() external view returns (uint256);

    function setRebalanceTimeThreshold(uint256 _rebalanceTimeThreshold) external;

    function setGovernance(address _governance) external;
}

interface IBigRebalancer {
    function addressStorage() external view returns (address);

    function addressTreasury() external view returns (address);

    function rebalance(uint256 threshold, uint256 triggerTime) external;

    function collectProtocol(
        uint256 amountEth,
        uint256 amountUsdc,
        uint256 amountOsqth,
        address to
    ) external;

    function transferOwnership(address newOwner) external;
}

contract CheapRebalancer is Ownable {
    using PRBMathUD60x18 for uint256;

    address public bigRebalancer = 0x86345a7f1D77F6056E2ff83e1b1071238AEf1483;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant OSQTH = 0xf1B99e3E573A1a9C5E6B2Ce818b617F0E664E86B;

    constructor() Ownable() {}

    function setContracts(address _bigRebalancer) external onlyOwner {
        bigRebalancer = _bigRebalancer;
    }

    function returnOwner(address to) external onlyOwner {
        IBigRebalancer(bigRebalancer).transferOwnership(to);
    }

    function returnGovernance(address to) external onlyOwner {
        IVaultStorage(IBigRebalancer(bigRebalancer).addressStorage()).setGovernance(to);
    }

    function collectProtocol(
        uint256 amountEth,
        uint256 amountUsdc,
        uint256 amountOsqth,
        address to
    ) external onlyOwner {
        IBigRebalancer(bigRebalancer).collectProtocol(amountEth, amountUsdc, amountOsqth, to);
    }

    function rebalance(uint256 threshold, uint256 newPM) public onlyOwner {
        IVaultStorage VaultStorage = IVaultStorage(IBigRebalancer(bigRebalancer).addressStorage());

        uint256 maxPM = VaultStorage.maxPriceMultiplier();
        uint256 minPM = VaultStorage.minPriceMultiplier();

        VaultStorage.setRebalanceTimeThreshold(
            block.timestamp.sub(VaultStorage.timeAtLastRebalance()).sub(
                (VaultStorage.auctionTime()).mul(maxPM.sub(newPM).div(maxPM.sub(minPM)))
            )
        );

        IBigRebalancer(bigRebalancer).rebalance(threshold, 0);

        VaultStorage.setRebalanceTimeThreshold(500000);
    }
}
