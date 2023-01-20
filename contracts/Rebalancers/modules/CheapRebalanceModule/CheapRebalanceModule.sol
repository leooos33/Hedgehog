// SPDX-License-Identifier: agpl-3.0
pragma solidity =0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import {PRBMathUD60x18} from "../../libraries/math/PRBMathUD60x18.sol";

interface IVaultMath {
    function getPrices() external view returns (uint256, uint256);
}
interface IVaultStorage {
    function timeAtLastRebalance() external view returns (uint256);

    function auctionTime() external view returns (uint256);

    function maxPriceMultiplier() external view returns (uint256);

    function minPriceMultiplier() external view returns (uint256);

    function setRebalanceTimeThreshold(uint256 _rebalanceTimeThreshold) external;

    function setGovernance(address _governance) external;
}

interface IRebalancer {
    function rebalance(uint256 threshold, uint256 triggerTime) external;

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

contract CheapRebalanceModule is Ownable {
    using PRBMathUD60x18 for uint256;

    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant OSQTH = 0xf1B99e3E573A1a9C5E6B2Ce818b617F0E664E86B;

    constructor() Ownable() {}

    function setGovernance(address to) external onlyOwner {
        IVaultStorage(IRegistry(msg.sender).components(4)).setGovernance(to);
    }

    function rebalance(uint256 threshold, uint256 newPM, uint256 newThreshold, address rebalancer) public onlyOwner {
        IVaultStorage VaultStorage = IVaultStorage(IRegistry(msg.sender).components(4));

        uint256 maxPM = VaultStorage.maxPriceMultiplier();
        uint256 minPM = VaultStorage.minPriceMultiplier();

        VaultStorage.setRebalanceTimeThreshold(
            block.timestamp.sub(VaultStorage.timeAtLastRebalance()).sub(
                (VaultStorage.auctionTime()).mul(maxPM.sub(newPM).div(maxPM.sub(minPM)))
            )
        );

        IRebalancer(rebalancer).rebalance(threshold, 0);

        VaultStorage.setRebalanceTimeThreshold(newThreshold);
    }

    function isQuickRebalance() public view returns (bool) {
        (uint256 ethUsdcPrice, ) = IVaultMath(IRegistry(msg.sender).components(2)).getPrices();
        IVaultStorage VaultStorage = IVaultStorage(IRegistry(msg.sender).components(4));
        uint256 cachedPrice = VaultStorage.ethPriceAtLastRebalance();

        uint256 ratio = cachedPrice > ethUsdcPrice ? cachedPrice.div(ethUsdcPrice) : ethUsdcPrice.div(cachedPrice);

        return ratio <= VaultStorage.rebalanceThreshold();
    }

    function collectProtocol(
        address rebalancer,
        uint256 amountEth,
        uint256 amountUsdc,
        uint256 amountOsqth,
        address to
    ) external onlyOwner {
        IRebalancer(rebalancer).collectProtocol(amountEth, amountUsdc, amountOsqth, to);
    }
}
