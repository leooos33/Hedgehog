process.exit(0); // Block file in order to not accidentally deploy

const { ethers } = require("hardhat");
const { utils } = ethers;
const { BigNumber } = require("ethers");
const { _vaultStorageAddressV2 } = require("../../test/common/index");

const deposit = async () => {
    let tx;
    let MyContract = await ethers.getContractFactory("VaultStorage");
    const VaultStorage = await MyContract.attach(_vaultStorageAddressV2);

    // tx = await VaultStorage.setRebalanceTimeThreshold(500000, { nonce: 1 });
};

deposit().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
