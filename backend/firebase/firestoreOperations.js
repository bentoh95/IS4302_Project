const db = require("./firebaseAdmin");

// Example: Add a grant of probate document
db.collection("grants_of_probate").doc("S8654321B").set({
  caseNumber: "SGP2025-00124", 
  applicantName: "John Smith",
  applicantNRIC: "S2234567A",  
  deceasedName: "Jane Smith",
  deceasedNRIC: "S8654321B",  
  grantDate: new Date(),  
  court: "Family Justice Courts of Singapore",
  approved: true,  
  documentURL: "https://example.com/Jane/fake-grant-of-probate.pdf"  // Dummy file URL
})
.then(() => {
  console.log("Grant of probate document successfully written!");
})
.catch((error) => {
  console.error("Error writing document: ", error);
});

// Example: Add a grant of probate document
db.collection("grants_of_probate").doc("S7654321B").set({
  caseNumber: "SGP2025-00125", 
  applicantName: "Mary Chia",
  applicantNRIC: "S1234567A",  
  deceasedName: "Kenny Chia",
  deceasedNRIC: "S7654321B",  
  grantDate: new Date(),  
  court: "Family Justice Courts of Singapore",
  approved: true,  
  documentURL: "https://example.com/Kenny/fake-grant-of-probate.pdf"  // Dummy file URL
})
.then(() => {
  console.log("Grant of probate document successfully written!");
})
.catch((error) => {
  console.error("Error writing document: ", error);
});

