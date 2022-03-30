```
  it("Should deposit", async function () {

    const wethInput = utils.parseUnits("2", 18).toString();
    const usdcInput = utils.parseUnits("2", 18).toString();
    const osqthInput = utils.parseUnits("2", 18).toString();

    await getWETH(wethInput, contract.address);
    
    expect(await getERC20Balance(contract.address, wethAddress)).to.equal("0");
    expect(await getERC20Balance(contract.address, usdcAddress)).to.equal("0");
    expect(await getERC20Balance(contract.address, osqthAddress)).to.equal("0");
  });
```

// console.log(await getERC20Allowance(depositor.address, contract.address, wethAddress));