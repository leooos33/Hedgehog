// SPDX-License-Identifier: agpl-3.0
pragma solidity =0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import {PRBMathUD60x18} from "../libraries/math/PRBMathUD60x18.sol";

interface IVaultStorage {
    function timeAtLastRebalance() external view returns (uint256);

    function auctionTime() external view returns (uint256);

    function maxPriceMultiplier() external view returns (uint256);

    function minPriceMultiplier() external view returns (uint256);

    function setRebalanceTimeThreshold(uint256 _rebalanceTimeThreshold) external;

    function setGovernance(address _governance) external;

    function setKeeper(address _governance) external;
}

interface IRebalancer {
    function rebalance(uint256 threshold, uint256 triggerTime) external;

    function collectProtocol(
        uint256 amountEth,
        uint256 amountUsdc,
        uint256 amountOsqth,
        address to
    ) external;

    function transferOwnership(address newOwner) external;

    function setKeeper(address to) external;
}

/**
 * Error
 * M0: Not an owner
*/

contract CheapRebalancer {
    using PRBMathUD60x18 for uint256;

    address addressStorage = 0xa6D7b99c05038ad2CC39F695CF6D2A06DdAD799a;

    mapping(address => bool) public isOwner;

    constructor() {
        isOwner[0x4530DA167C5a751e48f35b2aa08F44570C03B7dd] = true;
        isOwner[0x4530DA167C5a751e48f35b2aa08F44570C03B7dd] = true;
    }

    function setContracts(address _addressStorage) external onlyOwners {
        addressStorage = _addressStorage;
    }

    function returnOwner(address to, address rebalancer) external onlyOwners {
        IRebalancer(rebalancer).transferOwnership(to);
    }

    function setGovernance(address to) external onlyOwners {
        IVaultStorage(addressStorage).setGovernance(to);
    }

    function setKeeper(address to) external onlyOwners {
        IVaultStorage(addressStorage).setKeeper(to);
    }

    //TODO: think about should we pass 3 params exept 1
    function collectProtocol(
        address rebalancer,
        uint256 amountEth,
        address to
    ) external onlyOwners {
        IRebalancer(rebalancer).collectProtocol(amountEth, 0, 0, to);
    }

    function rebalance(
        address rebalancer,
        uint256 threshold,
        uint256 newPM,
        uint256 newThreshold
    ) public onlyOwners {
        IVaultStorage VaultStorage = IVaultStorage(addressStorage);

        VaultStorage.setKeeper(rebalancer);

        uint256 maxPM = VaultStorage.maxPriceMultiplier();
        uint256 minPM = VaultStorage.minPriceMultiplier();

        VaultStorage.setRebalanceTimeThreshold(
            block.timestamp.sub(VaultStorage.timeAtLastRebalance()).sub(
                (VaultStorage.auctionTime()).mul(maxPM.sub(newPM).div(maxPM.sub(minPM)))
            )
        );

        IRebalancer(rebalancer).rebalance(threshold, 0);

        VaultStorage.setRebalanceTimeThreshold(newThreshold);

        IRebalancer(rebalancer).setKeeper(address(this));
    }

    function transferOwnership(
        address to
    ) public onlyOwners {
        isOwner[msg.sender] = false;
        isOwner[to] = true;
    }

    // TODO: think about where to put only owner
    modifier onlyOwners() {
        require(isOwner[msg.sender], "M0");
        _;
    }
}
