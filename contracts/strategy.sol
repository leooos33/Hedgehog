// SPDX-License-Identifier: Unlicense

pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

// import "@openzeppelin/contracts/math/Math.sol";
// import "@openzeppelin/contracts/math/SafeMath.sol";
// import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
// import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

// import "./interfaces/IVault.sol";
// import "./libraries/SharedEvents.sol";
// import "./libraries/Constants.sol";
// import "./libraries/StrategyMath.sol";

// import "./core/VaultParams.sol";
// import "./core/VaultAuction.sol";

// import "hardhat/console.sol";

// contract Vault is IVault, ReentrancyGuard, VaultAuction {
//     // using SafeMath for uint256;
//     using StrategyMath for uint256;

//     /**
//      * @notice strategy constructor
//        @param _cap max amount of wETH that strategy accepts for deposits
//        @param _rebalanceTimeThreshold rebalance time threshold (seconds)
//        @param _rebalancePriceThreshold rebalance price threshold (0.05*1e18 = 5%)
//        @param _auctionTime auction duration (seconds)
//        @param _minPriceMultiplier minimum auction price multiplier (0.95*1e18 = min auction price is 95% of twap)
//        @param _maxPriceMultiplier maximum auction price multiplier (1.05*1e18 = max auction price is 105% of twap)
//        @param _targetEthShare targeted share of value in wETH (0.5*1e18 = 50% of total value(in usd) in wETH)
//        @param _targetUsdcShare targeted share of value in USDC (~0.2622*1e18 = 26.22% of total value(in usd) in USDC)
//        @param _targetOsqthShare targeted share of value in oSQTH (~0.2378*1e18 = 23.78% of total value(in usd) in oSQTH)
//      */
//     constructor(
//         uint256 _cap,
//         uint256 _rebalanceTimeThreshold,
//         uint256 _rebalancePriceThreshold,
//         uint256 _auctionTime,
//         uint256 _minPriceMultiplier,
//         uint256 _maxPriceMultiplier,
//         uint256 _targetEthShare,
//         uint256 _targetUsdcShare,
//         uint256 _targetOsqthShare
//     )
//         public
//         VaultAuction(
//             _cap,
//             _rebalanceTimeThreshold,
//             _rebalancePriceThreshold,
//             _auctionTime,
//             _minPriceMultiplier,
//             _maxPriceMultiplier,
//             _targetEthShare,
//             _targetUsdcShare,
//             _targetOsqthShare
//         )
//     {}

//     function deposit(
//         uint256 _amountEth,
//         uint256 _amountUsdc,
//         uint256 _amountOsqth,
//         address to,
//         uint256 _amountEthMin,
//         uint256 _amountUsdcMin,
//         uint256 _amountOsqthMin
//     ) external override nonReentrant returns (uint256 shares) {
//         require(_amountEth > 0 || (_amountUsdc > 0 || _amountOsqth > 0), "ZA"); //Zero amount
//         require(to != address(0) && to != address(this), "WA"); //Wrong address

//         //Poke positions so vault's current holdings are up to date
//         _poke(address(Constants.poolEthUsdc), orderEthUsdcLower, orderEthUsdcUpper);
//         _poke(address(Constants.poolEthOsqth), orderOsqthEthLower, orderOsqthEthUpper);

//         //Calculate shares to mint
//         (uint256 _shares, uint256 amountEth, uint256 amountUsdc, uint256 amountOsqth) = calcSharesAndAmounts(
//             _amountEth,
//             _amountUsdc,
//             _amountOsqth
//         );

//         require(amountEth >= _amountEthMin, "Amount ETH min");
//         require(amountUsdc >= _amountUsdcMin, "Amount USDC min");
//         require(amountOsqth >= _amountOsqthMin, "Amount oSQTH min");

//         //Pull in tokens
//         if (amountEth > 0) Constants.weth.transferFrom(msg.sender, address(this), _amountEth);
//         if (amountUsdc > 0) Constants.usdc.transferFrom(msg.sender, address(this), _amountUsdc);
//         if (amountOsqth > 0) Constants.osqth.transferFrom(msg.sender, address(this), _amountOsqth);

//         //Mint shares to user
//         _mint(to, _shares);
//         require(totalSupply() <= cap, "Cap is reached");

//         shares = _shares;

//         emit SharedEvents.Deposit(to, _shares);
//     }
// /**
//   @notice withdraws tokens in proportion to the vault's holdings.
//   @dev provide strategy tokens, returns set of wETH, USDC, and oSQTH
//   @param shares shares burned by sender
//   @param amountEthMin revert if resulting amount of wETH is smaller than this
//   @param amountUsdcMin revert if resulting amount of USDC is smaller than this
//   @param amountOsqthMin revert if resulting amount of oSQTH is smaller than this
//  */
//  function withdraw(
//     uint256 shares,
//     uint256 amountEthMin,
//     uint256 amountUsdcMin,
//     uint256 amountOsqthMin
// )
//     external
//     override
//     nonReentrant
//     returns (
//         uint256 amountEth,
//         uint256 amountUsdc,
//         uint256 amountOsqth
//     )
// {
//     require(shares > 0, "Zero shares");

//     uint256 totalSupply = totalSupply();

//     _burn(msg.sender, shares);

//     //withdraw user share of tokens from the lp positions in current proportion
//     (uint256 amountEth0, uint256 amountUsdc) = _burnLiquidityShare(
//         Constants.poolEthUsdc,
//         orderEthUsdcLower,
//         orderEthUsdcUpper,
//         shares,
//         totalSupply
//     );
//     (uint256 amountOsqth, uint256 amountEth1) = _burnLiquidityShare(
//         Constants.poolEthOsqth,
//         orderOsqthEthLower,
//         orderOsqthEthUpper,
//         shares,
//         totalSupply
//     );

//     //sum up received eth from eth:usdc pool and from osqth:eth pool
//     amountEth = amountEth0.add(amountEth1);

//     console.log(amountEth);
//     console.log(amountUsdc);
//     console.log(amountOsqth);
//     require(amountEth >= amountEthMin, "amountEthMin");
//     require(amountUsdc >= amountUsdcMin, "amountUsdcMin");
//     require(amountOsqth >= amountOsqthMin, "amountOsqthMin");

//     //send tokens to user
//     if (amountEth > 0) Constants.weth.transfer(msg.sender, amountEth);
//     if (amountUsdc > 0) Constants.usdc.transfer(msg.sender, amountUsdc);
//     if (amountOsqth > 0) Constants.osqth.transfer(msg.sender, amountOsqth);

//     //track deposited wETH amount
//     //TODO

//     emit SharedEvents.Withdraw(msg.sender, shares, amountEth, amountUsdc, amountOsqth);
// }
// }
