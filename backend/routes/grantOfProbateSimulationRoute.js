const express = require("express");
const router = express.Router();

const grantOfProbateSimulationController = require("../controllers/grantOfProbateSimulationController.js");

// Your route handlers
router.get("/test-firebase", async (req, res) => {
  res.send("This is a test route");
});

router.get(
  "/getGrantOfProbate/:deceasedNRIC",
  grantOfProbateSimulationController.getGrantOfProbateURL
);

router.get(
  "/confirmGrantOfProbate/:deceasedNRIC",
  grantOfProbateSimulationController.confirmGrantOfProbate
);

router.get("/getAllGrantOfProbateToday", grantOfProbateSimulationController.getGrantOfProbateToday);

module.exports = router;
