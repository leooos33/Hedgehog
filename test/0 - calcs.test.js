const { assert } = require("chai");
const { ethers } = require("hardhat");
const { utils } = ethers;
const { assertWP } = require('./helpers');

describe("Calcs", function () {
  let contract, tx;
  it("Should deploy contract", async function () {
    const Contract = await ethers.getContractFactory("VaultMath");
    contract = await Contract.deploy(
        utils.parseUnits("40", 18),
        1000,
        utils.parseUnits("0.05", 18),
        "1000000000000000000000",
        "900000000000000000",
        "1100000000000000000",
        "500000000000000000",
        "262210246107746000",
        "237789753892254000",
    );
    await contract.deployed();
  });

  it("__calcSharesAndAmounts case 1", async function () {

    const test_sute = {
      targetEthShare: "500000000000000000",
      targetUsdcShare: "262210246107746000",
      targetOsqthShare: "237789753892254000",
      totalSupply: "0",
      _amountEth: "10000000000000000000",
      _amountUsdc: "13110512305",
      _amountOsqth: "23871300000000000000",
      osqthEthPrice: "211180000000000000",
      ethUsdcPrice: "2650000000000000000000",
      usdcAmount: "41326682043",
      ethAmount: "19855700000000000000",
      osqthAmount: "17933300000000000000",
    }
    console.log(test_sute);

    const amount = await contract.__calcSharesAndAmounts(
      test_sute,
    );
    console.log(">>", amount);

    assert(assertWP(amount[0].toString(), "52969536310487300000000"), `test_sute: sub 1`)
    assert(assertWP(amount[1].toString(), "9994252134054210000"), `test_sute: sub 2`)
    assert(assertWP(amount[2].toString(), "13889155152", 4, 6), `test_sute: sub 3`)
    assert(assertWP(amount[3].toString(), "22507157451405300000"), `test_sute: sub 4`)
  });

  it("__calcSharesAndAmounts case 2", async function () {

    const test_sute = {
      targetEthShare: "500000000000000000",
      targetUsdcShare: "262210246107746000",
      targetOsqthShare: "237789753892254000",
      totalSupply: "1000000000000000000000000",
      _amountEth: "10000000000000000000",
      _amountUsdc: "13110512305",
      _amountOsqth: "23871300000000000000",
      osqthEthPrice: "211180000000000000",
      ethUsdcPrice: "2650000000000000000000",
      usdcAmount: "41326682043",
      ethAmount: "19855700000000000000",
      osqthAmount: "17933300000000000000",
    }
    console.log(test_sute);

    const amount = await contract.__calcSharesAndAmounts(
      test_sute,
    );
    console.log(">>", amount);

    assert(assertWP(amount[0].toString(), "509419225163916000000000"), `test_sute: sub 1`)
    assert(assertWP(amount[1].toString(), "10114875309087200000"), `test_sute: sub 2`)
    assert(assertWP(amount[2].toString(), "21052606345", 4, 6), `test_sute: sub 3`)
    assert(assertWP(amount[3].toString(), "9135567790632050000"), `test_sute: sub 4`)
  });

  it("__getAuctionPrices", async function () {

    const test_sute = {
      osqthEthPrice: "199226590621515000",
      ethUsdcPrice: "2500000000000000000000",
      auctionTime: "1000000000000000000000",
      _auctionTriggerTime: "9775000000000000000000",
      _isPriceInc: false,
      timestamp: "10000000000000000000000",
    }
    console.log(test_sute);

    const amount = await contract.__getAuctionPrices(
      test_sute,
    );
    console.log(">>", amount);

    assert(assertWP(amount[0].toString(), "188269128137332000"), `test_sute: sub 1`)
    assert(assertWP(amount[1].toString(), "2362500000000000000000"), `test_sute: sub 2`)
  });

  it("__getDeltas", async function () {

    const test_sute = {
      osqthEthPrice: "219149249683667000",
      ethUsdcPrice: "2750000000000000000000",
      usdcAmount: "51160624399",
      ethAmount: "20000000000000000000",
      osqthAmount: "0",
    }
    console.log(test_sute);

    const amount = await contract.__getDeltas(
      test_sute,
    );
    console.log(">>", amount);

    assert(assertWP(amount[0].toString(), "698068291015541000", 9), `test_sute: sub 1`)
    assert(assertWP(amount[1].toString(), "23324220948", 4, 6), `test_sute: sub 2`)
    assert(assertWP(amount[2].toString(), "41887449738930900000", 9), `test_sute: sub 3`)
  });

  it("__getAuctionPrices", async function () {

    const test_sute = {
      osqthEthPrice: "199226590621515000",
      ethUsdcPrice: "2500000000000000000000",
      auctionTime: "1000000000000000000000",
      _auctionTriggerTime: "1632160192",
      _isPriceInc: false,
      timestamp: "1648646659",
    }
    console.log(test_sute);

    const amount = await contract.__getAuctionPrices(
      test_sute,
    );
    console.log(">>", amount);

    assert(assertWP(amount[0].toString(), "179303931559364000"), `test_sute: sub 1`)
    assert(assertWP(amount[1].toString(), "2250000000000010000000"), `test_sute: sub 2`)
  });

  it("__getDeltas", async function () {

    const test_sute = {
      osqthEthPrice: "3051898194732165000000",
      ethUsdcPrice: "243207708904178100",
      usdcAmount: "24972947408",
      ethAmount: "14748768501230203130",
      osqthAmount: "27296229334056607430",
    }
    console.log(test_sute);

    const amount = await contract.__getDeltas(
      test_sute,
    );
    console.log(">>", amount);

    assert(assertWP(amount[0].toString(), "92986063062278283012528", 9), `test_sute: sub 1`)
    assert(assertWP(amount[1].toString(), "13111334969", 4, 6), `test_sute: sub 2`)
    assert(assertWP(amount[2].toString(), "12803845416930781791", 9), `test_sute: sub 3`)
  });
});