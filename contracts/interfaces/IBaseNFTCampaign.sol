// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface IBaseNFTCampaign {
    struct UserInfo {
        bytes32 link;
        address referral;
        uint256 hxtoAmount;
        uint256 hxtoDebt;
    }

    function campaignStart() external view returns (uint256);

    function isExit() external view returns (bool);

    function userInfo(address) external view returns(UserInfo memory);
    
    function hxtoPoolAmount() external view returns (uint256);
    function rewardNFT() external view returns (address);

    function baseRewardCap(address) external view returns (uint256);
    
    function setBeforeAddRewards(uint256, uint256, uint256, uint256) external;
    function setExitTrigger(bool, address) external;

    function directReferralHxtoAmount() external view returns (uint256);
    function indirectReferralHxtoAmount() external view returns (uint256);

    function initialize(bytes memory, bytes memory) external;
    function claim(address) external returns(uint256);
}