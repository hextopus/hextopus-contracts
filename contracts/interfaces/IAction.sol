// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface IAction {
    function execute(address account, bytes calldata _action) external;
}