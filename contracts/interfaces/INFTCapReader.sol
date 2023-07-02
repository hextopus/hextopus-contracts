// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface INFTCapReader {
    function getNFTMultiplier(address account) external view returns (uint256);
}
