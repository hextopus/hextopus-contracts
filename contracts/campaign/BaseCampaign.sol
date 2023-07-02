// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "../interfaces/IERC20.sol";
import "../interfaces/IAction.sol";
import "../interfaces/ICapReader.sol";
import "../interfaces/INFTCapReader.sol";
import "../interfaces/IVester.sol";
import "../interfaces/IHXTO.sol";
import "../interfaces/IStaker.sol";

contract BaseCampaign {    
    struct UserInfo {
        bytes32 link;
        address referral;
        uint256 referralHxtoAmount;
        uint256 referralHxtoDebt;
    }

    IHXTO public hxto;
    IHXTO public esHxto;

    IVester public vester;
    IStaker public staker;
    ICapReader public capReader;
    INFTCapReader public NFTCapReader;

    address public treasury;

    // User campaign info
    mapping(address => UserInfo) public userInfo;

    // Campaign pool amounts
    uint256 public hxtoPoolAmount;
    uint256 public rewardTokenPoolAmount;

    // Campaign reward token
    address public rewardToken;

    // Reward amounts
    uint256 public participationRewardTokenAmount;

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
    event Claim(address account, uint256 esHxtoAmount);
    event AddRewards(uint256 initialRewardTokenAmount, uint256 initialHxtoAmount);
    event RemoveReward(uint256 rewardTokenAmount, uint256 hxtoAmount);

    // Modifier
    // For timelock
    modifier onlyGov() {
        require(msg.sender == gov, "BaseCampaign: not gov");
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
        require(rewardToken == address(0), "BaseCampaign: already initialized");

        (rewardToken, action, owner, isWhiteListCampaign, minimumRequirement, NFTCapReader) = abi.decode(_config, (address, IAction, address, bool, uint256, INFTCapReader));
        (hxto, esHxto, vester, staker, capReader, treasury) = abi.decode(_tokenConfig, (IHXTO, IHXTO, IVester, IStaker, ICapReader, address));
    }

    // Setter
    function setGov(address _gov) external onlyOwner {
        gov = _gov;
    }

    function setBeforeAddRewards(
        uint256 _rewardTokenAmount, 
        uint256 _hxtoAmount,
        uint256 _directReferralMultiplier,
        uint256 _indirectReferralMultiplier,
        uint256 _minimumParticipationAccounts,
        uint256 _minimumReferralAccounts
    ) external onlyGov {
        require(_minimumParticipationAccounts >= _minimumReferralAccounts, "BaseCampaign: minimum participants must greater than referral");
        require(_rewardTokenAmount != 0, "BaseCampaign: set initial amounts");
        
        uint256 minimumHxto = _hxtoAmount / ((_minimumReferralAccounts - 1) * (_directReferralMultiplier + _indirectReferralMultiplier) + _directReferralMultiplier);

        participationRewardTokenAmount = _rewardTokenAmount / _minimumParticipationAccounts;

        directReferralHxtoAmount = minimumHxto * _directReferralMultiplier; 
        indirectReferralHxtoAmount = minimumHxto * _indirectReferralMultiplier;

        rewardTokenPoolAmount = _rewardTokenAmount;
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
    function participate(address referral, address account, bytes32 link, bytes memory actionData) external onlyWhiteList(account){
        require(!isExit, "BaseCampaign: Campaign is over now");
        require(campaignStart != 0, "BaseCampaign: Not start yet");
        require(link != 0, "BaseCampaign: link can not be empty");

        uint256 curRewardTokenPoolAmount = rewardTokenPoolAmount;
        uint256 curHxtoPoolAmount = hxtoPoolAmount;

        UserInfo storage userCampaignInfo = userInfo[account];

        require(userCampaignInfo.link == 0, "BaseCampaign: Can't participate twice");

        curRewardTokenPoolAmount -= (participationRewardTokenAmount);

        action.execute(account, actionData);

        if(referral != address(0) && curHxtoPoolAmount > directReferralHxtoAmount){
            // Direct referral participation info
            UserInfo storage directReferral = userInfo[referral];

            require(directReferral.link != 0, "BaseCampaign: Wrong referral code");
            
            curHxtoPoolAmount -= directReferralHxtoAmount;

            // Add direct referral reward to 1st level referral
            directReferral.referralHxtoAmount += (directReferralHxtoAmount);

            if(directReferral.referral != address(0) && curHxtoPoolAmount > indirectReferralHxtoAmount){
                // Indirect referral
                UserInfo storage indirectReferral = userInfo[directReferral.referral];

                require(indirectReferral.link != 0, "BaseCampaign: Wrong referral code");

                curHxtoPoolAmount -= (indirectReferralHxtoAmount);

                // Add indirect referral reward to 2nd level referral
                indirectReferral.referralHxtoAmount += (indirectReferralHxtoAmount);
            }
        }

        userCampaignInfo.link = link;
        userCampaignInfo.referral = referral;

        IERC20(rewardToken).transfer(account, participationRewardTokenAmount);

        rewardTokenPoolAmount = curRewardTokenPoolAmount;
        hxtoPoolAmount = curHxtoPoolAmount;

        emit Participate(link, account, referral);
    }

    /// @notice Claim referral reward
    /// @param account address of account
    function claim(address account) external returns (uint256){
        UserInfo storage userCampaignInfo = userInfo[account];

        uint256 esHxtoAmount;

        esHxtoAmount = (userCampaignInfo.referralHxtoAmount - userCampaignInfo.referralHxtoDebt);

        if(esHxtoAmount > 0){
            uint256 hxtoCap = baseRewardCap(account) + capReader.getCap(account);

            if(hxtoCap >= userCampaignInfo.referralHxtoDebt && userCampaignInfo.referralHxtoAmount > hxtoCap){
                esHxtoAmount = hxtoCap - userCampaignInfo.referralHxtoDebt;
            } else if (userCampaignInfo.referralHxtoDebt > hxtoCap){
                esHxtoAmount = 0;
            }

            userCampaignInfo.referralHxtoDebt += esHxtoAmount;
        }

        if(esHxtoAmount > 0){
            esHxto.transfer(account, esHxtoAmount);
        }
        
        emit Claim(account, esHxtoAmount);

        return esHxtoAmount;
    }
    
    /// @dev Charge campaing reward pool and set according to `minimumTargetAccounts`.
    function addRewards() external {
        uint256 curRewardTokenPoolAmount = rewardTokenPoolAmount;
        uint256 curHxtoPoolAmount = hxtoPoolAmount;

        require(curRewardTokenPoolAmount != 0, "BaseCampaign: Can not add reward before setting");
        require(curHxtoPoolAmount != 0, "BaseCampaign: Can not add reward before setting");
        require(campaignStart == 0, "BaseCampaign: Can not add reward twice");

        campaignStart = block.timestamp;

        IERC20(rewardToken).transferFrom(msg.sender, address(this), curRewardTokenPoolAmount);
        hxto.transferFrom(msg.sender, address(vester), curHxtoPoolAmount);

        esHxto.mint(address(this), curHxtoPoolAmount);

        emit AddRewards(rewardTokenPoolAmount, hxtoPoolAmount);
    }

    /// @notice Close campaign.
    function exit() external {
        require(isExit, "BaseCampaign: forbidden");

        uint256 curRewardTokenPoolAmount = rewardTokenPoolAmount;
        uint256 feeRewardToken = curRewardTokenPoolAmount * REMOVE_FEE / FEE_PRECISION;
        uint256 withdrawRewardTokenAmount = curRewardTokenPoolAmount - feeRewardToken;

        uint256 curHxtoPoolAmount = hxtoPoolAmount;
        uint256 feeHxto = curHxtoPoolAmount * REMOVE_FEE / FEE_PRECISION;
        uint256 withdrawHxtoAmount = curHxtoPoolAmount - feeHxto;

        hxtoPoolAmount = 0;
        rewardTokenPoolAmount = 0;

        vester.withdraw(curHxtoPoolAmount);
        esHxto.burn(address(this), curHxtoPoolAmount);

        IERC20(rewardToken).transfer(exitReceiver, withdrawRewardTokenAmount);
        IERC20(rewardToken).transfer(treasury, feeRewardToken);

        hxto.transfer(exitReceiver, withdrawHxtoAmount);
        hxto.transfer(treasury, feeHxto);

        emit RemoveReward(curRewardTokenPoolAmount, curHxtoPoolAmount);

        return;
    }

    /// @notice Basically campaign base reward cap is direct hxto reward * 2
    function baseRewardCap(address account) public view returns (uint256){
        uint256 multiplier = NFTCapReader.getNFTMultiplier(account);

        if(multiplier > 2){
            return directReferralHxtoAmount * multiplier;
        }

        return directReferralHxtoAmount * 2;
    }
}

