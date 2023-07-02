// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTCapReader is Ownable{
    struct NFTUtil {
        address NFT;
        uint256 multiplier;
    }

    NFTUtil[] public NFTList;

    function setNFTUtil (address _NFT, uint256 _multiplier) public onlyOwner {
        NFTList.push(NFTUtil(
            _NFT,
            _multiplier
        ));
    }

    function editNFTUtil (uint256 _index, uint256 _multiplier) public onlyOwner {
        NFTList[_index].multiplier = _multiplier;
    }

    function getNFTMultiplier (address _account) public view returns(uint256){
        require(_account != address(0), "NFTCapReader: Address can not be zero");
        
        uint256 maxMultiplier = 0;

        for(uint256 i = 0; i < NFTList.length; i++){
            uint256 NFTBalance = IERC721(NFTList[i].NFT).balanceOf(_account);
            
            if(NFTBalance > 0 && maxMultiplier < NFTList[i].multiplier){
                maxMultiplier = NFTList[i].multiplier;
            }
        }
        
        return maxMultiplier;
    }
}