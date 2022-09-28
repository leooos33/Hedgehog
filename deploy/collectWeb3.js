process.exit(0); // Block file in order to not accidentally deploy

const Web3 = require("Web3");
const { utils } = require("ethers");
const { IFURA_MAINNET_URL, MAINNET_DEPLOYMENT_KEY_OLD } = require("../shared/config");
const IRebalancer = require("./abi/IRebalancer.json");

const populate = async () => {
    const web3 = new Web3(new Web3.providers.HttpProvider(IFURA_MAINNET_URL));
    const Rebalancer = new web3.eth.Contract(IRebalancer, "0x412AfCc7A3Ee9589bdC883cB8F2dEe7E41CF0b14");

    const me = "0x42B1299fCcA091A83C08C24915Be6E6d63906b1a";

    // const SOME_SIGNER_TO_SEND_FROM = web3.eth.accounts.privateKeyToAccount(MAINNET_DEPLOYMENT_KEY_OLD);
    // console.log(SOME_SIGNER_TO_SEND_FROM);

    const tx = {
        gasPrice: 12000000000,
        to: "0x412AfCc7A3Ee9589bdC883cB8F2dEe7E41CF0b14",
        gas: 100000,
        data: Rebalancer.methods.collectProtocol(utils.parseUnits("0.001", 18).toString(), "0", "0", me).encodeABI(),
        nonce: 43,
    };

    const signPromise = web3.eth.accounts.signTransaction(tx, MAINNET_DEPLOYMENT_KEY_OLD);

    signPromise
        .then((signedTx) => {
            const sentTx = web3.eth.sendSignedTransaction(signedTx.raw || signedTx.rawTransaction);
            sentTx.on("receipt", (receipt) => {
                console.log(receipt);
            });
            sentTx.on("error", (err) => {
                console.log(err);
            });
        })
        .catch((err) => {
            console.log("Unexpected:", err);
        });
};
populate();
