const { expect } = require("chai");
const { ethers } = require("hardhat");


describe("Will", function() {
    let Will;
    let will;
    let owner, beneficiary1, beneficiary2, editor1, editor2, others;

    // Deploy Will
    beforeEach(async function() {
        [owner, beneficiary1, beneficiary2, editor1, editor2, ...others] = await ethers.getSigners();

        Will = await ethers.getContractFactory("Will");
        will = await Will.connect(owner).deploy();
        await will.waitForDeployment();

    
    });

    it("Should create a will successfully", async function () {
        await will.createWill(owner.address);
        const willData = await will.getWillData(owner.address);
        expect(willData.owner).to.equal(owner.address);
        expect(willData.beneficiaries).to.be.an('array').that.is.empty;
        expect(willData.state).to.equal(0); // WillState.InCreation
    }); 

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
        console.log(willString);          
        // Check if the returned string matches the expected string exactly
        expect(willString).to.equal(expectedWill);
    });

    it("Should add an editor successfully", async function () {
        await will.addEditor(owner.address, editor1.address);
        const isEditor = await will.authorizedEditors[owner.adress][editor1.address];
        expect(isEditor).to.equal(true);
    });
});