// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * A simple ERC721 token representing fractional shares of a physical asset.
*/
contract AssetToken is ERC721 {
    uint256 private _nextTokenId;

    // Mapping token ID => asset ID so multiple tokens can belong to one "physical asset."
    mapping(uint256 => uint256) public tokenToAssetId;

    // Mapping token ID => % share to track fractional ownership for each token.
    mapping(uint256 => uint256) public tokenSharePercentage;

    event ShareMinted(
        address indexed to,
        uint256 indexed tokenId,
        uint256 indexed assetId,
        uint256 sharePercentage
    );

    constructor() ERC721("AssetToken", "AST") {
    }

    // Create tokens only after death, in that case owner is the platform since the platform is creating
    function mint(address to) external returns (uint256) {
        uint256 tokenId = _nextTokenId;
        _nextTokenId++;

        _safeMint(to, tokenId);

        return tokenId;
    }

    function mintShare(
        address to,
        uint256 assetId,
        uint256 sharePercentage
    ) external returns (uint256) {
        require(sharePercentage > 0, "Share must be > 0");

        uint256 tokenId = _nextTokenId;
        _nextTokenId++;

        // Mint the actual NFT
        _safeMint(to, tokenId);

        // Store share info
        tokenToAssetId[tokenId] = assetId;
        tokenSharePercentage[tokenId] = sharePercentage;

        emit ShareMinted(to, tokenId, assetId, sharePercentage);

        return tokenId;
    }
}
