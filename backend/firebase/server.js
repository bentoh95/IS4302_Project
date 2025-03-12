const express = require("express");
const admin = require("firebase-admin");
const moment = require("moment"); // For date manipulation

// Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert(require("./serviceAccountKey.json")),
  databaseURL: "https://is4302-ed891.firebaseio.com"
});

// Create Express app
const app = express();

// Get Firestore instance
const db = admin.firestore();

// Define the API endpoint
app.get("/api/grants-of-probate/past-week", async (req, res) => {
  try {
    // Calculate the date 7 days ago
    const weekAgo = moment().subtract(7, "days").toDate();

    // Query Firestore for documents created in the past week
    const snapshot = await db
      .collection("grants_of_probate")
      .where("grantDate", ">=", weekAgo)
      .get();

    // Check if any documents are found
    if (snapshot.empty) {
      return res.status(404).send("No documents found for the past week.");
    }

    // Format documents into an array
    const grants = snapshot.docs.map(doc => doc.data());

    // Send response with the retrieved data
    res.json(grants);
  } catch (error) {
    console.error("Error retrieving documents:", error);
    res.status(500).send("An error occurred while retrieving the data.");
  }
});

// Start the server
const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
