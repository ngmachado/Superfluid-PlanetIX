pragma solidity ^0.8.0;

import "forge-std/Console.sol";
import { ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";
import { SuperfluidFrameworkDeployer, SuperfluidTester, Superfluid, ConstantFlowAgreementV1, CFAv1Library } from "./utils/SuperfluidTester.sol";
import { ERC1820RegistryCompiled } from "@superfluid-finance/ethereum-contracts/contracts/libs/ERC1820RegistryCompiled.sol";
import { MissionControlStream } from "./../src/MissionControlStream.sol";
import { IMissionControlExtension } from "./../src/interface/IMissionControlExtension.sol";
import { MockMissionControl } from "./mocks/MockMissionControl.sol";

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { MissionControlStreamV2 } from "./mocks/MissionControlStreamV2.sol";

contract UpgradabilityTest is SuperfluidTester {

    event TerminationCallReverted(address indexed sender);

    /// @dev This is required by solidity for using the CFAv1Library in the tester
    using CFAv1Library for CFAv1Library.InitData;

    SuperfluidFrameworkDeployer internal immutable sfDeployer;
    SuperfluidFrameworkDeployer.Framework internal sf;
    Superfluid host;
    ConstantFlowAgreementV1 cfa;
    CFAv1Library.InitData internal cfaV1Lib;

    MockMissionControl mockMissionCtrl;
    MissionControlStream missionCtrlStream;

    MissionControlStream missionCtrlStreamLogic;
    MissionControlStreamV2 missionCtrlStreamLogicV2;

    ProxyAdmin proxyAdmin;
    TransparentUpgradeableProxy proxy;

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
        (token1, superToken1) = sfDeployer.deployWrapperSuperToken("Energy", "Energy", 18, type(uint256).max);
        (token2, superToken2) = sfDeployer.deployWrapperSuperToken("PIX", "PIX", 18, type(uint256).max);

        for (uint32 i = 0; i < N_TESTERS; ++i) {
            token1.mint(TEST_ACCOUNTS[i], INIT_TOKEN_BALANCE);
            token2.mint(TEST_ACCOUNTS[i], INIT_TOKEN_BALANCE);
            vm.startPrank(TEST_ACCOUNTS[i]);
            token1.approve(address(superToken1), INIT_SUPER_TOKEN_BALANCE);
            token2.approve(address(superToken2), INIT_SUPER_TOKEN_BALANCE);
            superToken1.upgrade(INIT_SUPER_TOKEN_BALANCE);
            superToken2.upgrade(INIT_SUPER_TOKEN_BALANCE);
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

        //logic contract
        missionCtrlStreamLogic = new MissionControlStream();
        //deploy proxyAdmin
        proxyAdmin = new ProxyAdmin();
        //deploy proxy
        proxy = new TransparentUpgradeableProxy(
            address(missionCtrlStreamLogic),
            address(proxyAdmin),
            abi.encodeWithSignature("initialize(address,address,address,address)", address(host), address(superToken1),address(superToken2),address(mockMissionCtrl))
        );
        // we use the proxy as MissionControlStream
        missionCtrlStream = MissionControlStream(address(proxy));
        mockMissionCtrl._setMissionControlStream(address(missionCtrlStream));
        vm.stopPrank();
    }

    // deploy new mission control stream
    function deployMissionControlStreamV2() public {
        vm.startPrank(admin);
        //logic contract
        missionCtrlStreamLogicV2 = new MissionControlStreamV2();
        proxyAdmin.upgrade(proxy, address(missionCtrlStreamLogicV2));
        vm.stopPrank();

    }

    // helper functions
    function _createCollectOrder(int256 x, int256 y, int256 z) public pure returns (IMissionControlExtension.CollectOrder memory) {
        return IMissionControlExtension.CollectOrder({
            x: x,
            y: y,
            z: z
        });
    }

    // is app jailed
    function _checkAppJailed() public returns (bool) {
        assertFalse(host.isAppJailed(missionCtrlStream), "app is jailed");
    }

    function testDeployMissionControleStream() public {
        assertEq(address(missionCtrlStream.acceptedToken1()), address(superToken1));
        assertEq(address(missionCtrlStream.acceptedToken2()), address(superToken2));
        assertEq(address(missionCtrlStream.host()), address(host));
        assertEq(address(missionCtrlStream.missionControl()), address(mockMissionCtrl));
    }

    function testDeployUpgradeAndTestDeployMissionControleStream() public {
        deployMissionControlStreamV2();
        assertEq(address(missionCtrlStream.acceptedToken1()), address(superToken1));
        assertEq(address(missionCtrlStream.acceptedToken2()), address(superToken2));
        assertEq(address(missionCtrlStream.host()), address(host));
        assertEq(address(missionCtrlStream.missionControl()), address(mockMissionCtrl));
        assertEq(MissionControlStreamV2(address(missionCtrlStream)).counter(), 0);
    }

    function testIncrementAndDecrementUpgradedMissionControlStream() public {
        deployMissionControlStreamV2();
        // cast mission contract to mission control stream v2
        MissionControlStreamV2 missionCtrlStreamV2 = MissionControlStreamV2(address(missionCtrlStream));
        // increment
        missionCtrlStreamV2.increment();
        assertEq(missionCtrlStreamV2.counter(), 1);
        // decrement
        missionCtrlStreamV2.decrement();
        assertEq(missionCtrlStreamV2.counter(), 0);
    }

    function testInitiateProxy() public returns (bool) {
        vm.startPrank(admin);
        // expect to revert on initiate call
        vm.expectRevert("Initializable: contract is already initialized");
        missionCtrlStream.initialize(address(host), address(superToken1), address(superToken2), address(mockMissionCtrl));
        vm.stopPrank();
    }

    // test upgradeTo proxyAdmin should fail if already initialized
    function testUpgradeToProxyAdmin() public returns (bool) {
        vm.startPrank(admin);
        //logic contract
        missionCtrlStreamLogicV2 = new MissionControlStreamV2();
        vm.expectRevert("Initializable: contract is already initialized");
        proxyAdmin.upgradeAndCall(
            proxy,
            address(missionCtrlStreamLogicV2),
            abi.encodeWithSignature("initialize(address,address,address,address)", address(host), address(superToken1),address(superToken2),address(mockMissionCtrl))
        );
        vm.stopPrank();
    }

    // test proxy admin
    function testProxyAdmin() public returns (bool) {
        vm.startPrank(admin);
        address implementation = proxyAdmin.getProxyImplementation(proxy);
        assertEq(implementation, address(missionCtrlStreamLogic));
        vm.stopPrank();
        // upgrade
        deployMissionControlStreamV2();
        vm.startPrank(admin);
        implementation = proxyAdmin.getProxyImplementation(proxy);
        assertEq(implementation, address(missionCtrlStreamLogicV2));
        // how is admin of proxy
        assertEq(proxyAdmin.getProxyAdmin(proxy), address(proxyAdmin));
        // who is owner of proxyAdmin contract
        assertEq(proxyAdmin.owner(), address(admin));
        vm.stopPrank();
    }


    // user should continue to stream after upgrade
    function testUserStreamAfterUpgrade() public {
        vm.startPrank(alice);
        mockMissionCtrl._setMinFlowRate(100); // 100 wei per second for each tile
        IMissionControlExtension.CollectOrder[] memory tiles = new IMissionControlExtension.CollectOrder[](3);
        tiles[0] = _createCollectOrder(1, 1, 1);
        tiles[1] = _createCollectOrder(2, 2, 2);
        tiles[2] = _createCollectOrder(3, 3, 3);
        cfaV1Lib.createFlow(address(missionCtrlStream), superToken1 , 300, abi.encode(tiles));
        _checkAppJailed();
        // get user flowRate
        (,int96 flowRate,,) = cfa.getFlow(superToken1, alice, address(missionCtrlStream));
        assertEq(flowRate, 300);
        vm.stopPrank();
        //deploy v2
        deployMissionControlStreamV2();
        // check user flowRate after upgrade
        (,flowRate,,) = cfa.getFlow(superToken1, alice, address(missionCtrlStream));
        assertEq(flowRate, 300);
    }


}