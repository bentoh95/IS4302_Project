// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./WillTypes.sol";
import "./WillUtils.sol";

library WillDistribution {
    using WillTypes for WillTypes.WillData;
    using WillUtils for *;

    /**
     * @dev Transfers ETH from the Will to each beneficiary based on allocation.
     */
    function distributeAssetsToBeneficiaries(
        WillTypes.WillData storage userWill,
        mapping(address => mapping(address => uint256)) storage allocs,
        address owner
    ) internal returns (uint256 totalDistributed, uint256 remainingAssets) {
        uint256 total = userWill.digitalAssets;
        remainingAssets = total;
        address[] memory beneficiaries = userWill.beneficiaries;

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            address b = beneficiaries[i];
            uint256 percent = allocs[owner][b];
            uint256 amount = WillUtils.calculateAssetDistribution(total, percent);
            if (amount > 0) {
                totalDistributed += amount;
                remainingAssets -= amount;
                payable(b).transfer(amount);
            }
        }
    }
}
