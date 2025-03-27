const { expect } = require("chai");
const { ethers } = require("hardhat");


describe("Will", function() {
    let Will;
    let will;
    let owner, beneficiary1, beneficiary2, editor1, editor2, viewer1, viewer2, nonOwner, others;

    // Deploy Will
    beforeEach(async function() {
        [owner, beneficiary1, beneficiary2, editor1, editor2, viewer1, viewer2, nonOwner, ...others] = await ethers.getSigners();

        Will = await ethers.getContractFactory("Will");
        will = await Will.connect(owner).deploy();
        await will.waitForDeployment();
    });

    it("Should create a will successfully", async function () {
        await will.createWill(owner.address);
        const willData = await will.getWillData(owner.address);
        expect(willData.owner).to.equal(owner.address);
        expect(willData.beneficiaries).to.be.an('array').that.is.empty;
        expect(willData.digitalAssets).to.equal(0);
        expect(willData.state).to.equal(0); // WillState.InCreation
    }); 

    /* it("Should add a beneficiary successfully", async function () {
        await will.createWill(owner.address);

        // Add beneficiary with an allocation of 100
        await will.addBeneficiary(owner.address, beneficiary1.address, 100);

        // Await the result of getBeneficiaryAllocationPercentage to get the actual allocation
        const allocation = await will.getBeneficiaryAllocationPercentage(owner.address, beneficiary1.address);

        // Assert that the allocation is 100
        expect(allocation).to.equal(100);
    }); */

    it("Should add beneficiaries successfully", async function () {
        await will.createWill(owner.address);
        // Add multiple beneficiaries with their allocations
        const beneficiaries = [beneficiary1.address, beneficiary2.address];
        const allocations = [20, 50];
        await will.addBeneficiaries(owner.address, beneficiaries, allocations);
        // Check if the allocations are set correctly
        const allocation1 = await will.getBeneficiaryAllocationPercentage(owner.address, beneficiary1.address);
        const allocation2 = await will.getBeneficiaryAllocationPercentage(owner.address, beneficiary2.address);
        expect(allocation1).to.equal(20);
        expect(allocation2).to.equal(50);
    });
    

    /* it("Should update the allocation for a beneficiary", async function () { 
        // Create a will for the owner 
        await will.createWill(owner.address); 
        // Add a beneficiary with an initial allocation 
        const initialAllocation = 100; await will.addBeneficiary(owner.address, beneficiary1.address, initialAllocation); 
        // Update the allocation for the beneficiary 
        const updatedAllocation = 200; await will.updateAllocation(owner.address, beneficiary1.address, updatedAllocation); 
        const allocation = await will.getBeneficiaryAllocationPercentage(owner.address, beneficiary1.address);
        expect(allocation).to.equal(200);
    }); */

    it("Should update the allocation for a beneficiary", async function () { 
        // Create a will for the owner 
        await will.createWill(owner.address); 
        // Add a beneficiary with an initial allocation 
        const beneficiaries = [beneficiary1.address, beneficiary2.address];
        const initialAllocations = [10, 60];
        const updatedAllocations = [20, 70];
        await will.addBeneficiaries(owner.address, beneficiaries, initialAllocations);
        // Update allocations
        await will.updateAllocations(owner.address, beneficiaries, updatedAllocations);
        const allocation1 = await will.getBeneficiaryAllocationPercentage(owner.address, beneficiary1.address);
        const allocation2 = await will.getBeneficiaryAllocationPercentage(owner.address, beneficiary2.address);
        expect(allocation1).to.equal(20);
        expect(allocation2).to.equal(70);
    });

    /* it("Should remove beneficiary", async function () { 
        // Create a will for the owner 
        await will.createWill(owner.address); 
        // Add a beneficiary with an initial allocation 
        const initialAllocation = 100; await will.addBeneficiary(owner.address, beneficiary1.address, initialAllocation); 
        // Remove the beneficiary 
        await will.removeBeneficiary(owner.address, beneficiary1.address);
        const allocation = await will.getBeneficiaryAllocationPercentage(owner.address, beneficiary1.address);
        expect(allocation).to.equal(0); 
    }); */

    it("Should remove beneficiary", async function () { 
        await will.createWill(owner.address);
        // Add multiple beneficiaries with their allocations
        const beneficiaries = [beneficiary1.address, beneficiary2.address];
        const allocations = [20, 50];
        await will.addBeneficiaries(owner.address, beneficiaries, allocations); 
        // Remove one beneficiary 
        const beneficiariesToRemove = [beneficiary1.address];
        await will.removeBeneficiaries(owner.address, beneficiariesToRemove);
        const allocation1 = await will.getBeneficiaryAllocationPercentage(owner.address, beneficiary1.address);
        const allocation2 = await will.getBeneficiaryAllocationPercentage(owner.address, beneficiary2.address);
        expect(allocation1).to.equal(0); 
        expect(allocation2).to.equal(50); // Other allocation should be unaffected
    });

    it("Should fund will successfully", async function () {
        await will.createWill(owner.address);
        await will.fundWill(owner.address, {value: 100});
        const digitalAssets = await will.getDigitalAssets(owner.address);
        expect(digitalAssets).to.equal(100);
    });

    // I have no idea how to check payments without running into errors
    it("Should distribute assets correctly and make payments", async function () {
        console.log("=== Starting distributeAssets test ===")
        // Create will
        await will.createWill(owner.address);

        // Add beneficiaries and their allocations
        const beneficiaries = [beneficiary1.address, beneficiary2.address];
        const allocations = [30, 50]; // Allocations as percentages
        console.log("Beneficiaries:", beneficiaries); // Log beneficiaries' addresses
        
        await will.addBeneficiaries(owner.address, beneficiaries, allocations);

        // Fund the will with 100 units
        const fundAmount = ethers.parseEther("1.0"); 
        await will.fundWill(owner.address, { value: fundAmount });

        // Check that the assets have been funded correctly
        const digitalAssets = await will.getDigitalAssets(owner.address);
        expect(digitalAssets).to.equal(fundAmount, "The fund amount was not set correctly.");

        // Calculate expected amounts
        const expectedAmount1 = (fundAmount * 30n) / 100n;
        const expectedAmount2 = (fundAmount * 50n) / 100n;
        const expectedRemaining = fundAmount - expectedAmount1 - expectedAmount2;

        // Log expected amounts
        console.log("Expected Amounts:", expectedAmount1, expectedAmount2, expectedRemaining);

        // Log the contract balance before distribution
        const contractBalanceBefore = await ethers.provider.getBalance(await will.getAddress());
        console.log("Contract balance before distribution:", contractBalanceBefore.toString());

        // Initial balances (in terms of units)
        const initialBalance1 = await ethers.provider.getBalance(beneficiary1.address);
        const initialBalance2 = await ethers.provider.getBalance(beneficiary2.address);

        // Log initial balances
        console.log("Initial Balances:", initialBalance1, initialBalance2);

        // Distribute assets
        const tx = await will.distributeAssets(owner.address);
        const receipt = await tx.wait(); // Wait for the transaction to be mined

        // Log the contract balance after distribution
        const contractBalanceAfter = await ethers.provider.getBalance(await will.getAddress());
        console.log("Contract balance after distribution:", contractBalanceAfter.toString());

        // Final balances after distribution
        const finalBalance1 = await ethers.provider.getBalance(beneficiary1.address);
        const finalBalance2 = await ethers.provider.getBalance(beneficiary2.address);

        // Log final balances after distribution
        console.log("Final Balances:", finalBalance1, finalBalance2);

        // Calculate received amounts as regular numbers
        const receivedAmount1 = finalBalance1 - initialBalance1;
        const receivedAmount2 = finalBalance2 - initialBalance2;

        // Log the received amounts
        console.log(`Beneficiary1 received: ${receivedAmount1} units`);
        console.log(`Beneficiary2 received: ${receivedAmount2} units`);

        // Verify that the received amounts are correct
        // expect(receivedAmount1).to.be.closeTo(expectedAmount1, 1);
        // expect(receivedAmount2).to.be.closeTo(expectedAmount2, 1);
        expect(receivedAmount1).to.equal(expectedAmount1);
        expect(receivedAmount2).to.equal(expectedAmount2);


        // Check remaining assets in the will after distribution
        const remainingAssets = await will.getDigitalAssets(owner.address);
        expect(remainingAssets).to.equal(expectedRemaining);

        // Log the remaining assets for verification
        console.log(`Remaining assets: ${remainingAssets} units`);
        console.log("=== Ending distributeAssets test ===")
    });
    
    
    

    /* it("Should return correct will details", async function () {
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
    }); */

    it("Should return correct will details", async function () {
        console.log("=== Starting Should return correct will details test ===")
        await will.createWill(owner.address);
        // Add multiple beneficiaries with their allocations
        const beneficiaries = [beneficiary1.address, beneficiary2.address];
        const allocations = [20, 50];
        await will.addBeneficiaries(owner.address, beneficiaries, allocations);
        await will.fundWill(owner.address, {value: 100});
        // Call viewWill function to get the will string
        const willString = await will.viewWill(owner.address);
    
        // Construct the expected string based on your logic
        const expectedWill = `Beneficiaries & Allocations:\n- ${beneficiary1.address.toLowerCase().substring(2)} -> 20\n- ${beneficiary2.address.toLowerCase().substring(2)} -> 50\nTotal Digital Assets: 100\n`;
 
        console.log(willString);          
        // Check if the returned string matches the expected string exactly
        expect(willString).to.equal(expectedWill);
    });

    it("Should add an editor successfully", async function () {
        await will.createWill(owner.address);
        await will.addEditor(owner.address, editor1.address);
        const editorExists = await will.isAuthorisedEditorExist(owner.address, editor1.address);
        expect(editorExists).to.equal(true);
    });

    it("Should remove an editor successfully", async function () {
        await will.createWill(owner.address);
        await will.addEditor(owner.address, editor1.address);
        await will.removeEditor(owner.address, editor1.address);
        const editorExists = await will.isAuthorisedEditorExist(owner.address, editor1.address);
        expect(editorExists).to.equal(false);
    });

    it("Should revert if adding the same editor twice", async function () {
        await will.createWill(owner.address);
        await will.addEditor(owner.address, editor1.address);
        await expect(will.addEditor(owner.address, editor1.address)).to.be.revertedWith("Editor already exists");
    });

    it("Should revert if trying to remove an editor who does not exist", async function () {
        await will.createWill(owner.address);
        await expect(will.removeEditor(owner.address, editor1.address)).to.be.revertedWith("Editor not found");
    });
      
    it("Should revert if a non-owner tries to remove an editor", async function () {
        await will.createWill(owner.address);
        await will.addEditor(owner.address, editor1.address);
        await expect(will.connect(nonOwner).removeEditor(owner.address, editor1.address)).to.be.revertedWith("Not the owner");
    });

    it("should revert if adding invalid editor address", async function () {
        await will.createWill(owner.address);
        const zeroAddress = ethers.ZeroAddress;
        await expect(
            will.addEditor(owner.address, zeroAddress)
        ).to.be.revertedWith("Invalid editor address");
    });

    it("Should add a viewer successfully", async function () {
        await will.createWill(owner.address);
        await will.addViewer(owner.address, viewer1.address);
        const viewerExists = await will.isAuthorisedViewer(owner.address, viewer1.address);
        expect(viewerExists).to.equal(true);
    });

    it("Should remove a viewer successfully", async function () {
        await will.createWill(owner.address);
        await will.addViewer(owner.address, viewer1.address);
        await will.removeViewer(owner.address, viewer1.address);
        const viewerExists = await will.isAuthorisedViewer(owner.address, viewer1.address);
        expect(viewerExists).to.equal(false);
    });

    it("Should revert if adding the same viewer twice", async function () {
        await will.createWill(owner.address);
        await will.addViewer(owner.address, viewer1.address);
        await expect(will.addViewer(owner.address, viewer1.address)).to.be.revertedWith("Viewer already exists");
    });

    it("Should revert if trying to remove an viewer who does not exist", async function () {
        await will.createWill(owner.address);
        await expect(will.removeViewer(owner.address, viewer1.address)).to.be.revertedWith("Viewer not found");
    });

    it("Should allow the viewer with permission to call WillViewForBeneficiaries if will is InCreation (owner check)", async function () {
        await will.createWill(owner.address);
        await will.addViewer(owner.address, viewer1.address);
        const beneficiaries = [beneficiary1.address, beneficiary2.address];
        const allocations = [20, 50];
        await will.addBeneficiaries(owner.address, beneficiaries, allocations);

        const viewerExists = await will.isAuthorisedViewer(owner.address, viewer1.address);
        expect(viewerExists).to.equal(true);

        const result = await will.connect(viewer1).WillViewForBeneficiaries(owner.address);
        expect(result).to.include("Beneficiaries & Allocations:");
    });
  
    it("Should not allow the viewer without permission to call WillViewForBeneficiaries if will is InCreation (owner check)", async function () {
        await will.createWill(owner.address);
        await expect(
            will.connect(viewer2).WillViewForBeneficiaries(owner.address)
        ).to.be.revertedWith("Not authorized to view this will (InCreation)");
    });
});