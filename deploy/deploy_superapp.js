/*
 * Usage: npx hardhat deploySuperApp --network <network> --mission <missionControlAddress> --token1 <SuperToken1Address> --token2 <SuperToken2Address>
 * Verify: npx hardhat verify --network <network> <contract address>
 *
 * Notes:
 * You need to have a .env file based on .env-template.
 */

const metadata = require("@superfluid-finance/metadata");

task("deploySuperApp", "Deploy Super App")
    .addParam("mission", "Mission Control")
    .addParam("token1", "Accepted Super Token 1")
    .addParam("token2", "Accepted Super Token 2")
    .setAction(async (taskArgs, hre) => {
        try {

            const chainId = await hre.getChainId();
            const host = metadata.networks.filter((item) => item.chainId == chainId)[0]
                .contractsV1.host;

            console.log(`network: ${hre.network.name}`);
            console.log(`chainId: ${chainId}`);
            console.log(`rpc: ${hre.network.config.url}`);
            console.log(`deployer address: ${(await hre.ethers.getSigners())[0].address}`);
            console.log(`Mission Control: ${taskArgs.mission}`);
            console.log(`Accepted Super Token 1: ${taskArgs.token1}`);
            console.log(`Accepted Super Token 2: ${taskArgs.token2}`);

            // deploy Super App
            const MissionControlStream = await hre.ethers.getContractFactory("MissionControlStream");
            const missionControlStream = await upgrades.deployProxy(MissionControlStream, [host, taskArgs.token1, taskArgs.token2, taskArgs.mission], { kind: "transparent" });
            console.log("MissionControlStream deployed to:", missionControlStream.address);


        } catch (error) {
            console.log(error);
        }
    });

