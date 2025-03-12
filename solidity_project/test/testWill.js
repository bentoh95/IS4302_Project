const { expect } = require("chai");
const { ethers } = require("hardhat");


describe("Will", function() {
    let Will;
    let will;
    let owner, beneficiary1, beneficiary2, others;

    // Deploy Will
    beforeEach(async function() {
        [owner, beneficiary1, beneficiary2, ...others] = await ethers.getSigners();

        Will = await ethers.getContractFactory("Will");
        will = await Will.connect(owner).deploy();
        await will.waitForDeployment();

    
    });
/*
    it("Should create a will successfully", async function () {
        await will.createWill(owner.address);
        const willData = await will.viewWill(owner.address);
        expect(willData).to.include("Beneficiaries & Allocations:");
    });
*/
    it("Should create a will successfully", async function () {
        await will.createWill(owner.address);
        const willData = await will.getWillData(owner.address);
        expect(willData.owner).to.equal(owner.address);
        expect(willData.beneficiaries).to.be.an('array').that.is.empty;
        expect(willData.state).to.equal(0); // WillState.InCreation
    });
/* 
    it("Should add a beneficiary successfully", async function () {
        await will.createWill(owner.address);
        // Add beneficiary with an allocation of 100
        await will.addBeneficiary(owner.address, beneficiary1.address, 100);
        const willData = await will.getWillData(owner.address);
        
        // Convert to lowercase to match contract output
        // const beneficiaryAddress = checkBeneficiaries.address.slice(2).toLowerCase();
        expect(will.getBeneficiaryAllocation(owner.address, beneficiary1.address)).to.equal(100);
        // expect(willData).to.include("-> 100");
      });
*/ 

      it("Should add a beneficiary successfully", async function () {
        await will.createWill(owner.address);
    
        // Add beneficiary with an allocation of 100
        await will.addBeneficiary(owner.address, beneficiary1.address, 100);
    
        // Await the result of getBeneficiaryAllocation to get the actual allocation
        const allocation = await will.getBeneficiaryAllocation(owner.address, beneficiary1.address);
    
        // Assert that the allocation is 100
        expect(allocation).to.equal(100);
    });
    

    it("Should update the allocation for a beneficiary", async function () { 
    // Create a will for the owner 
    await will.createWill(owner.address); 
    // Add a beneficiary with an initial allocation 
    const initialAllocation = 100; await will.addBeneficiary(owner.address, beneficiary1.address, initialAllocation); 
    // Update the allocation for the beneficiary 
    const updatedAllocation = 200; await will.updateAllocation(owner.address, beneficiary1.address, updatedAllocation); 
    const allocation = await will.getBeneficiaryAllocation(owner.address, beneficiary1.address);
    expect(allocation).to.equal(200);
    // Fetch the will details and verify the updated allocation 
    // const updatedWill = await will.viewWill(owner.address); 
    // expect(updatedWill).to.include("-> 200"); 
    // Ensure the updated allocation is reflected 
    // expect(updatedWill).to.include(beneficiary1.address); 
    // Check if addr1 is listed 
    // expect(updatedWill).to.include(updatedAllocation.toString()); 
    // Ensure the updated allocation is correct 
    });

    it("Should remove beneficiary", async function () { 
        // Create a will for the owner 
        await will.createWill(owner.address); 
        // Add a beneficiary with an initial allocation 
        const initialAllocation = 100; await will.addBeneficiary(owner.address, beneficiary1.address, initialAllocation); 
        // Remove the beneficiary 
        await will.removeBeneficiary(owner.address, beneficiary1.address);
        const allocation = await will.getBeneficiaryAllocation(owner.address, beneficiary1.address);
        expect(allocation).to.equal(0);
        // willData = await will.viewWill(owner.address);
        // Check that the beneficiary is no longer present
        // const beneficiaryAddress = beneficiary1.address.slice(2).toLowerCase();
        // expect(willData).to.not.include(beneficiaryAddress);
        // expect(willData).to.not.include("-> 100");  
    });

    it("Should return correct will details", async function () {
        await will.createWill(owner.address);
        // Sample setup: Add beneficiaries and allocations
        await will.addBeneficiary(owner.address, beneficiary1.address, 100);
        await will.addBeneficiary(owner.address, beneficiary2.address, 50);
    
        // Call viewWill function to get the will string
        const willString = await will.viewWill(owner.address);
    
        // Construct the expected string based on your logic
        const expectedWill = `Beneficiaries & Allocations:\n- ${beneficiary1.address.toLowerCase().substring(2)} -> 100\n- ${beneficiary2.address.toLowerCase().substring(2)} -> 50\n`;            
        // Check if the returned string matches the expected string exactly
        expect(willString).to.equal(expectedWill);
    });
});