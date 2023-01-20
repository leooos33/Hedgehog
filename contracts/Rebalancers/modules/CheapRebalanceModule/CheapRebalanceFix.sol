// SPDX-License-Identifier: agpl-3.0
pragma solidity =0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import {CheapRebalancer} from "./CheapRebalancer.sol";

interface ICheapRebalancer {
    function rebalance(uint256 threshold, uint256 triggerTime) external;
    
    function setContracts(address _bigRebalancer) external;

    function collectProtocol(
        uint256 amountEth,
        uint256 amountUsdc,
        uint256 amountOsqth,
        address to
    ) external;
}

interface IRegistry {
    address[] public components;
}

contract CheapRebalanceFix is Ownable {
    CheapRebalancer cheapRebalancer = CheapRebalancer(0x17e8a3e01A73c754052cdCdee29E5804300c5406)
    constructor() Ownable() {}

    function setGovernance(address to) external onlyOwner {
        IVaultStorage(IRegistry(msg.sender).components(4)).setGovernance(to);
    }

    function rebalance(uint256 threshold, uint256 newPM, address rebalancer) public onlyOwner {
        cheapRebalancer.setContracts(rebalancer);
        cheapRebalancer.rebalance(threshold, newPM);
    }

    function collectProtocol(
        address rebalancer,
        uint256 amountEth,
        uint256 amountUsdc,
        uint256 amountOsqth,
        address to
    ) external onlyOwner {
        cheapRebalancer.setContracts(rebalancer);
        cheapRebalancer.collectProtocol(amountEth, amountUsdc, amountOsqth, to);
    }
}
