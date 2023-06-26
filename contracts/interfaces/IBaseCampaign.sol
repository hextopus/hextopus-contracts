// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface IBaseCampaign {
    struct UserInfo {
        bytes32 link;
        address referral;
        uint256 referralHxtoAmount;
        uint256 referralHxtoDebt;
    }

    function campaignStart() external view returns (uint256);

    function setDeposit(uint256, uint256) external;
    function isExit() external view returns (bool);
    function depositLockPeriod() external view returns (uint256);

    function userInfo(address) external view returns(UserInfo memory);
    
    function hxtoPoolAmount() external view returns (uint256);
    function rewardTokenPoolAmount() external view returns (uint256);

    function baseRewardCap(address) external view returns (uint256);
    
    function setBeforeAddRewards(uint256, uint256, uint256, uint256, uint256, uint256) external;
    function setExitTrigger(bool, address) external;

    function participationRewardTokenAmount() external view returns (uint256);
    function participationHxtoAmount() external view returns (uint256);
    function directReferralRewardTokenAmount() external view returns (uint256);
    function directReferralHxtoAmount() external view returns (uint256);
    function indirectReferralRewardTokenAmount() external view returns (uint256);
    function indirectReferralHxtoAmount() external view returns (uint256);

    function initialize(bytes memory, bytes memory) external;

    function participate(address, address, bytes32, bytes memory) external;
    function claimAll(address) external returns(uint256);
}