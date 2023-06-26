// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IHXTO.sol";
import "../interfaces/IBaseCampaign.sol";
import "../interfaces/IStaker.sol";

contract CapReader is Ownable{
    IHXTO public immutable hxto;
    IHXTO public immutable esHxto;

    IStaker public staker;

    /// @notice Index 0 reserved for esHxto
    mapping(uint256 => uint256) public stakeAdditionalCap;

    // Precision
    uint256 public constant BASE_PRECISION = 1000;

    constructor(IHXTO _esHxto, IHXTO _hxto, IStaker _staker){
        esHxto = _esHxto;
        hxto = _hxto;
        staker = _staker;
    }

    function setStaker (IStaker _staker) public onlyOwner {
        require(address(_staker) != address(0), "CapReader: Staker cap can not be zero");

        staker = _staker;
    }

    function setStakeAdditionalCap (uint256 index, uint256 _additionalCap) public onlyOwner {
        require(_additionalCap != 0, "CapReader: Additional cap can not be zero");

        stakeAdditionalCap[index] = _additionalCap;
    }

    function getCap (address account) public view returns(uint256){
        require(account != address(0), "CapReader: Address can not be zero");

        IStaker.UserInfo memory userStakeInfo = staker.userInfo(account);

        uint256 hxtoAdditionalCap = userStakeInfo.stakeAmount * stakeAdditionalCap[userStakeInfo.stakePeriodIndex] / BASE_PRECISION;
        uint256 esHxtoAdditionalCap = esHxto.balanceOf(account) * stakeAdditionalCap[0] / BASE_PRECISION;
        
        return hxtoAdditionalCap + esHxtoAdditionalCap;
    }
}