const { expect, assert, util } = require("chai");
const { ethers } = require("hardhat");
const { utils, BigNumber } = ethers;
const { loadTestDataset, toWEIS, assertWP } = require('./helpers');

describe.only("Math", function () {
  let contract, tx;
  it("Should deploy contract", async function () {
    const Contract = await ethers.getContractFactory("VaultMathTest");
    contract = await Contract.deploy(
      utils.parseUnits("40", 18),
      1000,
      utils.parseUnits("0.05", 18),
      100,
      "900000000000000000",
      "1100000000000000000",
      "500000000000000000",
      "262210246107746000",
      "237789753892254000",
    );
    await contract.deployed();
  });

  it("_getAuctionPrices", async function () {

    const test_sute = {
      osqthEthPrice: "199226590621515000",
      ethUsdcPrice: "2500000000000000000000",
      auctionTime: "1000000000000000000000",
      _auctionTriggerTime: "9775000000000000000000",
      _isPriceInc: false,
      timestamp: "10000000000000000000000",
    }
    console.log(test_sute);

    const amount = await contract._getAuctionPrices(
      test_sute,
    );
    console.log(">>", amount);

    assert(assertWP(amount[0].toString(), "188269128137332000"), `test_sute: sub 1`)
    assert(assertWP(amount[1].toString(), "2362500000000000000000"), `test_sute: sub 2`)
  });

  it("_getDeltas", async function () {

    const test_sute = {
      osqthEthPrice: "219149249683667000",
      ethUsdcPrice: "2750000000000000000000",
      usdcAmount: "51160624399",
      ethAmount: "20000000000000000000",
      osqthAmount: "0",
    }
    console.log(test_sute);

    const amount = await contract._getDeltas(
      test_sute,
    );
    console.log(">>", amount);

    assert(assertWP(amount[0].toString(), "698068291015541000", 9), `test_sute: sub 1`)
    assert(assertWP(amount[1].toString(), "27836403450722400000000", 6, 18), `test_sute: sub 2`)
    assert(assertWP(amount[2].toString(), "41887449738930900000", 9), `test_sute: sub 3`)
  
  });
});
