// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract Lockable {
    IERC721 tokenContract;

    mapping(uint256 => bool) public tokenIdLocked;
    mapping(uint256 => address) public tokenIdController;

    constructor(address _tokenAddress) {
        tokenContract = IERC721(_tokenAddress);
    }

    function lockToken(
        uint256 _tokenId,
        address _controller,
        bool _proxy
    ) public {
        require(tokenIdLocked[_tokenId] != true, "Token is already locked!");
        address tokenOwner;
        if (_proxy) {
            tokenOwner = tx.origin;
        } else {
            tokenOwner = msg.sender;
        }
        require(
            tokenOwner == tokenContract.ownerOf(_tokenId),
            "You must own the tokenId in order to lock it!"
        );
        require(_controller != address(0), "Controller address must not be 0!");
        tokenIdLocked[_tokenId] = true;
        tokenIdController[_tokenId] = _controller;
    }

    function unlockToken(uint256 _tokenId) public {
        require(tokenIdLocked[_tokenId] == true, "Token is not locked!");
        require(
            msg.sender == tokenIdController[_tokenId],
            "Only designated controller address can initiate unlock!"
        );
        tokenIdLocked[_tokenId] = false;
        delete tokenIdController[_tokenId];
    }
}
