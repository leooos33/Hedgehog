// https://docs.euler.finance/developers/integration-guide
// https://gist.github.com/abhishekvispute/b0101938489a8b8dc292e3070c27156e
// https://soliditydeveloper.com/uniswap3/

// SPDX-License-Identifier: agpl-3.0
pragma solidity =0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IAuction} from "../interfaces/IAuction.sol";
import {IVault} from "../interfaces/IVault.sol";

import "hardhat/console.sol";

contract FlashDeposit is Ownable {
    using SafeMath for uint256;

    address public addressVault = 0x6894cf73D22B34fA2b30E5a4c706AD6c2f2b24ac;


    constructor() Ownable() {}
    
    function setContracts(address _addressVault) external onlyOwner {
        addressVault = _addressVault;
    }

    /**
    @notice deposit tokens in proportion to the vault's holding
    @param amountEth ETH amount to deposit
    @param amountUsdc USDC amount to deposit
    @param amountOsqth oSQTH amount to deposit 
    @param to receiver address
    @param amountEthMin revert if resulting amount of ETH is smaller than this
    @param amountUsdcMin revert if resulting amount of USDC is smaller than this
    @param amountOsqthMin revert if resulting amount of oSQTH is smaller than this
    @return shares minted shares
    */
    function deposit(
        uint256 amountEth,
        address to,
        uint256 amountEthMin,
        uint256 amountUsdcMin,
        uint256 amountOsqthMin,
    ) external override nonReentrant notPaused returns (uint256) {
        (uint256 usdcToDeposit, uint256 osqthToDeposit) = IVault(addressMath).getAmountsToDeposit(amountEth)
        
    }
}
