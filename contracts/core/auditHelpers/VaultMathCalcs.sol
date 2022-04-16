// SPDX-License-Identifier: Unlicense

pragma solidity =0.7.6;
pragma abicoder v2;

// import "../VaultParams.sol";
// import "../../libraries/StrategyMath.sol";

// import "hardhat/console.sol";

// contract VaultMathCalcs {
//     using StrategyMath for uint256;

//     uint256 public minPriceMultiplier;
//     uint256 public maxPriceMultiplier;


//     constructor(
//         uint256 _minPriceMultiplier,
//         uint256 _maxPriceMultiplier
//     ) public {
//         minPriceMultiplier = _minPriceMultiplier;
//         maxPriceMultiplier = _maxPriceMultiplier;
//     }

//     //@dev <tested>
//     function _calcSharesAndAmounts(Constants.SharesInfo memory params)
//         public
//         view
//         returns (
//             uint256,
//             uint256,
//             uint256,
//             uint256
//         )
//     {
//         uint256 depositorValue = (
//             params._amountOsqth.mul(params.ethUsdcPrice).mul(params.osqthEthPrice).div(uint256(1e36))
//         ).add((params._amountUsdc.mul(uint256(1e12)))).add((params._amountEth.mul(params.ethUsdcPrice).div(1e18)));

//         if (params.totalSupply == 0) {
//             return (
//                 depositorValue,
//                 depositorValue.mul(targetEthShare).div(params.ethUsdcPrice),
//                 depositorValue.mul(targetUsdcShare).div(uint256(1e30)),
//                 depositorValue.mul(targetOsqthShare.mul(1e18)).div(params.osqthEthPrice).div(params.ethUsdcPrice)
//             );
//         } else {
//             uint256 totalValue = getTotalValue(
//                 params.osqthAmount,
//                 params.ethUsdcPrice,
//                 params.ethAmount,
//                 params.osqthEthPrice,
//                 params.usdcAmount
//             );

//             return (
//                 params.totalSupply.mul(depositorValue).div(totalValue),
//                 params.ethAmount.mul(depositorValue).div(totalValue),
//                 params.usdcAmount.mul(depositorValue).div(totalValue),
//                 params.osqthAmount.mul(depositorValue).div(totalValue)
//             );
//         }
//     }

//     //@dev <tested>
//     function _getAuctionPrices(Constants.AuctionInfo memory params) public view returns (uint256, uint256) {
//         // console.log("_getAuctionPrices => timestamp: %s", params.timestamp);
//         // console.log("_getAuctionPrices => _auctionTriggerTime: %s", params._auctionTriggerTime);

//         uint256 auctionCompletionRatio = params.timestamp.sub(params._auctionTriggerTime) >= params.auctionTime
//             ? 1e18
//             : (params.timestamp.sub(params._auctionTriggerTime)).wdiv(params.auctionTime);

//         // console.log("auctionCompletionRatio %s", auctionCompletionRatio);

//         uint256 priceMultiplier;
//         if (params._isPriceInc) {
//             priceMultiplier = maxPriceMultiplier.sub(
//                 auctionCompletionRatio.wmul(maxPriceMultiplier.sub(minPriceMultiplier))
//             );
//         } else {
//             priceMultiplier = minPriceMultiplier.add(
//                 auctionCompletionRatio.wmul(maxPriceMultiplier.sub(minPriceMultiplier))
//             );
//         }
//         // console.log("priceMultiplier %s", priceMultiplier);

//         return (
//             params.osqthEthPrice.wmul(priceMultiplier).wdiv(uint256(1e18)),
//             params.ethUsdcPrice.wmul(priceMultiplier).wdiv(uint256(1e18))
//         );
//     }

//     //@dev <tested>
//     function _getDeltas(Constants.DeltasInfo memory params)
//         public
//         view
//         returns (
//             uint256,
//             uint256,
//             uint256,
//             bool
//         )
//     {
//         // console.log("__getDeltas");
//         // console.log("osqthEthPrice %s", params.osqthEthPrice);
//         // console.log("ethUsdcPrice %s", params.ethUsdcPrice);
//         // console.log("usdcAmount %s", params.usdcAmount);
//         // console.log("ethAmount %s", params.ethAmount);
//         // console.log("osqthAmount %s", params.osqthAmount);

//         uint256 totalValue = getTotalValue(
//             params.osqthAmount,
//             params.ethUsdcPrice,
//             params.ethAmount,
//             params.osqthEthPrice,
//             params.usdcAmount
//         );

//         return (
//             targetEthShare.wmul(totalValue.wdiv(params.ethUsdcPrice)).suba(params.ethAmount),
//             ((targetUsdcShare * totalValue) / 1e30).suba(params.usdcAmount),
//             targetOsqthShare.wmul(totalValue).wmul(1e18).wdiv(params.osqthEthPrice).wdiv(params.ethUsdcPrice).suba(
//                 params.osqthAmount
//             ),
//             params.isPriceInc
//         );
//     }

//     function getTotalValue(
//         uint256 osqthAmount,
//         uint256 ethUsdcPrice,
//         uint256 ethAmount,
//         uint256 osqthEthPrice,
//         uint256 usdcAmount
//     ) public view returns (uint256) {
//         uint256 osqthValue = osqthAmount.wmul(ethUsdcPrice).wmul(osqthEthPrice).wdiv(uint256(1e18));
//         uint256 ethValue = ethAmount.wmul(ethUsdcPrice).wdiv(1e18);

//         uint256 totalValue = osqthValue.add(usdcAmount.mul(uint256(1e12))).add(ethValue);

//         // console.log("osqthValue %s", osqthValue);
//         // console.log("ethValue %s", ethValue);
//         // console.log("totalValue %s", totalValue);
//         return totalValue;
//     }
// }
