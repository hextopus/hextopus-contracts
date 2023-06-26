// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "../libraries/Clones.sol";
import "../interfaces/IBaseSocialAction.sol";

contract SocialActionFactory {
    address immutable impl;

    event ClonedSocialAction(address indexed);

    constructor(address _impl){
        impl = _impl;
    }

    function clone(bytes memory _config) external returns (address){
        address cloneContract = Clones.clone(impl);

        IBaseSocialAction(cloneContract).initialize(_config);

        emit ClonedSocialAction(cloneContract);
        
        return cloneContract;
    }
}