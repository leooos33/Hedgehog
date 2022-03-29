import { expect } from "chai";
import { ethers } from "hardhat";

describe("Vault", function () {
  it("Should deploy", async function () {
    const Contract = await ethers.getContractFactory("Vault");
    const contract = await Contract.deploy(
      10 ** 18 * 40,
      "0x8ad599c3a0ff1de082011efddc58f1908eb6e6d8",
      "0x82c427adfdf2d245ec51d8046b41c4ee87f0d29c",
      "0x65d66c76447ccb45daf1e8044e918fa786a483a1",//_oracleEthUsdc,
      "0x65d66c76447ccb45daf1e8044e918fa786a483a1",//_oracleOsqthEth,
      1000,
      0.05 * (10 ** 18),
      100,
      0.95 * (10 ** 18),
      1.05 * (10 ** 18),
      0.5 * (10 ** 18),
      0.2622 * (10 ** 18),
      0.2378 * (10 ** 18),
    );
    await contract.deployed();
  });
});
