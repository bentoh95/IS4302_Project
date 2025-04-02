// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library WillTypes {
    enum WillState {
        InCreation,
        InExecution,
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
}
