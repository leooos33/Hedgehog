const { ethers } = require("hardhat");
const { utils } = ethers;
const { BigNumber } = require("ethers");

module.exports = [
    utils.parseUnits("100", 18),
    BigNumber.from(43200),
    utils.parseUnits("0.1", 18),
    BigNumber.from("600"),
    BigNumber.from("950000000000000000"),
    BigNumber.from("1050000000000000000"),
    BigNumber.from("0"),
    "0x42B1299fCcA091A83C08C24915Be6E6d63906b1a",
];
