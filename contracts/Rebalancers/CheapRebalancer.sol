// SPDX-License-Identifier: agpl-3.0
pragma solidity =0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IVaultStorage {
    function timeAtLastRebalance() external view returns (uint256);

    function setRebalanceTimeThreshold(uint256 _rebalanceTimeThreshold) external;

    function setGovernance(address _governance) external;
}

interface IBigRebalancer {
    function addressStorage() external view returns (address);

    function addressTreasury() external view returns (address);

    function rebalance(uint256 threshold, uint256 triggerTime) external;

    function transferOwnership(address newOwner) external;
}

contract CheapRebalancer is Ownable {
    using SafeMath for uint256;

    address public bigRebalancer = 0x86345a7f1D77F6056E2ff83e1b1071238AEf1483;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

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

    function rebalance(uint256 threshold, uint256 priceMultiplier) public onlyOwner {
        IVaultStorage VaultStorage = IVaultStorage(IBigRebalancer(bigRebalancer).addressStorage());

        uint256 timeAtLastRebalance = VaultStorage.timeAtLastRebalance();

        uint256 rebalanceTimeThreshold = timeAtLastRebalance - block.timestamp + priceMultiplier;

        VaultStorage.setRebalanceTimeThreshold(rebalanceTimeThreshold);

        IBigRebalancer(bigRebalancer).rebalance(threshold, 0);

        IERC20(WETH).transfer(IBigRebalancer(bigRebalancer).addressTreasury(), IERC20(WETH).balanceOf(address(this)));

        VaultStorage.setRebalanceTimeThreshold(35000); //TODO: change here to smth mngtfull
    }
}
