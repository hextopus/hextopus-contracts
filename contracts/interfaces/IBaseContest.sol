// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface IBaseContest {
    function initialize(bytes calldata _config, bytes calldata _accessConfig) external;
    function setWinners(address[] memory _winners, address[] memory _raffleWinners) external;
}