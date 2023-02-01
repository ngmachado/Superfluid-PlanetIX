// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IMCCrosschainServices {
    function getNewlandsGenesisBalance(address _user) external view returns (uint256);
}
