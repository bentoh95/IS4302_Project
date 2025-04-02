// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library WillLib {
    enum WillState {InCreation, InExecution, DeathConfirmed,
        GrantOfProbateConfirmed, Closed} // TODO: change InExecution state to GrantOfProbateConfirmed?
//  enum Role { Viewer, Editor }
    
    struct WillData {
        address owner;
        string nric;
        address[] beneficiaries;
        uint256 digitalAssets;
        WillState state;
        address residualBeneficiary;
        uint256[] assetIds;
    }
    
    // Helper function for validating beneficiary allocation percentages // TODO: why are we not using this !?!?!
    function validateAllocations(uint256[] memory allocations) internal pure returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < allocations.length; i++) {
            require(allocations[i] > 0, "Allocation percentage must be greater than 0");
            total += allocations[i];
        }
        require(total <= 100, "Total allocation exceeds 100%");
        return total;
    }
    
    // Helper function to calculate remaining percentage
    function calculateRemainingPercentage(uint256 totalAllocated) internal pure returns (uint256) {
        return 100 - totalAllocated;
    }

    // Helper function to check if a beneficiary exists in the array
    function beneficiaryExists(address[] memory beneficiaries, address beneficiary) internal pure returns (bool) {
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            if (beneficiaries[i] == beneficiary) {
                return true;
            }
        }
        return false;
    }
    
    // Helper function to remove a beneficiary from an array
    function removeBeneficiaryFromArray(address[] storage beneficiariesArray, address beneficiary) internal returns (bool) {
        uint256 len = beneficiariesArray.length;
        for (uint256 j = 0; j < len; j++) {
            if (beneficiariesArray[j] == beneficiary) {
                beneficiariesArray[j] = beneficiariesArray[len - 1];
                beneficiariesArray.pop();
                return true;
            }
        }
        return false;
    }
    
    // Helper function to calculate asset distribution
    function calculateAssetDistribution(uint256 totalAssets, uint256 allocationPercentage) internal pure returns (uint256) {
        return (totalAssets * allocationPercentage) / 100;
    }

//Helper funciton to split string for Death registry NRIC and grant of probate NRIC data
    function splitString(
        string memory str,
        string memory delimiter
    ) internal pure returns (string[] memory) {
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

    /// @dev Helper: sums the allocations for all current beneficiaries.
    function getTotalAllocation(
        mapping(address => mapping(address => uint256)) storage beneficiaryAllocPercentages,
        address owner,
        address[] memory beneficiaries
    )
        internal
        view
        returns (uint256 total)
    {
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            total += beneficiaryAllocPercentages[owner][beneficiaries[i]];
        }
    }

    /**
     * @dev Adds new beneficiaries to the willData.beneficiaries array, updates their allocations,
     *      and ensures the leftover (if any) is assigned to the residualBeneficiary.
     */
    function addBeneficiaries(
        WillData storage willData,
        mapping(address => mapping(address => uint256)) storage beneficiaryAllocPercentages,
        address owner,
        address[] memory newBeneficiaries,
        uint256[] memory newPercentages
    )
        internal
    {
        require(newBeneficiaries.length == newPercentages.length, "Mismatched input arrays");

        // Sum up the old total
        uint256 oldTotal = getTotalAllocation(beneficiaryAllocPercentages, owner, willData.beneficiaries);

        // Calculate new total
        uint256 newTotal = oldTotal;
        for (uint256 i = 0; i < newBeneficiaries.length; i++) {
            require(newPercentages[i] > 0, "Allocation must be greater than 0");

            // If brand new, push to the beneficiaries array
            if (beneficiaryAllocPercentages[owner][newBeneficiaries[i]] == 0) {
                willData.beneficiaries.push(newBeneficiaries[i]);
            }
            newTotal += newPercentages[i];
        }
        require(newTotal <= 100, "Total allocation exceeds 100%");

        // Update the mapping and emit events in the main contract
        for (uint256 i = 0; i < newBeneficiaries.length; i++) {
            beneficiaryAllocPercentages[owner][newBeneficiaries[i]] = newPercentages[i];
        }

        // Assign leftover to the residual beneficiary if <100% total
        uint256 remainingPercentage = calculateRemainingPercentage(newTotal);
        if (remainingPercentage > 0) {
            address residual = willData.residualBeneficiary;
            // If the residual beneficiary is not in the list or has 0% so far, push or set it
            if (beneficiaryAllocPercentages[owner][residual] == 0) {
                willData.beneficiaries.push(residual);
            }
            beneficiaryAllocPercentages[owner][residual] += remainingPercentage;
        }
    }

    /**
     * @dev Removes a list of beneficiaries from the willData.beneficiaries array and updates allocations,
     *      reassigning leftover to the residual beneficiary.
     */
    function removeBeneficiaries(
        WillData storage willData,
        mapping(address => mapping(address => uint256)) storage beneficiaryAllocPercentages,
        address owner,
        address[] memory beneficiariesToRemove
    )
        internal
    {
        address residual = willData.residualBeneficiary;
        for (uint256 i = 0; i < beneficiariesToRemove.length; i++) {
            address beneficiary = beneficiariesToRemove[i];
            require(beneficiary != residual, "Cannot remove the residual beneficiary");
            require(beneficiaryAllocPercentages[owner][beneficiary] != 0, "Beneficiary does not exist");

            // Remove from mapping
            delete beneficiaryAllocPercentages[owner][beneficiary];
            // Remove from array
            removeBeneficiaryFromArray(willData.beneficiaries, beneficiary);
        }

        // Recalculate total
        uint256 newTotal = getTotalAllocation(beneficiaryAllocPercentages, owner, willData.beneficiaries);

        // Assign leftover allocation to residual if needed
        uint256 remainingPercentage = calculateRemainingPercentage(newTotal);
        if (remainingPercentage > 0) {
            if (beneficiaryAllocPercentages[owner][residual] == 0) {
                willData.beneficiaries.push(residual);
            }
            beneficiaryAllocPercentages[owner][residual] += remainingPercentage;
        }
    }

    /**
     * @dev Updates allocation percentages for multiple beneficiaries at once,
     *      reassigning leftover to the residual beneficiary.
     */
    function updateAllocations(
        WillData storage willData,
        mapping(address => mapping(address => uint256)) storage beneficiaryAllocPercentages,
        address owner,
        address[] memory beneficiariesToUpdate,
        uint256[] memory newPercentages
    )
        internal
    {
        require(beneficiariesToUpdate.length == newPercentages.length, "Mismatched input arrays");

        // Sum of current allocations among *all* existing beneficiaries
        uint256 oldTotal = getTotalAllocation(beneficiaryAllocPercentages, owner, willData.beneficiaries);

        // Adjust that total for any new changes
        uint256 newTotal = oldTotal;
        for (uint256 i = 0; i < beneficiariesToUpdate.length; i++) {
            address ben = beneficiariesToUpdate[i];
            uint256 oldAlloc = beneficiaryAllocPercentages[owner][ben];
            uint256 newAlloc = newPercentages[i];
            require(newAlloc > 0, "Allocation must be > 0");

            newTotal = newTotal - oldAlloc + newAlloc;
        }
        require(newTotal <= 100, "Total allocation exceeds 100%");

        // Now actually update them in the mapping
        for (uint256 i = 0; i < beneficiariesToUpdate.length; i++) {
            beneficiaryAllocPercentages[owner][beneficiariesToUpdate[i]] = newPercentages[i];
        }

        // Add leftover to residual
        uint256 remainingPercentage = calculateRemainingPercentage(newTotal);
        if (remainingPercentage > 0) {
            address residual = willData.residualBeneficiary;
            uint256 residualAlloc = beneficiaryAllocPercentages[owner][residual];
            if (residualAlloc == 0) {
                willData.beneficiaries.push(residual);
            }
            beneficiaryAllocPercentages[owner][residual] = residualAlloc + remainingPercentage;
        }
    }

    function updateWillStatesByNRIC(
        address[] storage allOwners,
        mapping(address => WillData) storage wills,
        string[] memory nrics,
        WillState currentState,
        WillState newState
    ) internal {
        for (uint256 i = 0; i < nrics.length; i++) {
            string memory currentNric = nrics[i];
            for (uint256 j = 0; j < allOwners.length; j++) {
                address owner = allOwners[j];
                WillData storage willData = wills[owner];
                if (
                    keccak256(bytes(willData.nric)) == keccak256(bytes(currentNric)) &&
                    willData.state == currentState
                ) {
                    willData.state = newState;
                }
            }
        }
    }

    function isViewPermitted(
        WillData storage userWill,
        mapping(address => mapping(address => uint256)) storage allocs,
        mapping(address => mapping(address => bool)) storage viewers,
        address viewerAddr
    ) internal view returns (bool) {
        if (userWill.state == WillState.InCreation) {
            return viewerAddr == userWill.owner || viewers[userWill.owner][viewerAddr];
        } else {
            if (viewers[userWill.owner][viewerAddr]) return true;
            address[] memory beneficiaries = userWill.beneficiaries;
            for (uint256 i = 0; i < beneficiaries.length; i++) {
                if (beneficiaries[i] == viewerAddr && allocs[userWill.owner][viewerAddr] > 0) {
                    return true;
                }
            }
        }
        return false;
    }

    function distributeAssetsToBeneficiaries(
        WillData storage userWill,
        mapping(address => mapping(address => uint256)) storage allocs,
        address owner
    ) internal returns (uint256 totalDistributed, uint256 remainingAssets) {
        uint256 total = userWill.digitalAssets;
        remainingAssets = total;
        address[] memory beneficiaries = userWill.beneficiaries;

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            address b = beneficiaries[i];
            uint256 percent = allocs[owner][b];
            uint256 amount = calculateAssetDistribution(total, percent);
            if (amount > 0) {
                totalDistributed += amount;
                remainingAssets -= amount;
                payable(b).transfer(amount);
            }
        }
    }

}