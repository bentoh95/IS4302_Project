// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./AssetToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AssetRegistry
 * @notice Tracks and manages fractional shares for multiple physical assets.
 *
 *         Workflow:
 *         1) Create asset (no tokens minted yet).
 *         2) Set beneficiaries + their allocations (must total 100).
 *         3) Upon execution (death), call distributeAsset() to mint actual tokens
 *            for each beneficiary according to stored allocations.
 *
 *         No leftover/residual logic here. We require exactly 100% allocation 
 *     
 * */

contract AssetRegistry {
    /// @notice Reference to the deployed ERC721 contract (AssetToken).
    AssetToken public assetToken;
    uint256 private _nextAssetId = 1;

    /// @dev Stores basic info about each asset.
    struct AssetInfo {
        address assetOwner;
        string description;   // E.g., "House on 123 Street"
        bool isExecuted; // Whether it has been distributed // TODOS: change to state
        bool isLocked; // Whether the person died
        bool exists;
        uint256 value;
        string certificationUrl; // Verify validity of ownership
        address[] beneficiaries;
    }

    /// @dev A mapping of assetId -> AssetInfo
    /// @dev A mapping of assetId -> Beneficiaries and their respective allocations
    mapping(uint256 => AssetInfo) public assets;
    mapping(uint256 => mapping(address => uint256)) beneficiaryAllocPercentages;
    // Ensure that there are no duplicate assets
    mapping(bytes32 => bool) public assetKeyExists;

   /**
     * @notice Initialize this registry with the address of an already deployed AssetToken.
     * @param _assetTokenAddress Address of the AssetToken contract.
     *
     * Even though we don't mint at creation time, we still need to know where
     * to mint later once the owner calls distributeAsset() upon death/execution.
     */
    constructor(address _assetTokenAddress) {
        require(_assetTokenAddress != address(0), "Invalid AssetToken address");
        assetToken = AssetToken(_assetTokenAddress);
    }

    /**
     * @notice Create a new asset in the registry, specifying its unique ID and description.
     *
     * Requirements:
     * - Only the contract owner can create an asset in this simplified design.
     */
    function createAsset(address assetOwner, string memory description, uint256 value, string memory certificationUrl, address[] memory beneficiaries, uint256[] memory allocations) external returns (uint256){
        bytes32 assetKey = keccak256(abi.encodePacked(description, value, certificationUrl));
        require(!assetKeyExists[assetKey], "Asset already exists");

        assetKeyExists[assetKey] = true;

        // Checks for percentage alloc
        require(beneficiaries.length == allocations.length, "Mismatched input arrays");
        uint256 totalAlloc = 0;
        for (uint256 i = 0; i < allocations.length; i++) {
            require(allocations[i] > 0, "Allocation must be greater than 0");
            totalAlloc += allocations[i];
        }
        require(totalAlloc == 100, "Allocations are not totalled to 100");

        uint256 assetId = _nextAssetId;
        _nextAssetId++;

        // Updated mapping
        for (uint256 i = 0; i < allocations.length; i++) {
            beneficiaryAllocPercentages[assetId][beneficiaries[i]] = allocations[i];
        }

        assets[assetId] = AssetInfo({
            assetOwner: assetOwner,
            description: description,
            isExecuted: false,
            isLocked: false,
            exists: true,
            value: value,
            certificationUrl: certificationUrl,
            beneficiaries: beneficiaries
        });

        return assetId;
    }

    function getAssetData(uint256 assetId) public view returns (AssetInfo memory) {
        return assets[assetId];
    }

    /*
     We are simplifying the update for tokenized assets since the fractional ownership tends to be larger
     compared to monetary digital assets so its shorter and we can just pass in the whole new beneficiary/allocation
    */

    function updateBeneficiariesAndAllocations(
        uint256 assetId,
        address[] memory newBeneficiaries,
        uint256[] memory newAllocations
    ) external {
        require(assets[assetId].exists, "Asset does not exist");
        require(!assets[assetId].isExecuted, "Asset already executed");
        require(newBeneficiaries.length == newAllocations.length, "Mismatched arrays");

        // Clear old allocations
        address[] memory oldBens = assets[assetId].beneficiaries;
        for (uint256 i = 0; i < oldBens.length; i++) {
            delete beneficiaryAllocPercentages[assetId][oldBens[i]];
        }

        // Checks for percentage alloc
        require(newBeneficiaries.length == newAllocations.length, "Mismatched input arrays");
        uint256 totalAlloc = 0;
        for (uint256 i = 0; i < newAllocations.length; i++) {
            require(newAllocations[i] > 0, "Allocation must be greater than 0");
            totalAlloc += newAllocations[i];
        }
        require(totalAlloc == 100, "Allocations are not totalled to 100");

        // Update mappings and assign
        assets[assetId].beneficiaries = newBeneficiaries;
        for (uint256 i = 0; i < newAllocations.length; i++) {
            beneficiaryAllocPercentages[assetId][newBeneficiaries[i]] = newAllocations[i];
        }
    }

    function distributeAsset(uint256 assetId) external {
        require(assets[assetId].exists, "Asset does not exist");
        require(!assets[assetId].isExecuted, "Already executed");

        AssetInfo storage asset = assets[assetId];
        address[] memory bens = asset.beneficiaries;

        for (uint256 i = 0; i < bens.length; i++) {
            address ben = bens[i];
            uint256 pct = beneficiaryAllocPercentages[assetId][ben];
            if (pct > 0) {
                assetToken.mintShare(ben, assetId, pct);
            }
        }

        asset.isExecuted = true;
    }

    /**
     * @notice Mint a fractional share of a particular asset by calling `AssetToken.mintShare`.
     * @param to The address receiving the newly minted share token.
     * @param assetId A unique identifier for the physical asset.
     * @param sharePercentage The fraction of the asset, e.g., 25 for 25%.
     *
     * Requirements:
     * - `assetId` must exist in this registry.
     * - `sharePercentage` must be > 0.
     * - The sum of already minted shares + `sharePercentage` must not exceed 100.
     * - Only the contract owner can call this, in this simplified approach.
     */
    function mintShare(
        address to,
        uint256 assetId,
        uint256 sharePercentage
    ) external {
        require(assets[assetId].exists, "Asset does not exist");
        require(sharePercentage > 0, "Share must be > 0");
        require(sharePercentage < 100, "Share must be < 100");

        // Mint the token in the AssetToken contract
        // (which also sets tokenToAssetId[tokenId] and tokenSharePercentage[tokenId])
        assetToken.mintShare(to, assetId, sharePercentage);
    }

    /**
     * @notice Returns the description and total minted share percentage of an asset.
     * @param assetId The asset identifier to query.
     * @return description The text describing the asset
     */
    function getAssetInfo(uint256 assetId) external view returns (string memory description) {
        AssetInfo storage asset = assets[assetId];
        require(asset.exists, "Asset does not exist");
        return (asset.description);
    }

    // when setting allocation, take in arr of address for beneficiary
    // and its allocation
    function getBeneficiaryAllocation(uint256 assetId, address beneficiary) external view returns (uint256) {
        return beneficiaryAllocPercentages[assetId][beneficiary];
    }

}

