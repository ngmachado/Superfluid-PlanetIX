/*
 * Usage: npx hardhat upgradeSuperApp --network <network> --superApp <superAppAddr>
 * Verify: npx hardhat verify --network <network> <contract address>
 *
 * Notes:
 * You need to have a .env file based on .env-template.
 */

const metadata = require("@superfluid-finance/metadata");

task("upgradeSuperApp", "Upgrade Super App")
    .addParam("superapp", "Super App")
    .setAction(async (taskArgs, hre) => {
        try {

            const chainId = await hre.getChainId();
            console.log(`network: ${hre.network.name}`);
            console.log(`chainId: ${chainId}`);
            console.log(`rpc: ${hre.network.config.url}`);
            console.log(`deployer address: ${(await hre.ethers.getSigners())[0].address}`);
            console.log(`Super App: ${taskArgs.superapp}`);

            // deploy Super App
            const MissionControlStream = await hre.ethers.getContractFactory("MissionControlStream");
            const missionControlStream = await upgrades.upgradeProxy(taskArgs.superapp, MissionControlStream);
            console.log("MissionControlStream deployed to:", missionControlStream.address);


        } catch (error) {
            console.log(error);
        }
    });

