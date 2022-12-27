pragma solidity ^0.8.0;

import {IMissionControl} from "./../../src/MissionControlStream.sol";
import "forge-std/Console.sol";

contract MockMissionControl is IMissionControl {

    // Mock Vars
    int96 public minFlowRate;
    address public acceptedToken;
    address public missionControlStream;

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
        console.log(numberOfTiles);
        // attention: this can overflow silently. Only for testing
        return minFlowRate * int96(int256(numberOfTiles));
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
        // decide based on tiles min flowRate
        require(mockTilePrice(tiles.length) == flowRate, "FlowRate don't match price");
    }

    // user is streaming and change the rented tiles
    function updateRentTiles(
        address supertoken,
        address renter,
        CollectOrder[] memory addTiles,
        CollectOrder[] memory removeTiles,
        int96 flowRate
    ) external override
    {
    }
    // user stop streaming to the game
    function deleteRentTiles(
        address supertoken,
        address rente
    ) external override
    {
    }
}
