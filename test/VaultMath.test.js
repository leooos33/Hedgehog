const { assert } = require("chai");
const { ethers } = require("hardhat");
const { poolEthUsdc, poolEthOsqth } = require("./common");
const { utils } = ethers;
const { assertWP } = require('./helpers');

describe("VaultMath", function () {
  let contract, tx;
  it("Should deploy contract", async function () {
    const Contract = await ethers.getContractFactory("VaultMath");
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

  it("_floor", async function () {

    const test_sute = [
      "195031",
      "60"
    ];
    console.log(test_sute);

    const amount = await contract._floor(
      ...test_sute,
    );
    console.log(">>", amount);

    assert(amount.toString() == "195000", `should not fail`);
  });


  it("_floor", async function () {

    const test_sute = [
      "13223",
      "60"
    ];
    console.log(test_sute);

    const amount = await contract._floor(
      ...test_sute,
    );
    console.log(">>", amount);

    assert(amount.toString() == "13200", `should not fail`);
  });


  it("getTick", async function () {

    const amount = await contract.getTick(poolEthUsdc);
    console.log(">>", amount);

    assert(amount.toString() == "195031", `should not fail`);
  });

  it("getTick", async function () {

    const amount = await contract.getTick(poolEthOsqth);
    console.log(">>", amount);

    assert(amount.toString() == "13223", `should not fail`);
  });

  it("_getBoundaries", async function () {

    const amount = await contract._getBoundaries();
    console.log(">>", amount);

    assert(amount[0].toString() == "193980", `test_sute: sub 1`);
    assert(amount[1].toString() == "196080", `test_sute: sub 2`);
    assert(amount[2].toString() == "12180", `test_sute: sub 3`);
    assert(amount[3].toString() == "14280", `test_sute: sub 4`);
  });
});