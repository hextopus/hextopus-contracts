// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface IHXTO {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function transferFrom(address from, address to, uint256 amount) external;
    function transfer(address to, uint256 amount) external;
    function balanceOf(address account) external view returns(uint256);
}