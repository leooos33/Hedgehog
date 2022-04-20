// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;
pragma abicoder v2;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IVault.sol";
import "./libraries/SharedEvents.sol";
import "./libraries/Constants.sol";
import "./libraries/math/StrategyMath.sol";
import "./core/VaultAuction.sol";

import "hardhat/console.sol";

contract Vault is IVault, ReentrancyGuard, VaultAuction {
    using StrategyMath for uint256;

    /**
     * @notice strategy constructor
       @param _cap max amount of wETH that strategy accepts for deposits
       @param _rebalanceTimeThreshold rebalance time threshold (seconds)
       @param _rebalancePriceThreshold rebalance price threshold (0.05*1e18 = 5%)
       @param _auctionTime auction duration (seconds)
       @param _minPriceMultiplier minimum auction price multiplier (0.95*1e18 = min auction price is 95% of twap)
       @param _maxPriceMultiplier maximum auction price multiplier (1.05*1e18 = max auction price is 105% of twap)
     */
    constructor(
        uint256 _cap,
        uint256 _rebalanceTimeThreshold,
        uint256 _rebalancePriceThreshold,
        uint256 _auctionTime,
        uint256 _minPriceMultiplier,
        uint256 _maxPriceMultiplier,
        address uniswapAdaptorAddress
    )
        public
        VaultAuction(
            _cap,
            _rebalanceTimeThreshold,
            _rebalancePriceThreshold,
            _auctionTime,
            _minPriceMultiplier,
            _maxPriceMultiplier,
            uniswapAdaptorAddress
        )
    {}

    function deposit(
        uint256 _amountEth,
        uint256 _amountUsdc,
        uint256 _amountOsqth,
        address to,
        uint256 _amountEthMin,
        uint256 _amountUsdcMin,
        uint256 _amountOsqthMin
    ) external override nonReentrant returns (uint256 shares) {
        require(_amountEth > 0 || (_amountUsdc > 0 || _amountOsqth > 0), "ZA"); //Zero amount
        require(to != address(0) && to != address(this), "WA"); //Wrong address

        //Poke positions so vault's current holdings are up to date
        _poke(address(Constants.poolEthUsdc), orderEthUsdcLower, orderEthUsdcUpper);
        _poke(address(Constants.poolEthOsqth), orderOsqthEthLower, orderOsqthEthUpper);

        //Calculate shares to mint
        (uint256 _shares, uint256 amountEth, uint256 amountUsdc, uint256 amountOsqth) = calcSharesAndAmounts(
            _amountEth,
            _amountUsdc,
            _amountOsqth
        );

        console.log("_shares %s", _shares);
        console.log("amountEth %s", amountEth);
        console.log("amountUsdc %s", amountUsdc);
        console.log("amountOsqth %s", amountOsqth);

        require(amountEth >= _amountEthMin, "Amount ETH min");
        require(amountUsdc >= _amountUsdcMin, "Amount USDC min");
        require(amountOsqth >= _amountOsqthMin, "Amount oSQTH min");

        //Pull in tokens
        if (amountEth > 0) Constants.weth.transferFrom(msg.sender, address(this), amountEth);
        if (amountUsdc > 0) Constants.usdc.transferFrom(msg.sender, address(this), amountUsdc);
        if (amountOsqth > 0) Constants.osqth.transferFrom(msg.sender, address(this), amountOsqth);

        //Mint shares to user
        _mint(to, _shares);
        require(totalSupply() <= cap, "Cap is reached");

        emit SharedEvents.Deposit(to, _shares);
    }

    /**
    @notice withdraws tokens in proportion to the vault's holdings.
    @dev provide strategy tokens, returns set of wETH, USDC, and oSQTH
    @param shares shares burned by sender
    @param amountEthMin revert if resulting amount of wETH is smaller than this
    @param amountUsdcMin revert if resulting amount of USDC is smaller than this
    @param amountOsqthMin revert if resulting amount of oSQTH is smaller than this
    */
    function withdraw(
        uint256 shares,
        uint256 amountEthMin,
        uint256 amountUsdcMin,
        uint256 amountOsqthMin
    ) external override nonReentrant {
        require(shares > 0, "0");

        uint256 oldTotalSupply = totalSupply();

        _burn(msg.sender, shares);

        (uint256 amountEth, uint256 amountUsdc, uint256 amountOsqth) = _getWithdrawAmounts(shares, oldTotalSupply);

        console.log("amountEth %s", amountEth);
        console.log("amountUsdc %s", amountUsdc);
        console.log("amountOsqth %s", amountOsqth);
        console.log("ballance weth %s", getBalance(Constants.weth));
        console.log("ballance usdc %s", getBalance(Constants.usdc));
        console.log("ballance osqth %s", getBalance(Constants.osqth));

        require(amountEth >= amountEthMin, "amountEthMin");
        require(amountUsdc >= amountUsdcMin, "amountUsdcMin");
        require(amountOsqth >= amountOsqthMin, "amountOsqthMin");

        //send tokens to user
        if (amountEth > 0) Constants.weth.transfer(msg.sender, amountEth);
        if (amountUsdc > 0) Constants.usdc.transfer(msg.sender, amountUsdc);
        if (amountOsqth > 0) Constants.osqth.transfer(msg.sender, amountOsqth);

        emit SharedEvents.Withdraw(msg.sender, shares, amountEth, amountUsdc, amountOsqth);
    }
}
