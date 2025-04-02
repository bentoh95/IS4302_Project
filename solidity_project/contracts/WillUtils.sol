// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library WillUtils {
    /**
     * @dev Splits a string by a one-character delimiter.
     */
    function splitString(string memory str, string memory delimiter)
        internal
        pure
        returns (string[] memory)
    {
        bytes memory b = bytes(str);
        bytes memory delim = bytes(delimiter);

        uint256 count = 1;
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == delim[0]) {
                count++;
            }
        }

        string[] memory parts = new string[](count);
        uint256 k;
        uint256 lastIndex;
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == delim[0]) {
                bytes memory finalSegment = new bytes(b.length - lastIndex);
                for (uint j = lastIndex; j < b.length; j++) {
                    finalSegment[j - lastIndex] = b[j];
                }
                parts[k] = string(finalSegment);

                lastIndex = i + 1;
            }
        }

        bytes memory temp = new bytes(b.length - lastIndex);
        for (uint256 i = lastIndex; i < b.length; i++) {
            temp[i - lastIndex] = b[i];
        }
        parts[k] = string(temp);

        return parts;
    }

    /**
     * @dev Simple math for asset distribution.
     */
    function calculateAssetDistribution(uint256 totalAssets, uint256 allocationPercentage)
        internal
        pure
        returns (uint256)
    {
        return (totalAssets * allocationPercentage) / 100;
    }

    function calculateRemainingPercentage(uint256 totalAllocated)
        internal
        pure
        returns (uint256)
    {
        return 100 - totalAllocated;
    }
}
