// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./SVGNFT.sol";

contract SVGStaking is ERC20, ReentrancyGuard, Ownable {
    SVGNFT nftToken;
    // uint256 public immutable maxSupply;
    uint256 public rewardPerDay;

    mapping(address => Staker) public addressToStaker;
    mapping(uint256 => bool) public tokenIdStaked;

    struct Staker {
        uint256 stakedAmount;
        uint256[] stakedTokenIdList;
        uint256 lastUpdatedTime;
        uint256 unclaimedRewards;
    }

    constructor(address payable _nftContractAddress)
        ERC20("SVG NFT reward token", "svgNFT")
        ReentrancyGuard()
    {
        nftToken = SVGNFT(_nftContractAddress);
        // // maxSupply capped at 10 million
        // maxSupply = 10000000 * 10**18;
        // 10 tokens per NFT staked per day (until we reach the maxSupply)
        rewardPerDay = 10 * 10**18;
    }

    // To update _mint function if we have a max supply cap
    // function _mint(
    //     address _address,
    //     uint256 _amount
    // ) internal override(ERC20) {
    //     require( _totalSupply + _amount <= maxSupply);
    //     super._mint(_address, _amount);
    // }

    function getStakedTokenIdList(address _address)
        external
        view
        returns (uint256[] memory _tokenIdList)
    {
        _tokenIdList = addressToStaker[_address].stakedTokenIdList;
    }

    function updateRewardAmountPerDay(uint256 _amountEther) external onlyOwner {
        uint256 _amountWei = _amountEther * 10**18;
        rewardPerDay = _amountWei;
    }

    function stake(uint256 _tokenId) public nonReentrant {
        require(tokenIdStaked[_tokenId] != true, "Token already staked!");
        require(
            nftToken.tokenIdLocked(_tokenId) != true,
            "Token must not be locked!"
        );
        require(
            nftToken.ownerOf(_tokenId) == msg.sender,
            "You can only stake tokens you own!"
        );
        nftToken.lockToken(_tokenId, address(this), true);
        tokenIdStaked[_tokenId] = true;
        addressToStaker[msg.sender].unclaimedRewards += calculateRewards(
            msg.sender
        );
        addressToStaker[msg.sender].stakedAmount += 1;
        addressToStaker[msg.sender].stakedTokenIdList.push(_tokenId);
        addressToStaker[msg.sender].lastUpdatedTime = block.timestamp;
    }

    function stakeAll() external nonReentrant {
        uint256 _nftCount = nftToken.balanceOf(msg.sender);
        require(_nftCount > 0, "You don't have any tokens to stake!");
        for (uint256 i = 0; i < _nftCount; i++) {
            uint256 _tokenId = nftToken.tokenOfOwnerByIndex(msg.sender, i);
            if (
                tokenIdStaked[_tokenId] != true &&
                nftToken.tokenIdLocked(_tokenId) != true
            ) {
                nftToken.lockToken(_tokenId, address(this), true);
                tokenIdStaked[_tokenId] = true;
                addressToStaker[msg.sender]
                    .unclaimedRewards += calculateRewards(msg.sender);
                addressToStaker[msg.sender].stakedAmount += 1;
                addressToStaker[msg.sender].stakedTokenIdList.push(_tokenId);
                addressToStaker[msg.sender].lastUpdatedTime = block.timestamp;
            }
        }
    }

    function removeFromArray(uint256[] storage _array, uint256 _index)
        internal
    {
        _array[_index] = _array[_array.length - 1];
        _array.pop();
    }

    function unstake(uint256 _tokenId) public nonReentrant {
        require(tokenIdStaked[_tokenId] == true, "Token is already unstaked!");
        require(
            nftToken.ownerOf(_tokenId) == msg.sender,
            "You can only unstake tokens you own!"
        );
        addressToStaker[msg.sender].unclaimedRewards += calculateRewards(
            msg.sender
        );
        addressToStaker[msg.sender].stakedAmount -= 1;
        for (
            uint256 i = 0;
            i < addressToStaker[msg.sender].stakedTokenIdList.length;
            i++
        ) {
            if (addressToStaker[msg.sender].stakedTokenIdList[i] == _tokenId) {
                removeFromArray(
                    addressToStaker[msg.sender].stakedTokenIdList,
                    i
                );
            }
        }
        addressToStaker[msg.sender].lastUpdatedTime = block.timestamp;
        tokenIdStaked[_tokenId] = false;
        nftToken.unlockToken(_tokenId);
    }

    function unstakeAll() external nonReentrant {
        require(
            addressToStaker[msg.sender].stakedTokenIdList.length > 0,
            "You don't have anything to unstake!"
        );
        addressToStaker[msg.sender].unclaimedRewards += calculateRewards(
            msg.sender
        );
        addressToStaker[msg.sender].stakedAmount = 0;
        for (
            uint256 i = 0;
            i < addressToStaker[msg.sender].stakedTokenIdList.length;
            i++
        ) {
            uint256 _tokenId = addressToStaker[msg.sender].stakedTokenIdList[i];
            tokenIdStaked[_tokenId] = false;
            nftToken.unlockToken(_tokenId);
        }
        addressToStaker[msg.sender].stakedTokenIdList = new uint256[](0);
        addressToStaker[msg.sender].lastUpdatedTime = block.timestamp;
    }

    function claimRewards() external nonReentrant {
        uint256 claimableAmount = getAvailableRewards(msg.sender);
        require(claimableAmount > 0, "You have no rewards to claim!");
        addressToStaker[msg.sender].unclaimedRewards = 0;
        _mint(msg.sender, claimableAmount);
        addressToStaker[msg.sender].lastUpdatedTime = block.timestamp;
    }

    function calculateRewards(address _address)
        public
        view
        returns (uint256 rewardAmount)
    {
        uint256 rewardPerSecond = rewardPerDay / (24 * 60 * 60);
        rewardAmount =
            (block.timestamp - addressToStaker[_address].lastUpdatedTime) *
            addressToStaker[_address].stakedAmount *
            rewardPerSecond;
    }

    function getAvailableRewards(address _address)
        public
        view
        returns (uint256 availableRewards)
    {
        availableRewards =
            addressToStaker[_address].unclaimedRewards +
            calculateRewards(_address);
    }

    function withdrawFunds() external payable onlyOwner {
        (bool sent, ) = msg.sender.call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}
}
