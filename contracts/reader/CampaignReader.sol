// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IERC20.sol";
import "../interfaces/IBaseCampaign.sol";
import "../interfaces/ICapReader.sol";
import "../interfaces/IStaker.sol";

contract CampaignReader is Ownable{
    struct CampaignInfo {
        bool isExit;
        uint256 remainHxto;
        uint256 remainRewardToken;
    }

    struct RewardInfo {
        uint256 participationReward;
        uint256 directReferralReward;
        uint256 indirectReferralReward;
    }

    struct UserInfo {
        bool isParticipate;
        uint256 lockedHxto;
        uint256 claimableHxto;
        uint256 claimedHxto;
    }

    IBaseCampaign[] public campaigns;
    ICapReader public capReader;
    IStaker public staker;

    function setCapReader(ICapReader _capReader) public onlyOwner {
        require(address(_capReader) != address(0), "Campaign reader: Cap reader can not be zero address");

        capReader = _capReader;
    }

    function setStaker (IStaker _staker) public onlyOwner {
        require(address(_staker) != address(0), "Campaign reader: Staker cap can not be zero");

        staker = _staker;
    }

    function addCampaign (IBaseCampaign campaign) public onlyOwner {
        require(address(campaign) != address(0), "Campaign reader: Campaign can not be zero address");

        campaigns.push(campaign);
    }

    function removeCampaign(uint256 index) public onlyOwner returns(IBaseCampaign[] memory) {
        require(index < campaigns.length, "Campaign reader: Wrong index");

        for (uint256 i = index; i<campaigns.length-1; i++){
            campaigns[i] = campaigns[i+1];
        }

        campaigns.pop();
        
        return campaigns;
    }

    function getCampaignsPoolInfo() public view returns (CampaignInfo[] memory){
        CampaignInfo[] memory campaignInfo = new CampaignInfo[](campaigns.length);

        for(uint256 i = 0; i < campaigns.length; i++){
            IBaseCampaign campaign = campaigns[i];
            
            campaignInfo[i].isExit = campaign.isExit();
            campaignInfo[i].remainHxto = campaign.hxtoPoolAmount();
            campaignInfo[i].remainRewardToken = campaign.rewardTokenPoolAmount();
        }

        return campaignInfo;
    }

    function getCampaignsRewardInfo() public view returns (RewardInfo[] memory){
        RewardInfo[] memory rewardInfo = new RewardInfo[](campaigns.length);

        for(uint256 i = 0; i < campaigns.length; i++){
            IBaseCampaign campaign = campaigns[i];

            rewardInfo[i].participationReward = campaign.participationRewardTokenAmount();
            rewardInfo[i].directReferralReward = campaign.directReferralHxtoAmount();
            rewardInfo[i].indirectReferralReward = campaign.indirectReferralHxtoAmount();
        }

        return rewardInfo;
    }

    function getCampaignUserInfo(address account, uint256 index) public view returns(UserInfo memory userInfo){
        IBaseCampaign campaign = campaigns[index];

        IBaseCampaign.UserInfo memory userCampaignInfo = campaign.userInfo(account);

        if(userCampaignInfo.link != 0) userInfo.isParticipate = true;
        
        userInfo.claimedHxto += userCampaignInfo.referralHxtoDebt;
        
        uint256 hxtoCap = campaign.baseRewardCap(account) + capReader.getCap(account);

        if(userCampaignInfo.referralHxtoAmount != userCampaignInfo.referralHxtoDebt){
            if(hxtoCap < userCampaignInfo.referralHxtoDebt){                
                userInfo.lockedHxto += (userCampaignInfo.referralHxtoAmount - userCampaignInfo.referralHxtoDebt);
            } else if(userCampaignInfo.referralHxtoAmount > hxtoCap){
                uint256 claimableReferralHxto = hxtoCap - userCampaignInfo.referralHxtoDebt;
                
                userInfo.claimableHxto += claimableReferralHxto;

                userInfo.lockedHxto += (userCampaignInfo.referralHxtoAmount - (userCampaignInfo.referralHxtoDebt + claimableReferralHxto));
            } else {
                userInfo.claimableHxto += (userCampaignInfo.referralHxtoAmount - userCampaignInfo.referralHxtoDebt);
            }
        }
    }

    function getHxtoRequirement(address account, uint256 index) public view returns (uint256) {
        IBaseCampaign campaign = campaigns[index];

        IBaseCampaign.UserInfo memory userCampaignInfo = campaign.userInfo(account);
        
        uint256 hxtoCap = campaign.baseRewardCap(account) + capReader.getCap(account);

        uint256 maxStakePeriodIndex = staker.stakePeriodMaxIndex();

        uint256 additionalCap = capReader.stakeAdditionalCap(maxStakePeriodIndex);

        require(additionalCap != 0, "Campaign reader: Additional cap can not be zero");

        if(hxtoCap >= userCampaignInfo.referralHxtoAmount){
            return 0;
        }else {
            return (userCampaignInfo.referralHxtoAmount - hxtoCap) * 1000 / additionalCap;
        }
    }
}