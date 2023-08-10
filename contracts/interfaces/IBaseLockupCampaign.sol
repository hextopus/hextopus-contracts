// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface IBaseLockupCampaign {
    struct UserInfo {
        bytes32 link;
        address referral;
        uint256 participationRewardAmount;
        uint256 participationRewardDebt;
        uint256 referralHxtoAmount;
        uint256 referralHxtoDebt;
    }

    function campaignStart() external view returns (uint256);

    function isExit() external view returns (bool);
    function isClaimable() external view returns (bool);

    function userInfo(address) external view returns(UserInfo memory);
    
    function hxtoPoolAmount() external view returns (uint256);
    function rewardTokenPoolAmount() external view returns (uint256);

    function baseRewardCap(address) external view returns (uint256);
    
    function setBeforeAddRewards(uint256, uint256, uint256, uint256, uint256, uint256) external;
    function setExitTrigger(bool, address) external;
    function setIsClaimable(bool) external;

    function participationRewardTokenAmount() external view returns (uint256);
    function directReferralHxtoAmount() external view returns (uint256);
    function indirectReferralHxtoAmount() external view returns (uint256);

    function initialize(bytes memory, bytes memory) external;

    function participate(address, address, bytes32, bytes memory) external;
    
    function claim(address) external returns(uint256);
    function claimParticipationReward(address) external returns(uint256);
}