// const { assert } = require("chai");
// const { ethers } = require("hardhat");
// const { poolEthUsdc, poolEthOsqth, wethAddress, osqthAddress, usdcAddress } = require("./common");
// const { utils } = ethers;
// const { assertWP, getWETH, getUSDC, getOSQTH, getERC20Balance } = require('./helpers');

// describe("VaultAuction", function () {
//     let contract, tx;
//     it("Should deploy contract", async function () {
//         const Contract = await ethers.getContractFactory("VaultAuction");
//         contract = await Contract.deploy(
//             utils.parseUnits("40", 18),
//             1000,
//             utils.parseUnits("0.05", 18),
//             "1000000000000000000000",
//             "900000000000000000",
//             "1100000000000000000",
//             "500000000000000000",
//             "262210246107746000",
//             "237789753892254000",
//         );
//         await contract.deployed();
//     });
// });
