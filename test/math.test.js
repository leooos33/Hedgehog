const { expect, util } = require("chai");
const { ethers } = require("hardhat");
const { utils, BigNumber } = ethers;
const { loadTestDataset, toWEIS, getERC20Balance, getWETH, approveERC20, getERC20Allowance, getUSDC, getOSQTH } = require('./helpers');
const { wethAddress, usdcAddress, osqthAddress } = require('./common');

describe.only("Math", function () {
  let contract, tx;
  it("Should deploy", async function () {
    const Contract = await ethers.getContractFactory("VaultMathTest");
    contract = await Contract.deploy(
      utils.parseUnits("40", 18),
      1000,
      utils.parseUnits("0.05", 18),
      100,
      utils.parseUnits("0.95", 18),
      utils.parseUnits("1.05", 18),
      utils.parseUnits("0.5", 18),
      utils.parseUnits("0.2622", 18),
      utils.parseUnits("0.2378", 18),
    );
    await contract.deployed();
  });

  it("_calcSharesAndAmounts", async function () {
    const testsDs = await loadTestDataset("_calcSharesAndAmounts");

    for (let i in testsDs) {
      let test_sute = { ...testsDs[i] };

      console.log(test_sute);
      test_sute = {
        totalSupply: toWEIS(test_sute.totalSupply),
        _amountEth: toWEIS(test_sute._amountEth),
        _amountUsdc: toWEIS(test_sute._amountUsdc, 6),
        _amountOsqth: toWEIS(test_sute._amountOsqth),
        osqthEthPrice: toWEIS(test_sute.osqthEthPrice),
        ethUsdcPrice: toWEIS(test_sute.ethUsdcPrice),
        usdcAmount: toWEIS(test_sute.usdcAmount, 6),
        ethAmount: toWEIS(test_sute.ethAmount),
        osqthAmount: toWEIS(test_sute.osqthAmount),
      }
      console.log(test_sute);

      const amount = await contract._calcSharesAndAmounts(
        test_sute,
      );
      console.log(">>", amount);

      expect(amount[0].toString()).to.equal(toWEIS(testsDs[i].shares), `test_sute ${i}: sub 1`);
      expect(amount[1].toString()).to.equal(toWEIS(testsDs[i].amountEth), `test_sute ${i}: sub 2`);
      expect(amount[2].toString()).to.equal(toWEIS(testsDs[i].amountUsdc, 6), `test_sute ${i}: sub 3`);
      expect(amount[3].toString()).to.equal(toWEIS(testsDs[i].amountOsqth), `test_sute ${i}: sub 4`);
    }
  });
});
