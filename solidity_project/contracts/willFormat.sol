// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./willLib.sol";
import "./AssetRegistry.sol";

library WillFormat {
    // Helper function to get substring
    function substring(string memory str, uint startIndex, uint endIndex) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for(uint i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }

    //Helper function to split string for Death registry NRIC and grant of probate NRIC data
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
    
    // Formatting function for will view
    function formatWillView(
        AssetRegistry assetRegistry,
        WillLib.WillData storage userWill,
        mapping(address => mapping(address => uint256)) storage beneficiaryAllocPercentages
    ) internal view returns (string memory) {
        string memory willString = "=== DIGITAL ASSETS ===\nBeneficiaries & Allocations:\n";

        uint256 numBeneficiaries = userWill.beneficiaries.length;
        for (uint256 i = 0; i < numBeneficiaries; i++) {
            address beneficiary = userWill.beneficiaries[i];
            uint256 allocation = beneficiaryAllocPercentages[userWill.owner][beneficiary];

            string memory beneficiaryString = Strings.toHexString(uint256(uint160(beneficiary)), 20);
            beneficiaryString = substring(beneficiaryString, 2, bytes(beneficiaryString).length);

            willString = string(
                abi.encodePacked(
                    willString,
                    "- ", beneficiaryString, " -> ", Strings.toString(allocation), "%\n"
                )
            );
        }

        willString = string(abi.encodePacked(
            willString,
            "Total Digital Assets (Wei): ",
            Strings.toString(userWill.digitalAssets),
            "\n\n"
        ));

        willString = string(abi.encodePacked(
            willString,
            "=== PHYSICAL ASSETS ===\n"
        ));

        for (uint256 i = 0; i < userWill.assetIds.length; i++) {
            uint256 assetId = userWill.assetIds[i];
            AssetRegistry.AssetInfo memory asset = assetRegistry.getAssetData(assetId);

            willString = string(abi.encodePacked(
                willString,
                "Asset ID: ", Strings.toString(assetId), "\n",
                "Description: ", asset.description, "\n",
                "Value: ", Strings.toString(asset.value), "\n"
            ));

            for (uint256 j = 0; j < asset.beneficiaries.length; j++) {
                address beneficiary = asset.beneficiaries[j];
                uint256 allocation = assetRegistry.getBeneficiaryAllocation(assetId, beneficiary); 

                string memory beneficiaryString = Strings.toHexString(uint256(uint160(beneficiary)), 20);
                beneficiaryString = substring(beneficiaryString, 2, bytes(beneficiaryString).length);

                willString = string(
                    abi.encodePacked(
                        willString,
                        "- ", beneficiaryString, " -> ", Strings.toString(allocation), "%\n"
                    )
                );
                
                if (i < userWill.assetIds.length - 1) {
                    willString = string(abi.encodePacked(willString, "\n"));
                }
            }

            willString = string(abi.encodePacked(willString, "\n")); // space between assets
        }

        return willString;
    }
    
    // Format distribution details
    function formatDistributionDetails(
        address[] memory beneficiaries, 
        mapping(address => mapping(address => uint256)) storage beneficiaryAllocPercentages,
        address owner,
        uint256 totalAssets,
        uint256 remainingAssets
    ) internal view returns (string memory) {
        string memory distributionDetails = "Asset Distribution Details:\n";
        
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            address beneficiary = beneficiaries[i];
            uint256 allocationPercentage = beneficiaryAllocPercentages[owner][beneficiary];
            uint256 amountToPay = WillLib.calculateAssetDistribution(totalAssets, allocationPercentage);
            
            if (amountToPay > 0) {
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
        
        return distributionDetails;
    }

    function collectAssetDistributionProofs(
        AssetRegistry assetRegistry,
        uint256[] storage assetIds
    )
        internal
        view
        returns (
            uint256[] memory ids,
            bool[] memory executed,
            address[][] memory beneficiaries,
            uint256[][] memory tokenIds,
            uint256[][] memory shares
        )
    {
        uint256 len = assetIds.length;
        ids            = assetIds;
        executed       = new bool[](len);
        beneficiaries  = new address[][](len);
        tokenIds       = new uint256[][](len);
        shares         = new uint256[][](len);

        for (uint256 i = 0; i < len; i++) {
            uint256 id = ids[i];
            (
                bool isExec,
                address[] memory bens,
                uint256[] memory tIds,
                uint256[] memory pct
            ) = assetRegistry.getAssetDistributionProof(id);

            executed[i]      = isExec;
            beneficiaries[i] = bens;
            tokenIds[i]      = tIds;
            shares[i]        = pct;
        }
    }
}