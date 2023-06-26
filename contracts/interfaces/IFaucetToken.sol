// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFaucetToken {
    function mint(address account, uint256 amount) external;

    function decimals() external view returns (uint8);
}
