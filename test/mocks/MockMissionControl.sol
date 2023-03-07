pragma solidity ^0.8.0;

import {IMissionControlExtension} from "./../../src/Interfaces/IMissionControlExtension.sol";
import "forge-std/console.sol";


//Attention: This is a mock contract for testing purposes only. Real implementation is MissionControl.sol external to this repo

contract MockMissionControl is IMissionControlExtension {

    // Mock Vars
    int96 public minFlowRate;
    address public acceptedToken;
    address public missionControlStream;

    uint256 public tilesCount;

    bool revertOnCreate;
    bool revertOnUpdate;
    bool revertOnDelete;

    // save user coordinates, copied from MissionControl contract for testing purposes
    mapping(address => mapping(int => mapping(int => CollectOrder))) public rentedTiles;

    // save user termination timestamp
    mapping(address => uint256) public userTerminationTimestamp;

    function _setAcceptedToken(address _acceptedToken) public {
        acceptedToken = _acceptedToken;
    }

    function _setMinFlowRate(int96 _minFlowRate) public {
        minFlowRate = _minFlowRate;
    }

    function _setMissionControlStream(address _missionControlStream) public {
        missionControlStream = _missionControlStream;
    }

    function mockTilePrice(uint256 numberOfTiles) public view returns (int96) {
        // attention: this can overflow silently. Only for testing
        return minFlowRate * int96(int256(numberOfTiles));
    }

    function _setRevertOnCreate(bool _revertOnCreate) public {
        revertOnCreate = _revertOnCreate;
    }

    function _setRevertOnUpdate(bool _revertOnUpdate) public {
        revertOnUpdate = _revertOnUpdate;
    }

    function _setRevertOnDelete(bool _revertOnDelete) public {
        revertOnDelete = _revertOnDelete;
    }

    function _setTilesCount(uint256 _tilesCount) public {
        tilesCount = _tilesCount;
    }


    // @dev: Mission control refuse operation by reverting
    function createRentTiles(
        address supertoken,
        address renter,
        CollectOrder[] memory tiles,
        int96 flowRate
    )
    external override
    {
        if(revertOnCreate) revert("MockMissionControl: revertOnCreate");
        // decide based on tiles min flowRate
        require(mockTilePrice(tiles.length) == flowRate, "FlowRate don't match price");
        for(uint256 i = 0; i < tiles.length; i++) {
            CollectOrder memory tile = tiles[i];
            rentedTiles[renter][tile.x][tile.y] = tile;
        }
    }

    // user is streaming and change the rented tiles
    function updateRentTiles(
        address supertoken,
        address renter,
        CollectOrder[] memory addTiles,
        CollectOrder[] memory removeTiles,
        int96 oldFlowRate,
        int96 flowRate
    ) external override
    {
        if(revertOnUpdate) revert("MockMissionControl: revertOnUpdate");
        // should always get old and new flow rate
        require(oldFlowRate != 0, "oldFlowRate should be != 0");
        require(flowRate != 0, "flowRate should be != 0");

        // we are mocking the price of the tiles
        uint256 diff = abs(int256(addTiles.length) - int256(removeTiles.length));
        uint256 diffFlowRate = abs(int256(flowRate - oldFlowRate));
        // if we set tilesCount, we want to calculate based on past "state"
        if(tilesCount != 0) {
            uint256 diffFromSetTiles = tilesCount - removeTiles.length;
            uint256 diffFlowRateFromSetTiles = abs(int256(flowRate - oldFlowRate));
            require(diffFlowRateFromSetTiles == diffFromSetTiles * uint256(uint96(minFlowRate)), "FlowRate don't match price");
        } else {
            require(diffFlowRate == diff * uint256(uint96(minFlowRate)), "FlowRate don't match price");
        }

        // add tiles if needed
        for(uint256 i = 0; i < addTiles.length; i++) {
            CollectOrder memory tile = addTiles[i];
            rentedTiles[renter][tile.x][tile.y] = tile;
        }
        // remove tiles if needed
        for(uint256 i = 0; i < removeTiles.length; i++) {
            CollectOrder memory tile = removeTiles[i];
            delete rentedTiles[renter][tile.x][tile.y];
        }
    }
    // user stop streaming to the game
    function deleteRentTiles(
        address supertoken,
        address renter
    ) external override
    {
        if(revertOnDelete) revert("MockMissionControl: revertOnDelete");
        // set timestamp
        userTerminationTimestamp[renter] = block.timestamp;
    }


    function abs(int256 x) internal pure returns (uint256) {
        return x >= 0 ? uint256(x) : uint256(-x);
    }
}
