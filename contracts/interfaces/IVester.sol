// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface IVester {
    struct UserInfo{
        uint256 vestingAmount;
        uint256 vestingDept;
        uint256 pairAmount;
        uint256 pairDept;
        uint256 lastUpdatedAt;
        bool isVesing;
    }

    function userInfo(address account) external view returns(UserInfo memory);
    function withdraw(uint256 amount) external;
}