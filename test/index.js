const { expect } = require("chai");
const { ethers } = require("hardhat");
const { utils } = ethers;
const { getERC20Balance, getWETH, approveERC20, getERC20Allowance } = require('./helpers');
const { wethAddress, usdcAddress, osqthAddress } = require('./common');

describe("Vault", function () {
  let contract, tx;
  it("Should deploy", async function () {
    const Contract = await ethers.getContractFactory("Vault");
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

  // it("Should deposit", async function () {
  //   const depositor = (await ethers.getSigners())[3];
  //   const wethInput = utils.parseUnits("2", 18).toString();
    
  //   await getWETH(wethInput, depositor.address);
  //   expect(await getERC20Balance(depositor.address, wethAddress)).to.equal(wethInput);

  //   await approveERC20(depositor, contract.address, wethInput, wethAddress);

  //   tx = await contract.connect(depositor).deposit(wethInput);
  //   await tx.wait();

  //   // Balances
  //   expect(await getERC20Balance(depositor.address, wethAddress)).to.equal("0");
  //   expect(await getERC20Balance(contract.address, wethAddress)).to.equal(wethInput);

  //   // Shares
  //   expect(await getERC20Balance(depositor.address, contract.address)).to.equal(wethInput);
    
  //   // Meta
  //   expect(await contract.totalEthDeposited()).to.equal(wethInput);
  // });

  // it("Should withdraw", async function () {
  //   const depositor = (await ethers.getSigners())[3];
  //   const sharesInput = utils.parseUnits("2", 18).toString();
    
  //   tx = await contract.connect(depositor).withdraw(sharesInput, 0, 1, 1);
  //   await tx.wait();

  //   // Balances
  //   expect(await getERC20Balance(depositor.address, wethAddress)).to.equal("0", "test 1");
  //   expect(await getERC20Balance(contract.address, wethAddress)).to.equal("0", "test 2");

  //   // Shares
  //   expect(await getERC20Balance(depositor.address, contract.address)).to.equal("0", "test 3");
    
  //   // Meta
  //   expect(await contract.totalEthDeposited()).to.equal("2000000000000000000", "test 4");
  // });
});
