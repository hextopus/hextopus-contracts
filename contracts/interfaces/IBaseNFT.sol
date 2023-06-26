// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface IBaseNFT {
    function isOwnerOf(address, uint256) external view returns (bool);

    function mint(address account) external returns (uint256);

    function burn(address account, uint256 id) external;
}