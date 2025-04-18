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

    function stateToString(WillState state) internal pure returns (string memory) {
        if (state == WillState.InCreation)            return "InCreation";
        if (state == WillState.DeathConfirmed)        return "DeathConfirmed";
        if (state == WillState.GrantOfProbateConfirmed) return "GrantOfProbateConfirmed";
        if (state == WillState.Closed)                return "Closed";
        return "Unknown";
    }

    function isBeneficiary(
        mapping(address => uint256) storage allocPercent,
        address beneficiary
    ) internal view returns (bool) {
        return allocPercent[beneficiary] > 0;
    }

    function rebalanceAdd(
        WillData storage will,
        mapping(address => uint256) storage alloc,
        address[] memory bens,
        uint256[] memory pcts
    ) internal returns (uint256 newTotal) {
        require(bens.length == pcts.length, "Mismatched input arrays");

        // 1. current total
        for (uint256 i = 0; i < will.beneficiaries.length; i++) {
            newTotal += alloc[will.beneficiaries[i]];
        }

        // 2. apply updates
        for (uint256 i = 0; i < bens.length; i++) {
            require(pcts[i] > 0, "Allocation must be >0");

            if (alloc[bens[i]] == 0) {
                will.beneficiaries.push(bens[i]);           // brand‑new beneficiary
            }

            newTotal = newTotal - alloc[bens[i]] + pcts[i];
            alloc[bens[i]] = pcts[i];
        }

        require(newTotal <= 100, "Total allocation exceeds 100%");

        // 3. residual beneficiary
        uint256 residualPct = calculateRemainingPercentage(newTotal);
        if (residualPct > 0) {
            address residual = will.residualBeneficiary;
            if (alloc[residual] == 0) {
                will.beneficiaries.push(residual);
            }
            alloc[residual] += residualPct;
        }
    }

 function rebalanceRemove(
        WillData storage will,
        mapping(address => uint256) storage alloc,
        address[] memory toRemove
    ) internal returns (uint256 newTotal) {
        address residual = will.residualBeneficiary;

        // 1. delete allocations & array slots
        for (uint256 i = 0; i < toRemove.length; i++) {
            require(toRemove[i] != residual, "Cannot remove the residual beneficiary");
            require(alloc[toRemove[i]] > 0, "Beneficiary not found");

            alloc[toRemove[i]] = 0;
            removeBeneficiaryFromArray(will.beneficiaries, toRemove[i]);
        }

        // 2. recalc total
        for (uint256 i = 0; i < will.beneficiaries.length; i++) {
            newTotal += alloc[will.beneficiaries[i]];
        }

        // 3. give leftovers to residual
        uint256 residualPct = calculateRemainingPercentage(newTotal);
        if (residualPct > 0) {
            if (alloc[residual] == 0) {
                will.beneficiaries.push(residual);
            }
            alloc[residual] += residualPct;
        }
    }
}
