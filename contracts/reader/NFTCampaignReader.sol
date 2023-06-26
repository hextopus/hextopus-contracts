// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IERC20.sol";
import "../interfaces/IBaseNFTCampaign.sol";
import "../interfaces/ICapReader.sol";
import "../interfaces/IStaker.sol";

contract NFTCampaignReader is Ownable{
    struct CampaignInfo {
        bool isExit;
        uint256 remainHxto;
    }

    struct RewardInfo {
        address rewardNFT;
        uint256 directReferralReward;
        uint256 indirectReferralReward;
    }

    struct UserInfo {
        bool isParticipate;
        uint256 lockedHxto;
        uint256 claimableHxto;
        uint256 claimedHxto;
    }

    IBaseNFTCampaign[] public campaigns;
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

    function addCampaign (IBaseNFTCampaign campaign) public onlyOwner {
        require(address(campaign) != address(0), "Campaign reader: Campaign can not be zero address");

        campaigns.push(campaign);
    }

    function removeCampaign(uint256 index) public onlyOwner returns(IBaseNFTCampaign[] memory) {
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
            IBaseNFTCampaign campaign = campaigns[i];

            campaignInfo[i].isExit = campaign.isExit();
            campaignInfo[i].remainHxto = campaign.hxtoPoolAmount();
        }

        return campaignInfo;
    }

    function getCampaignsRewardInfo() public view returns (RewardInfo[] memory){
        RewardInfo[] memory rewardInfo = new RewardInfo[](campaigns.length);

        for(uint256 i = 0; i < campaigns.length; i++){
            IBaseNFTCampaign campaign = campaigns[i];

            rewardInfo[i].rewardNFT = campaign.rewardNFT();
            rewardInfo[i].directReferralReward = campaign.directReferralHxtoAmount();
            rewardInfo[i].indirectReferralReward = campaign.indirectReferralHxtoAmount();
        }

        return rewardInfo;
    }

    function getCampaignReferralRewardInfo(address account, uint256 index) public view returns(UserInfo memory userInfo){
        IBaseNFTCampaign campaign = campaigns[index];

        IBaseNFTCampaign.UserInfo memory userCampaignInfo = campaign.userInfo(account);
        
        if(userCampaignInfo.link != 0) userInfo.isParticipate = true;

        userInfo.claimedHxto += userCampaignInfo.hxtoDebt;
        
        uint256 hxtoCap = campaign.baseRewardCap(account) + capReader.getCap(account);

        if(userCampaignInfo.hxtoAmount != userCampaignInfo.hxtoDebt){
            if(hxtoCap < userCampaignInfo.hxtoDebt){                
                userInfo.lockedHxto += (userCampaignInfo.hxtoAmount - userCampaignInfo.hxtoDebt);
            } else if(userCampaignInfo.hxtoAmount > hxtoCap){
                uint256 claimableReferralHxto = hxtoCap - userCampaignInfo.hxtoDebt;
                
                userInfo.claimableHxto += claimableReferralHxto;

                userInfo.lockedHxto += (userCampaignInfo.hxtoAmount - (userCampaignInfo.hxtoDebt + claimableReferralHxto));
            } else {
                userInfo.claimableHxto += (userCampaignInfo.hxtoAmount - userCampaignInfo.hxtoDebt);
            }
        }
    }

    function getHxtoRequirement(address account, uint256 index) public view returns (uint256) {
        IBaseNFTCampaign campaign = campaigns[index];

        IBaseNFTCampaign.UserInfo memory userCampaignInfo = campaign.userInfo(account);
        
        uint256 hxtoCap = campaign.baseRewardCap(account) + capReader.getCap(account);

        uint256 maxStakePeriodIndex = staker.stakePeriodMaxIndex();

        uint256 additionalCap = capReader.stakeAdditionalCap(maxStakePeriodIndex);

        require(additionalCap != 0, "Campaign reader: Additional cap can not be zero");

        if(hxtoCap >= userCampaignInfo.hxtoAmount){
            return 0;
        }else {
            return (userCampaignInfo.hxtoAmount - hxtoCap) * 1000 / additionalCap;
        }
    }
}