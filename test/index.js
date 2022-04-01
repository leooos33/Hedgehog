const { expect, util } = require("chai");
const { ethers } = require("hardhat");
const { utils, BigNumber } = ethers;
const { loadTestDataset, toWEIS, getERC20Balance, getWETH, approveERC20, getERC20Allowance, getUSDC, getOSQTH } = require('./helpers');
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

  it("Should calculate", async function () {

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
        ethUsdcPrice: toWEIS(test_sute.ethUsdcPrice, 6),
        usdcAmount: toWEIS(test_sute.usdcAmount, 6),
        ethAmount: toWEIS(test_sute.ethAmount),
        osqthAmount: toWEIS(test_sute.osqthAmount),
      }
      console.log(test_sute);

      const amount = await contract._calcSharesAndAmounts(
        test_sute,
      );
      console.log(amount);

      expect(amount[0].toString()).to.equal(toWEIS(testsDs[i].shares), `test_sute ${i}: sub 1`);
      expect(amount[1].toString()).to.equal(toWEIS(testsDs[i].amountEth), `test_sute ${i}: sub 2`);
      expect(amount[2].toString()).to.equal(toWEIS(testsDs[i].amountUsdc, 6), `test_sute ${i}: sub 3`);
      expect(amount[3].toString()).to.equal(toWEIS(testsDs[i].amountOsqth), `test_sute ${i}: sub 4`);
    }



    // // expect(amount.toString()).to.equal("1807878779577599762727898140000000000000000000000002000000,266539217285974315000000000000000000000000000000000294,474025816005246657787254892308000000000000000000000524400000000000000000000,475600000000000001784352804974740098", "test 1");

    // const arr = amount.toString().split(',');
    // console.log(utils.formatUnits(BigNumber.from(arr[0]), 18));
    // console.log(utils.formatUnits(BigNumber.from(arr[1]), 18));
    // console.log(utils.formatUnits(BigNumber.from(arr[2]), 6));
    // console.log(utils.formatUnits(BigNumber.from(arr[3]), 18));
  });

  // it("Should deposit", async function () {
  //   const depositor = (await ethers.getSigners())[3];

  //   const wethInput = "266539217285974315000000000000000000000000000000000294"
  //   const usdcInput = "474025816005246657787254892308000000000000000000000524400000000000000000000"
  //   const osqthInput = utils.parseUnits("2", 18).toString();

  //   await getWETH(wethInput, depositor.address);
  //   await getUSDC(usdcInput, depositor.address);
  //   await getOSQTH(osqthInput, depositor.address);

  //   expect(await getERC20Balance(depositor.address, wethAddress)).to.equal(wethInput);
  //   expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal(usdcInput);
  //   expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal(osqthInput);

  //   await approveERC20(depositor, contract.address, wethInput, wethAddress);
  //   await approveERC20(depositor, contract.address, usdcInput, usdcAddress);
  //   await approveERC20(depositor, contract.address, osqthInput, osqthAddress);

  //   // tx = await contract.connect(depositor).deposit(wethInput);
  //   // await tx.wait();

  //   // // Balances
  //   // expect(await getERC20Balance(depositor.address, wethAddress)).to.equal("0");
  //   // expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal("0");
  //   // expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal("0");

  //   // expect(await getERC20Balance(contract.address, wethAddress)).to.equal(wethInput);
  //   // expect(await getERC20Balance(contract.address, usdcAddress)).to.equal(usdcInput);
  //   // expect(await getERC20Balance(contract.address, osqthAddress)).to.equal(osqthInput);

  //   // // Shares
  //   // expect(await getERC20Balance(depositor.address, contract.address)).to.equal(wethInput);

  //   // // Meta
  //   // expect(await contract.totalEthDeposited()).to.equal(wethInput);
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
