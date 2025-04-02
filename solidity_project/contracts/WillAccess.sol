// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./WillTypes.sol";

library WillAccess {
    using WillTypes for WillTypes.WillData;

    /**
     * @dev Checks if `viewerAddr` is allowed to view the Will.
     */
    function isViewPermitted(
        WillTypes.WillData storage userWill,
        mapping(address => mapping(address => uint256)) storage allocs,
        mapping(address => mapping(address => bool)) storage viewers,
        address viewerAddr
    ) internal view returns (bool) {
        // If still in creation, only the owner or an explicitly authorized viewer
        if (userWill.state == WillTypes.WillState.InCreation) {
            return (viewerAddr == userWill.owner || viewers[userWill.owner][viewerAddr]);
        } else {
            // After creation => either an authorized viewer or a real beneficiary
            if (viewers[userWill.owner][viewerAddr]) {
                return true;
            }
            // Check if viewerAddr is a beneficiary with a >0% allocation
            for (uint256 i = 0; i < userWill.beneficiaries.length; i++) {
                if (
                    userWill.beneficiaries[i] == viewerAddr &&
                    allocs[userWill.owner][viewerAddr] > 0
                ) {
                    return true;
                }
            }
            return false;
        }
    }
}
