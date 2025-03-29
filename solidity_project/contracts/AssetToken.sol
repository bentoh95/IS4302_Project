// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AssetToken
 * @notice A simple ERC721 token representing fractional shares of a physical asset.
 *         In a more advanced setup, you might keep share logic in a separate registry,
 *         but this example demonstrates storing it in the token contract itself.
 */
contract AssetToken is ERC721, Ownable(msg.sender) {
    /// @dev Token ID counter to increment each time we mint.
    uint256 private _nextTokenId;

    /// @dev (Optional) Mapping token ID => asset ID (e.g., keccak256("Property A"))
    ///      so multiple tokens can belong to one "physical asset."
    mapping(uint256 => uint256) public tokenToAssetId;

    /// @dev (Optional) Mapping token ID => % share (e.g., 25 = 25%)
    ///      If you want to track fractional ownership for each token.
    mapping(uint256 => uint256) public tokenSharePercentage;

    /// @notice Emitted when a new token is minted with share data.
    event ShareMinted(
        address indexed to,
        uint256 indexed tokenId,
        uint256 indexed assetId,
        uint256 sharePercentage
    );

    /**
     * @dev Passes name="Test" and symbol="TST" to the ERC721 constructor.
     *      Adjust as you like (e.g., "AssetToken", "AST").
     */
    constructor() ERC721("AssetToken", "AST") {
        // You could do additional setup here if needed.
    }

    /**
     * @notice Simple mint function restricted to the contract owner.
     * @param to The address receiving the new token.
     * @return tokenId The newly minted token’s ID.
     *
     * Usage:
     *  - Mints an NFT with no specific asset/percentage data.
     *  - You can use setTokenAssetAndShare() if you want to add them after minting.
     */

    // Create tokens only after death, in that case owner is the platform since the platform is creating
    function mint(address to) external onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId;
        _nextTokenId++;

        _safeMint(to, tokenId);

        return tokenId;
    }

    /**
     * @notice Mint a fractional share of a specific asset in one step.
     * @param to The address receiving the new token.
     * @param assetId A unique identifier for the physical asset (e.g. keccak256("Property A")).
     * @param sharePercentage The fraction of the asset represented by this token (e.g., 25 = 25%).
     * @return tokenId The newly minted token’s ID.
     *
     * Ensures the total minted shares (if you track them externally) do not exceed 100%. // TODO in AssetRegistry: track 100% 
     * That's typically enforced in a separate registry, but you can do it here if you store cumulative shares.
     */
    function mintShare(
        address to,
        uint256 assetId,
        uint256 sharePercentage
    ) external onlyOwner returns (uint256) {
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
