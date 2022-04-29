// const { assert } = require("chai");
// const { ethers } = require("hardhat");
// const { utils } = ethers;
// const { assertWP } = require('./helpers');
// const { poolEthUsdc,
//   poolEthOsqth,
//   osqthAddress,
//   usdcAddress,
//   wethAddress, } = require('./common');

// describe("Oracle", function () {
//   let contract, tx;
//   it("Should deploy contract", async function () {
//     const Contract = await ethers.getContractFactory("VaultMathOracle");
//     contract = await Contract.deploy();
//     await contract.deployed();
//   });

//   it("_getTwap osqthEthPrice", async function () {

//     const test_sute = [
//       poolEthOsqth,
//       osqthAddress,
//       wethAddress,
//       420,
//     ];
//     console.log(test_sute);

//     const amount = await contract._getTwap(
//       ...test_sute,
//     );
//     console.log(">>", amount);

//     assert(assertWP(amount.toString(), "266539217285974314"), `should not fail`)
//   });

//   it("_getTwap ethOsqthPrice", async function () {

//     const test_sute = [
//       poolEthOsqth,
//       wethAddress,
//       osqthAddress,
//       420,
//     ];
//     console.log(test_sute);

//     const amount = await contract._getTwap(
//       ...test_sute,
//     );
//     console.log(">>", amount);

//     assert(assertWP(amount.toString(), "3751793113908200371"), `should not fail`)
//   });

//   it("_getTwap usdcEthPrice", async function () {

//     const test_sute = [
//       poolEthUsdc,
//       usdcAddress,
//       wethAddress,
//       420,
//     ];
//     console.log(test_sute);

//     const amount = await contract._getTwap(
//       ...test_sute,
//     );
//     console.log(">>", amount);

//     assert(assertWP(amount.toString(), "294864036548739"), `should not fail`)
//   });

//   it("_getTwap ethUsdcPrice", async function () {

//     const test_sute = [
//       poolEthUsdc,
//       wethAddress,
//       usdcAddress,
//       420,
//     ];
//     console.log(test_sute);

//     const amount = await contract._getTwap(
//       ...test_sute,
//     );
//     console.log(">>", amount);

//     assert(assertWP(amount.toString(), "3391393578000000000000"), `should not fail`)
//   });
// });

// // TODO: add this pairs to check

// // uint256 osqthEthPrice = Constants.oracle.getTwap(
// //   Constants.poolEthOsqth,
// //   address(Constants.weth),
// //   address(Constants.osqth),
// //   twapPeriod,
// //   true
// // );

// // uint256 usdcEthPrice = Constants.oracle.getTwap(
// //   Constants.poolEthUsdc,
// //   address(Constants.usdc),
// //   address(Constants.weth),
// //   twapPeriod,
// //   true
// // );

// // uint256 osqthEthPrice = Constants.oracle.getTwap(
// //   Constants.poolEthOsqth,
// //   address(Constants.osqth),
// //   address(Constants.weth),
// //   twapPeriod,
// //   true
// // );

// // uint256 ethUsdcPrice = Constants.oracle.getTwap(
// //   Constants.poolEthUsdc,
// //   address(Constants.weth),
// //   address(Constants.usdc),
// //   twapPeriod,
// //   true
// // );
