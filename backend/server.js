const express = require("express");

const app = express();
const PORT = process.env.PORT || 3001;

// Import Routes
const grantOfProbateRoutes = require("./routes/grantOfProbateSimulationRoute.js");
const govDeathRoutes = require("./routes/govDeathSimulationRoute.js");

// Use Routes
app.use("/api", grantOfProbateRoutes);
app.use("/api", govDeathRoutes);

// Start Server
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
