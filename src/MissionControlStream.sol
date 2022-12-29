pragma solidity ^0.8.0;

import {
    ISuperfluid, ISuperToken, SuperAppDefinitions, ISuperAgreement
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {
    IConstantFlowAgreementV1
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import { SuperAppBase } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// split each operation to a separate function for readability and easier Mission implementation
interface IMissionControl {
    // mission Control PlaceOrder struct
    struct PlaceOrder {
        int x;
        int y;
        int z;
        uint tokenId;
        address tokenAddress;
    }
    // user start streaming to the game
    function createRentTiles(address supertoken, address renter, PlaceOrder[] memory tiles, int96 flowRate) external;
    // user is streaming and change the rented tiles
    function updateRentTiles(address supertoken, address renter, PlaceOrder[] memory addTiles, PlaceOrder[] memory removeTiles, int96 oldFlowRate, int96 flowRate) external;
    // user stop streaming to the game
    function deleteRentTiles(address supertoken, address renter) external;
}

contract MissionControlStream is SuperAppBase, Ownable {

    error ZeroAddress();
    error NotCFAv1();
    error NotSuperToken();
    error NotHost();

    modifier onlyHost() {
        if(msg.sender != address(host)) revert NotHost();
        _;
    }

    modifier onlyExpected(ISuperToken superToken, address agreementClass) {
        if(!_isSameToken(superToken)) revert NotSuperToken();
        if(!_isCFAv1(agreementClass)) revert NotCFAv1();
        _;
    }

    ISuperfluid public host;
    IConstantFlowAgreementV1 public cfa;
    ISuperToken public acceptedToken;
    IMissionControl public missionControl;
    bytes32 constant cfaId = keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1");

    constructor(
        ISuperfluid _host,
        ISuperToken _acceptedToken,
        address _missionControl,
        string memory _registrationKey
    ) {
        if(address(_host) == address(0)) revert ZeroAddress();
        if(address(_acceptedToken) == address(0)) revert ZeroAddress();
        if(_missionControl == address(0)) revert ZeroAddress();

        host = _host;
        cfa = IConstantFlowAgreementV1(address(_host.getAgreementClass(cfaId)));
        acceptedToken = _acceptedToken;
        // set MissionControl contract
        missionControl = IMissionControl(_missionControl);

        uint256 configWord = SuperAppDefinitions.APP_LEVEL_FINAL |
        SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP |
        SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP;
        host.registerAppWithKey(configWord, _registrationKey);
    }

    function afterAgreementCreated(
        ISuperToken superToken,
        address agreementClass,
        bytes32 /*agreementId*/,
        bytes calldata agreementData,
        bytes calldata /*cbdata*/,
        bytes calldata ctx
    )
    external override
    onlyHost
    onlyExpected(superToken, agreementClass)
    returns (bytes memory newCtx)
    {
        newCtx = ctx;
        IMissionControl.PlaceOrder[] memory newTiles =
            abi.decode(host.decodeCtx(ctx).userData, (IMissionControl.PlaceOrder[]));
        address player = _getPlayer(agreementData);
        // @dev: if missionControl don't want to rent by any reason, it should revert
        missionControl.createRentTiles(address(superToken), player, newTiles, _getFlowRate(player));
    }

    function beforeAgreementUpdated(
        ISuperToken superToken,
        address /*agreementClass*/,
        bytes32 /*agreementId*/,
        bytes calldata agreementData,
        bytes calldata /*ctx*/
    )
    external
    view
    virtual
    override
    returns (bytes memory cbdata)
    {
        cbdata = abi.encode(_getFlowRate(_getPlayer(agreementData)));
    }

    function afterAgreementUpdated(
        ISuperToken superToken,
        address agreementClass,
        bytes32 /*agreementId*/,
        bytes calldata agreementData,
        bytes calldata cbdata,
        bytes calldata ctx
    ) external override
    onlyHost
    returns(bytes memory newCtx) {
        if(!_isCFAv1(agreementClass)) revert NotCFAv1();
        newCtx = ctx;
        // front end sends two arrays, newTiles to rent and oldTiles to remove
        (IMissionControl.PlaceOrder[] memory addTiles, IMissionControl.PlaceOrder[] memory removeTiles) =
        abi.decode(host.decodeCtx(ctx).userData, (IMissionControl.PlaceOrder[], IMissionControl.PlaceOrder[]));
        // @dev: if missionControl don't want to rent by any reason, it should revert
        address player = _getPlayer(agreementData);
        // decode old flow rate from callback data
        int96 oldFlowRate = abi.decode(cbdata, (int96));
        // also send old flow rate
        missionControl.updateRentTiles(
            address(superToken),
            player,
            addTiles,
            removeTiles,
            oldFlowRate,
            _getFlowRate(player)
        );
    }

    function afterAgreementTerminated(
        ISuperToken superToken,
        address agreementClass,
        bytes32, /*agreementId*/
        bytes calldata agreementData,
        bytes calldata, /*cbdata*/
        bytes calldata ctx
    ) external override onlyHost returns (bytes memory newCtx) {
        if (superToken != acceptedToken || agreementClass != address(cfa)) {
            return ctx;
        }
        try missionControl.deleteRentTiles(address(superToken), _getPlayer(agreementData)) {} catch {}
        return ctx;
    }

    function getFlowRate(address player) public view returns (int96) {
        return _getFlowRate(player);
    }

    //approve another address to move SuperToken on behalf of this contract
    function approve(address to, uint256 amount) public onlyOwner {
        acceptedToken.approve(to, amount);
    }

    // get player from agreement data
    function _getPlayer(bytes calldata agreementData) internal pure returns (address player) {
        (player,) = abi.decode(agreementData, (address, address));
    }

    function _getFlowRate(address sender) internal view returns (int96 flowRate) {
            (,flowRate,,) = cfa.getFlow(acceptedToken, sender, address(this));
    }

    function _isSameToken(ISuperToken superToken) private view returns (bool) {
        return address(superToken) == address(acceptedToken);
    }

    function _isCFAv1(address agreementClass) private view returns (bool) {
        return ISuperAgreement(agreementClass).agreementType() == cfaId;
    }
}