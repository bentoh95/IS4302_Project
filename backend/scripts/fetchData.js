// scripts/fetchData.js
const db = require("../firebase/firebaseAdmin"); 

async function fetchDeathCertificate() {
  try {
    const snapshot = await db.collection("death_certificate").get();
    snapshot.forEach((doc) => {
      console.log(doc.id, "=>", doc.data());
    });
    console.log("✅ Firebase data fetch completed!");
  } catch (error) {
    console.error("❌ Error fetching data:", error);
    process.exit(1); 
  }
}

fetchDeathCertificate();
