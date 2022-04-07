const path = require('path');
const fs = require('fs');
const dotenv = require('dotenv');

const envDir = path.join(__dirname, '.env');
const { ALCHEMY_KEY } = dotenv.parse(fs.readFileSync(envDir));

const getForkingParams = () => {
    return {
        url: `https://eth-mainnet.alchemyapi.io/v2/${ALCHEMY_KEY}`,
        lockNumber: 14487787,
    };
}

module.exports = {
    getForkingParams,
}