// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./willLib.sol";

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

    // Formatting function for will view
    function formatWillView(WillLib.WillData storage userWill, mapping(address => mapping(address => uint256)) storage beneficiaryAllocPercentages) internal view returns (string memory) {
        string memory willString = "Beneficiaries & Allocations:\n";
        uint256 numBeneficiaries = userWill.beneficiaries.length;
        
        for (uint256 i = 0; i < numBeneficiaries; i++) {
            address beneficiary = userWill.beneficiaries[i];
            uint256 allocation = beneficiaryAllocPercentages[userWill.owner][beneficiary];
            
            // Convert address to full hex string WITHOUT "0x" prefix
            string memory beneficiaryString = Strings.toHexString(uint256(uint160(beneficiary)), 20);
            // Remove "0x" prefix
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
}