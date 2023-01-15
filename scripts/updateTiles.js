const { ethers } = require("ethers");

const MissionControlStreamABI = require("../artifacts/src/MissionControlStream.sol/MissionControlStream.json");
const ISuperfluid = require("@superfluid-finance/ethereum-contracts/build/contracts/ISuperfluid");
const IConstantFlowAgreementV1 = require("@superfluid-finance/ethereum-contracts/build/contracts/IConstantFlowAgreementV1");
const ISuperToken = require("@superfluid-finance/ethereum-contracts/build/contracts/ISuperToken");

// price per second for each tile
const flowRate = "385802469135";

const hostAddress = "0xEB796bdb90fFA0f28255275e16936D25d3418603";
const cfaAddress = "0x49e565Ed1bdc17F3d220f72DF0857C26FA83F873";

const missionAddress = "0xf2cef2CF8ddc8b8e0E16d7995A58F8aAf435FF24";
const superTokenAddress = "0x934aedA8514B6d3f1Aa8B0B9f7d050907B6d6EAD";

let cfaV1, host, superApp, wallet, superToken;


function INIT() {
    if(wallet === undefined) throw("set global wallet first...");
    host = new ethers.Contract(hostAddress, ISuperfluid.abi, wallet);
    cfaV1 = new ethers.Contract(cfaAddress, IConstantFlowAgreementV1.abi, wallet);
    superApp = new ethers.Contract(missionAddress, MissionControlStreamABI.abi, wallet);
    superToken = new ethers.Contract(superTokenAddress, ISuperToken.abi, wallet);
}

const encode = (newX, newY, newZ, tokenId, tokenAddress, removeX, removeY, removeZ) => {
    return ethers.utils.defaultAbiCoder.encode( ["tuple(int256, int256, int256, uint256, address)[]", "tuple(int256, int256, int256)[]" ],
        [
            [[newX, newY, newZ, tokenId, tokenAddress]],
            [[removeX, removeY, removeZ]]

        ]);
}


(async () => {
    // Configurations
    const url = "RPC_URL";
    const provider = new ethers.providers.JsonRpcProvider(url);
    const privateKey = "0xPRIVATE_KEY";
    wallet = new ethers.Wallet(privateKey, provider);

    // instance contracts
    INIT();

    //encode userData to send with stream. userData = PlaceOrder[]
    let userData = encode(0,-2,2, 7, "0xF8a6a111daD517C56942A5BE4521163737003FF8", 0,-2,2,);

    // call superApp
    const callData = cfaV1.interface.encodeFunctionData("updateFlow", [
        superTokenAddress,
        missionAddress,
        flowRate,
        "0x",
    ]);
    const tx = await host.connect(wallet).callAgreement(cfaAddress, callData, userData);
    console.log(tx);
})();