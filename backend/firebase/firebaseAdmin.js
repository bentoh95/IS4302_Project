const admin = require("firebase-admin");

// Load service account key JSON file
const serviceAccount = require("./serviceAccountKey.json");

// Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://is4302-ed891.firebaseio.com"
});

// Export Firestore instance
const db = admin.firestore();

module.exports = db;
