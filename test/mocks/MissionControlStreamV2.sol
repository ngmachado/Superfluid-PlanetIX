pragma solidity ^0.8.0;

import {
    ISuperfluid, ISuperToken, SuperAppDefinitions, ISuperAgreement
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {
    IConstantFlowAgreementV1
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import { SuperAppBase } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IMissionControlExtension } from "./../../src/Interfaces/IMissionControlExtension.sol";

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MissionControlStreamV2 is OwnableUpgradeable, SuperAppBase {

    error ZeroAddress();
    error NotCFAv1();
    error NotSuperToken();
    error NotHost();
    error EmptyTiles();

    event TerminationCallReverted(address indexed sender);

    // @dev: function is only called by superfluid contract
    modifier onlyHost() {
        if(msg.sender != address(host)) revert NotHost();
        _;
    }

    // @dev: function can only called if reacting to a CFA stream and super token are allowed
    modifier onlyExpected(ISuperToken superToken, address agreementClass) {
        if(!_isSameToken(superToken)) revert NotSuperToken();
        if(!_isCFAv1(agreementClass)) revert NotCFAv1();
        _;
    }

    ISuperfluid public host;
    IConstantFlowAgreementV1 public cfa;
    ISuperToken public acceptedToken1;
    ISuperToken public acceptedToken2;
    IMissionControlExtension public missionControl;
    bytes32 constant cfaId = keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1");
    // new storage slot, always add new storage variables at the end
    uint256 public counter;

    /* bag struct for local variables to avoid stack too deep error */
    struct RuntimeVars {
        IMissionControlExtension.CollectOrder[] addTiles;
        IMissionControlExtension.CollectOrder[] removeTiles;
        address player;
        int96 oldFlowRate;
        int96 newFlowRate;
    }

    // increment counter by one
    function increment() public {
        counter++;
    }

    // decrement counter by one
    function decrement() public {
        counter--;
    }

    function initialize(
        address _host,
        address _acceptedToken1,
        address _acceptedToken2,
        address _missionControl
    )
    external
    initializer
    {

        if(_host == address(0) ||
            _acceptedToken1 == address(0) ||
            _acceptedToken2 == address(0) ||
            _missionControl == address(0)
        ) revert ZeroAddress();

        host = ISuperfluid(_host);
        cfa = IConstantFlowAgreementV1(address(ISuperfluid(_host).getAgreementClass(cfaId)));
        acceptedToken1 = ISuperToken(_acceptedToken1);
        acceptedToken2 = ISuperToken(_acceptedToken2);
        missionControl = IMissionControlExtension(_missionControl);

        host.registerAppWithKey(
            SuperAppDefinitions.APP_LEVEL_FINAL |
            SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP,
            ""
        );

        __Ownable_init();

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
        RuntimeVars memory vars;
        vars.addTiles = abi.decode(host.decodeCtx(ctx).userData, (IMissionControlExtension.CollectOrder[]));
        if(vars.addTiles.length == 0) revert EmptyTiles();
        vars.player = _getPlayer(agreementData);
        vars.newFlowRate = _getFlowRate(superToken, vars.player);
        // @dev: if missionControl don't want to rent by any reason, it should revert
        missionControl.createRentTiles(address(superToken), vars.player, vars.addTiles, vars.newFlowRate);
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
        cbdata = abi.encode(_getFlowRate(superToken, _getPlayer(agreementData)));
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
        RuntimeVars memory vars;
        // frontend sends two arrays, addTiles to rent and removeTiles to stop renting
        (vars.addTiles, vars.removeTiles) = abi.decode(host.decodeCtx(ctx).userData,
            (
             IMissionControlExtension.CollectOrder[],
             IMissionControlExtension.CollectOrder[]
            )
        );
        if(vars.addTiles.length == 0 && vars.removeTiles.length == 0) revert EmptyTiles();
        vars.player = _getPlayer(agreementData);
        // decode old flow rate from callback data
        vars.oldFlowRate = abi.decode(cbdata, (int96));
        vars.newFlowRate = _getFlowRate(superToken, vars.player);
        // @dev: if missionControl don't want to rent by any reason, it should revert
        missionControl.updateRentTiles(
            address(superToken),
            vars.player,
            vars.addTiles,
            vars.removeTiles,
            vars.oldFlowRate,
            vars.newFlowRate
        );
    }

    function afterAgreementTerminated(
        ISuperToken superToken,
        address agreementClass,
        bytes32, /*agreementId*/
        bytes calldata agreementData,
        bytes calldata, /*cbdata*/
        bytes calldata ctx
    ) external override onlyHost returns (bytes memory) {
        if (!_isSameToken(superToken) || !_isCFAv1(agreementClass)) {
            return ctx;
        }

        // @dev: missionControl shouldn't revert on termination callback. If reverts notify by emitting event
        address player = _getPlayer(agreementData);
        try missionControl.deleteRentTiles(address(superToken), player) {} catch {
            emit TerminationCallReverted(player);
        }
        return ctx;
    }

    function getFlowRate(address superToken, address player) public view returns (int96) {
        return _getFlowRate(ISuperToken(superToken), player);
    }

    //approve another address to move SuperToken on behalf of this contract
    function approve(ISuperToken superToken, address to, uint256 amount) public onlyOwner {
        superToken.approve(to, amount);
    }

    // get player from agreement data
    function _getPlayer(bytes calldata agreementData) internal pure returns (address player) {
        (player,) = abi.decode(agreementData, (address, address));
    }

    function _getFlowRate(ISuperToken superToken, address sender) internal view returns (int96 flowRate) {
        (,flowRate,,) = cfa.getFlow(superToken, sender, address(this));
    }

    function _isSameToken(ISuperToken superToken) private view returns (bool) {
        return address(superToken) == address(acceptedToken1) || address(superToken) == address(acceptedToken2);
    }

    function _isCFAv1(address agreementClass) private view returns (bool) {
        return ISuperAgreement(agreementClass).agreementType() == cfaId;
    }
}