process.exit(0); // Block file in order to not accidentally deploy
const { deployContract } = require("./common");

const deploy = async () => {
    const RescueTeam = await deployContract("RescueTeam", [], false);
    console.log(RescueTeam.address);
};

deploy().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
