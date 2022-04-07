const path = require('path');
const fs = require('fs');
const dotenv = require('dotenv');

const envDir = path.join(__dirname, '.env');
const { ALCHEMY_KEY } = dotenv.parse(fs.readFileSync(envDir));

const getForkingParams = (blockNumber = 14487787) => {
    return {
        url: `https://eth-mainnet.alchemyapi.io/v2/${ALCHEMY_KEY}`,
        blockNumber,
    };
}

const getResetParams = (blockNumber = 14487787) => {
    return {
        jsonRpcUrl: `https://eth-mainnet.alchemyapi.io/v2/${ALCHEMY_KEY}`,
        blockNumber,
    };
}

module.exports = {
    getForkingParams,
    getResetParams
}