/*
 * Usage: npx hardhat deploy --network <network>
 *
 * Notes:
 * You need to have a .env file based on .env-template.
 * If verification fails, you can run again this script to verify later.
 */

const metadata = require("@superfluid-finance/metadata");

const sleep = (waitTimeInMs) =>
    new Promise((resolve) => setTimeout(resolve, waitTimeInMs));

module.exports = async function ({ deployments, getNamedAccounts }) {
    const chainId = await hre.getChainId();
    const host = metadata.networks.filter((item) => item.chainId == chainId)[0]
        .contractsV1.host;
    const registrationKey = "";
    if (host === undefined) {
        console.log("Host contract not found for this network");
        return;
    }

    // AGOLD Token
    const superTokenA = "0x3CAD7147c15C0864B8cF0EcCca43f98735e6e782";
    // ALITE Token
    const superTokenB = "0x39161eb4Ce381d92a472Dfc88dA033700C14D49D";
    //new MC
    const missionControl = "0x421f672626c253462521AD7616Df4622bbC51523";

    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    console.log(`network: ${hre.network.name}`);
    console.log(`chainId: ${chainId}`);
    console.log(`rpc: ${hre.network.config.url}`);
    console.log(`host: ${host}`);

    const MissionControlStream = await deploy("MissionControlStream", {
        from: deployer,
        args: [host, superTokenA, superTokenB, missionControl, registrationKey],
        log: true,
        skipIfAlreadyDeployed: false,
    });

    // wait for 15 seconds to allow etherscan to indexed the contracts
    await sleep(15000);

    try {
        await hre.run("verify:verify", {
            address: MissionControlStream.address,
            constructorArguments: [host, superTokenA, superTokenB, missionControl, registrationKey],
            contract: "src/MissionControlStream.sol:MissionControlStream",
        });
    } catch (err) {
        console.error(err);
    }
};
