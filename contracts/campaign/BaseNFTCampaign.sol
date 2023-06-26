// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../interfaces/IERC20.sol";
import "../interfaces/IAction.sol";
import "../interfaces/ICapReader.sol";
import "../interfaces/IVester.sol";
import "../interfaces/IHXTO.sol";
import "../interfaces/IBaseNFT.sol";
import "../interfaces/IStaker.sol";

contract BaseNFTCampaign {    
    struct UserInfo {
        bytes32 link;
        address referral;
        uint256 hxtoAmount;
        uint256 hxtoDebt;
    }

    IHXTO public hxto;
    IHXTO public esHxto;

    IERC721 public SBT;

    IVester public vester;
    IStaker public staker;
    ICapReader public capReader;

    address public treasury;

    // User campaign info
    mapping(address => UserInfo) public userInfo;

    // Campaign pool amounts
    uint256 public hxtoPoolAmount;

    // Campaign reward token
    IBaseNFT public rewardNFT;

    // Reward amounts
    uint256 public directReferralHxtoAmount;
    uint256 public indirectReferralHxtoAmount;

    address public gov; // Campaign manager
    address public owner; // Hextopus admin

    IAction public action;

    // Remove fee
    uint256 public constant REMOVE_FEE = 500;
    uint256 public constant FEE_PRECISION = 10000;

    // Campaign minimum period
    uint256 public campaignStart;
    uint256 public constant campaignPeriod = 4 weeks;

    // WhiteList
    bool public isWhiteListCampaign;
    uint256 public minimumRequirement;

    // Exit 
    bool public isExit;
    address public exitReceiver;

    // Event
    event Participate(bytes32 link, address account, address referral);
    event ClaimAll(address account, uint256 esHxtoAmount);
    event AddRewards(uint256 initialHxtoAmount);
    event RemoveReward(uint256 hxtoAmount);

    // Modifier
    // For timelock
    modifier onlyGov() {
        require(msg.sender == gov, "BaseNFTCampaign: not gov");
        _;
    }

    // For campaign owner
    modifier onlyOwner() {
        require(msg.sender == owner, "BaseCampaign: caller is not the owner");
        _;
    }

    modifier onlyWhiteList(address account){
        if(isWhiteListCampaign){
            require(staker.userInfo(account).stakeAmount >= minimumRequirement, "BaseCampaign: need more stake");
        }
        _;
    }

    function initialize(bytes memory _config, bytes memory _tokenConfig) external {
        require(address(rewardNFT) == address(0), "BaseNFTCampaign: already initialized");

        (rewardNFT, action, owner, isWhiteListCampaign, minimumRequirement, SBT) = abi.decode(_config, (IBaseNFT, IAction, address,  bool, uint256, IERC721));
        (hxto, esHxto, vester, staker, capReader, treasury) = abi.decode(_tokenConfig, (IHXTO, IHXTO, IVester, IStaker, ICapReader, address));
    }

    // Setter
    function setGov(address _gov) external onlyOwner {
        gov = _gov;
    }

    function setBeforeAddRewards(
        uint256 _hxtoAmount,
        uint256 _directReferralMultiplier,
        uint256 _indirectReferralMultiplier,
        uint256 _minimumTargetAccounts
    ) external onlyGov {
        uint256 x = _hxtoAmount / ((_minimumTargetAccounts - 1) * (_directReferralMultiplier + _indirectReferralMultiplier) + _directReferralMultiplier);

        directReferralHxtoAmount = x * _directReferralMultiplier; 
        indirectReferralHxtoAmount = x * _indirectReferralMultiplier;

        hxtoPoolAmount = _hxtoAmount;
    }

    function setExitTrigger(bool _isExit, address _exitReceiver) external onlyGov {
        require(block.timestamp >= campaignStart + campaignPeriod, "BaseCampaign: Can not exit during campaign period");

        isExit = _isExit; 
        exitReceiver = _exitReceiver;
    }

    /// @notice `account` participates campaign referred by `referral`.
    /// @param referral address of referral.
    /// zero address if _account participates without referral.
    /// @param account address of participator
    function participate(address referral, address account, bytes32 link, bytes memory actionData) external {
        require(!isExit, "BaseCampaign: Campaign is over now");
        require(campaignStart != 0, "BaseCampaign: Not start yet");
        require(link != 0, "BaseCampaign: link can not be empty");

        UserInfo storage userCampaignInfo = userInfo[account];

        require(userCampaignInfo.link == 0, "BaseCampaign: Can't participate twice");

        action.execute(account, actionData);

        uint256 curHxtoPoolAmount = hxtoPoolAmount;

        if(referral != address(0) && curHxtoPoolAmount > directReferralHxtoAmount){
            // Direct referral participation info
            UserInfo storage directReferral = userInfo[referral];

            require(directReferral.link != 0, "BaseCampaign: Wrong referral code");
            
            curHxtoPoolAmount -= directReferralHxtoAmount;

            // Add direct referral reward to 1st level referral
            directReferral.hxtoAmount += (directReferralHxtoAmount);

            if(directReferral.referral != address(0) && curHxtoPoolAmount > indirectReferralHxtoAmount){
                // Indirect referral
                UserInfo storage indirectReferral = userInfo[directReferral.referral];

                require(indirectReferral.link != 0, "BaseCampaign: Wrong referral code");

                curHxtoPoolAmount -= (indirectReferralHxtoAmount);

                // Add indirect referral reward to 2nd level referral
                indirectReferral.hxtoAmount += (indirectReferralHxtoAmount);
            }
        }

        userCampaignInfo.link = link;
        userCampaignInfo.referral = referral;
    
        rewardNFT.mint(account);

        hxtoPoolAmount = curHxtoPoolAmount;

        emit Participate(link, account, referral);
    }

    /// @notice Claim participation reward, referral reward, participation deposit.
    /// @param account address of account
    function claim(address account) external returns (uint256){
        UserInfo storage userCampaignInfo = userInfo[account];

        uint256 esHxtoAmount;

        esHxtoAmount = (userCampaignInfo.hxtoAmount - userCampaignInfo.hxtoDebt);

        if(esHxtoAmount > 0){
            uint256 hxtoCap = baseRewardCap(account) + capReader.getCap(account);

            if(hxtoCap >= userCampaignInfo.hxtoDebt && userCampaignInfo.hxtoAmount > hxtoCap){
                esHxtoAmount = hxtoCap - userCampaignInfo.hxtoDebt;
            } else if (userCampaignInfo.hxtoDebt > hxtoCap){
                esHxtoAmount = 0;
            }

            userCampaignInfo.hxtoDebt += esHxtoAmount;
        }

        if(esHxtoAmount > 0){
            esHxto.transfer(account, esHxtoAmount);
        }

        emit ClaimAll(account, esHxtoAmount);

        return esHxtoAmount;
    }
    
    /// @dev Charge campaing reward pool and set according to `minimumTargetAccounts`.
    function addRewards() external {
        require(campaignStart == 0, "BaseCampaign: Can not add reward twice");
        campaignStart = block.timestamp;

        hxto.transferFrom(msg.sender, address(vester), hxtoPoolAmount);

        esHxto.mint(address(this), hxtoPoolAmount);

        emit AddRewards(hxtoPoolAmount);
    }

    /// @notice Close campaign.
    function exit() external {
        require(isExit, "BaseCampaign: forbidden");

        uint256 curHxtoPoolAmount = hxtoPoolAmount;
        uint256 feeHxto = curHxtoPoolAmount * REMOVE_FEE / FEE_PRECISION;
        uint256 withdrawHxtoAmount = curHxtoPoolAmount - feeHxto;

        hxtoPoolAmount = 0;

        vester.withdraw(curHxtoPoolAmount);

        hxto.transfer(exitReceiver, withdrawHxtoAmount);
        hxto.transfer(treasury, feeHxto);

        esHxto.burn(address(this), curHxtoPoolAmount);

        emit RemoveReward(curHxtoPoolAmount);

        return;
    }

    /// @notice Basically campaign base reward cap is direct hxto reward * 2
    function baseRewardCap(address account) public view returns (uint256){
        if(address(SBT) != address(0)){
            if(SBT.balanceOf(account) != 0){
                return directReferralHxtoAmount * 3;
            }else {
                return directReferralHxtoAmount * 2;
            }
        }else{
            return directReferralHxtoAmount * 2;
        }
    }
}

