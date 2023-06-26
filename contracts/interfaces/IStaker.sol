// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface IStaker {
    struct UserInfo{
        uint256 stakeAmount;
        uint256 stakeStartTime;
        uint256 stakePeriodIndex;
    }

    function userInfo(address account) external view returns(UserInfo memory);
    function stakePeriod(uint256 index) external view returns(uint256);
    function setStakePeriod(uint256 index, uint256 period) external;
    function stakePeriodMaxIndex() external view returns(uint256);
}