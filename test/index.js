const { expect } = require("chai");
const { ethers } = require("hardhat");
const { utils } = ethers;

describe("Vault", function () {
  it("Should deploy", async function () {
    const Contract = await ethers.getContractFactory("Vault");
    const contract = await Contract.deploy(
      utils.parseUnits("40", 18),
      "0x8ad599c3a0ff1de082011efddc58f1908eb6e6d8",
      "0x82c427adfdf2d245ec51d8046b41c4ee87f0d29c",
      "0x65d66c76447ccb45daf1e8044e918fa786a483a1",
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
});
