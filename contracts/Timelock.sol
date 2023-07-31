// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "./interfaces/ITimelock.sol";
import "./interfaces/IBaseCampaign.sol";
import "./interfaces/IBaseLockupCampaign.sol";
import "./interfaces/IBaseNFTCampaign.sol";

contract Timelock is ITimelock {
    uint256 public constant MAX_BUFFER = 5 days;
    uint256 public minAuthorizations = 2;
    uint256 public buffer;
    address public admin;

    mapping (bytes32 => uint256) public pendingActions;
    mapping (address => address[]) public campaignManagers;
    mapping (address => mapping(address => bool)) public isManager;
    mapping (address => mapping (bytes32 => bool)) public signedActions;

    event SignAction(address signer, bytes32 action);
    event SignalPendingAction(bytes32 action);
    event SignalSetWinners(address campaign, address[] _winners, address[] _raffleWinners);
    event SignalSetBeforeAddRewards(address campaign, uint256 rewardTokenAmount, uint256 hxtoAmount);
    event SignalSetBeforeNFTAddRewards(address campaign, uint256 hxtoAmount);
    event SignalSetExitTrigger(address campaign, bool isExit, address receiver);
    event ClearAction(bytes32 action);

    modifier onlyManager(address _campaign) {
        require(msg.sender == admin || isManager[_campaign][msg.sender], "CampaginManager: forbidden");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "CampaignManager: forbidden");
        _;
    }

    constructor(
        uint256 _buffer
    ) {
        require(_buffer <= MAX_BUFFER, "CampaignManager: invalid _buffer");
        admin = msg.sender;
        buffer = _buffer;
    }

    function setMinAuthorization(uint256 _auth) external onlyAdmin {
        minAuthorizations = _auth;
    }

    function setAdmin(address _admin) external override onlyAdmin {
        admin = _admin;
    }

    function setCampaignManager(address _campaign, address _manager, bool _isActive) external onlyAdmin {
        isManager[_campaign][_manager] = _isActive;
        campaignManagers[_campaign].push(_manager);
    }

    function signalSetIsClaimable(address _campaign, bool _isClaimable) external onlyManager(_campaign) {
        bytes32 action = keccak256(abi.encodePacked("setIsClaimable", _campaign, _isClaimable));
        _setPendingAction(action);
        signedActions[msg.sender][action] = true;
    }

    function signSetIsClaimable(address _campaign, bool _isClaimable) external onlyManager(_campaign) {
        bytes32 action = keccak256(abi.encodePacked("setIsClaimable", _campaign, _isClaimable));
        require(pendingActions[action] != 0, "Timelock: action not signalled");
        require(!signedActions[msg.sender][action], "Timelock: already signed");
        signedActions[msg.sender][action] = true;
        emit SignAction(msg.sender, action);
    }

    function setIsClaimable(address _campaign, bool _isClaimable) external onlyManager(_campaign) {
        bytes32 action = keccak256(abi.encodePacked("setIsClaimable", _campaign, _isClaimable));
        _validateAction(action);
        _validateAuthorization(_campaign, action);

        IBaseLockupCampaign(_campaign).setIsClaimable(
            _isClaimable
        );
    }

    function signalSetExitTrigger(address _campaign, bool _isExit, address _exitReceiver) external onlyManager(_campaign) {
        bytes32 action = keccak256(abi.encodePacked("setExitTrigger", _campaign, _isExit, _exitReceiver));
        _setPendingAction(action);
        signedActions[msg.sender][action] = true;
        emit SignalSetExitTrigger(_campaign, _isExit, _exitReceiver);
    }

    function signSetExitTrigger(address _campaign, bool _isExit, address _exitReceiver) external onlyManager(_campaign) {
        bytes32 action = keccak256(abi.encodePacked("setExitTrigger", _campaign, _isExit, _exitReceiver));
        require(pendingActions[action] != 0, "Timelock: action not signalled");
        require(!signedActions[msg.sender][action], "Timelock: already signed");
        signedActions[msg.sender][action] = true;
        emit SignAction(msg.sender, action);
    }

    function setExitTrigger(address _campaign, bool _isExit, address _exitReceiver) external onlyManager(_campaign) {
        bytes32 action = keccak256(abi.encodePacked("setExitTrigger", _campaign, _isExit, _exitReceiver));
        _validateAction(action);
        _validateAuthorization(_campaign, action);

        IBaseCampaign(_campaign).setExitTrigger(
            _isExit,
            _exitReceiver
        );
    }

    function signalSetBeforeNFTAddRewards(address _campaign, uint256 _hxtoAmount, uint256 _directReferralMultiplier, uint256 _indirectReferralMultiplier, uint256 _minimumTargetAccounts) external onlyManager(_campaign) {
        bytes32 action = keccak256(abi.encodePacked("setBeforeAddRewards", _campaign, _hxtoAmount, _directReferralMultiplier, _indirectReferralMultiplier, _minimumTargetAccounts));
        _setPendingAction(action);
        signedActions[msg.sender][action] = true;
        emit SignalSetBeforeNFTAddRewards(_campaign, _hxtoAmount);
    }

    function signSetBeforeNFTAddRewards(address _campaign, uint256 _hxtoAmount, uint256 _directReferralMultiplier, uint256 _indirectReferralMultiplier, uint256 _minimumTargetAccounts) external onlyManager(_campaign) {
        bytes32 action = keccak256(abi.encodePacked("setBeforeAddRewards", _campaign, _hxtoAmount, _directReferralMultiplier, _indirectReferralMultiplier, _minimumTargetAccounts));
        require(pendingActions[action] != 0, "Timelock: action not signalled");
        require(!signedActions[msg.sender][action], "Timelock: already signed");
        signedActions[msg.sender][action] = true;
        emit SignAction(msg.sender, action);
    }

    function setBeforeNFTAddRewards(address _campaign, uint256 _hxtoAmount, uint256 _directReferralMultiplier, uint256 _indirectReferralMultiplier, uint256 _minimumTargetAccounts) external onlyManager(_campaign) {
        bytes32 action = keccak256(abi.encodePacked("setBeforeAddRewards", _campaign, _hxtoAmount, _directReferralMultiplier, _indirectReferralMultiplier, _minimumTargetAccounts));
        _validateAction(action);
        _validateAuthorization(_campaign, action);

        IBaseNFTCampaign(_campaign).setBeforeAddRewards(
            _hxtoAmount, 
            _directReferralMultiplier, 
            _indirectReferralMultiplier, 
            _minimumTargetAccounts
        );
    }

    function signalSetBeforeAddRewards(address _campaign, uint256 _rewardTokenAmount, uint256 _hxtoAmount, uint256 _directReferralMultiplier, uint256 _indirectReferralMultiplier, uint256 _minimumParticipationAccounts, uint256 _minimumReferralAccounts) external onlyManager(_campaign) {
        bytes32 action = keccak256(abi.encodePacked("setBeforeAddRewards", _campaign, _rewardTokenAmount, _hxtoAmount, _directReferralMultiplier, _indirectReferralMultiplier, _minimumParticipationAccounts, _minimumReferralAccounts));
        _setPendingAction(action);
        signedActions[msg.sender][action] = true;
        emit SignalSetBeforeAddRewards(_campaign, _rewardTokenAmount, _hxtoAmount);
    }

    function signSetBeforeAddRewards(address _campaign, uint256 _rewardTokenAmount, uint256 _hxtoAmount, uint256 _directReferralMultiplier, uint256 _indirectReferralMultiplier, uint256 _minimumParticipationAccounts, uint256 _minimumReferralAccounts) external onlyManager(_campaign) {
        bytes32 action = keccak256(abi.encodePacked("setBeforeAddRewards", _campaign, _rewardTokenAmount, _hxtoAmount, _directReferralMultiplier, _indirectReferralMultiplier, _minimumParticipationAccounts, _minimumReferralAccounts));
        require(pendingActions[action] != 0, "Timelock: action not signalled");
        require(!signedActions[msg.sender][action], "Timelock: already signed");
        signedActions[msg.sender][action] = true;
        emit SignAction(msg.sender, action);
    }

    function setBeforeAddRewards(address _campaign, uint256 _rewardTokenAmount, uint256 _hxtoAmount, uint256 _directReferralMultiplier, uint256 _indirectReferralMultiplier, uint256 _minimumParticipationAccounts, uint256 _minimumReferralAccounts) external onlyManager(_campaign) {
        bytes32 action = keccak256(abi.encodePacked("setBeforeAddRewards", _campaign, _rewardTokenAmount, _hxtoAmount, _directReferralMultiplier, _indirectReferralMultiplier, _minimumParticipationAccounts, _minimumReferralAccounts));
        _validateAction(action);
        _validateAuthorization(_campaign, action);

        IBaseCampaign(_campaign).setBeforeAddRewards(
            _rewardTokenAmount, 
            _hxtoAmount, 
            _directReferralMultiplier, 
            _indirectReferralMultiplier, 
            _minimumParticipationAccounts,
            _minimumReferralAccounts
        );
    }

    function setMinAuthorizations(uint256 _count) external onlyAdmin {
        minAuthorizations = _count;
    }

    function cancelAction(bytes32 _action) external onlyAdmin {
        _clearAction(_action);
    }

    function _setPendingAction(bytes32 _action) private {
        require(pendingActions[_action] == 0, "Timelock: action already signalled");
        pendingActions[_action] = block.timestamp + buffer;
        emit SignalPendingAction(_action);
    }

    function _validateAction(bytes32 _action) private view {
        require(pendingActions[_action] != 0, "Timelock: action not signalled");
        require(pendingActions[_action] < block.timestamp, "Timelock: action time not yet passed");
    }

    function _clearAction(bytes32 _action) private {
        require(pendingActions[_action] != 0, "Timelock: invalid _action");
        delete pendingActions[_action];
        emit ClearAction(_action);
    }

    function _validateAuthorization(address _campaign, bytes32 _action) private view {
        uint256 count = 0;
        uint256 len = campaignManagers[_campaign].length;
        for (uint256 i = 0; i < len; i++) {
            address signer = campaignManagers[_campaign][i];
            if (signedActions[signer][_action]) {
                count++;
            }
        }

        if (count == 0) {
            revert("Timelock: action not authorized");
        }

        require(count >= minAuthorizations, "Timelock: insufficient authorization");
    }
}
