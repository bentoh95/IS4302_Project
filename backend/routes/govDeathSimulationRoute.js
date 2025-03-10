const express = require("express");
const router = express.Router();

const govDeathSimulationController = require("../controllers/govDeathSimulationController.js");

// Your route handlers
router.get("/test-firebase", async (req, res) => {
  res.send("This is a test route");
});

router.get(
  "/getCertificate/:deceasedNRIC",
  govDeathSimulationController.getDeathCertURL
);

module.exports = router;
