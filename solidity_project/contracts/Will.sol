// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Strings.sol";

contract Will {
    enum WillState {InCreation, InExecution, Closed}
    
    struct WillData {
        address owner;
        address[] beneficiaries;
        uint256 digitalAssets;
        WillState state;  
        address residualBeneficiary;
    }
    
    mapping(address => WillData) private wills;
    mapping(address => mapping(address => uint256)) private beneficiaryAllocPercentages;
    mapping(address => mapping(address => bool)) private authorizedEditors; //willOwner address to editor address to F/T
    mapping(address => mapping(address => bool)) private authorizedViewers; // mapping of who has the permission to view will

    
    event WillCreated(address indexed owner);
    event BeneficiaryAdded(address indexed owner, address beneficiary, uint256 allocationPercentage);
    event BeneficiaryRemoved(address indexed owner, address beneficiary);
    event AllocationPercentageUpdated(address indexed owner, address beneficiary, uint256 allocationPercentage);
    event AssetsDistributed(address indexed owner, uint256 totalDistributed, uint256 remainingAssets);
    event WillFunded(address indexed owner, uint256 amount);

    
    /* 
    -------------------
        PERMISSIONS
    -------------------
    */
    modifier onlyOwner(address owner) {
        require(wills[owner].owner == msg.sender, "Not the owner");
        _;
    }

    modifier onlyAuthorizedEditors (address owner) {
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
        WillData storage userWill = wills[owner];
        require(userWill.owner != address(0), "Will does not exist");

        // Before death scenario
        if (userWill.state == WillState.InCreation) {
            // Only the owner or an explicitly authorizedViewer can view
            require(
                msg.sender == userWill.owner || authorizedViewers[owner][msg.sender],
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

    
    /* 
    --------------------------
        WILL FUNCTIONALITIES
    --------------------------
    */

    function createWill(address owner) public {
        require(msg.sender != address(0), "Invalid sender address");
        require(wills[owner].owner == address(0), "Will already exists");
        
        // Initialize empty array with proper syntax
        address[] memory emptyArray = new address[](0);
        
        wills[owner] = WillData({
            owner: owner,
            beneficiaries: emptyArray,
            digitalAssets: 0,
            state: WillState.InCreation,
            residualBeneficiary: address(0)
        });
        
        emit WillCreated(owner);
    }

    // Helper function for updating one beneficiary's allocation percentage.
    function updateOneAllocationPercentage(address owner, address beneficiary, uint256 allocationPercentage) public onlyAuthorizedEditors(owner) {
        require(allocationPercentage > 0, "Allocation percentage must be greater than 0"); // Cannot update someone's allocation to 0
        require(wills[owner].owner != address(0), "Will does not exist");
        
        beneficiaryAllocPercentages[owner][beneficiary] = allocationPercentage;
        emit AllocationPercentageUpdated(owner, beneficiary, allocationPercentage);
    }

    // Update multiple beneficiaries' allocation percentages by taking in an array of beneficiaries to update and an array of their respective new allocation percentages
    // Their new percentages cannot tally to more than 100%
    function updateAllocations(address owner, address[] memory beneficiariesToUpdate, uint256[] memory newPercentages) public onlyAuthorizedEditors(owner) residualBeneficiaryExists(owner){
        require(beneficiariesToUpdate.length == newPercentages.length, "Mismatched input arrays");

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
            newTotal = newTotal - beneficiaryAllocPercentages[owner][beneficiary] + newPercentages[i]; // Replace all the allocation percentages that need to be updated
        }
        
        require(newTotal <= 100, "Total allocation exceeds 100%");

        for (uint256 i = 0; i < beneficiariesToUpdate.length; i++) {
            beneficiaryAllocPercentages[owner][beneficiariesToUpdate[i]] = newPercentages[i];
            emit AllocationPercentageUpdated(owner, beneficiariesToUpdate[i], newPercentages[i]);
        }

        // Assign leftover percentage to residual beneficiary
        uint256 remainingPercentage = 100 - newTotal;
        if (remainingPercentage > 0) {
            if (beneficiaryAllocPercentages[owner][residualBeneficiary] == 0) {
                wills[owner].beneficiaries.push(residualBeneficiary); // Add residual beneficiary if not present
                beneficiaryAllocPercentages[owner][residualBeneficiary] = remainingPercentage;
                emit AllocationPercentageUpdated(owner, residualBeneficiary, remainingPercentage);
            }
            else {
                beneficiaryAllocPercentages[owner][residualBeneficiary] += remainingPercentage;
                emit BeneficiaryAdded(owner, residualBeneficiary, remainingPercentage);
            }
        }
    } 

    function addBeneficiaries(address owner, address[] memory newBeneficiaries, uint256[] memory newPercentages) public onlyAuthorizedEditors(owner) residualBeneficiaryExists(owner) {
        require(newBeneficiaries.length == newPercentages.length, "Mismatched input arrays");

        uint256 oldTotal = 0;
        address[] memory allBeneficiaries = wills[owner].beneficiaries;
        address residualBeneficiary = wills[owner].residualBeneficiary; 

        // Calculate the current total allocation
        for (uint256 i = 0; i < allBeneficiaries.length; i++) {
            oldTotal += beneficiaryAllocPercentages[owner][allBeneficiaries[i]];
        }

        uint256 newTotal = oldTotal;
        for (uint256 i = 0; i < newBeneficiaries.length; i++) {
            require(newPercentages[i] > 0, "Allocation must be greater than 0");
            if (beneficiaryAllocPercentages[owner][newBeneficiaries[i]] == 0) {
                wills[owner].beneficiaries.push(newBeneficiaries[i]); // Add them to beneficiaries[] if new
            }
            // Add new allocations
            
            newTotal += newPercentages[i];
        }
        
        // Update the allocations in the mapping
        for (uint256 i = 0; i < newBeneficiaries.length; i++) {
            beneficiaryAllocPercentages[owner][newBeneficiaries[i]] = newPercentages[i];
            emit BeneficiaryAdded(owner, newBeneficiaries[i], newPercentages[i]);
        }

        require(newTotal <= 100, "Total allocation exceeds 100%");

        // Calculate the remaining percentage for the residual beneficiary
        uint256 remainingPercentage = 100 - newTotal;

        // If the total allocation is less than 100%, assign the remaining percentage to the residual beneficiary
        if (remainingPercentage > 0) {
            // Add the residual beneficiary to the list if not already present
            if (beneficiaryAllocPercentages[owner][residualBeneficiary] == 0) {
                wills[owner].beneficiaries.push(residualBeneficiary);
                beneficiaryAllocPercentages[owner][residualBeneficiary] = remainingPercentage;
                emit BeneficiaryAdded(owner, residualBeneficiary, remainingPercentage);
            }
            else {
                beneficiaryAllocPercentages[owner][residualBeneficiary] += remainingPercentage;
                emit BeneficiaryAdded(owner, residualBeneficiary, remainingPercentage);
            }
            
        }
        
    }

    function removeBeneficiaries(address owner, address[] memory beneficiariesToRemove) public onlyAuthorizedEditors(owner) residualBeneficiaryExists(owner){
        address residualBeneficiary = wills[owner].residualBeneficiary; 

        // Check if any of the beneficiaries to be removed is the residual beneficiary
        for (uint256 i = 0; i < beneficiariesToRemove.length; i++) {
            address beneficiary = beneficiariesToRemove[i];
            require(beneficiary != residualBeneficiary, "Cannot remove the residual beneficiary");
        }
        
        for (uint256 i = 0; i < beneficiariesToRemove.length; i++) {
            address beneficiary = beneficiariesToRemove[i];
            require(beneficiaryAllocPercentages[owner][beneficiary] != 0, "Beneficiary does not exist");
            delete beneficiaryAllocPercentages[owner][beneficiary];
            
            uint256 len = wills[owner].beneficiaries.length;
            for (uint256 j = 0; j < len; j++) {
                if (wills[owner].beneficiaries[j] == beneficiary) {
                    wills[owner].beneficiaries[j] = wills[owner].beneficiaries[len - 1];
                    wills[owner].beneficiaries.pop();
                    break;
                }
            }
            emit BeneficiaryRemoved(owner, beneficiary);
        }

        // Recalculate total allocation
        uint256 newTotal = 0;
        address[] memory remainingBeneficiaries = wills[owner].beneficiaries;
        for (uint256 i = 0; i < remainingBeneficiaries.length; i++) {
            newTotal += beneficiaryAllocPercentages[owner][remainingBeneficiaries[i]];
        }

        // Assign leftover allocation to residual beneficiary
        uint256 remainingPercentage = 100 - newTotal;
        if (remainingPercentage > 0) {
            // Add residual beneficiary to list if not already present
            if (beneficiaryAllocPercentages[owner][residualBeneficiary] == 0) {
                wills[owner].beneficiaries.push(residualBeneficiary);
                beneficiaryAllocPercentages[owner][residualBeneficiary] = remainingPercentage;
                emit BeneficiaryAdded(owner, residualBeneficiary, remainingPercentage);
            }
            else {
                beneficiaryAllocPercentages[owner][residualBeneficiary] += remainingPercentage;
                emit BeneficiaryAdded(owner, residualBeneficiary, remainingPercentage);
            }
            
            
        }
    }

    // Function to add digital assets to the will
    function fundWill(address owner) external payable onlyOwner(owner) {
        require(msg.value > 0, "Must send ETH");
        wills[owner].digitalAssets += msg.value;
        emit WillFunded(owner, msg.value);
    }

    function distributeAssets(address owner) external returns (string memory) {
        // require(wills[owner].state == WillState.InExecution, "Will is not in execution mode");
        WillData storage userWill = wills[owner];        
        address[] memory beneficiaries = userWill.beneficiaries;
        require(userWill.digitalAssets > 0, "No assets to distribute");
        
        uint256 totalDistributed = 0;
        uint256 remainingAssets = userWill.digitalAssets;
        string memory distributionDetails = "Asset Distribution Details:\n";

        // Loop through array of beneficiaries, calculate amount to pay based on allocationPercentage and transfer the amount
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            address beneficiary = beneficiaries[i];
            uint256 allocationPercentage = beneficiaryAllocPercentages[owner][beneficiary];
            uint256 amountToPay = (userWill.digitalAssets * allocationPercentage) / 100;
            
            if (amountToPay > 0) {
                totalDistributed += amountToPay;
                remainingAssets -= amountToPay;
                payable(beneficiary).transfer(amountToPay);

                distributionDetails = string(
                    abi.encodePacked(
                        distributionDetails,
                        "- ", Strings.toHexString(uint256(uint160(beneficiary)), 20), 
                        " -> Allocation: ", 
                        Strings.toString(allocationPercentage), 
                        "%, Amount Paid: $", 
                        Strings.toString(amountToPay), 
                        "\n"
                    )
                );
            }
        }
        // Print undistributed assets
        if (remainingAssets > 0) {
            distributionDetails = string(
                abi.encodePacked(
                    distributionDetails,
                    "Undistributed Assets: $", 
                    Strings.toString(remainingAssets), 
                    "\n"
                )
            );
        }
        // Update remaining assets in the will
        userWill.digitalAssets = remainingAssets;
        emit AssetsDistributed(owner, totalDistributed, remainingAssets);
        // Return the distribution details string
        return distributionDetails;
    }

    function viewWill(address owner) public onlyOwner(owner) onlyAuthorizedEditors(owner) view returns (string memory) {
        require(wills[owner].owner != address(0), "Will does not exist");
        
        WillData storage userWill = wills[owner];
        string memory willString = "Beneficiaries & Allocations:\n";
        uint256 numBeneficiaries = userWill.beneficiaries.length;
        
        for (uint256 i = 0; i < numBeneficiaries; i++) {
            address beneficiary = userWill.beneficiaries[i];
            uint256 allocation = beneficiaryAllocPercentages[owner][beneficiary];
            
            // Convert address to full hex string WITHOUT "0x" prefix to match test expectations
            string memory beneficiaryString = Strings.toHexString(uint256(uint160(beneficiary)), 20);
            // Remove "0x" prefix to match test expectations (which removes the prefix)
            beneficiaryString = substring(beneficiaryString, 2, bytes(beneficiaryString).length);
            
            string memory allocationString = Strings.toString(allocation);
            
            willString = string(
                abi.encodePacked(
                    willString,
                    "- ", beneficiaryString, " -> ", allocationString, "\n"
                )
            );
        }

        string memory digitalAssetsString = Strings.toString(userWill.digitalAssets);
        willString = string(abi.encodePacked(willString, "Total Digital Assets: ", digitalAssetsString, "\n"));
    
        // emit WillViewed(owner);
        
        return willString;
    }

    // Copied same viewWill function to another function for more customisability 
    function WillViewForBeneficiaries(address owner) public view onlyViewPermitted(owner) returns (string memory) {

        WillData storage userWill = wills[owner];
        string memory willString = "Beneficiaries & Allocations:\n";
        uint256 numBeneficiaries = userWill.beneficiaries.length;

        for (uint256 i = 0; i < numBeneficiaries; i++) {
            address beneficiary = userWill.beneficiaries[i];
            uint256 allocation = beneficiaryAllocPercentages[owner][beneficiary];
            
            string memory beneficiaryString = Strings.toHexString(uint256(uint160(beneficiary)), 20);
            beneficiaryString = substring(beneficiaryString, 2, bytes(beneficiaryString).length); 

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

    function removeEditor(address owner, address editor) public onlyOwner(owner) {
        require(authorizedEditors[owner][editor], "Editor not found");
        authorizedEditors[owner][editor] = false;
    } 

    function addViewer(address owner, address viewer) public onlyOwner(owner) {
        require(viewer != address(0), "Invalid viewer address");
        require(!authorizedViewers[owner][viewer], "Viewer already exists");
        authorizedViewers[owner][viewer] = true;
    }

    function removeViewer(address owner, address viewer) public onlyOwner(owner) {
        require(authorizedViewers[owner][viewer], "Viewer not found");
        authorizedViewers[owner][viewer] = false;
    } 

    function getWillData(address owner) public view returns (WillData memory) {
            return wills[owner];
    }

    function checkBeneficiaries(address owner, address beneficiary) public view returns (bool check) {
        return beneficiaryAllocPercentages[owner][beneficiary] > 0;
        }   

    function getBeneficiaryAllocationPercentage(address owner, address beneficiary) public view returns (uint256) {
        require(wills[owner].owner != address(0), "Will does not exist");
        return beneficiaryAllocPercentages[owner][beneficiary];
    }

    function getDigitalAssets(address owner) public view returns (uint256) {
        require(wills[owner].owner != address(0), "Will does not exist");
        return wills[owner].digitalAssets;
    }

    function isAuthorisedEditorExist(address owner, address editor) public view returns (bool check) {
        require(wills[owner].owner != address(0), "Will does not exist");
        return authorizedEditors[owner][editor];
    }

    function isAuthorisedViewer(address owner, address viewer) public view returns (bool check) {
        require(wills[owner].owner != address(0), "Will does not exist");
        return authorizedViewers[owner][viewer];
    }

    function setResidualBeneficiary(address owner, address beneficiary) public onlyOwner(owner) onlyAuthorizedEditors(owner){
        require(wills[owner].state == WillState.InCreation, "Cannot modify after execution");
        require(beneficiary != address(0), "Invalid beneficiary address"); 
        wills[owner].residualBeneficiary = beneficiary;
    }

    /* 
    --------------------------
        UTILS
    --------------------------
    */

    // Helper function to get substring
    function substring(string memory str, uint startIndex, uint endIndex) private pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for(uint i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }

}