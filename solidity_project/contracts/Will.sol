// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";

import "./willLib.sol";
import "./willFormat.sol";
import "./AssetRegistry.sol";
import "hardhat/console.sol";

contract Will {
    AssetRegistry public assetRegistry;
    using WillLib for WillLib.WillData;
    using WillLib for address[];
    string storedValue;

    constructor(address _assetRegistryAddress) {
        require(_assetRegistryAddress != address(0), "Invalid address");
        assetRegistry = AssetRegistry(_assetRegistryAddress);
    }

    mapping(address => WillLib.WillData) private wills;
    mapping(address => mapping(address => uint256))
        private beneficiaryAllocPercentages;
    mapping(address => mapping(address => bool)) private authorizedEditors; //willOwner address to editor address to F/T
    mapping(address => mapping(address => bool)) private authorizedViewers; // mapping of who has the permission to view will
    //  mapping(address => mapping(address => Role)) private authorizedUsers; // mapping for both viewers and editors
    address[] public allWillOwners;

    event Test(string message);
    event WillCreated(address indexed owner);
    event BeneficiaryAdded(
        address indexed owner,
        address beneficiary,
        uint256 allocationPercentage
    );
    event BeneficiaryRemoved(address indexed owner, address beneficiary);
    event AllocationPercentageUpdated(
        address indexed owner,
        address beneficiary,
        uint256 allocationPercentage
    );
    event AssetsDistributed(
        address indexed owner,
        uint256 totalDistributed,
        uint256 remainingAssets
    );
    event TriggerSkipped(address owner, uint256 assetId, string reason);
    event WillFunded(address indexed owner, uint256 amount);
    event DeathUpdated(string value);
    event ProbateUpdated(string value);
    event DataReceived(string newValue);
    event DeathToday();
    event GrantOfProbateToday();

    /* 
    -------------------
        CALLING DATABASES
    -------------------
    */

    // Call death registry daily for new NRICS posted on the government death registry
    function callDeathRegistryToday() public {
        // data comes in from event listeners in format of S7654321B,S7654321A, S7654321C etc
        emit DeathToday();
    }

    // Call grant of probate daily for new NRICS posted on the government Grant of Probate registry
    function callGrantOfProbateToday() public {
        // data comes in from event listeners in format of S7654321B,S7654321A, S7654321C etc
        emit GrantOfProbateToday();
    }

    /* 
    -------------------
        PERMISSIONS
    -------------------
    */
    modifier onlyWillOwner(address owner) {
        require(wills[owner].owner == msg.sender, "Not the owner");
        _;
    }

    modifier onlyAuthorizedEditors(address owner) {
        require(
            wills[owner].owner == msg.sender ||
            authorizedEditors[owner][msg.sender],
            "Not authorized"
        );
        _;
    }


    modifier residualBeneficiaryExists(address owner) {
        require(
            wills[owner].residualBeneficiary != address(0),
            "Residual beneficiary not set"
        );
        _;
    }

    modifier onlyViewPermitted(address owner) {
        WillLib.WillData storage userWill = wills[owner];
        require(userWill.owner != address(0), "Will does not exist");

        // Before death scenario
        if (userWill.state == WillLib.WillState.InCreation) {
            // Only the owner or an explicitly authorizedViewer can view
            require(
                msg.sender == userWill.owner ||
                    authorizedViewers[owner][msg.sender],
                "Not authorized to view this will (InCreation)"
            );
        }
        // After death scenario
        else {
            // EITHER an explicitly authorizedViewer, OR a real beneficiary with nonzero allocation
            bool isBeneficiary = false;
            address[] memory beneficiaries = userWill.beneficiaries;

            for (uint256 i = 0; i < beneficiaries.length; i++) {
                if (
                    beneficiaries[i] == msg.sender &&
                    beneficiaryAllocPercentages[owner][msg.sender] > 0
                ) {
                    isBeneficiary = true;
                    break;
                }
            }
            require(
                authorizedViewers[owner][msg.sender] || isBeneficiary,
                "You are not authorized or a beneficiary of this will"
            );
        }
        _;
    }

    modifier editableBeforeDeath(address owner) {
        require(
            wills[owner].state == WillLib.WillState.InCreation,
            "Will locked: editing not allowed after DeathConfirmed"
        );
        _;
    }
    
    /* 
    --------------------------
        WILL FUNCTIONALITIES
    --------------------------
    */

    function createWill(address owner, string memory nric) public {
        require(msg.sender != address(0), "Invalid sender address");
        require(wills[owner].owner == address(0), "Will already exists");

        // Initialize empty array with proper syntax
        address[] memory emptyArray = new address[](0);
        uint256[] memory emptyArray2 = new uint256[](0);

        wills[owner] = WillLib.WillData({
            owner: owner,
            nric: nric,
            beneficiaries: emptyArray,
            digitalAssets: 0,
            state: WillLib.WillState.InCreation,
            residualBeneficiary: address(0),
            assetIds: emptyArray2
        });

        allWillOwners.push(owner);

        emit WillCreated(owner);
    }


    function addBeneficiaries(
        address owner,
        address[] memory newBeneficiaries,
        uint256[] memory newPercentages
    )
        public
        onlyAuthorizedEditors(owner)
        residualBeneficiaryExists(owner)
        editableBeforeDeath(owner)
    {
        uint256 total = WillLib.rebalanceAdd(
            wills[owner],
            beneficiaryAllocPercentages[owner],
            newBeneficiaries,
            newPercentages
        );

        // Emit events for the ones we just (re)wrote
        for (uint256 i = 0; i < newBeneficiaries.length; i++) {
            emit BeneficiaryAdded(owner, newBeneficiaries[i], newPercentages[i]);
        }

        // Optionally emit for residual top‑up
        uint256 residualPct = WillLib.calculateRemainingPercentage(total);
        if (residualPct > 0) {
            emit BeneficiaryAdded(
                owner,
                wills[owner].residualBeneficiary,
                residualPct
            );
        }
    }

    function removeBeneficiaries(
        address owner,
        address[] memory toRemove
    )
        public
        onlyAuthorizedEditors(owner)
        residualBeneficiaryExists(owner)
        editableBeforeDeath(owner)
    {
        uint256 total = WillLib.rebalanceRemove(
            wills[owner],
            beneficiaryAllocPercentages[owner],
            toRemove
        );

        // events
        for (uint256 i = 0; i < toRemove.length; i++) {
            emit BeneficiaryRemoved(owner, toRemove[i]);
        }

        uint256 residualPct = WillLib.calculateRemainingPercentage(total);
        if (residualPct > 0) {
            emit BeneficiaryAdded(
                owner,
                wills[owner].residualBeneficiary,
                residualPct
            );
        }
    }
    // Helper function for updating one beneficiary's allocation percentage.
    function updateOneAllocationPercentage(
        address owner,
        address beneficiary,
        uint256 allocationPercentage
    ) public onlyAuthorizedEditors(owner) editableBeforeDeath(owner) {
        require(
            allocationPercentage > 0,
            "Allocation percentage must be greater than 0"
        ); // Cannot update someone's allocation to 0
        require(wills[owner].owner != address(0), "Will does not exist");

        beneficiaryAllocPercentages[owner][beneficiary] = allocationPercentage;
        emit AllocationPercentageUpdated(
            owner,
            beneficiary,
            allocationPercentage
        );
    }

    // Update multiple beneficiaries' allocation percentages
    function updateAllocations(
        address owner,
        address[] memory beneficiariesToUpdate,
        uint256[] memory newPercentages
    ) public onlyAuthorizedEditors(owner) residualBeneficiaryExists(owner) editableBeforeDeath(owner) {
        require(
            beneficiariesToUpdate.length == newPercentages.length,
            "Mismatched input arrays"
        );

        uint256 oldTotal = 0;
        address[] memory allBeneficiaries = wills[owner].beneficiaries;
        address residualBeneficiary = wills[owner].residualBeneficiary;

        // Calculate the current sum of allocation percentages
        for (uint256 i = 0; i < allBeneficiaries.length; i++) {
            oldTotal += beneficiaryAllocPercentages[owner][allBeneficiaries[i]];
        }

        // Calculate the expected sum of allocation percentages after updating
        uint256 newTotal = oldTotal;
        for (uint256 i = 0; i < beneficiariesToUpdate.length; i++) {
            address beneficiary = beneficiariesToUpdate[i];
            newTotal =
                newTotal -
                beneficiaryAllocPercentages[owner][beneficiary] +
                newPercentages[i]; // Replace all the allocation percentages that need to be updated
        }

        require(newTotal <= 100, "Total allocation exceeds 100%");

        for (uint256 i = 0; i < beneficiariesToUpdate.length; i++) {
            beneficiaryAllocPercentages[owner][
                beneficiariesToUpdate[i]
            ] = newPercentages[i];
            emit AllocationPercentageUpdated(
                owner,
                beneficiariesToUpdate[i],
                newPercentages[i]
            );
        }

        // Assign leftover percentage to residual beneficiary
        uint256 remainingPercentage = WillLib.calculateRemainingPercentage(
            newTotal
        );
        if (remainingPercentage > 0) {
            if (beneficiaryAllocPercentages[owner][residualBeneficiary] == 0) {
                wills[owner].beneficiaries.push(residualBeneficiary); // Add residual beneficiary if not present
                beneficiaryAllocPercentages[owner][
                    residualBeneficiary
                ] = remainingPercentage;
                emit AllocationPercentageUpdated(
                    owner,
                    residualBeneficiary,
                    remainingPercentage
                );
            } else {
                beneficiaryAllocPercentages[owner][
                    residualBeneficiary
                ] += remainingPercentage;
                emit BeneficiaryAdded(
                    owner,
                    residualBeneficiary,
                    remainingPercentage
                );
            }
        }
    }

    // Function to add digital assets to the will
    function fundWill(address owner) external payable onlyWillOwner(owner) editableBeforeDeath(owner) {
        require(msg.value > 0, "Must send ETH");
        wills[owner].digitalAssets += msg.value;
        emit WillFunded(owner, msg.value);
    }

    function distributeAssets(address owner) external returns (string memory) {
        // Must update state to Grant Of Probate Confirmed to trigger distribution
        require(
            wills[owner].state == WillLib.WillState.GrantOfProbateConfirmed,
            "Will state must be GrantOfProbateConfirmed to distribute assets"
        );
        WillLib.WillData storage userWill = wills[owner];
        address[] memory beneficiaries = userWill.beneficiaries;
        require(userWill.digitalAssets > 0, "No assets to distribute");

        uint256 totalDistributed = 0;
        uint256 remainingAssets = userWill.digitalAssets;
        string memory distributionDetails = "Asset Distribution Details:\n";

        // Loop through array of beneficiaries, calculate amount to pay based on allocationPercentage and transfer the amount
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            address beneficiary = beneficiaries[i];
            uint256 allocationPercentage = beneficiaryAllocPercentages[owner][
                beneficiary
            ];
            uint256 amountToPay = WillLib.calculateAssetDistribution(
                userWill.digitalAssets,
                allocationPercentage
            );

            if (amountToPay > 0) {
                totalDistributed += amountToPay;
                remainingAssets -= amountToPay;
                payable(beneficiary).transfer(amountToPay);
            }
        }

        // Generate distribution details using the utility function
        distributionDetails = WillFormat.formatDistributionDetails(
            beneficiaries,
            beneficiaryAllocPercentages,
            owner,
            userWill.digitalAssets,
            remainingAssets
        );

        // Update remaining assets in the will
        userWill.digitalAssets = remainingAssets;

        // Emit events / state
        emit AssetsDistributed(owner, totalDistributed, remainingAssets);
        userWill.state = WillLib.WillState.Closed;

        // Return the distribution details string
        return distributionDetails;
    }

    function viewWill(
        address owner
    )
        public
        view
        onlyWillOwner(owner)
        onlyAuthorizedEditors(owner)
        returns (string memory)
    {
        require(wills[owner].owner != address(0), "Will does not exist");
        return
            WillFormat.formatWillView(
                assetRegistry,
                wills[owner],
                beneficiaryAllocPercentages
            );
    }

    // View function for beneficiaries
    function WillViewForBeneficiaries(
        address owner
    ) public view onlyViewPermitted(owner) returns (string memory) {
        // Use the same formatting function but without the digital assets section
        return
            WillFormat.formatWillView(
                assetRegistry,
                wills[owner],
                beneficiaryAllocPercentages
            );
    }

    /* 
    --------------------------------------
        INTERACTIONS WITH EXTERNAL EVENTS
    --------------------------------------
    */

    // function to update will state based on death nrics
    function updateWillStateToDeathConfirmed(
        string memory deathRegistryNrics
    ) public {
        console.log(deathRegistryNrics);
        string[] memory nrics = WillFormat.splitString(deathRegistryNrics, ",");
        // Loop through all NRICs
        for (uint256 i = 0; i < nrics.length; i++) {
            string memory currentNric = nrics[i];
            for (uint256 j = 0; j < allWillOwners.length; j++) {
                address owner = allWillOwners[j];
                WillLib.WillData storage willData = wills[owner];
                if (
                    keccak256(bytes(willData.nric)) ==
                    keccak256(bytes(currentNric)) &&
                    (willData.state == WillLib.WillState.InCreation)
                ) {
                    willData.state = WillLib.WillState.DeathConfirmed;
                }
            }
        }
        emit DeathUpdated(deathRegistryNrics);
    }

    // function to update will state based on death nrics
    function updateWillStateToGrantOfProbateConfirmed(
        string memory grantOfProbateNrics
    ) public {
        string[] memory nrics = WillFormat.splitString(
            grantOfProbateNrics,
            ","
        );
        // Loop through all NRICs
        for (uint256 i = 0; i < nrics.length; i++) {
            string memory currentNric = nrics[i];
            for (uint256 j = 0; j < allWillOwners.length; j++) {
                address owner = allWillOwners[j];
                WillLib.WillData storage willData = wills[owner];
                if (
                    keccak256(bytes(willData.nric)) ==
                    keccak256(bytes(currentNric)) &&
                    (willData.state == WillLib.WillState.DeathConfirmed)
                ) {
                    willData.state = WillLib.WillState.GrantOfProbateConfirmed;
                }
            }
        }
        emit ProbateUpdated(grantOfProbateNrics);
    }


    /* 
    ------------------------
        ADDING PERMISSIONS
    ------------------------
    */

    function addEditor(
        address owner,
        address editor
    ) public onlyWillOwner(owner) {
        require(editor != address(0), "Invalid editor address");
        require(!authorizedEditors[owner][editor], "Editor already exists");
        authorizedEditors[owner][editor] = true;
    }

    function removeEditor(
        address owner,
        address editor
    ) public onlyWillOwner(owner) {
        require(authorizedEditors[owner][editor], "Editor not found");
        authorizedEditors[owner][editor] = false;
    }

    function addViewer(
        address owner,
        address viewer
    ) public onlyWillOwner(owner) {
        require(viewer != address(0), "Invalid viewer address");
        require(!authorizedViewers[owner][viewer], "Viewer already exists");
        authorizedViewers[owner][viewer] = true;
    }

    function removeViewer(
        address owner,
        address viewer
    ) public onlyWillOwner(owner) {
        require(authorizedViewers[owner][viewer], "Viewer not found");
        authorizedViewers[owner][viewer] = false;
    }

    function getWillData(
        address owner
    ) public view returns (WillLib.WillData memory) {
        return wills[owner];
    }

    function checkBeneficiaries(
        address owner,
        address beneficiary
    ) external view returns (bool) {
        return WillLib.isBeneficiary(beneficiaryAllocPercentages[owner], beneficiary);
    }

    function getBeneficiaryAllocationPercentage(
        address owner,
        address beneficiary
    ) public view returns (uint256) {
        require(wills[owner].owner != address(0), "Will does not exist");
        return beneficiaryAllocPercentages[owner][beneficiary];
    }

    function getDigitalAssets(address owner) public view returns (uint256) {
        require(wills[owner].owner != address(0), "Will does not exist");
        return wills[owner].digitalAssets;
    }

    function getWillState(address owner) external view returns (string memory) {
        require(wills[owner].owner != address(0), "Will does not exist");
        return WillLib.stateToString(wills[owner].state);
    }

    function isAuthorisedEditorExist(
        address owner,
        address editor
    ) public view returns (bool check) {
        require(wills[owner].owner != address(0), "Will does not exist");
        return authorizedEditors[owner][editor];
    }

    function isAuthorisedViewer(
        address owner,
        address viewer
    ) public view returns (bool check) {
        require(wills[owner].owner != address(0), "Will does not exist");
        return authorizedViewers[owner][viewer];
    }

    function setResidualBeneficiary(
        address owner,
        address beneficiary
    ) public onlyWillOwner(owner) onlyAuthorizedEditors(owner) {
        require(
            wills[owner].state == WillLib.WillState.InCreation,
            "Cannot modify after execution"
        );
        require(beneficiary != address(0), "Invalid beneficiary address");
        wills[owner].residualBeneficiary = beneficiary;
    }

    /* 
    ------------------------
        ASSET REGISTRY
    ------------------------
    */

    function createAsset(
        address owner,
        string memory description,
        uint256 value,
        string memory certificationUrl,
        address[] memory beneficiaries,
        uint256[] memory allocations
    ) public onlyAuthorizedEditors(owner) onlyWillOwner(owner) {
        uint256 assetId = assetRegistry.createAsset(
            owner,
            description,
            value,
            certificationUrl,
            beneficiaries,
            allocations
        );
        wills[owner].assetIds.push(assetId);
    }

    function viewAssetDescription(
        address owner,
        uint256 assetId
    ) external view onlyViewPermitted(owner) returns (string memory) {
        return assetRegistry.getAssetInfo(assetId);
    }

//  If the will is not in the GrantOfProbateConfirmed state, the function emits a TriggerSkipped event
//  and exits without reverting, to prevent system breakage.
//  If the will is in GrantOfProbateConfirmed, the asset is distributed and the will is marked as Closed.
    function triggerDistribution(address assetOwner, uint256 assetId) internal {
        WillLib.WillData storage userWill = wills[assetOwner];
        require(userWill.owner != address(0), "Will does not exist");

        if (userWill.state != WillLib.WillState.GrantOfProbateConfirmed) {
            emit TriggerSkipped(assetOwner, assetId, "Not in GrantOfProbateConfirmed state");
            return;
        }

        assetRegistry.distributeAsset(assetId);
        userWill.state = WillLib.WillState.Closed;
    }

    function updateAssetBeneficiariesAndAllocations(
        address owner,
        uint256 assetId,
        address[] memory newBeneficiaries,
        uint256[] memory newAllocations
    ) external onlyAuthorizedEditors(owner) onlyWillOwner(owner) {
        assetRegistry.updateBeneficiariesAndAllocations(
            assetId,
            newBeneficiaries,
            newAllocations
        );
    }

    function viewAllAssetDistributionProofs(
            address owner
        )
        external
        view
        onlyViewPermitted(owner)
        returns (
            uint256[] memory assetIds,
            bool[]    memory executed,
            address[][] memory beneficiaries,
            uint256[][] memory tokenIds,
            uint256[][] memory shares
        )
    {
        return WillFormat.collectAssetDistributionProofs(
            assetRegistry,
            wills[owner].assetIds
            );
    }
    /**
     * For Testing 
     */
    function forceSetWillStateGrantOfProbateConfirmed(address ownerAddress) external {
        WillLib.WillData storage userWill = wills[ownerAddress];
        require(userWill.owner == ownerAddress, "Will does not exist");
        userWill.state = WillLib.WillState.GrantOfProbateConfirmed;
    }

    function callTriggerDistributionForTesting(address assetOwner, uint256 assetId) public {
        triggerDistribution(assetOwner, assetId);
    }

    function emitTestEvent() public {
        emit Test("Hello, Test event!");
    }

    function receiveProcessedData(string memory _newValue) public {
        console.log(_newValue);
        storedValue = _newValue; // Store processed data
        emit DataReceived(storedValue);
    }

    function getStoredValue() public view returns (string memory) {
        return storedValue;
    }
}
