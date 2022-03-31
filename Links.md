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


```
    /**
      @notice withdraws tokens in proportion to the vault's holdings.
      @dev provide strategy tokens, returns set of wETH, USDC, and oSQTH
      @param shares shares burned by sender
      @param amountEthMin revert if resulting amount of wETH is smaller than this
      @param amountUsdcMin revert if resulting amount of USDC is smaller than this
      @param amountOsqthMin revert if resulting amount of oSQTH is smaller than this
     */
    function withdraw(
        uint256 shares,
        uint256 amountEthMin,
        uint256 amountUsdcMin,
        uint256 amountOsqthMin
    )
        external
        override
        nonReentrant
        returns (
            uint256 amountEth,
            uint256 amountUsdc,
            uint256 amountOsqth
        )
    {
        require(shares > 0, "Zero shares");

        uint256 totalSupply = totalSupply();

        _burn(msg.sender, shares);

        //withdraw user share of tokens from the lp positions in current proportion
        (uint256 amountEth0, uint256 amountUsdc) = _burnLiquidityShare(
            Constants.poolEthUsdc,
            orderEthUsdcLower,
            orderEthUsdcUpper,
            shares,
            totalSupply
        );
        (uint256 amountOsqth, uint256 amountEth1) = _burnLiquidityShare(
            Constants.poolEthOsqth,
            orderOsqthEthLower,
            orderOsqthEthUpper,
            shares,
            totalSupply
        );

        //sum up received eth from eth:usdc pool and from osqth:eth pool
        amountEth = amountEth0.add(amountEth1);

        console.log(amountEth);
        console.log(amountUsdc);
        console.log(amountOsqth);
        require(amountEth >= amountEthMin, "amountEthMin");
        require(amountUsdc >= amountUsdcMin, "amountUsdcMin");
        require(amountOsqth >= amountOsqthMin, "amountOsqthMin");

        //send tokens to user
        if (amountEth > 0) Constants.weth.transfer(msg.sender, amountEth);
        if (amountUsdc > 0) Constants.usdc.transfer(msg.sender, amountUsdc);
        if (amountOsqth > 0) Constants.osqth.transfer(msg.sender, amountOsqth);

        //track deposited wETH amount
        //TODO

        emit SharedEvents.Withdraw(msg.sender, shares, amountEth, amountUsdc, amountOsqth);
    }
```