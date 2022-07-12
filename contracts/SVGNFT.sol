// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "./SVGFactory.sol";
import "./Lockable.sol";

contract SVGNFT is
    VRFConsumerBaseV2,
    ERC721Enumerable,
    ERC721URIStorage,
    Ownable,
    Lockable,
    SVGFactory
{
    bytes32 immutable keyHash =
        0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;
    uint64 subscriptionId;
    uint32 callbackGasLimit = 500000;
    uint16 immutable requestConfirmations = 3;
    uint32 immutable numWords = 1;
    uint256 public s_requestId;
    uint256 public tokenCounter;
    uint256 public maxSupply;
    uint256 public mintPriceWei;
    VRFCoordinatorV2Interface COORDINATOR;
    bool paused = false;

    mapping(uint256 => address) internal requestIdToSender;
    mapping(uint256 => uint256) internal requestIdToTokenId;
    mapping(uint256 => uint256) internal tokenIdToRandomness;

    event RequestedRandomSVG(uint256 requestId, uint256 tokenId);
    event CreatedUnfinishedSVG(uint256 tokenId, uint256 randomNumber);
    event CompletedNFTMint(uint256 tokenId, string tokenURI);

    constructor(uint64 _subscriptionId, address _vrfCoordinator)
        ERC721("Random SVG NFT", "rSVGNFT")
        VRFConsumerBaseV2(_vrfCoordinator)
        Lockable(address(this))
        SVGFactory()
    {
        subscriptionId = _subscriptionId;
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
        tokenCounter = 1;
        maxSupply = 500;
        mintPriceWei = 0.05 * 10**18;
    }

    function updateMintPrice(uint256 _mintPriceEther) external onlyOwner {
        uint256 _mintPriceWei = _mintPriceEther * 10**18;
        mintPriceWei = _mintPriceWei;
    }

    function create() external payable returns (uint256) {
        require(tokenCounter <= maxSupply, "Sorry, we have minted out!");
        require(
            msg.value == mintPriceWei,
            "You need to include the right eth amount for mint!"
        );
        s_requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        requestIdToSender[s_requestId] = msg.sender;
        requestIdToTokenId[s_requestId] = tokenCounter;
        emit RequestedRandomSVG(s_requestId, tokenCounter);
        tokenCounter += 1;
        return s_requestId;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomness)
        internal
        override
    {
        address nftOwner = requestIdToSender[requestId];
        uint256 tokenId = requestIdToTokenId[requestId];
        _safeMint(nftOwner, tokenId);
        tokenIdToRandomness[tokenId] = randomness[0];
        emit CreatedUnfinishedSVG(tokenId, randomness[0]);
    }

    function completeMint(uint256 _tokenId)
        external
        returns (string memory _tokenURI)
    {
        require(
            bytes(tokenURI(_tokenId)).length <= 0,
            "Mint already completed!"
        );
        require(tokenCounter > _tokenId, "Token not minted yet!");
        require(
            tokenIdToRandomness[_tokenId] > 0,
            "Still waiting for random number from Chainlink VRF"
        );

        uint256 randomNumber = tokenIdToRandomness[_tokenId];
        string memory svg = _generateSVG(randomNumber);
        string memory _imageURI = _svgToImageURI(svg);
        _tokenURI = _formatTokenURI(_imageURI);
        _setTokenURI(_tokenId, _tokenURI);
        emit CompletedNFTMint(_tokenId, _tokenURI);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        require(tokenIdLocked[tokenId] != true);
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function withdrawFunds() external payable onlyOwner {
        (bool sent, ) = msg.sender.call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");
    }

    function togglePause() external onlyOwner {
        paused = !paused;
    }

    function updateChainlinkSubscriptionId(uint64 _subId) external onlyOwner {
        subscriptionId = _subId;
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}
}
