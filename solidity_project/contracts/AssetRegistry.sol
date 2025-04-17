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
    AssetToken public assetToken;
    uint256 private _nextAssetId = 1;

    struct AssetInfo {
        address assetOwner;
        string description;   
        bool isExecuted; // Whether it has been distributed 
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
    mapping(bytes32 => bool) public assetKeyExists; // Ensure that there are no duplicate assets
    mapping(uint256 => uint256[]) private _assetTokenIds; // keeps track of tokenIds minted per asset

    constructor(address _assetTokenAddress) {
        require(_assetTokenAddress != address(0), "Invalid AssetToken address");
        assetToken = AssetToken(_assetTokenAddress);
    }

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
    Update Beneficiaries and Allocations of physical
    - simplifying the update for tokenized assets since there's likely fewer fractional ownership tends to be
    for physical assets, we will pass in the whole new beneficiary/allocation and not mandate residuary beneficiary
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

    // Distribute physical assets are called by Will.sol's triggerDistribution()
    function distributeAsset(uint256 assetId) external {
        require(assets[assetId].exists, "Asset does not exist");
        require(!assets[assetId].isExecuted, "Already executed");

        AssetInfo storage asset = assets[assetId];
        address[] memory bens = asset.beneficiaries;

        for (uint256 i = 0; i < bens.length; i++) {
            address ben = bens[i];
            uint256 pct = beneficiaryAllocPercentages[assetId][ben];
            if (pct > 0) {
                uint256 tokenId = assetToken.mintShare(ben, assetId, pct);
                _assetTokenIds[assetId].push(tokenId); 
            }
        }

        asset.isExecuted = true;
    }

    // Mint a fractional share of a particular asset 
    function mintShare(
        address to,
        uint256 assetId,
        uint256 sharePercentage
    ) external {
        require(assets[assetId].exists, "Asset does not exist");
        require(sharePercentage > 0, "Share must be > 0");
        require(sharePercentage < 100, "Share must be < 100");

        assetToken.mintShare(to, assetId, sharePercentage);
    }

    function getAssetDistributionProof(
            uint256 assetId
        )
        external
        view
        returns (
            bool isExecuted,               // has distributeAsset() been called?
            address[] memory beneficiaries,// beneficiaries in stored order
            uint256[] memory tokenIds,     // tokenIds minted (one‑to‑one)
            uint256[] memory shares        // % shares for each beneficiary
        )
    {
        AssetInfo storage asset = assets[assetId];
        require(asset.exists, "Asset does not exist");

        isExecuted    = asset.isExecuted;
        beneficiaries = asset.beneficiaries;
        tokenIds      = _assetTokenIds[assetId];

        // build the shares array on‑the‑fly
        uint256 len = beneficiaries.length;
        shares = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            shares[i] = beneficiaryAllocPercentages[assetId][beneficiaries[i]];
        }
    }

    function getAssetInfo(uint256 assetId) external view returns (string memory description) {
        AssetInfo storage asset = assets[assetId];
        require(asset.exists, "Asset does not exist");
        return (asset.description);
    }

    function getBeneficiaryAllocation(uint256 assetId, address beneficiary) external view returns (uint256) {
        return beneficiaryAllocPercentages[assetId][beneficiary];
    }


}

