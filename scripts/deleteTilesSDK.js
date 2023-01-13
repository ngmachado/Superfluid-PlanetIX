const { ethers } = require("ethers");
const { Framework } = require("@superfluid-finance/sdk-core");

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

//NOTE
//Requires @superfluid-finance/sdk-core and graphql as dependencies
//Initialize framework with Framework.create
//create an operation, then exec the operation like so:
//const createFlowOperation = superToken.createFlow({params...}) - note that userData is a param that is passed here
//await createFlowOperation.exec(signer)
function INIT() {
    if(wallet === undefined) throw("set global wallet first...");
    host = new ethers.Contract(hostAddress, ISuperfluid.abi, wallet);
    cfaV1 = new ethers.Contract(cfaAddress, IConstantFlowAgreementV1.abi, wallet);
    superApp = new ethers.Contract(missionAddress, MissionControlStreamABI.abi, wallet);
    superToken = new ethers.Contract(superTokenAddress, ISuperToken.abi, wallet);
}

const encodePlaceOrder = (x, y, z, tokenId, tokenAddress) => {
    return ethers.utils.defaultAbiCoder.encode( [ "tuple(int256, int256, int256, uint256, address)[]" ],
        [[[x, y, z, tokenId, tokenAddress]]]);
}


(async () => {
    // Configurations
    var url = "RPC_URL";
    var provider = new ethers.providers.JsonRpcProvider(url);
    var privateKey = "0xPRIVATE_KEY";
    wallet = new ethers.Wallet(privateKey, provider);

    const sf = await Framework.create({
        chainId: (await provider.getNetwork()).chainId,
        provider
    })
    // instance contracts
    INIT();

    //Load the Super Token 
    //Note that this can also be done by passing the symbol of the super token as a string to sf.loadSuperToken() 
    //like this: sf.loadSuperToken("DAIx"), etc
    const superToken = await sf.loadSuperToken(superTokenAddress);

    //create operation
    const deleteFlowOperation = superToken.deleteFlow({
        sender: wallet.address,
        receiver: missionAddress
    });

    //execute operation
    const tx = await deleteFlowOperation.exec(wallet);

    console.log(tx);
})();