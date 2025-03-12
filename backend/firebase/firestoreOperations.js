const db = require("./firebaseAdmin");

async function applyForGrantOfProbate() {
  db.collection("grants_of_probate").doc("probate1").set({
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

  db.collection("grants_of_probate").doc("probate2").set({
    caseNumber: "SGP2025-00125", 
    applicantName: "Mary Chia",
    applicantNRIC: "S1234567A",  
    deceasedName: "Kenny Chia",
    deceasedNRIC: "S8654321B",  
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
}

async function addDeathCertificate() {
  try {
    const deceasedNRIC = "S7654321B";
    const deathCertRef = db.collection("death_certificate").doc(deceasedNRIC); //set up automatic id
    await deathCertRef.set({
      deceasedName: "Jane Doe",
      deceasedNRIC: deceasedNRIC, // primary key
      deceasedDOB: new Date("18 August 1998"),
      deceasedGender: "Male",
      deceasedNationality: "Singaporean",
      deathCertURL: deceasedNRIC + ".pdf",
      deathDate: new Date(),
    });
    console.log("Document ID:", deathCertRef.id);

    console.log("Death certificate document successfully created!");
  } catch (error) {
    console.error("Error creating death certificate:", error);
  }
}

const createDatabase = async () => {
  await applyForGrantOfProbate();
  await addDeathCertificate();
};

const clearDatabase = async () => {
  const collections = await db.listCollections();

  for (const collection of collections) {
    const snapshot = await collection.get();
    const batch = db.batch();

    snapshot.docs.forEach((doc) => batch.delete(doc.ref));

    await batch.commit();
    console.log(`Deleted all documents from collection: ${collection.id}`);
  }

  console.log("Database cleared successfully.");
};

module.exports = { createDatabase, clearDatabase };
