// process.exit(0); // Block file in order to not accidentally deploy

const Web3 = require("Web3");
const { IFURA_MAINNET_URL } = require("../shared/config");
const IRebalancer = require("./abi/IRebalancer.json");

const populate = async () => {
    const web3 = new Web3(new Web3.providers.HttpProvider(IFURA_MAINNET_URL));
    const Rebalancer = new web3.eth.Contract(IRebalancer, "0x09b1937D89646b7745377f0fcc8604c179c06aF5");

    const addressAuction = await Rebalancer.methods.addressAuction().call();
    console.log(addressAuction);
};
populate();
