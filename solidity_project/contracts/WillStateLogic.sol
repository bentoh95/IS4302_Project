// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./WillTypes.sol";
import "./WillUtils.sol";

library WillStateLogic {
    using WillTypes for WillTypes.WillData;

    /**
     * @dev Updates the Will state from `currentState` to `newState` if the NRIC matches.
     */
    function updateWillStatesByNRIC(
        address[] storage allOwners,
        mapping(address => WillTypes.WillData) storage wills,
        string[] memory nrics,
        WillTypes.WillState currentState,
        WillTypes.WillState newState
    ) internal {
        for (uint256 i = 0; i < nrics.length; i++) {
            for (uint256 j = 0; j < allOwners.length; j++) {
                address owner = allOwners[j];
                WillTypes.WillData storage wd = wills[owner];
                if (
                    keccak256(bytes(wd.nric)) == keccak256(bytes(nrics[i])) &&
                    wd.state == currentState
                ) {
                    wd.state = newState;
                }
            }
        }
    }
}
