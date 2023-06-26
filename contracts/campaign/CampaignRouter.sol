// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IBaseCampaign.sol";

contract CampaignRouter is Ownable {
    mapping(address => bool) public isActiveCampaign;

    modifier onlyActiveCampaign(address campaign) {
        require(isActiveCampaign[campaign], "CampaignRouter: not active campaign");
        _;
    }    

    function setActiveCampaign(address _campaign, bool _isActive) external onlyOwner{
        require(_campaign != address(0), "CampaignRouter: campaign address can not be zero");

        isActiveCampaign[_campaign] = _isActive;
    }

    function participate(address campaign, address referral, address account, bytes32 link, bytes memory actionData) external onlyActiveCampaign(campaign){
        IBaseCampaign(campaign).participate(referral, account, link, actionData);
    }
    
    function claimAll(address campaign, address account) external onlyActiveCampaign(campaign) returns (uint256 esHxtoAmount) {
        esHxtoAmount = IBaseCampaign(campaign).claimAll(account);
    }
}