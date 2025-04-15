// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library WillLib {
    enum WillState {
        InCreation,
        DeathConfirmed,
        GrantOfProbateConfirmed,
        Closed
    }

    struct WillData {
        address owner;
        string nric;
        address[] beneficiaries;
        uint256 digitalAssets;
        WillState state;
        address residualBeneficiary;
        uint256[] assetIds;
    }

    // Helper function to calculate remaining percentage
    function calculateRemainingPercentage(
        uint256 totalAllocated
    ) internal pure returns (uint256) {
        return 100 - totalAllocated;
    }

    // Helper function to check if a beneficiary exists in the array
    function beneficiaryExists(
        address[] memory beneficiaries,
        address beneficiary
    ) internal pure returns (bool) {
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            if (beneficiaries[i] == beneficiary) {
                return true;
            }
        }
        return false;
    }

    // Helper function to remove a beneficiary from an array
    function removeBeneficiaryFromArray(
        address[] storage beneficiariesArray,
        address beneficiary
    ) internal returns (bool) {
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
    function calculateAssetDistribution(
        uint256 totalAssets,
        uint256 allocationPercentage
    ) internal pure returns (uint256) {
        return (totalAssets * allocationPercentage) / 100;
    }
}
