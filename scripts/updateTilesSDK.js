const { ethers } = require("ethers");
const { Framework } = require("@superfluid-finance/sdk-core");

const MissionControlStreamABI = require("../artifacts/src/MissionControlStream.sol/MissionControlStream.json");
const ISuperfluid = require("@superfluid-finance/ethereum-contracts/build/contracts/ISuperfluid");
const IConstantFlowAgreementV1 = require("@superfluid-finance/ethereum-contracts/build/contracts/IConstantFlowAgreementV1");
const ISuperToken = require("@superfluid-finance/ethereum-contracts/build/contracts/ISuperToken");

// price per second for each tile
const flowRate = "385802469135";

const missionAddress = "0xf2cef2CF8ddc8b8e0E16d7995A58F8aAf435FF24";
const superTokenAddress = "0x934aedA8514B6d3f1Aa8B0B9f7d050907B6d6EAD";

let sf, cfaV1, host, superApp, wallet, superToken;

//NOTE
//Requires @superfluid-finance/sdk-core and graphql as dependencies
//Initialize framework with Framework.create
//create an operation, then exec the operation like so:
//const createFlowOperation = superToken.createFlow({params...}) - note that userData is a param that is passed here
//await createFlowOperation.exec(signer)
async function INIT() {
    if(wallet === undefined) throw("set global wallet first...");
    sf = await Framework.create({
        chainId: (await provider.getNetwork()).chainId,
        provider
    });
    host = sf.contracts.host.connect(wallet);
    cfaV1 = sf.contracts.cfaV1.connect(wallet);
    superApp = new ethers.Contract(missionAddress, MissionControlStreamABI.abi, wallet);
    //Load the Super Token 
    //Note that this can also be done by passing the symbol of the super token as a string to sf.loadSuperToken() 
    //like this: sf.loadSuperToken("DAIx"), etc
    superToken = await sf.loadSuperToken(superTokenAddress);
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

    //create operation
    const updateFlowOperation = superToken.updateFlow({
        receiver: missionAddress,
        flowRate,
        userData
    });
      
    //execute operation
    const tx = await updateFlowOperation.exec(wallet);

    console.log(tx);
})();