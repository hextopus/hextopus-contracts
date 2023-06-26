// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IERC20.sol";
import "../interfaces/IHXTO.sol";

contract Vester is Ownable {
    struct Vesting {
        uint256 payout; 
        uint256 vestingPeriod; 
        uint256 lastBlock;
    }

    mapping( address => Vesting ) public vestingInfo; 

    bool isActive = false;

    uint256 public defaultVestingPeriod = 90 days;

    IHXTO public immutable esHxto;
    IHXTO public immutable hxto;

    /// @notice Vesting HXTO amounts + Campaign reward pool HXTO amounts
    uint256 public totalReservedAmount;
    mapping(address => bool) public isActiveCampaign;

    // Precision
    uint256 public constant BASE_PRECISION = 10000;
    uint256 public VEST_BPS = 5000; 

    event SetVestingPeriod(uint256);
    event SetVestBasisPoints(uint256);
    event SetActiveCampaign(address, bool);
    event Vest(address, uint256);
    event Redeem(address, uint256);
    event Withdraw(address, uint256);

    constructor(IHXTO _esHxto, IHXTO _hxto){
        esHxto = _esHxto;
        hxto = _hxto;
    }

    function setVestingPeriod(uint256 _vestingPeriod) external onlyOwner {
        require(_vestingPeriod != 0, "Vester: Vesting duration can not be zero");

        defaultVestingPeriod = _vestingPeriod;

        emit SetVestingPeriod(_vestingPeriod);
    }

    function setVestBasisPoints(uint256 _bps) external onlyOwner {
        require(_bps != 0, "Vester: Basis point can not be zero");

        VEST_BPS = _bps;

        emit SetVestBasisPoints(_bps);
    }

    function setActiveCampaign(address _campaign, bool _isActive) external onlyOwner {
        require(_campaign != address(0), "Vester: Campaign can not be zero address");

        isActiveCampaign[_campaign] = _isActive;

        emit SetActiveCampaign(_campaign, _isActive);
    }

    function setIsActive(bool _isActive) external onlyOwner {
        isActive = _isActive;
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external onlyOwner {
        IERC20(_token).transfer(_account, _amount);
    }

    function vest(uint256 amount) external {
        require(isActive, "Vester: Vester is not active");
        require(amount != 0, "Vester: Vesting amount can not be zero");

        uint256 hxtoAmount = amount * VEST_BPS / BASE_PRECISION;

        vestingInfo[ msg.sender ] = Vesting({ 
            payout: vestingInfo[ msg.sender ].payout + ( amount + hxtoAmount ),
            vestingPeriod: defaultVestingPeriod,
            lastBlock: block.timestamp
        });

        // esHXTO amounts + HXTO amounts will be reserved for redeem
        totalReservedAmount += (amount + hxtoAmount);

        esHxto.transferFrom(msg.sender, address(this), amount);
        hxto.transferFrom(msg.sender, address(this), hxtoAmount);

        esHxto.burn(address(this), amount);

        emit Vest(msg.sender, amount);
    }

    function redeem() external {
        Vesting memory userVestInfo = vestingInfo[msg.sender];

        uint percentVested = percentVestedFor(msg.sender); 

        if ( percentVested >= 10000 ) { 
            // fully vested
            delete vestingInfo[ msg.sender ];

            hxto.transfer( msg.sender, userVestInfo.payout );

            totalReservedAmount -= userVestInfo.payout;

            emit Redeem(msg.sender, userVestInfo.payout);
        } else { 
            // partially vested 
            uint256 payout = userVestInfo.payout * percentVested / 10000;
            
            vestingInfo[ msg.sender ] = Vesting({
                payout: userVestInfo.payout - payout,
                vestingPeriod: userVestInfo.vestingPeriod - (block.timestamp - userVestInfo.lastBlock),
                lastBlock: block.timestamp
            });

            hxto.transfer( msg.sender, payout );

            totalReservedAmount -= payout;

            emit Redeem(msg.sender, payout);
        }
    }

    ///  @notice calculate how far into vesting a depositor is
    ///  @param _depositor address
    ///  @return percentVested_ uint
    function percentVestedFor( address _depositor ) public view returns ( uint percentVested_ ) {
        Vesting memory userVestInfo = vestingInfo[ _depositor ];

        uint blocksSinceLast = block.timestamp - userVestInfo.lastBlock;

        uint vesting = userVestInfo.vestingPeriod;

        if ( vesting > 0 ) {
            percentVested_ = blocksSinceLast * 10000 / vesting;
        } else {
            percentVested_ = 0;
        }
    }

    /// @notice calculate amount of payout token available for claim by account
    /// @param account address
    /// @return pendingPayout_ uint 
    function claimable(address account) external view returns (uint256){
        Vesting memory userVestInfo = vestingInfo[account];

        uint percentVested = percentVestedFor(account); 

        if ( percentVested >= 10000 ) { 
            return userVestInfo.payout;
        } else { 
            return userVestInfo.payout * percentVested / 10000;
        }
    }

    function withdraw(uint256 amount) external {
        require(isActiveCampaign[msg.sender], "Vester: Sender must be active campaign");

        uint256 hxtoBalance = hxto.balanceOf(address(this));

        require((hxtoBalance - amount) >= totalReservedAmount, "Vester: Insufficient reserve");

        hxto.transfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount);
    }
}
