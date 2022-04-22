const { expect } = require("chai");
const { loadTestDataset, toWEIS, toWEI } = require("../helpers");

const { _calcSharesAndAmounts } = require("./_calcSharesAndAmounts");

const auditCalcSharesAndAmounts = async () => {
    const testsDs = await loadTestDataset("_calcSharesAndAmounts");

    for (let i in testsDs) {
        let test_sute = { ...testsDs[i] };

        console.log(test_sute);
        test_sute = {
            totalSupply: toWEI(test_sute.totalSupply),
            _amountEth: toWEI(test_sute._amountEth),
            _amountUsdc: toWEI(test_sute._amountUsdc, 6),
            _amountOsqth: toWEI(test_sute._amountOsqth),
            osqthEthPrice: toWEI(test_sute.osqthEthPrice),
            ethUsdcPrice: toWEI(test_sute.ethUsdcPrice),
            usdcAmount: toWEI(test_sute.usdcAmount, 6),
            ethAmount: toWEI(test_sute.ethAmount),
            osqthAmount: toWEI(test_sute.osqthAmount),
        };
        console.log(test_sute);

        const amount = await _calcSharesAndAmounts(test_sute);
        console.log(amount);

        expect(amount[0].toString()).to.equal(toWEIS(testsDs[i].shares), `test_sute ${i}: sub 1`);
        expect(amount[1].toString()).to.equal(toWEIS(testsDs[i].amountEth), `test_sute ${i}: sub 2`);
        expect(amount[2].toString()).to.equal(toWEIS(testsDs[i].amountUsdc, 6), `test_sute ${i}: sub 3`);
        expect(amount[3].toString()).to.equal(toWEIS(testsDs[i].amountOsqth), `test_sute ${i}: sub 4`);
    }
};

const auditAll = async () => {
    await auditCalcSharesAndAmounts();
};

// auditAll();
