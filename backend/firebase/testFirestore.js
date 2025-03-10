const db = require("./firebaseAdmin.js");

async function testFirestoreConnection() {
  try {
    const testRef = db.collection("test_connection").doc("ping");
    await testRef.set({
      message: "Firestore is connected!",
      timestamp: new Date().toISOString(),
    });

    const doc = await testRef.get();
    if (doc.exists) {
      console.log("✅ Firestore is connected! Data:", doc.data());
    } else {
      console.log("❌ Firestore connection failed: No document found.");
    }
  } catch (error) {
    console.error("❌ Error connecting to Firestore:", error);
  }
}

// Run test function
testFirestoreConnection();
