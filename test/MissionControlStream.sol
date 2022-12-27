pragma solidity ^0.8.0;

import "forge-std/Console.sol";
import { ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";
import { SuperfluidFrameworkDeployer, SuperfluidTester, Superfluid, ConstantFlowAgreementV1, CFAv1Library } from "./utils/SuperfluidTester.sol";
import { ERC1820RegistryCompiled } from "@superfluid-finance/ethereum-contracts/contracts/libs/ERC1820RegistryCompiled.sol";
import { IMissionControl, MissionControlStream } from "./../src/MissionControlStream.sol";
import { MockMissionControl } from "./mocks/MockMissionControl.sol";

contract MissionControlTest is SuperfluidTester {

    /// @dev This is required by solidity for using the CFAv1Library in the tester
    using CFAv1Library for CFAv1Library.InitData;

    SuperfluidFrameworkDeployer internal immutable sfDeployer;
    SuperfluidFrameworkDeployer.Framework internal sf;
    Superfluid host;
    ConstantFlowAgreementV1 cfa;
    CFAv1Library.InitData internal cfaV1Lib;

    MockMissionControl mockMissionCtrl;
    MissionControlStream missionCtrlStream;

    constructor() SuperfluidTester(3) {
        vm.startPrank(admin);
        vm.etch(ERC1820RegistryCompiled.at, ERC1820RegistryCompiled.bin);
        sfDeployer = new SuperfluidFrameworkDeployer();
        sf = sfDeployer.getFramework();
        host = sf.host;
        cfa = sf.cfa;
        cfaV1Lib = CFAv1Library.InitData(host,cfa);
        vm.stopPrank();
    }

    function setUp() public virtual {
        (token, superToken) = sfDeployer.deployWrapperSuperToken("Energy", "Energy", 18, type(uint256).max);

        for (uint32 i = 0; i < N_TESTERS; ++i) {
            token.mint(TEST_ACCOUNTS[i], INIT_TOKEN_BALANCE);
            vm.startPrank(TEST_ACCOUNTS[i]);
            token.approve(address(superToken), INIT_SUPER_TOKEN_BALANCE);
            superToken.upgrade(INIT_SUPER_TOKEN_BALANCE);
            vm.stopPrank();
        }
        deployMockMissionControl();
        deployMissionControlStream();
    }

    function deployMockMissionControl() public {
        vm.startPrank(admin);
        mockMissionCtrl = new MockMissionControl();
        vm.stopPrank();
    }

    function deployMissionControlStream() public {
        vm.startPrank(admin);
        missionCtrlStream = new MissionControlStream(host, superToken, address(mockMissionCtrl), "");
        mockMissionCtrl._setMissionControlStream(address(missionCtrlStream));
        vm.stopPrank();
    }

    function testDeployMissionControleStream() public {
        assertEq(address(missionCtrlStream.acceptedToken()), address(superToken));
        assertEq(address(missionCtrlStream.host()), address(host));
        assertEq(address(missionCtrlStream.missionControl()), address(mockMissionCtrl));
    }

    function testUserRentTiles() public {
        vm.startPrank(alice);
        mockMissionCtrl._setMinFlowRate(100); // 100 wei per second for each tile
        IMissionControl.CollectOrder[] memory tiles = new IMissionControl.CollectOrder[](3);
        tiles[0] = IMissionControl.CollectOrder(1, 1, 1);
        tiles[1] = IMissionControl.CollectOrder(2, 2, 2);
        tiles[2] = IMissionControl.CollectOrder(3, 3, 3);
        cfaV1Lib.createFlow(address(missionCtrlStream), superToken , 300, abi.encode(tiles));
    }
}