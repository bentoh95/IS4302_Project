// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./WillTypes.sol";
import "./WillUtils.sol";

library WillAllocation {
    using WillTypes for WillTypes.WillData;
    using WillUtils for *;

    /**
     * @dev Returns the sum of all allocation percentages for the given owner's current beneficiaries.
     */
    function getTotalAllocation(
        mapping(address => mapping(address => uint256)) storage beneficiaryAllocPercentages,
        address owner,
        address[] memory beneficiaries
    ) internal view returns (uint256 total) {
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            total += beneficiaryAllocPercentages[owner][beneficiaries[i]];
        }
    }

    /**
     * @dev Adds new beneficiaries with new allocations. Reassign leftover to residual beneficiary if total < 100%.
     */
    function addBeneficiaries(
        WillTypes.WillData storage willData,
        mapping(address => mapping(address => uint256)) storage beneficiaryAllocPercentages,
        address owner,
        address[] memory newBeneficiaries,
        uint256[] memory newPercentages
    ) internal {
        require(newBeneficiaries.length == newPercentages.length, "Mismatched input arrays");

        uint256 oldTotal = getTotalAllocation(beneficiaryAllocPercentages, owner, willData.beneficiaries);
        uint256 newTotal = oldTotal;

        // Add or update each new beneficiary
        for (uint256 i = 0; i < newBeneficiaries.length; i++) {
            require(newPercentages[i] > 0, "Allocation must be > 0");
            if (beneficiaryAllocPercentages[owner][newBeneficiaries[i]] == 0) {
                willData.beneficiaries.push(newBeneficiaries[i]);
            }
            newTotal += newPercentages[i];
        }
        require(newTotal <= 100, "Total allocation exceeds 100%");

        // Update the mapping
        for (uint256 i = 0; i < newBeneficiaries.length; i++) {
            beneficiaryAllocPercentages[owner][newBeneficiaries[i]] = newPercentages[i];
        }

        // If < 100%, leftover goes to residual
        uint256 leftover = WillUtils.calculateRemainingPercentage(newTotal);
        if (leftover > 0) {
            address residual = willData.residualBeneficiary;
            if (beneficiaryAllocPercentages[owner][residual] == 0) {
                willData.beneficiaries.push(residual);
            }
            beneficiaryAllocPercentages[owner][residual] += leftover;
        }
    }

    /**
     * @dev Removes beneficiaries from the array and reassign leftover to the residual beneficiary.
     */
    function removeBeneficiaries(
        WillTypes.WillData storage willData,
        mapping(address => mapping(address => uint256)) storage beneficiaryAllocPercentages,
        address owner,
        address[] memory beneficiariesToRemove
    ) internal {
        address residual = willData.residualBeneficiary;
        for (uint256 i = 0; i < beneficiariesToRemove.length; i++) {
            require(beneficiariesToRemove[i] != residual, "Cannot remove residual beneficiary");
            require(beneficiaryAllocPercentages[owner][beneficiariesToRemove[i]] > 0, "Beneficiary not found");

            // Remove from mapping
            delete beneficiaryAllocPercentages[owner][beneficiariesToRemove[i]];

            // Remove from array
            bool success = _removeBeneficiaryFromArray(willData.beneficiaries, beneficiariesToRemove[i]);
            require(success, "Beneficiary not in array");
        }

        // Recalculate total
        uint256 newTotal = getTotalAllocation(beneficiaryAllocPercentages, owner, willData.beneficiaries);
        uint256 leftover = WillUtils.calculateRemainingPercentage(newTotal);

        // If leftover remains, apply to residual
        if (leftover > 0) {
            if (beneficiaryAllocPercentages[owner][residual] == 0) {
                willData.beneficiaries.push(residual);
            }
            beneficiaryAllocPercentages[owner][residual] += leftover;
        }
    }

    /**
     * @dev Updates the allocation for a list of beneficiaries. Reassign leftover to residual.
     */
    function updateAllocations(
        WillTypes.WillData storage willData,
        mapping(address => mapping(address => uint256)) storage beneficiaryAllocPercentages,
        address owner,
        address[] memory beneficiariesToUpdate,
        uint256[] memory newPercentages
    ) internal {
        require(beneficiariesToUpdate.length == newPercentages.length, "Mismatched input arrays");

        uint256 oldTotal = getTotalAllocation(beneficiaryAllocPercentages, owner, willData.beneficiaries);
        uint256 newTotal = oldTotal;

        // Adjust for each beneficiary
        for (uint256 i = 0; i < beneficiariesToUpdate.length; i++) {
            address ben = beneficiariesToUpdate[i];
            uint256 oldAlloc = beneficiaryAllocPercentages[owner][ben];
            uint256 newAlloc = newPercentages[i];
            require(newAlloc > 0, "Allocation must be >0");

            newTotal = newTotal - oldAlloc + newAlloc;
        }
        require(newTotal <= 100, "Total allocation exceeds 100%");

        // Update in mapping
        for (uint256 i = 0; i < beneficiariesToUpdate.length; i++) {
            beneficiaryAllocPercentages[owner][beneficiariesToUpdate[i]] = newPercentages[i];
        }

        // leftover => residual
        uint256 leftover = WillUtils.calculateRemainingPercentage(newTotal);
        if (leftover > 0) {
            address residual = willData.residualBeneficiary;
            if (beneficiaryAllocPercentages[owner][residual] == 0) {
                willData.beneficiaries.push(residual);
            }
            beneficiaryAllocPercentages[owner][residual] += leftover;
        }
    }

    // ----------------------------------------------------------------------------------
    // INTERNAL: remove beneficiary from array
    // ----------------------------------------------------------------------------------
    function _removeBeneficiaryFromArray(address[] storage arr, address toRemove)
        private
        returns (bool)
    {
        uint256 length = arr.length;
        for (uint256 i = 0; i < length; i++) {
            if (arr[i] == toRemove) {
                arr[i] = arr[length - 1];
                arr.pop();
                return true;
            }
        }
        return false;
    }
}
