// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "hardhat/console.sol";

import "./WillTypes.sol";
import "./WillUtils.sol";
import "./WillAccess.sol";
import "./WillAllocation.sol";
import "./WillStateLogic.sol";
import "./WillDistribution.sol";
import "./willFormat.sol";        // existing
import "./AssetRegistry.sol";     // existing

contract Will {

    AssetRegistry public assetRegistry;
    string private storedValue;

    mapping(address => WillTypes.WillData) private wills;

    // Track beneficiary allocations
    mapping(address => mapping(address => uint256)) private beneficiaryAllocPercentages;

    // Track authorized editors/viewers
    mapping(address => mapping(address => bool)) private authorizedEditors;
    mapping(address => mapping(address => bool)) private authorizedViewers;

    address[] public allWillOwners;

    // -------------------------------------------
    // EVENTS
    // -------------------------------------------
    event Test(string message);
    event WillCreated(address indexed owner);
    event BeneficiaryAdded(address indexed owner, address beneficiary, uint256 allocationPercentage);
    event BeneficiaryRemoved(address indexed owner, address beneficiary);
    event AllocationPercentageUpdated(address indexed owner, address beneficiary, uint256 allocationPercentage);
    event AssetsDistributed(address indexed owner, uint256 totalDistributed, uint256 remainingAssets);
    event WillFunded(address indexed owner, uint256 amount);
    event DeathToday();
    event GrantOfProbateToday();
    event DataReceived(string newValue);
    event DeathUpdated(string value);
    event ProbateUpdated(string value);

    // -------------------------------------------
    // MODIFIERS
    // -------------------------------------------
    modifier onlyWillOwner(address owner) {
        require(wills[owner].owner == msg.sender, "Not the owner");
        _;
    }

    modifier onlyAuthorizedEditors(address owner) {
        require(
            wills[owner].owner == msg.sender || authorizedEditors[owner][msg.sender],
            "Not authorized"
        );
        _;
    }

    modifier residualBeneficiaryExists(address owner) {
        require(wills[owner].residualBeneficiary != address(0), "Residual beneficiary not set");
        _;
    }

    modifier onlyViewPermitted(address owner) {
        require(wills[owner].owner != address(0), "Will does not exist");
        require(
            WillAccess.isViewPermitted(
                wills[owner],
                beneficiaryAllocPercentages,
                authorizedViewers,
                msg.sender
            ),
            "Unauthorized viewer"
        );
        _;
    }

    // -------------------------------------------
    // CONSTRUCTOR
    // -------------------------------------------
    constructor(address _assetRegistryAddress) {
        require(_assetRegistryAddress != address(0), "Invalid address");
        assetRegistry = AssetRegistry(_assetRegistryAddress);
    }

    // -------------------------------------------
    // CORE FUNCTIONS
    // -------------------------------------------

    function emitTestEvent() external {
        emit Test("Hello, Test event!");
    }

    // E.g. used for death registry NRIC
    function updateWillStateToDeathConfirmed(string memory deathRegistryNrics) external {
        string[] memory nrics = WillUtils.splitString(deathRegistryNrics, ",");
        WillStateLogic.updateWillStatesByNRIC(
            allWillOwners,
            wills,
            nrics,
            WillTypes.WillState.InCreation,
            WillTypes.WillState.DeathConfirmed
        );
        emit DeathUpdated(deathRegistryNrics);
    }

    function updateWillStateToGrantOfProbateConfirmed(string memory grantOfProbateNrics) external {
        string[] memory nrics = WillUtils.splitString(grantOfProbateNrics, ",");
        WillStateLogic.updateWillStatesByNRIC(
            allWillOwners,
            wills,
            nrics,
            WillTypes.WillState.InCreation,  // or DeathConfirmed, as needed
            WillTypes.WillState.DeathConfirmed
        );
        emit ProbateUpdated(grantOfProbateNrics);
    }

    function receiveProcessedData(string memory _newValue) external {
        console.log(_newValue);
        storedValue = _newValue;
        emit DataReceived(_newValue);
    }

    function getStoredValue() external view returns (string memory) {
        return storedValue;
    }

    // -------------------------------------------
    // WILL CREATION & ALLOCATIONS
    // -------------------------------------------
    function createWill(address owner, string memory nric) external {
        require(msg.sender != address(0), "Invalid sender address");
        require(wills[owner].owner == address(0), "Will already exists");

        // Initialize minimal arrays
        address[] memory emptyAddr;
        uint256[] memory emptyUints;

        wills[owner] = WillTypes.WillData({
            owner: owner,
            nric: nric,
            beneficiaries: emptyAddr,
            digitalAssets: 0,
            state: WillTypes.WillState.InCreation,
            residualBeneficiary: address(0),
            assetIds: emptyUints
        });

        allWillOwners.push(owner);

        emit WillCreated(owner);
    }

    function updateOneAllocationPercentage(
        address owner,
        address beneficiary,
        uint256 allocationPercentage
    ) external onlyAuthorizedEditors(owner) {
        require(allocationPercentage > 0, "Allocation must be >0");
        require(wills[owner].owner != address(0), "Will does not exist");

        beneficiaryAllocPercentages[owner][beneficiary] = allocationPercentage;
        emit AllocationPercentageUpdated(owner, beneficiary, allocationPercentage);
    }

    function addBeneficiaries(
        address owner,
        address[] memory newBeneficiaries,
        uint256[] memory newPercentages
    )
        external
        onlyAuthorizedEditors(owner)
        residualBeneficiaryExists(owner)
    {
        require(wills[owner].owner != address(0), "Will does not exist");
        WillAllocation.addBeneficiaries(wills[owner], beneficiaryAllocPercentages, owner, newBeneficiaries, newPercentages);

        // Emit for each
        for (uint256 i = 0; i < newBeneficiaries.length; i++) {
            emit BeneficiaryAdded(owner, newBeneficiaries[i], newPercentages[i]);
        }
    }

    function removeBeneficiaries(
        address owner,
        address[] memory beneficiariesToRemove
    )
        external
        onlyAuthorizedEditors(owner)
        residualBeneficiaryExists(owner)
    {
        require(wills[owner].owner != address(0), "Will does not exist");
        WillAllocation.removeBeneficiaries(wills[owner], beneficiaryAllocPercentages, owner, beneficiariesToRemove);

        // Emit
        for (uint256 i = 0; i < beneficiariesToRemove.length; i++) {
            emit BeneficiaryRemoved(owner, beneficiariesToRemove[i]);
        }
    }

    function updateAllocations(
        address owner,
        address[] memory beneficiariesToUpdate,
        uint256[] memory newPercentages
    )
        external
        onlyAuthorizedEditors(owner)
        residualBeneficiaryExists(owner)
    {
        require(wills[owner].owner != address(0), "Will does not exist");
        WillAllocation.updateAllocations(wills[owner], beneficiaryAllocPercentages, owner, beneficiariesToUpdate, newPercentages);

        for (uint256 i = 0; i < beneficiariesToUpdate.length; i++) {
            emit AllocationPercentageUpdated(owner, beneficiariesToUpdate[i], newPercentages[i]);
        }
    }

    // -------------------------------------------
    // FUNDS & DISTRIBUTION
    // -------------------------------------------
    function fundWill(address owner) external payable onlyWillOwner(owner) {
        require(msg.value > 0, "Must send ETH");
        wills[owner].digitalAssets += msg.value;
        emit WillFunded(owner, msg.value);
    }

    function distributeAssets(address owner) external returns (string memory) {
        require(wills[owner].digitalAssets > 0, "No assets to distribute");

        (uint256 totalDist, uint256 remain) = WillDistribution.distributeAssetsToBeneficiaries(
            wills[owner],
            beneficiaryAllocPercentages,
            owner
        );

        wills[owner].digitalAssets = remain;

        // Format the distribution details
        string memory distDetails = WillFormat.formatDistributionDetails(
            wills[owner].beneficiaries,
            beneficiaryAllocPercentages,
            owner,
            (wills[owner].digitalAssets + totalDist),
            remain
        );

        emit AssetsDistributed(owner, totalDist, remain);
        return distDetails;
    }

    // -------------------------------------------
    // VIEW FUNCTIONS
    // -------------------------------------------
    function viewWill(address owner)
        external
        view
        onlyWillOwner(owner)
        onlyAuthorizedEditors(owner)
        returns (string memory)
    {
        require(wills[owner].owner != address(0), "Will does not exist");
        return WillFormat.formatWillView(assetRegistry, wills[owner], beneficiaryAllocPercentages);
    }

    function WillViewForBeneficiaries(address owner)
        external
        view
        onlyViewPermitted(owner)
        returns (string memory)
    {
        // Reuse the same WillFormat with or without digital assets
        return WillFormat.formatWillView(assetRegistry, wills[owner], beneficiaryAllocPercentages);
    }

    // -------------------------------------------
    // EDITOR / VIEWER MANAGEMENT
    // -------------------------------------------
    function addEditor(address owner, address editor) external onlyWillOwner(owner) {
        require(editor != address(0), "Invalid editor address");
        require(!authorizedEditors[owner][editor], "Already an editor");
        authorizedEditors[owner][editor] = true;
    }

    function removeEditor(address owner, address editor) external onlyWillOwner(owner) {
        require(authorizedEditors[owner][editor], "Editor not found");
        authorizedEditors[owner][editor] = false;
    }

    function addViewer(address owner, address viewer) external onlyWillOwner(owner) {
        require(viewer != address(0), "Invalid viewer address");
        require(!authorizedViewers[owner][viewer], "Already a viewer");
        authorizedViewers[owner][viewer] = true;
    }

    function removeViewer(address owner, address viewer) external onlyWillOwner(owner) {
        require(authorizedViewers[owner][viewer], "Viewer not found");
        authorizedViewers[owner][viewer] = false;
    }

    // -------------------------------------------
    // GETTERS
    // -------------------------------------------
    function getWillData(address owner) external view returns (WillTypes.WillData memory) {
        return wills[owner];
    }

    function checkBeneficiaries(address owner, address beneficiary) external view returns (bool) {
        return beneficiaryAllocPercentages[owner][beneficiary] > 0;
    }

    function getBeneficiaryAllocationPercentage(address owner, address beneficiary)
        external
        view
        returns (uint256)
    {
        require(wills[owner].owner != address(0), "Will does not exist");
        return beneficiaryAllocPercentages[owner][beneficiary];
    }

    function getDigitalAssets(address owner) external view returns (uint256) {
        require(wills[owner].owner != address(0), "Will does not exist");
        return wills[owner].digitalAssets;
    }

    function isAuthorisedEditorExist(address owner, address editor) external view returns (bool) {
        require(wills[owner].owner != address(0), "Will does not exist");
        return authorizedEditors[owner][editor];
    }

    function isAuthorisedViewer(address owner, address viewer) external view returns (bool) {
        require(wills[owner].owner != address(0), "Will does not exist");
        return authorizedViewers[owner][viewer];
    }

    function setResidualBeneficiary(address owner, address beneficiary)
        external
        onlyWillOwner(owner)
        onlyAuthorizedEditors(owner)
    {
        require(wills[owner].state == WillTypes.WillState.InCreation, "Cannot modify after creation");
        require(beneficiary != address(0), "Invalid beneficiary");
        wills[owner].residualBeneficiary = beneficiary;
    }

    // -------------------------------------------
    // ASSET REGISTRY
    // -------------------------------------------
    function createAsset(
        address owner,
        string memory description,
        uint256 value,
        string memory certificationUrl,
        address[] memory beneficiaries,
        uint256[] memory allocations
    )
        external
        onlyAuthorizedEditors(owner)
        onlyWillOwner(owner)
    {
        uint256 assetId = assetRegistry.createAsset(owner, description, value, certificationUrl, beneficiaries, allocations);
        wills[owner].assetIds.push(assetId);
    }

    function viewAssetDescription(address owner, uint256 assetId)
        external
        view
        onlyViewPermitted(owner)
        returns (string memory)
    {
        return assetRegistry.getAssetInfo(assetId);
    }

    // Optionally auto-distribute
    function triggerDistribution(address assetOwner, uint256 assetId) internal {
        require(wills[assetOwner].owner != address(0), "Will does not exist");
        if (wills[assetOwner].state == WillTypes.WillState.InExecution) {
            assetRegistry.distributeAsset(assetId);
        }
    }

    function updateAssetBeneficiariesAndAllocations(
        address owner,
        uint256 assetId,
        address[] memory newBeneficiaries,
        uint256[] memory newAllocations
    )
        external
        onlyAuthorizedEditors(owner)
        onlyWillOwner(owner)
    {
        assetRegistry.updateBeneficiariesAndAllocations(assetId, newBeneficiaries, newAllocations);
    }
}
