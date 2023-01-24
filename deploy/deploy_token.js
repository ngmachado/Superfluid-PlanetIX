/*
 * Usage: npx hardhat deployToken --network <network>
 * Verify: npx hardhat verify --network <network> <contract address>
 *
 * Notes:
 * You need to have a .env file based on .env-template.
 */

const metadata = require("@superfluid-finance/metadata");
task("deployToken", "Deploy Pure Super Token")
    .setAction(async (taskArgs, hre) => {
        try {

            const chainId = await hre.getChainId();
            const superTokenFactoryAddr = metadata.networks.filter((item) => item.chainId == chainId)[0]
                .contractsV1.superTokenFactory;
            console.log(`network: ${hre.network.name}`);
            console.log(`chainId: ${chainId}`);
            console.log(`rpc: ${hre.network.config.url}`);
            console.log(`deployer address`, (await hre.ethers.getSigners())[0].address);
            console.log("superTokenFactory", superTokenFactoryAddr);

            // deploy MintablePureSuperToken Logic Contract
            const GoldLiteProxy = await hre.ethers.getContractFactory("GoldLiteProxy");
            const goldLiteProxy = await GoldLiteProxy.deploy();

            // initialize MintablePureSuperToken Contract
            await goldLiteProxy.initialize(
                superTokenFactoryAddr,
                "Astro Gold Lite",
                "ALITE",
                (await hre.ethers.getSigners())[0].address
            );

            console.log("GoldLiteProxy deployed to:", goldLiteProxy.address);
        } catch (error) {
            console.log(error);
        }
    });

