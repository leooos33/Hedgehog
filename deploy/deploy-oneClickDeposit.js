process.exit(0); // Block file in order to not accidentally deploy

const { _vaultAddressV2, _oneClickDepositAddressV2, _oneClickWithdrawAddressV2 } = require("../test/common");
const { deployContract } = require("./common");

const deploy = async () => {
    // const Contract = await deployContract("OneClickDeposit", [], false);
    // console.log(Contract.address);

    const Contract = await ethers.getContractAt("OneClickWithdraw", _oneClickWithdrawAddressV2);
    tx = await Contract.setContracts(_vaultAddressV2);
};

deploy().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
