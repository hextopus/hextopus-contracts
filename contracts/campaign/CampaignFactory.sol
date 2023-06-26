// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "../libraries/Clones.sol";
import "../interfaces/IBaseCampaign.sol";

contract CampaignFactory {
    address immutable impl;

    event ClonedCampaign(address indexed);

    constructor(address _impl){
        impl = _impl;
    }

    function clone(bytes memory _config, bytes memory _tokenConfig) external returns (address){
        address cloneContract = Clones.clone(impl);

        IBaseCampaign(cloneContract).initialize(_config, _tokenConfig);

        emit ClonedCampaign(cloneContract);
        
        return cloneContract;
    }
}