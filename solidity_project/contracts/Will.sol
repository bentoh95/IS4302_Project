// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Strings.sol";

contract Will {
    enum WillState {
        InCreation,
        InExecution,
        DeathConfirmed,
        GrantOfProbateConfirmed,
        Closed
    }

    event Test(string message);

    struct WillData {
        address owner;
        string nric;
        address[] beneficiaries;
        WillState state;
    }

    mapping(address => WillData) private wills;
    mapping(address => mapping(address => uint256)) private beneficiaryAlloc;
    mapping(address => mapping(address => bool)) private authorizedEditors; //willOwner address to editor address to F/T
    mapping(address => mapping(address => bool)) private authorizedViewers; // mapping of who has the permission to view will
    //Keep track of will owners as we cannot loop through wills mapping
    address[] public allWillOwners;

    // Nrics that will be received from the government registries daily
    string public deathRegistryNrics;
    string public grantOfProbateNrics;

    event WillCreated(address indexed owner);
    event BeneficiaryAdded(
        address indexed owner,
        address beneficiary,
        uint256 allocation
    );
    event BeneficiaryRemoved(address indexed owner, address beneficiary);
    event AllocationUpdated(
        address indexed owner,
        address beneficiary,
        uint256 allocation
    );
    event DeathToday(string nrics);
    event GrantOfProbateToday(string nrics);

    /* 
    -------------------
        CALLING DATABASES
    -------------------
    */

    // Call death registry daily for new NRICS posted on the government death registry
    function callDeathRegistryToday() public {
        // data comes in from event listeners in format of S7654321B,S7654321A, S7654321C etc
        deathRegistryNrics = "S7654321B";
        emit DeathToday(deathRegistryNrics);
    }

    // Call grant of probate daily for new NRICS posted on the government Grant of Probate registry
    function callGrantOfProbateToday() public {
        // data comes in from event listeners in format of S7654321B,S7654321A, S7654321C etc
        grantOfProbateNrics = "S7654321B";
        emit GrantOfProbateToday(grantOfProbateNrics);
    }

    /* 
    -------------------
        PERMISSIONS
    -------------------
    */
    modifier onlyOwner(address owner) {
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

    modifier onlyViewPermitted(address owner) {
        WillData storage userWill = wills[owner];
        require(userWill.owner != address(0), "Will does not exist");

        // Before death scenario
        if (userWill.state == WillState.InCreation) {
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
                    beneficiaryAlloc[owner][msg.sender] > 0
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

    /* 
    --------------------------
        WILL FUNCTIONALITIES
    --------------------------
    */

    function emitTestEvent() public {
        emit Test("Hello, Test event!");
    }

    // function to update will state based on death nrics
    function updateWillStateToDeathConfirmed() public {
        string[] memory nrics = splitString(deathRegistryNrics, ",");
        // Loop through all NRICs
        for (uint256 i = 0; i < nrics.length; i++) {
            string memory currentNric = nrics[i];
            for (uint256 j = 0; j < allWillOwners.length; j++) {
                address owner = allWillOwners[j];
                WillData storage willData = wills[owner];
                if (
                    keccak256(bytes(willData.nric)) == keccak256(bytes(currentNric)) &&
                    (willData.state == WillState.InCreation || willData.state == WillState.InExecution)
                ) {
                    willData.state = WillState.DeathConfirmed;
                }
            }
        }
        emit DeathToday(deathRegistryNrics);
    }

    // function to update will state based on death nrics
    function updateWillStateToGrantOfProbateConfirmed() public {
        string[] memory nrics = splitString(grantOfProbateNrics, ",");
        // Loop through all NRICs
        for (uint256 i = 0; i < nrics.length; i++) {
            string memory currentNric = nrics[i];
            for (uint256 j = 0; j < allWillOwners.length; j++) {
                address owner = allWillOwners[j];
                WillData storage willData = wills[owner];
                if (
                    keccak256(bytes(willData.nric)) == keccak256(bytes(currentNric)) &&
                    (willData.state == WillState.DeathConfirmed)
                ) {
                    willData.state = WillState.GrantOfProbateConfirmed;
                }
            }
        }
        emit GrantOfProbateToday(grantOfProbateNrics);
    }

    function createWill(address owner, string memory nric) public {
        require(msg.sender != address(0), "Invalid sender address");
        require(wills[owner].owner == address(0), "Will already exists");

        // Initialize empty array with proper syntax
        address[] memory emptyArray = new address[](0);

        wills[owner] = WillData({
            owner: owner,
            nric: nric,
            beneficiaries: emptyArray,
            state: WillState.InCreation
        });

        allWillOwners.push(owner);

        emit WillCreated(owner);
    }

    function addBeneficiary(
        address owner,
        address beneficiary,
        uint256 allocation
    ) public onlyOwner(owner) onlyAuthorizedEditors(owner) {
        require(allocation > 0, "Need to allocate more than 0");
        require(
            beneficiaryAlloc[owner][beneficiary] == 0,
            "Allocation already exists"
        );

        beneficiaryAlloc[owner][beneficiary] = allocation;
        wills[owner].beneficiaries.push(beneficiary);

        emit BeneficiaryAdded(owner, beneficiary, allocation);
    }

    function removeBeneficiary(
        address owner,
        address beneficiary
    ) public onlyOwner(owner) onlyAuthorizedEditors(owner) {
        require(
            beneficiaryAlloc[owner][beneficiary] != 0,
            "Allocation does not exist"
        );

        delete beneficiaryAlloc[owner][beneficiary];

        // Remove from the beneficiaries array
        uint256 len = wills[owner].beneficiaries.length;
        for (uint256 i = 0; i < len; i++) {
            if (wills[owner].beneficiaries[i] == beneficiary) {
                wills[owner].beneficiaries[i] = wills[owner].beneficiaries[
                    len - 1
                ];
                wills[owner].beneficiaries.pop();
                break;
            }
        }

        emit BeneficiaryRemoved(owner, beneficiary);
    }

    function updateAllocation(
        address owner,
        address beneficiary,
        uint256 allocation
    ) public onlyOwner(owner) onlyAuthorizedEditors(owner) {
        require(allocation > 0, "Need to allocate more than 0");
        require(
            beneficiaryAlloc[owner][beneficiary] != 0,
            "Allocation does not exist"
        );

        beneficiaryAlloc[owner][beneficiary] = allocation;

        emit AllocationUpdated(owner, beneficiary, allocation);
    }

    function viewWill(
        address owner
    )
        public
        view
        onlyOwner(owner)
        onlyAuthorizedEditors(owner)
        returns (string memory)
    {
        require(wills[owner].owner != address(0), "Will does not exist");

        WillData storage userWill = wills[owner];
        string memory willString = "Beneficiaries & Allocations:\n";
        uint256 numBeneficiaries = userWill.beneficiaries.length;

        for (uint256 i = 0; i < numBeneficiaries; i++) {
            address beneficiary = userWill.beneficiaries[i];
            uint256 allocation = beneficiaryAlloc[owner][beneficiary];

            // Convert address to full hex string WITHOUT "0x" prefix to match test expectations
            string memory beneficiaryString = Strings.toHexString(
                uint256(uint160(beneficiary)),
                20
            );
            // Remove "0x" prefix to match test expectations (which removes the prefix)
            beneficiaryString = substring(
                beneficiaryString,
                2,
                bytes(beneficiaryString).length
            );

            string memory allocationString = Strings.toString(allocation);

            willString = string(
                abi.encodePacked(
                    willString,
                    "- ",
                    beneficiaryString,
                    " -> ",
                    allocationString,
                    "\n"
                )
            );
        }

        // emit WillViewed(owner);

        return willString;
    }

    // Copied same viewWill function to another function for more customisability
    function WillViewForBeneficiaries(
        address owner
    ) public view onlyViewPermitted(owner) returns (string memory) {
        WillData storage userWill = wills[owner];
        string memory willString = "Beneficiaries & Allocations:\n";
        uint256 numBeneficiaries = userWill.beneficiaries.length;

        for (uint256 i = 0; i < numBeneficiaries; i++) {
            address beneficiary = userWill.beneficiaries[i];
            uint256 allocation = beneficiaryAlloc[owner][beneficiary];

            string memory beneficiaryString = Strings.toHexString(
                uint256(uint160(beneficiary)),
                20
            );
            beneficiaryString = substring(
                beneficiaryString,
                2,
                bytes(beneficiaryString).length
            );

            string memory allocationString = Strings.toString(allocation);

            willString = string(
                abi.encodePacked(
                    willString,
                    "- ",
                    beneficiaryString,
                    " -> ",
                    allocationString,
                    "\n"
                )
            );
        }

        return willString;
    }

    function addEditor(address owner, address editor) public onlyOwner(owner) {
        require(editor != address(0), "Invalid editor address");
        require(!authorizedEditors[owner][editor], "Editor already exists");
        authorizedEditors[owner][editor] = true;
    }

    function removeEditor(
        address owner,
        address editor
    ) public onlyOwner(owner) {
        require(authorizedEditors[owner][editor], "Editor not found");
        authorizedEditors[owner][editor] = false;
    }

    function addViewer(address owner, address viewer) public onlyOwner(owner) {
        require(viewer != address(0), "Invalid viewer address");
        require(!authorizedViewers[owner][viewer], "Viewer already exists");
        authorizedViewers[owner][viewer] = true;
    }

    function removeViewer(
        address owner,
        address viewer
    ) public onlyOwner(owner) {
        require(authorizedViewers[owner][viewer], "Viewer not found");
        authorizedViewers[owner][viewer] = false;
    }

    function getWillData(address owner) public view returns (WillData memory) {
        return wills[owner];
    }

    function checkBeneficiaries(
        address owner,
        address beneficiary
    ) public view returns (bool check) {
        return beneficiaryAlloc[owner][beneficiary] > 0;
    }

    function getBeneficiaryAllocation(
        address owner,
        address beneficiary
    ) public view returns (uint256) {
        require(wills[owner].owner != address(0), "Will does not exist");
        return beneficiaryAlloc[owner][beneficiary];
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
    
    function getWillState(address owner) public view returns (string memory) {
        require(wills[owner].owner != address(0), "Will does not exist");

        WillState state = wills[owner].state;

        if (state == WillState.InCreation) return "InCreation";
        if (state == WillState.InExecution) return "InExecution";
        if (state == WillState.DeathConfirmed) return "DeathConfirmed";
        if (state == WillState.GrantOfProbateConfirmed) return "GrantOfProbateConfirmed";
        if (state == WillState.Closed) return "Closed";

        return "Unknown";
    }

    /* 
    --------------------------
        UTILS
    --------------------------
    */

    // Helper function to get substring
    function substring(
        string memory str,
        uint startIndex,
        uint endIndex
    ) private pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }

        //Helper funciton to split string for Death registry NRIC and grant of probate NRIC data
    function splitString(string memory str, string memory delimiter) internal pure returns (string[] memory) {
        bytes memory b = bytes(str);
        bytes memory delim = bytes(delimiter);

        uint count = 1;
        for (uint i = 0; i < b.length; i++) {
            if (b[i] == delim[0]) {
                count++;
            }
        }

        string[] memory parts = new string[](count);
        uint k = 0;
        uint lastIndex = 0;

        for (uint i = 0; i < b.length; i++) {
            if (b[i] == delim[0]) {
                bytes memory temporary = new bytes(i - lastIndex);
                for (uint j = lastIndex; j < i; j++) {
                    temporary[j - lastIndex] = b[j];
                }
                parts[k++] = string(temporary);
                lastIndex = i + 1;
            }
        }
        bytes memory temp = new bytes(b.length - lastIndex);
        for (uint i = lastIndex; i < b.length; i++) {
            temp[i - lastIndex] = b[i];
        }
        parts[k] = string(temp);

        return parts;
    }
}
