// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface IQualifier {
    function govToken() external view returns (address);
    function govTokenStandard() external view returns (uint256);

    function HXTO() external view returns (address);
    function HXTOStandard() external view returns (uint256);

    function qualify(address account) external returns (bool);
}