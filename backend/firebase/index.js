const govDeathSimulationRoutes = require("../routes/govDeathSimulationRoute.js");
const express = require("express");
const http = require("http");
const bodyParser = require("body-parser");
//const cors = require("cors");
const db = require("./firebaseAdmin.js"); // Correctly import the Firestore instance
const app = express();
/*app.use(
  cors({
    credentials: true,
  })
);*/

app.use(bodyParser.json());
//app.use("/img", express.static("img"));
app.use("/pdf", express.static("pdf"));

app.use((req, res, next) => {
  console.log(req.path, req.method);
  next();
});

app.get("/", (req, res) => {
  res.send("HELLO)s");
});

// Example route to check Firebase connection
app.get("/test-firebase", async (req, res) => {
  try {
    // Example Firebase interaction
    const snapshot = await db.collection("death_certificate").get();
    if (snapshot.empty) {
      res.status(404).send("No documents found!");
      return;
    }
    res.status(200).send("Successfully connected to Firebase!");
  } catch (error) {
    console.error("Error connecting to Firebase:", error);
    res.status(500).send("Error connecting to Firebase.");
  }
});

// Set up HTTP server
const server = http.createServer(app);
server.listen(3000, () => {
  console.log("Server is running on http://localhost:3000");
});

app.use("/api/govDeathSimulation/", govDeathSimulationRoutes);
