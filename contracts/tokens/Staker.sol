// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IHXTO.sol";
import "../interfaces/IERC20.sol";

contract Staker is Ownable {
    struct UserInfo{
        uint256 stakeAmount;
        uint256 stakeStartTime;
        uint256 stakePeriodIndex;
    }

    mapping(address => UserInfo) public userInfo;

    /// @notice Index 0 reserved for unstake user
    mapping(uint256 => uint256) public stakePeriod;

    IHXTO public immutable hxto;

    /// @notice Need for hxto requirement calculation
    uint256 public stakePeriodMaxIndex;

    event Stake(address account, uint256 amount, uint256 stakePeriod);
    event Unstake(address account, uint256 amount);

    constructor(IHXTO _hxto){
        hxto = _hxto;
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external onlyOwner {
        IERC20(_token).transfer(_account, _amount);
    }

    function setStakePeriod (uint256 index, uint256 _period) external onlyOwner {
        require(index != 0, "Staker: Index 0 reserved for unstake user");
        require(_period != 0, "Staker: Additional cap can not be zero");
        // Store max index number
        if(stakePeriodMaxIndex < index){
            stakePeriodMaxIndex = index;
        }

        stakePeriod[index] = _period;
    }

    function stake(uint256 amount, uint256 periodIndex) external {
        require(periodIndex!= 0, "Staker: Wrong period index");
        require(stakePeriod[periodIndex] != 0, "Staker: Wrong period index");

        UserInfo storage user = userInfo[msg.sender];
        
        require(stakePeriod[periodIndex] >= stakePeriod[user.stakePeriodIndex], "Staker: Can not change to lower stake period");

        user.stakeStartTime = block.timestamp;
        user.stakePeriodIndex = periodIndex;
        user.stakeAmount += amount;

        hxto.transferFrom(msg.sender, address(this), amount);

        emit Stake(msg.sender, amount, stakePeriod[periodIndex]);
    }

    function unstake(uint256 amount) external {
        UserInfo storage user = userInfo[msg.sender];

        require(user.stakePeriodIndex != 0, "Staker: User period index is zero");
        require(user.stakeStartTime + stakePeriod[user.stakePeriodIndex] <= block.timestamp, "Staker: Can claim after lock up period");

        if(amount >= user.stakeAmount){
            amount = user.stakeAmount;
            
            user.stakeAmount = 0;
            user.stakePeriodIndex = 0;
        }else {
            user.stakeAmount -= amount;
        }

        hxto.transfer(msg.sender, amount);

        emit Unstake(msg.sender, amount);
    }
}
