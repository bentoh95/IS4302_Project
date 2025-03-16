// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Strings.sol";

contract Will {
    enum WillState {InCreation, InExecution, Closed}
    
    struct WillData {
        address owner;
        address[] beneficiaries;
        WillState state;  
    }
    
    mapping(address => WillData) private wills;
    mapping(address => mapping(address => uint256)) private beneficiaryAlloc;
    mapping(address => mapping(address => bool)) private authorizedEditors; //willOwner address to editor address to F/T

    
    event WillCreated(address indexed owner);
    event BeneficiaryAdded(address indexed owner, address beneficiary, uint256 allocation);
    event BeneficiaryRemoved(address indexed owner, address beneficiary);
    event AllocationUpdated(address indexed owner, address beneficiary, uint256 allocation);
    event WillViewed(address indexed owner);
    
    modifier onlyOwner(address owner) {
        require(wills[owner].owner == msg.sender, "Not the owner");
        _;
    }

    modifier onlyAuthorizedEditors (address owner) {
        require(
            wills[owner].owner == msg.sender || authorizedEditors[owner][msg.sender],
            "Not authorized"
        );
        _;
    }
    
    function createWill(address owner) public {
    require(msg.sender != address(0), "Invalid sender address");
    require(wills[owner].owner == address(0), "Will already exists");
    
    address[] memory emptyArray = new address[](0);
    
    wills[owner] = WillData({
        owner: msg.sender,  // Set the owner to msg.sender
        beneficiaries: emptyArray,
        state: WillState.InCreation
    });
    
    emit WillCreated(owner);
}
    
    function addBeneficiary(address owner, address beneficiary, uint256 allocation) public onlyOwner(owner) {
        require(allocation > 0, "Need to allocate more than 0");
        require(beneficiaryAlloc[owner][beneficiary] == 0, "Allocation already exists");
        
        beneficiaryAlloc[owner][beneficiary] = allocation;
        wills[owner].beneficiaries.push(beneficiary);
        
        emit BeneficiaryAdded(owner, beneficiary, allocation);
    }
    
    function removeBeneficiary(address owner, address beneficiary) public onlyOwner(owner) {
        require(beneficiaryAlloc[owner][beneficiary] != 0, "Allocation does not exist");
        
        delete beneficiaryAlloc[owner][beneficiary];
        
        // Remove from the beneficiaries array
        uint256 len = wills[owner].beneficiaries.length;
        for (uint256 i = 0; i < len; i++) {
            if (wills[owner].beneficiaries[i] == beneficiary) {
                wills[owner].beneficiaries[i] = wills[owner].beneficiaries[len - 1];
                wills[owner].beneficiaries.pop();
                break;
            }
        }
        
        emit BeneficiaryRemoved(owner, beneficiary);
    }
    
    function updateAllocation(address owner, address beneficiary, uint256 allocation) public onlyOwner(owner) onlyAuthorizedEditors(owner) {
        require(allocation > 0, "Need to allocate more than 0");
        require(beneficiaryAlloc[owner][beneficiary] != 0, "Allocation does not exist");
        
        beneficiaryAlloc[owner][beneficiary] = allocation;
        
        
        emit AllocationUpdated(owner, beneficiary, allocation);
    }
    
    function viewWill(address owner) public onlyOwner(owner) onlyAuthorizedEditors(owner) view returns (string memory) {
        require(wills[owner].owner != address(0), "Will does not exist");
        
        WillData storage userWill = wills[owner];
        string memory willString = "Beneficiaries & Allocations:\n";
        uint256 numBeneficiaries = userWill.beneficiaries.length;
        
        for (uint256 i = 0; i < numBeneficiaries; i++) {
            address beneficiary = userWill.beneficiaries[i];
            uint256 allocation = beneficiaryAlloc[owner][beneficiary];
            
            // Convert address to full hex string WITHOUT "0x" prefix to match test expectations
            string memory beneficiaryString = Strings.toHexString(uint256(uint160(beneficiary)), 20);
            // Remove "0x" prefix to match test expectations (which removes the prefix)
            beneficiaryString = substring(beneficiaryString, 2, bytes(beneficiaryString).length);
            
            string memory allocationString = Strings.toString(allocation);
            
            willString = string(
                abi.encodePacked(
                    willString,
                    "- ", beneficiaryString, " -> ", allocationString, "\n"
                )
            );
        }
    
        // emit WillViewed(owner);
        
        return willString;
    }

    // Helper function to get substring
    function substring(string memory str, uint startIndex, uint endIndex) private pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for(uint i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }

    function addEditor(address owner, address editor) public onlyOwner(owner) {
        require(editor != address(0), "Invalid editor address");
        require(!authorizedEditors[owner][editor], "Editor already exists");
        authorizedEditors[owner][editor] = true;
    }

    function removeEditor(address owner, address editor) public onlyOwner(owner) {
        require(authorizedEditors[owner][editor], "Editor not found");
        authorizedEditors[owner][editor] = false;
    }

    function getWillData(address owner) public view returns (WillData memory) {
            return wills[owner];
        }

    function checkBeneficiaries(address owner, address beneficiary) public view returns (bool check) {
        return beneficiaryAlloc[owner][beneficiary] > 0;
        }   

    function getBeneficiaryAllocation(address owner, address beneficiary) public view returns (uint256) {
        require(wills[owner].owner != address(0), "Will does not exist");
        return beneficiaryAlloc[owner][beneficiary];
    }
}