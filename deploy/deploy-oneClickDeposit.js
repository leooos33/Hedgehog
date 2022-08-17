process.exit(0); // Block file in order to not accidentally deploy

const { deployContract } = require("./common");

const deploy = async () => {
    const Contract = await deployContract("OneClickDeposit", [], false);
    console.log(Contract.address);
};

deploy().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
