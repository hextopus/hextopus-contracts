// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface ICapReader {
    function getCap (address account) external view returns(uint256);
    function setStakeAdditionalCap (uint256 index, uint256 additionalCap) external;
    function stakeAdditionalCap(uint256 index) external view returns (uint256);
}
